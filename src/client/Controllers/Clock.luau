--!strict
-- The day clock card (issue 288, docs/weather-sky-design.md, step 2): a dial of 24 hour segments that turns with the server time
-- of day (DayCycle.clockAt) under a fixed pointer, the phase and clock time, the countdown to the next change, the day and night
-- lengths, and the current weather as a chip. Everything it shows comes from Core/ClockView (pure, tested), Config/Phases and the
-- Env message; no clock or weather of its own. The card floats at the top right, under the income rate. Labels come from Locale.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Core = Shared:WaitForChild("Core")
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local Phases = require(Config:WaitForChild("Phases") :: ModuleScript) :: any
local DayCycle = require(Core:WaitForChild("DayCycle") :: ModuleScript) :: any
local ClockView = require(Core:WaitForChild("ClockView") :: ModuleScript) :: any
local Theme = require(script.Parent.Parent.Theme)

local Clock = {}

-- The same fixed text size as the HUD rows.
local ROW_TEXT = 14
local CARD_PADDING = 6
local GAP = 8
local DIAL = 72
local CARD_WIDTH = 150
-- The card hangs under the rate (Controllers/Hud, top row): the rate block is about RATE_BLOCK px high at full size and shrinks
-- with the screen fit. A phone (fit below SMALL_FIT) drops the day and night lengths line to stay compact.
local TOP_ROW_Y = 8
local RATE_BLOCK = 60
local SMALL_FIT = 0.8
local DAY_COLOR = Color3.fromRGB(255, 200, 0)
local NIGHT_COLOR = Color3.fromRGB(34, 52, 120)

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function textLine(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Font = Theme.fonts.body
	text.TextColor3 = Theme.colors.text
	text.TextSize = ROW_TEXT
	text.TextWrapped = true
	text.LayoutOrder = order
	text.Parent = parent
	return text
end

local function listLayout(parent: Instance, direction: Enum.FillDirection): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, if direction == Enum.FillDirection.Horizontal then GAP else 2)
	layout.Parent = parent
	return layout
end

