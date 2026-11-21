--!strict
-- Welcome screen (Bauplan.md, "Willkommen-Bildschirm"): after the join it shows the time away and the offline coins the
-- server has already credited, with one Collect button. It holds no game state; the numbers come from the Welcome message.
-- Labels come from the Locale tables in the language the HUD uses. Fixed text size, wrapped text and padding keep it
-- readable at 360 px wide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any

local WelcomeScreen = {}

-- The panel is at most this wide; on a narrow screen it shrinks to the screen width instead.
local PANEL_MAX_WIDTH = 300
local PANEL_MARGIN = 16
local PANEL_PADDING = 12
local TITLE_TEXT = 18
local ROW_TEXT = 14
local ROW_MIN_HEIGHT = 36
-- The Collect button is a touch target: at least 44 px high.
local BUTTON_MIN_HEIGHT = 44
local ROW_SIDE_PADDING = 8
local ROW_VERTICAL_PADDING = 4

-- Gives a text row or the button the shared look: wrapped text, inner padding, and a height that grows with the text.
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
end

local function row(parent: Instance, order: number, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextSize = size
	text.TextWrapped = true
	text.LayoutOrder = order
	fitRow(text, ROW_MIN_HEIGHT)
	text.Parent = parent
	return text
end

-- The time away in the largest unit that fits: "45 min", "2 h 5 min". The welcome only shows from one minute on.
local function duration(seconds: number, lang: string): string
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then
		return Locale.t("duration.minutes", lang, { minutes = minutes })
	end
	return Locale.t("duration.hours", lang, { hours = math.floor(minutes / 60), minutes = minutes % 60 })
end

-- Builds the screen, hidden until the first Welcome. `language` gives the language the HUD uses. Returns the handler
-- for the Welcome message, which paints the screen in that language.
function WelcomeScreen.build(language: () -> string): (any) -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Welcome"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Fills the screen minus the margin, at most PANEL_MAX_WIDTH wide; its height follows the rows.
	panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 0.1
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(PANEL_MAX_WIDTH, math.huge)
	widthLimit.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PANEL_PADDING)
	padding.PaddingRight = UDim.new(0, PANEL_PADDING)
	padding.PaddingTop = UDim.new(0, PANEL_PADDING)
	padding.PaddingBottom = UDim.new(0, PANEL_PADDING)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	panel.Parent = gui

	local title = row(panel, 1, TITLE_TEXT)
	local away = row(panel, 2, ROW_TEXT)
	local coins = row(panel, 3, ROW_TEXT)

	-- The Long Meter hint: one quiet line when the server says the offline cap was reached (Core/HintView).
	local hint = row(panel, 4, ROW_TEXT)
	hint.Visible = false

	local collect = Instance.new("TextButton")
	collect.TextSize = ROW_TEXT
	collect.TextWrapped = true
	collect.LayoutOrder = 5
	fitRow(collect, BUTTON_MIN_HEIGHT)
	collect.Parent = panel
	collect.Activated:Connect(function()
		gui.Enabled = false
	end)

	return function(welcome: any)
		local lang = language()
		title.Text = Locale.t("welcome.title", lang)
		collect.Text = Locale.t("welcome.collect", lang)
		away.Text = Locale.t("welcome.away", lang, { duration = duration(welcome.away, lang) })
		coins.Text = Locale.t("welcome.coins", lang, { coins = string.format("%.0f", welcome.coins) })
		hint.Text = Locale.t("hint.longMeter", lang)
		hint.Visible = welcome.hint == true
		gui.Enabled = true
	end
end

return WelcomeScreen
