--!strict
-- Leaderboard screen (Bauplan.md, section 3, Bestenliste): a yellow button opens the list with two tabs, "This server" and
-- "World", in the look of the shop window (Theme). While it is open the screen asks the server every 5 seconds, so the
-- server list is live; the world list is cached on the server. It holds no game state: the rows come from the RankList
-- message. Fixed text size, wrapped text and padding keep it readable at 360 px wide; nothing needs a hover.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Config"):WaitForChild("Locale") :: ModuleScript) :: any
local Ranking = require(Shared:WaitForChild("Core"):WaitForChild("Ranking") :: ModuleScript) :: any
local Theme = require(script.Parent.Theme)
local Digits = require(Shared:WaitForChild("Core"):WaitForChild("Digits") :: ModuleScript) :: any

local REFRESH_SECONDS = 5
local PANEL_MAX_WIDTH = 360
local PANEL_MARGIN = 16
local PANEL_PADDING = 14
local TITLE_TEXT = 24
local ROW_TEXT = 16
local BUTTON_TEXT = 17
local BUTTON_HEIGHT = 44 -- touch size
local ROW_MIN_HEIGHT = 36
local LIST_HEIGHT = 300 -- the rows scroll inside this height (up to 50 rows)
local GAP = 8

local LeaderboardScreen = {}

-- A rounded button of the shop look: bold caption, wrapped text, the touch height.
local function button(parent: Instance, order: number): TextButton
	local control = Instance.new("TextButton")
	control.AutoButtonColor = true
	control.BorderSizePixel = 0
	control.Font = Theme.fonts.bold
	control.TextSize = BUTTON_TEXT
	control.TextWrapped = true
	control.LayoutOrder = order
	control.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	Theme.round(control)
	control.Parent = parent
	return control
end

-- A tab button is yellow while its list shows, otherwise a dark pill.
local function tabLook(control: TextButton, active: boolean)
	control.BackgroundColor3 = if active then Theme.colors.accent else Theme.colors.panel
	control.TextColor3 = if active then Theme.colors.textDark else Theme.colors.text
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
	Theme.fitScreen(gui)

	-- The opener is a yellow button, so nobody misses it; the Style buttons stand above it (Controllers/Style).
	local opener = Instance.new("TextButton")
	opener.AnchorPoint = Vector2.new(0, 1)
	opener.Position = UDim2.new(0, PANEL_MARGIN, 1, -PANEL_MARGIN)
	opener.Size = UDim2.fromOffset(190, BUTTON_HEIGHT)
	opener.BackgroundColor3 = Theme.colors.accent
	opener.TextColor3 = Theme.colors.textDark
	opener.Font = Theme.fonts.bold
	opener.TextSize = BUTTON_TEXT
	opener.TextWrapped = true
	opener.BorderSizePixel = 0
	Theme.round(opener)
	opener.Parent = gui

	-- Window of the shop look: night-blue body, rounded, a yellow outline, a dimmed backdrop that closes it.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.colors.backdrop
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("TextButton") -- a button, so a tap on the window is not a tap on the backdrop
	panel.Name = "Window"
	panel.AutoButtonColor = false
	panel.Text = ""
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Fills the screen minus the margin, at most PANEL_MAX_WIDTH wide; its height follows the rows.
	panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.colors.window
	panel.BorderSizePixel = 0
	Theme.round(panel, 16)
	Theme.outline(panel, Theme.colors.accent, 2)
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
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	panel.Parent = backdrop

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Theme.fonts.title
	title.TextColor3 = Theme.colors.accent
	title.TextSize = TITLE_TEXT
	title.TextWrapped = true
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	title.Parent = panel

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.LayoutOrder = 2
	tabs.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, GAP)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	local serverTab = button(tabs, 1)
	serverTab.Size = UDim2.new(0.5, -GAP / 2, 0, BUTTON_HEIGHT)
	local worldTab = button(tabs, 2)
	worldTab.Size = UDim2.new(0.5, -GAP / 2, 0, BUTTON_HEIGHT)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.colors.stroke
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.LayoutOrder = 3
	list.Size = UDim2.new(1, 0, 0, LIST_HEIGHT)
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local close = button(panel, 4)
	close.BackgroundColor3 = Theme.colors.bad
	close.TextColor3 = Theme.colors.text

	-- One card of text in the list; its order keeps the rows in ranking order. The first three stand out in yellow.
	local function addRow(text: string, order: number, top: boolean)
		local row = Instance.new("TextLabel")
		row.BackgroundColor3 = Theme.colors.card
		row.BorderSizePixel = 0
		row.Font = Theme.fonts.body
		row.TextColor3 = if top then Theme.colors.accent else Theme.colors.text
		row.TextSize = ROW_TEXT
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, ROW_MIN_HEIGHT)
		row.AutomaticSize = Enum.AutomaticSize.Y
		Theme.round(row, 8)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, 10)
		rowPadding.PaddingRight = UDim.new(0, 10)
		rowPadding.PaddingTop = UDim.new(0, 6)
		rowPadding.PaddingBottom = UDim.new(0, 6)
		rowPadding.Parent = row
		row.Text = text
		row.Parent = list
	end

	-- Paints every text and the rows of the current tab in the language the HUD uses.
	local function paint()
		local lang = language()
		opener.Text = "🏆 " .. Locale.t("board.open", lang)
		title.Text = Locale.t("board.title", lang)
		serverTab.Text = Locale.t("board.tab.server", lang)
		worldTab.Text = Locale.t("board.tab.world", lang)
		tabLook(serverTab, tab == "server")
		tabLook(worldTab, tab == "world")
		close.Text = Locale.t("board.close", lang)
		for _, child in list:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local rows = if tab == "world" then lists.world else lists.server
		if #rows == 0 then
			addRow(Locale.t("board.empty", lang), 1, false)
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
					earned = Digits.group(entry.earned, 0, lang),
				})
			end
			addRow(text, index, index <= 3)
		end
	end

	local function setOpen(open: boolean)
		generation += 1
		local mine = generation
		backdrop.Visible = open
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
	backdrop.Activated:Connect(function()
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