-- Builds the card. `lang` gives the language in use. Returns `env` (the Env message handler) and `relabel` (repaint after a language change).
function Clock.build(lang: () -> string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Clock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the card is placed from the screen top, like the rate it hangs under
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	Theme.fitScreen(gui)

	local card = Instance.new("Frame")
	card.Name = "ClockCard"
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.colors.window
	card.BorderSizePixel = 0
	Theme.round(card)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, CARD_PADDING)
	padding.PaddingRight = UDim.new(0, CARD_PADDING)
	padding.PaddingTop = UDim.new(0, CARD_PADDING)
	padding.PaddingBottom = UDim.new(0, CARD_PADDING)
	padding.Parent = card
	listLayout(card, Enum.FillDirection.Vertical)

	-- The dial with the text under it.
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = 1
	row.Parent = card
	local rowLayout = listLayout(row, Enum.FillDirection.Horizontal)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local dial = Instance.new("Frame")
	dial.Name = "Dial"
	dial.BackgroundTransparency = 1
	dial.LayoutOrder = 1
	dial.Parent = row
	-- The face turns; the pointer stays at the top.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Theme.colors.iconTile
	face.BorderSizePixel = 0
	Theme.round(face, 1000)
	face.Parent = dial
	local segments = {}
	for _, segment in ClockView.segments(DayCycle.HOURS) do
		-- A holder as large as the face turns about its centre; its bar sits at the rim.
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Rotation = segment.angle
		holder.Parent = face
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.fromScale(0.5, 0.02)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = if segment.night then NIGHT_COLOR else DAY_COLOR
		bar.Parent = holder
		table.insert(segments, bar)
	end
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.fromScale(0.5, 0)
	pointer.Size = UDim2.fromOffset(4, 18)
	pointer.BackgroundColor3 = Theme.colors.bad
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 3
	pointer.Parent = dial

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.LayoutOrder = 2
	info.Parent = row
	listLayout(info, Enum.FillDirection.Vertical)
	local timeLine = textLine(info, 1)
	timeLine.Font = Theme.fonts.bold
	local changeLine = textLine(info, 2)
	local lengthsLine = textLine(info, 3)
	lengthsLine.TextColor3 = Theme.colors.textMuted

	-- The current weather, on its own line under the clock.
	local chip = Instance.new("TextLabel")
	chip.Name = "WeatherChip"
	chip.Size = UDim2.new(0, 0, 0, 0)
	chip.AutomaticSize = Enum.AutomaticSize.XY
	chip.Font = Theme.fonts.bold
	chip.TextSize = ROW_TEXT
	chip.TextColor3 = Theme.colors.textDark
	chip.TextWrapped = true
	chip.LayoutOrder = 2
	chip.Visible = false
	Theme.round(chip)
	local chipPadding = Instance.new("UIPadding")
	chipPadding.PaddingLeft = UDim.new(0, 10)
	chipPadding.PaddingRight = UDim.new(0, 10)
	chipPadding.PaddingTop = UDim.new(0, 2)
	chipPadding.PaddingBottom = UDim.new(0, 2)
	chipPadding.Parent = chip
	chip.Parent = card

	local forecastChip = chip:Clone()
	forecastChip.Name = "ForecastChip"
	forecastChip.LayoutOrder = 3
	forecastChip.Visible = false
	forecastChip.Parent = card

	-- Floating at the top right under the rate, dial above the text.
	dial.Size = UDim2.fromOffset(DIAL, DIAL)
	for _, bar in segments do
		bar.Size = UDim2.fromOffset(math.floor(DIAL * 0.12), math.floor(DIAL * 0.16))
	end
	rowLayout.FillDirection = Enum.FillDirection.Vertical
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	info.Size = UDim2.fromScale(1, 0)
	card.AnchorPoint = Vector2.new(1, 0)
	card.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	card.Parent = gui
	local function layoutFor(viewport: Vector2)
		local fit = Theme.fitFactor(viewport)
		card.Position = UDim2.new(1, -12, 0, TOP_ROW_Y + math.floor(RATE_BLOCK * fit))
		lengthsLine.Visible = fit >= SMALL_FIT
	end
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		layoutFor(camera.ViewportSize)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			layoutFor(camera.ViewportSize)
		end)
	else
		layoutFor(Vector2.new(800, 600))
	end

	local env: any = nil
	local nextWeather: string? = nil
	local shownSecond = -1
	local function paintTexts(now: number, hour: number)
		local function t(key: string, args: { [string]: any }?): string
			return Locale.t(key, lang(), args)
		end
		local lines = ClockView.lines(now, hour, if env ~= nil then env.phase else Phases[1].id, Phases, t)
		timeLine.Text = lines.time
		changeLine.Text = lines.change
		lengthsLine.Text = lines.lengths
		local rgb = if env ~= nil then ClockView.chip(env.weather) else nil
		chip.Visible = rgb ~= nil
		if rgb ~= nil then
			chip.BackgroundColor3 = color(rgb)
			chip.Text = t("weather." .. env.weather)
		end
		local forecast = ClockView.forecast(nextWeather, t)
		forecastChip.Visible = forecast ~= nil
		if forecast ~= nil then
			forecastChip.BackgroundColor3 = color(forecast.color)
			forecastChip.Text = forecast.text
		end
	end

	-- The dial every frame, the texts when the server second changes (the countdown) or Env or the language changes.
	local function update(force: boolean)
		local now = workspace:GetServerTimeNow()
		local hour = DayCycle.clockAt(now, Phases)
		face.Rotation = ClockView.angle(hour)
		local second = math.floor(now)
		if force or second ~= shownSecond then
			shownSecond = second
			paintTexts(now, hour)
		end
	end
	RunService.RenderStepped:Connect(function()
		update(false)
	end)
	update(true)

	return {
		env = function(change: any)
			env = change
			update(true)
		end,
		forecast = function(nextId: string?)
			if nextId ~= nextWeather then
				nextWeather = nextId
				update(true)
			end
		end,
		relabel = function()
			update(true)
		end,
	}
end

return Clock
