--!strict
-- Boosters on screen (Bauplan.md, section 3): a golden sky while the Sunshine Hour runs, a banner with the buyer's name and
-- the time left, and the Sunshine Hour button at the weather display. The button asks Roblox for the purchase prompt only
-- after a tap; the server decides what the purchase grants. Countdowns use the server clock. Labels come from Locale.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Boost = require(Config:WaitForChild("Boost") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any

local BoostView = {}

local GOLDEN = Color3.fromRGB(255, 214, 120)
local BANNER_TEXT = 16
local BUTTON_TEXT = 14
-- The Sunshine Hour button is a touch target: at least 44 px high.
local BUTTON_HEIGHT = 44

-- "m:ss" for a number of seconds, never negative.
local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Builds the golden sky, the banner and the button. `frame` is the HUD list and `nextOrder` gives the next layout order,
-- so the button sits right under the weather line. `lang` gives the language in use. Returns the handlers for the Env
-- and Delta messages, and `relabel`, which repaints the button and the banner after a language change.
function BoostView.build(frame: GuiObject, nextOrder: () -> number, lang: () -> string)
	local sky = Instance.new("ColorCorrectionEffect")
	sky.Name = "SunshineHour"
	sky.TintColor = GOLDEN
	sky.Enabled = false
	sky.Parent = Lighting

	local gui = Instance.new("ScreenGui")
	gui.Name = "Boost"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 8)
	banner.Size = UDim2.new(0.6, 0, 0, 56)
	banner.BackgroundColor3 = GOLDEN
	banner.BackgroundTransparency = 0.2
	banner.TextColor3 = Color3.new(0, 0, 0)
	banner.TextSize = BANNER_TEXT
	banner.TextWrapped = true
	banner.Visible = false
	banner.Parent = gui

	-- The purchase button is hidden until a product ID is set in Config (Milestone 3): nothing is offered before that.
	local button = Instance.new("TextButton")
	button.TextSize = BUTTON_TEXT
	button.TextWrapped = true
	button.LayoutOrder = nextOrder()
	button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	button.Visible = Boost.products.sunshine ~= 0
	button.Parent = frame
	button.Activated:Connect(function()
		if Boost.products.sunshine ~= 0 then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, Boost.products.sunshine)
		end
	end)

	-- The Sunshine Hour from Env (server time of its end, buyer, queued seconds) and the owner's Turbo from Delta.
	local sunshineEnds, sunshineBuyer, sunshineQueued = 0, "", 0
	local turboEnds = 0

	-- Shows the running boosters with their time left. Runs every second, so the countdown moves.
	local function refresh()
		local now = workspace:GetServerTimeNow()
		local running = sunshineEnds > now
		sky.Enabled = running
		local lines = {}
		if running then
			local line = Locale.t("boost.sunshine", lang(), { buyer = sunshineBuyer, time = clock(sunshineEnds - now) })
			if sunshineQueued > 0 then
				line ..= Locale.t("boost.queued", lang(), { time = clock(sunshineQueued) })
			end
			table.insert(lines, line)
		end
		if turboEnds > now then
			table.insert(lines, Locale.t("boost.turbo", lang(), { time = clock(turboEnds - now) }))
		end
		banner.Text = table.concat(lines, "\n")
		banner.Visible = #lines > 0
	end

	-- Repaints the button caption in the current language, then the banner.
	local function relabel()
		button.Text = Locale.t("boost.buy", lang())
		refresh()
	end
	relabel()

	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)

	return {
		env = function(change: any)
			sunshineEnds = change.sunshineEnds
			sunshineBuyer = change.sunshineBuyer
			sunshineQueued = change.sunshineQueued
			refresh()
		end,
		delta = function(change: any)
			turboEnds = workspace:GetServerTimeNow() + change.turbo
			refresh()
		end,
		relabel = relabel,
	}
end

return BoostView
