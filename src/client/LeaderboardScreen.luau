--!strict
-- Leaderboard screen (Bauplan.md, section 3, Bestenliste): a button opens the list with two tabs, "This server" and
-- "World". While it is open the screen asks the server every 5 seconds, so the server list is live; the world list is
-- cached on the server. It holds no game state: the rows come from the RankList message. Fixed text size, wrapped text
-- and padding keep it readable at 360 px wide; nothing needs a hover.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Config"):WaitForChild("Locale") :: ModuleScript) :: any
local Ranking = require(Shared:WaitForChild("Core"):WaitForChild("Ranking") :: ModuleScript) :: any

local REFRESH_SECONDS = 5
local PANEL_MAX_WIDTH = 300
local PANEL_MARGIN = 16
local PANEL_PADDING = 12
local TITLE_TEXT = 18
local ROW_TEXT = 14
local BUTTON_HEIGHT = 36
local ROW_MIN_HEIGHT = 28
local LIST_HEIGHT = 300 -- the rows scroll inside this height (up to 50 rows)

local LeaderboardScreen = {}

-- Gives a text row or a button the shared look: wrapped text, inner padding, and a height that grows with the text.
local function fit(control: GuiObject, height: number)
	control.Size = UDim2.new(1, 0, 0, height)
	control.AutomaticSize = Enum.AutomaticSize.Y
	local minHeight = Instance.new("UISizeConstraint")
	minHeight.MinSize = Vector2.new(0, height)
	minHeight.Parent = control
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = control
end

local function button(parent: Instance, order: number): TextButton
	local control = Instance.new("TextButton")
	control.TextSize = ROW_TEXT
	control.TextWrapped = true
	control.LayoutOrder = order
	fit(control, BUTTON_HEIGHT)
	control.Parent = parent
	return control
end

-- Builds the screen, closed, with its opener button at the bottom left. `net` is the folder of RemoteEvents from the
-- server; `language` gives the language the HUD uses.
function LeaderboardScreen.build(net: Instance, language: () -> string)
	local rankRequest = net:WaitForChild("RankRequest") :: RemoteEvent
	local rankList = net:WaitForChild("RankList") :: RemoteEvent
	local tab = "server"
	local lists: { server: { any }, world: { any } } = { server = {}, world = {} }
	-- Each open or close starts a new generation; a refresh loop stops as soon as its generation is over.
	local generation = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "Leaderboard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local opener = Instance.new("TextButton")
	opener.AnchorPoint = Vector2.new(0, 1)
	opener.Position = UDim2.new(0, PANEL_MARGIN, 1, -PANEL_MARGIN)
	opener.Size = UDim2.fromOffset(160, BUTTON_HEIGHT)
	opener.TextSize = ROW_TEXT
	opener.TextWrapped = true
	opener.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Fills the screen minus the margin, at most PANEL_MAX_WIDTH wide; its height follows the rows.
	panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
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

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.TextSize = TITLE_TEXT
	title.TextWrapped = true
	title.LayoutOrder = 1
	fit(title, BUTTON_HEIGHT)
	title.Parent = panel

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.LayoutOrder = 2
	tabs.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	local serverTab = button(tabs, 1)
	serverTab.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)
	local worldTab = button(tabs, 2)
	worldTab.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.LayoutOrder = 3
	list.Size = UDim2.new(1, 0, 0, LIST_HEIGHT)
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local close = button(panel, 4)

	-- One row of text in the list; its order keeps the rows in ranking order.
	local function addRow(text: string, order: number)
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.TextSize = ROW_TEXT
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = order
		fit(row, ROW_MIN_HEIGHT)
		row.Text = text
		row.Parent = list
	end

	-- Paints every text and the rows of the current tab in the language the HUD uses.
	local function paint()
		local lang = language()
		opener.Text = Locale.t("board.open", lang)
		title.Text = Locale.t("board.title", lang)
		serverTab.Text = Locale.t("board.tab.server", lang)
		worldTab.Text = Locale.t("board.tab.world", lang)
		close.Text = Locale.t("board.close", lang)
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local rows = if tab == "world" then lists.world else lists.server
		if #rows == 0 then
			addRow(Locale.t("board.empty", lang), 1)
		end
		for index, entry in rows do
			local rank = tostring(index)
			local text: string
			if tab == "world" then
				text = Locale.t("board.worldRow", lang, {
					rank = rank,
					name = entry.name,
					level = tostring(Ranking.level(entry.score)),
					exponent = string.format("%.1f", Ranking.exponent(entry.score)),
				})
			else
				text = Locale.t("board.serverRow", lang, {
					rank = rank,
					name = entry.name,
					level = tostring(entry.level),
					earned = string.format("%.0f", entry.earned),
				})
			end
			addRow(text, index)
		end
	end

	local function setOpen(open: boolean)
		generation += 1
		local mine = generation
		panel.Visible = open
		opener.Visible = not open
		if open then
			paint()
			task.spawn(function()
				while generation == mine do
					rankRequest:FireServer()
					task.wait(REFRESH_SECONDS)
				end
			end)
		end
	end

	rankList.OnClientEvent:Connect(function(payload: any)
		lists.server = payload.server or {}
		lists.world = payload.world or {}
		paint()
	end)
	opener.Activated:Connect(function()
		setOpen(true)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	serverTab.Activated:Connect(function()
		tab = "server"
		paint()
	end)
	worldTab.Activated:Connect(function()
		tab = "world"
		paint()
	end)
	paint()
end

return LeaderboardScreen
