--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends (coins, rate, storage, grid level, weather, goal), and its
-- buttons (language, grid expansion) only send intents; the rest is display only. No game rules here: the grid
-- expansion comes from Delta.view (GameCore.view). The shop is the market popup (Controllers/Market). Every label comes
-- from the Locale tables in the current language: the player's locale at the start, switched by the Language button.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local ShopView = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("ShopView") :: ModuleScript
) :: any
local BoostView = require(script.Parent.BoostView)
local Clock = require(script.Parent.Clock)
local Theme = require(script.Parent.Parent.Theme)

local Hud = {}

-- A control the player cannot use right now: its text stays readable, its background fades.
local DIMMED_TEXT = 0.3
local DIMMED_BACKGROUND = 0.6
-- The panel is at most this wide; on a narrow screen it shrinks to the screen width instead.
local PANEL_MAX_WIDTH = 220
-- Every row and button uses the same fixed text size. Long text wraps onto a second line and the row grows with it.
local ROW_TEXT = 16
local ROW_MIN_HEIGHT = 22
-- A button keeps a finger-sized height on a phone.
local BUTTON_MIN_HEIGHT = 44
-- Inner padding: left and right it keeps text off the edge and off the scrollbar; top and bottom it gives wrapped lines air.
local ROW_SIDE_PADDING = 8
local ROW_VERTICAL_PADDING = 2
-- The income per second sits alone in the top right corner, large. The tutorial line is a box at the top centre.
local RATE_TEXT = 44
local TUTORIAL_TEXT = 26
local TUTORIAL_WIDTH = 680
local TUTORIAL_TOP = 72 -- below the sunshine banner (BoostView)

-- Gives a row or button the shared look: fixed text size, wrapped text, inner padding, and a height that grows with the text.
local function fitRow(control: GuiObject, minimum: number)
	control.Size = UDim2.new(1, 0, 0, minimum)
	control.AutomaticSize = Enum.AutomaticSize.Y
	local minHeight = Instance.new("UISizeConstraint")
	minHeight.MinSize = Vector2.new(0, minimum)
	minHeight.Parent = control
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, ROW_SIDE_PADDING)
	padding.PaddingRight = UDim.new(0, ROW_SIDE_PADDING)
	padding.PaddingTop = UDim.new(0, ROW_VERTICAL_PADDING)
	padding.PaddingBottom = UDim.new(0, ROW_VERTICAL_PADDING)
	padding.Parent = control
	control.BackgroundColor3 = Theme.colors.window
	control.BorderSizePixel = 0
end

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	-- A display row: no background, no corners, only outlined text on the world.
	text.BackgroundTransparency = 1
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextStrokeTransparency = 0.4
	text.TextStrokeColor3 = Theme.colors.backdrop
	text.Font = Theme.fonts.body
	text.TextColor3 = Theme.colors.text
	text.TextSize = ROW_TEXT
	text.TextWrapped = true
	text.LayoutOrder = order
	fitRow(text, ROW_MIN_HEIGHT)
	text.Parent = parent
	return text
end

local function button(parent: Instance, caption: string, order: number, onClick: () -> ()): TextButton
	local control = Instance.new("TextButton")
	control.Text = caption
	control.Font = Theme.fonts.bold
	control.TextColor3 = Theme.colors.textDark
	control.TextSize = ROW_TEXT
	control.TextWrapped = true
	control.LayoutOrder = order
	fitRow(control, BUTTON_MIN_HEIGHT)
	Theme.round(control)
	control.BackgroundColor3 = Theme.colors.accent
	control.Parent = parent
	control.Activated:Connect(onClick)
	return control
end

-- Dims a control the player cannot use right now; it still shows its caption, readable.
local function dim(control: TextButton, usable: boolean)
	control.TextTransparency = if usable then 0 else DIMMED_TEXT
	control.BackgroundTransparency = if usable then 0 else DIMMED_BACKGROUND
end

local function format(value: number): string
	return string.format("%.1f", value)
end

local short = ShopView.short

