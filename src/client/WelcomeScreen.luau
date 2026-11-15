--!strict
-- Welcome screen (Bauplan.md, "Willkommen-Bildschirm"): after the join it shows the time away and the offline coins the
-- server has already credited, with one Collect button. It holds no game state; the numbers come from the Welcome message.
-- Labels are English, as in the HUD. Fixed text size, wrapped text and padding keep it readable at 360 px wide.
local Players = game:GetService("Players")

local WelcomeScreen = {}

-- The panel is at most this wide; on a narrow screen it shrinks to the screen width instead.
local PANEL_MAX_WIDTH = 300
local PANEL_MARGIN = 16
local PANEL_PADDING = 12
local TITLE_TEXT = 18
local ROW_TEXT = 14
local ROW_MIN_HEIGHT = 36
local ROW_SIDE_PADDING = 8
local ROW_VERTICAL_PADDING = 4

-- Gives a text row or the button the shared look: wrapped text, inner padding, and a height that grows with the text.
local function fitRow(control: GuiObject)
	control.Size = UDim2.new(1, 0, 0, ROW_MIN_HEIGHT)
	control.AutomaticSize = Enum.AutomaticSize.Y
	local minHeight = Instance.new("UISizeConstraint")
	minHeight.MinSize = Vector2.new(0, ROW_MIN_HEIGHT)
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
	fitRow(text)
	text.Parent = parent
	return text
end

-- The time away in the largest unit that fits: "45 min", "2 h 5 min". The welcome only shows from one minute on.
local function duration(seconds: number): string
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then
		return `{minutes} min`
	end
	return `{math.floor(minutes / 60)} h {minutes % 60} min`
end

-- Builds the screen, hidden until the first Welcome. Returns the handler for the Welcome message.
function WelcomeScreen.build(): (any) -> ()
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
	title.Text = "Welcome back"
	local away = row(panel, 2, ROW_TEXT)
	local coins = row(panel, 3, ROW_TEXT)

	local collect = Instance.new("TextButton")
	collect.Text = "Collect"
	collect.TextSize = ROW_TEXT
	collect.TextWrapped = true
	collect.LayoutOrder = 4
	fitRow(collect)
	collect.Parent = panel
	collect.Activated:Connect(function()
		gui.Enabled = false
	end)

	return function(welcome: any)
		away.Text = `You were away {duration(welcome.away)}`
		coins.Text = `Offline coins: +{string.format("%.0f", welcome.coins)}`
		gui.Enabled = true
	end
end

return WelcomeScreen