-- Builds the HUD in the player's GUI. `net` is ReplicatedStorage.Net. Returns the handlers for the server messages,
-- and `language`, which gives the language in use (the welcome screen follows it).
function Hud.build(net: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	-- The language of every label: the player's locale at the start, then whatever the Language button chose.
	local lang: string = Locale.resolve((Players.LocalPlayer :: Player).LocaleId)
	local function t(key: string, args: { [string]: any }?): string
		return Locale.t(key, lang, args)
	end
	local frame = Instance.new("ScrollingFrame")
	-- Fills the screen minus the margin, at most PANEL_MAX_WIDTH wide; the list scrolls.
	frame.Size = UDim2.new(1, -32, 1, -32)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = 6
	-- The scrollbar takes its own strip beside the rows, so it never covers their text.
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(PANEL_MAX_WIDTH, math.huge)
	widthLimit.Parent = frame
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	-- Each control gets the next layout order, so the list shows them top to bottom.
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Changes the language and paints every label again. Declared here, written below once the labels exist.
	local paint: () -> ()
	local language = button(frame, "", nextOrder(), function()
		lang = if lang == "en" then "de" else "en"
		paint()
	end)
	local coins = label(frame, nextOrder())
	local rate = Instance.new("TextLabel")
	rate.AnchorPoint = Vector2.new(1, 0)
	rate.Position = UDim2.new(1, -16, 0, 16)
	rate.Size = UDim2.fromOffset(0, 0)
	rate.AutomaticSize = Enum.AutomaticSize.XY
	rate.BackgroundTransparency = 1
	rate.Font = Theme.fonts.title
	rate.TextSize = RATE_TEXT
	rate.TextColor3 = Theme.colors.accent
	rate.TextXAlignment = Enum.TextXAlignment.Right
	rate.TextStrokeTransparency = 0.2
	rate.TextStrokeColor3 = Theme.colors.backdrop
	rate.Parent = gui
	-- The electricity price: a plain row, like the others. The control board popup (#115) can take it over: its text
	-- comes from ShopView.priceText(view.price, t), the same line the rule section of the Storage tab shows.
	local price = label(frame, nextOrder())
	local storage = label(frame, nextOrder())
	local storageHint = label(frame, nextOrder())
	local grid = label(frame, nextOrder())
	-- The day clock card with the current weather (Controllers/Clock) replaces the old weather text row.
	local clock = Clock.build(frame, nextOrder, function(): string
		return lang
	end)
	-- The Sunshine Hour button and banner, right under the clock card.
	local boost = BoostView.build(frame, nextOrder, function(): string
		return lang
	end)
	local goal = label(frame, nextOrder())
	-- The tutorial: one line for the current step and a button to skip it; both hidden when there is no step.
	-- The line sits in an opaque box with a yellow border, top centre; the box shrinks to the screen width on a phone.
	local tutorialBox = Instance.new("Frame")
	tutorialBox.Name = "TutorialBox"
	tutorialBox.AnchorPoint = Vector2.new(0.5, 0)
	tutorialBox.Position = UDim2.new(0.5, 0, 0, TUTORIAL_TOP)
	tutorialBox.Size = UDim2.fromScale(0.5, 0)
	tutorialBox.AutomaticSize = Enum.AutomaticSize.Y
	tutorialBox.BackgroundColor3 = Theme.colors.window
	tutorialBox.BorderSizePixel = 0
	tutorialBox.Visible = false
	Theme.round(tutorialBox)
	Theme.outline(tutorialBox, Theme.colors.accent, 3)
	local boxWidth = Instance.new("UISizeConstraint")
	boxWidth.MinSize = Vector2.new(260, 0)
	boxWidth.MaxSize = Vector2.new(TUTORIAL_WIDTH, math.huge)
	boxWidth.Parent = tutorialBox
	local boxPadding = Instance.new("UIPadding")
	boxPadding.PaddingLeft = UDim.new(0, 16)
	boxPadding.PaddingRight = UDim.new(0, 16)
	boxPadding.PaddingTop = UDim.new(0, 10)
	boxPadding.PaddingBottom = UDim.new(0, 10)
	boxPadding.Parent = tutorialBox
	tutorialBox.Parent = gui
	local tutorialLine = Instance.new("TextLabel")
	tutorialLine.Size = UDim2.fromScale(1, 0)
	tutorialLine.AutomaticSize = Enum.AutomaticSize.Y
	tutorialLine.BackgroundTransparency = 1
	tutorialLine.Font = Theme.fonts.bold
	tutorialLine.TextSize = TUTORIAL_TEXT
	tutorialLine.TextColor3 = Theme.colors.text
	tutorialLine.TextWrapped = true
	tutorialLine.TextXAlignment = Enum.TextXAlignment.Center
	tutorialLine.Parent = tutorialBox
	local tutorialStep = ""
	-- The line's Locale key and arguments (TutorialGuide chooses them); without a choice the step id names the text.
	local tutorialKey: string? = nil
	local tutorialArgs: { [string]: any }? = nil
	local skipArmedAt = -math.huge
	local tutorialForced = false -- the closing line shows after the tutorial is done
	local tutorialSkip: TextButton
	tutorialSkip = button(frame, "", 0, function()
		-- Two taps within three seconds skip for good; the first one only asks again.
		if os.clock() - skipArmedAt <= 3 then
			skipArmedAt = -math.huge
			local skipRemote = net:WaitForChild("TutorialSkip") :: RemoteEvent
			skipRemote:FireServer()
		else
			skipArmedAt = os.clock()
			tutorialSkip.Text = t("tutorial.skipConfirm")
			task.delay(3, function()
				if os.clock() - skipArmedAt >= 3 then
					tutorialSkip.Text = t("tutorial.skip")
				end
			end)
		end
	end)
	tutorialSkip.Visible = false
	local function paintTutorialLine()
		local args: { [string]: any } = {}
		for key, value in tutorialArgs or {} do
			-- Numbers are shortened (1,100 -> 1.1K); a string is a Locale key to translate (the tool in a nudge).
			args[key] = if type(value) == "number"
				then ShopView.short(value)
				elseif type(value) == "string" then t(value)
				else value
		end
		local key = tutorialKey or ("tutorial." .. tutorialStep)
		local shown = (tutorialStep ~= "" or tutorialForced) and tutorialKey ~= ""
		tutorialBox.Visible = shown
		if shown then
			tutorialLine.Text = t(key, args)
		end
	end

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	-- S5 Sign Paint: one row of colour buttons, shown once the item is owned; the server paints the rope of the plot.
	local paintRow = Instance.new("Frame")
	paintRow.BackgroundTransparency = 1
	paintRow.Size = UDim2.new(1, 0, 0, BUTTON_MIN_HEIGHT)
	paintRow.LayoutOrder = nextOrder()
	paintRow.Visible = false
	paintRow.Parent = frame
	local paintLayout = Instance.new("UIListLayout")
	paintLayout.FillDirection = Enum.FillDirection.Horizontal
	paintLayout.Padding = UDim.new(0, 4)
	paintLayout.Parent = paintRow
	local paintButtons: { TextButton } = {}
	for index, rgb in Assets.paintColors do
		local swatch = Instance.new("TextButton")
		swatch.Text = ""
		swatch.Size = UDim2.new(1 / #Assets.paintColors, -4, 1, 0)
		swatch.BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		swatch.BorderSizePixel = 0
		swatch.LayoutOrder = index
		Theme.round(swatch)
		swatch.Activated:Connect(function()
			send("SetPaint", { color = index })
		end)
		swatch.Parent = paintRow
		paintButtons[index] = swatch
	end
	-- The latest view from the server; buttons check it before they send.
	local latest: any = nil
	-- The last Snapshot, Delta and Env, kept so a language change can paint them again without waiting for the server.
	local lastSnapshot: any = nil
	local lastDelta: any = nil
	local lastEnv: any = nil

	-- The expansion asks first: what it gives, what is lost and what is kept, then "Expand" or "Cancel".
	local confirm = label(frame, nextOrder())
	local confirmYes: TextButton, confirmNo: TextButton
	local function askExpand(show: boolean)
		confirm.Visible = show
		confirmYes.Visible = show
		confirmNo.Visible = show
	end
	confirmYes = button(frame, "", nextOrder(), function()
		askExpand(false)
		if latest ~= nil and latest.goal ~= nil and latest.goal.allowed then
			send("Prestige")
		end
	end)
	confirmNo = button(frame, "", nextOrder(), function()
		askExpand(false)
	end)
	askExpand(false)
	local expand = button(frame, "", nextOrder(), function()
		if latest ~= nil and latest.goal ~= nil and latest.goal.allowed then
			askExpand(true)
		end
	end)
	-- Grid VIP: a glowing yellow pill right below the expansion row while today's free Turbo is waiting (Delta.extras).
	local freeTurbo = button(frame, "", nextOrder(), function()
		send("FreeTurbo")
	end)
	freeTurbo.Visible = false
	local glow = Instance.new("UIStroke")
	glow.Color = Theme.colors.accent
	glow.Thickness = 3
	glow.Transparency = 0.2
	glow.Parent = freeTurbo
	local pill = freeTurbo:FindFirstChildOfClass("UICorner") :: UICorner
	pill.CornerRadius = UDim.new(0.5, 0)
	TweenService:Create(
		glow,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	):Play()

	-- Captions and dimming from the server's view: the grid expansion.
	local function shop(view: any)
		if view.goal ~= nil then
			goal.Text = t("goal.next", { required = short(view.goal.required), earned = short(view.goal.earned) })
			expand.Text = t("goal.expand", { sparks = view.goal.sparks })
			dim(expand, view.goal.allowed)
			if view.sparks ~= nil and view.sparks.gridNext ~= nil then
				confirm.Text = t("expand.confirm", {
					now = string.format("%g", view.sparks.gridNow),
					next = string.format("%g", view.sparks.gridNext),
					sparks = view.goal.sparks,
				})
			end
			if not view.goal.allowed then
				askExpand(false)
			end
		else
			goal.Text = t("goal.done")
			expand.Text = t("goal.done")
			dim(expand, false)
		end
	end

	-- Each server message, painted from its data. Only the handlers below pass messages to the Boost view.
	local function storageText(charge: number)
		local fill = if latest ~= nil then latest.storage.fill else 0
		storage.Text = t("hud.storage", { value = format(charge), percent = math.floor(fill * 100 + 0.5) })
	end
	local function applySnapshot(state: any)
		coins.Text = t("hud.coins", { value = format(state.coins) })
		storageText(state.storage.charge)
		grid.Text = t("hud.gridLevel", { level = state.level })
	end
	local function applyDelta(change: any)
		latest = change.view
		coins.Text = t("hud.coins", { value = format(change.coins) })
		rate.Text = t("hud.rate", { value = format(change.rate) })
		storageText(change.charge)
		price.Text = ShopView.priceText(change.view.price, t)
		if change.view.sparks ~= nil then
			grid.Text = t("hud.gridChip", {
				level = change.view.sparks.gridLevel,
				now = string.format("%g", change.view.sparks.gridNow),
				sparks = change.view.sparks.available,
			})
		end
		local sparkView = change.view.sparks
		if sparkView ~= nil then
			local owned = false
			for _, item in sparkView.items do
				owned = owned or (item.id == "S5" and item.owned == true)
			end
			paintRow.Visible = owned
			for index, swatch in paintButtons do
				swatch.Text = if sparkView.paint == index then "✓" else ""
			end
		end
		shop(change.view)
		freeTurbo.Visible = change.extras ~= nil and change.extras.freeTurbo == true
	end
	local function applyEnv(change: any)
		clock.env(change)
	end

	-- Sets every caption in the current language, then paints the last server data in it. The server data is
	-- painted again on purpose: shop, storage and env texts are not kept anywhere else.
	paint = function()
		language.Text = t("hud.language", { name = t("language." .. lang) })
		storageHint.Text = t("hud.storageHint")
		expand.Text = t("action.expand")
		freeTurbo.Text = t("hud.freeTurbo")
		confirmYes.Text = t("expand.yes")
		confirmNo.Text = t("expand.no")
		tutorialSkip.Text = t("tutorial.skip")
		paintTutorialLine()
		if lastSnapshot ~= nil then
			applySnapshot(lastSnapshot)
		end
		if lastDelta ~= nil then
			applyDelta(lastDelta)
		end
		if lastEnv ~= nil then
			applyEnv(lastEnv)
		end
		boost.relabel()
	end
	paint()

	return {
		language = function(): string
			return lang
		end,
		snapshot = function(state: any)
			lastSnapshot = state
			applySnapshot(state)
		end,
		delta = function(change: any)
			lastDelta = change
			applyDelta(change)
			boost.delta(change)
		end,
		-- The server sends the step id ("" = no tutorial); the line sits at the top of the list.
		tutorial = function(change: any)
			tutorialStep = change.id
			tutorialKey, tutorialArgs = nil, nil
			tutorialSkip.Visible = tutorialStep ~= ""
			paintTutorialLine()
		end,
		-- TutorialGuide: the key and arguments of the line now; key "" hides the line (the skip button stays).
		tutorialLine = function(key: string?, args: { [string]: any }?, force: boolean?)
			tutorialForced = force == true
			if key == tutorialKey then
				tutorialArgs = args
				paintTutorialLine()
				return
			end
			tutorialKey, tutorialArgs = key, args
			paintTutorialLine()
		end,
		-- TutorialGuide: the expand button pulses twice, then rests.
		pulse = function(name: string, on: boolean)
			if name ~= "expand" then
				return
			end
			local stroke = expand:FindFirstChild("TutorialStroke") :: UIStroke?
			if not on then
				if stroke ~= nil then
					stroke:Destroy()
				end
				return
			end
			if stroke == nil then
				local created = Instance.new("UIStroke")
				created.Name = "TutorialStroke"
				created.Color = Theme.colors.accent
				created.Thickness = 3
				created.Parent = expand
			end
		end,
		env = function(change: any)
			lastEnv = change
			applyEnv(change)
			boost.env(change)
		end,
	}
end

return Hud
