--!strict
-- Market popup (design 0018, R1): a centred window over a dimmed world with a title bar, the coins, a close button,
-- four tabs and one card per offer. It opens only from the market's prompt and closes with the button, a tap beside the
-- window, Escape, or when the player walks away. No game rules here: Core/ShopView says which cards a tab has and what
-- each button sends; the server checks every message again. Colours and fonts come from Theme, texts from Locale.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local Plants = require(Config:WaitForChild("Plants") :: ModuleScript) :: any
local Upgrades = require(Config:WaitForChild("Upgrades") :: ModuleScript) :: any
local Effects = require(Config:WaitForChild("Effects") :: ModuleScript) :: any
local ShopView = require(Shared:WaitForChild("Core"):WaitForChild("ShopView") :: ModuleScript) :: any
local PopupGate = require(Shared:WaitForChild("Core"):WaitForChild("PopupGate") :: ModuleScript) :: any
local Theme = require(script.Parent.Parent.Theme)

local Market = {}

local COLORS = Theme.colors
-- The window is at most this big; on a small screen it shrinks to the screen, on a big one a UIScale enlarges it.
local WINDOW_WIDTH = 720
local WINDOW_HEIGHT = 560
local SCREEN_MARGIN = 8
local SCALE_WIDTH = 900
local SCALE_HEIGHT = 650
local MAX_SCALE = 1.5
local PADDING = 14
local HEADER_HEIGHT = 48
-- Tabs and buttons are at least 44 px high, the touch size.
local TOUCH = 44
local HINT_HEIGHT = 22
local GAP = 8
local SCROLLBAR = 6
-- Two columns of cards from this window width on; a single column gets taller cards so the text has three lines.
local TWO_COLUMNS_FROM = 620
local CARD_HEIGHT = 96
local CARD_HEIGHT_NARROW = 112
local ICON = 48
local BUTTON_WIDTH = 104
local STEP_WIDTH = 64
-- The popup closes when the player is this many studs beyond the prompt's reach.
local LEAVE_SLACK = 6
local LEAVE_CHECK_SECONDS = 0.3

local function text(parent: Instance, font: Enum.Font, size: number, color: Color3): TextLabel
	local control = Instance.new("TextLabel")
	control.BackgroundTransparency = 1
	control.Font = font
	control.TextSize = size
	control.TextColor3 = color
	control.TextXAlignment = Enum.TextXAlignment.Left
	control.TextTruncate = Enum.TextTruncate.AtEnd
	control.Text = ""
	control.Parent = parent
	return control
end

-- A rounded button whose caption shrinks to fit, so a long word in any language stays whole.
local function pill(parent: Instance, maxText: number): TextButton
	local control = Instance.new("TextButton")
	control.AutoButtonColor = true
	control.BorderSizePixel = 0
	control.Font = Theme.fonts.bold
	control.TextScaled = true
	control.Text = ""
	Theme.round(control)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 9
	limit.MaxTextSize = maxText
	limit.Parent = control
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = control
	control.Parent = parent
	return control
end

-- Builds the popup, hidden. `net` is ReplicatedStorage.Net, `language` gives the language in use. Returns `open`
-- (with the prompt that opened it), `close` and the handler for the Delta message.
function Market.build(net: Instance, language: () -> string)
	local player = Players.LocalPlayer :: Player
	local function t(key: string, args: { [string]: any }?): string
		return Locale.t(key, language(), args)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Market"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local close: () -> ()
	-- The dimmed backdrop takes every tap beside the window (it closes the popup) and frees the mouse while it shows.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = COLORS.backdrop
	backdrop.BackgroundTransparency = 0.4
	backdrop.BorderSizePixel = 0
	backdrop.AutoButtonColor = false
	backdrop.Modal = true
	backdrop.Text = ""
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		close()
	end)

	-- A button, so a tap on the window is not a tap on the backdrop.
	local window = Instance.new("TextButton")
	window.Name = "Window"
	window.AutoButtonColor = false
	window.Text = ""
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = COLORS.window
	window.BorderSizePixel = 0
	Theme.round(window, 16)
	Theme.outline(window, COLORS.accent, 2)
	local scale = Instance.new("UIScale")
	scale.Parent = window
	local windowPadding = Instance.new("UIPadding")
	windowPadding.PaddingLeft = UDim.new(0, PADDING)
	windowPadding.PaddingRight = UDim.new(0, PADDING)
	windowPadding.PaddingTop = UDim.new(0, PADDING)
	windowPadding.PaddingBottom = UDim.new(0, PADDING)
	windowPadding.Parent = window
	window.Parent = gui

	-- Title bar: bolt and title on the left, the coins and the close button on the right, a yellow line under it.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.Parent = window
	local title = text(header, Theme.fonts.title, 24, COLORS.accent)
	title.Size = UDim2.new(1, -(TOUCH + 140 + 2 * GAP), 0, TOUCH)
	local closeButton = pill(header, 22)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(TOUCH, TOUCH)
	closeButton.BackgroundColor3 = COLORS.bad
	closeButton.TextColor3 = COLORS.text
	closeButton.Text = "X"
	closeButton.Activated:Connect(function()
		close()
	end)
	local coins = text(header, Theme.fonts.bold, 16, COLORS.accent)
	coins.Name = "Coins"
	coins.AnchorPoint = Vector2.new(1, 0)
	coins.Position = UDim2.new(1, -(TOUCH + GAP), 0, 4)
	coins.Size = UDim2.fromOffset(140, TOUCH - 8)
	coins.BackgroundTransparency = 0
	coins.BackgroundColor3 = COLORS.panel
	coins.TextXAlignment = Enum.TextXAlignment.Center
	Theme.round(coins, (TOUCH - 8) / 2)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, 2)
	line.BackgroundColor3 = COLORS.accent
	line.BackgroundTransparency = 0.5
	line.BorderSizePixel = 0
	line.Parent = header

	-- Tab row: four equal buttons that always fit the window; the caption shrinks before it would be cut.
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.ZIndex = 3
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(0, HEADER_HEIGHT + GAP)
	tabBar.Size = UDim2.new(1, 0, 0, TOUCH)
	tabBar.Parent = window
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, GAP)
	tabLayout.Parent = tabBar
	local tabCount = #ShopView.tabs
	local tabButtons: { [string]: TextButton } = {}
	local currentTab: string = ShopView.tabs[1].id
	local setTab: (string) -> ()
	for index, tab in ShopView.tabs do
		local control = pill(tabBar, 16)
		control.Name = tab.id
		control.LayoutOrder = index
		control.Size = UDim2.new(1 / tabCount, -math.ceil(GAP * (tabCount - 1) / tabCount), 1, 0)
		control.Activated:Connect(function()
			setTab(tab.id)
		end)
		tabButtons[tab.id] = control
	end

	local hint = text(window, Theme.fonts.body, 14, COLORS.textMuted)
	hint.Name = "Hint"
	hint.ZIndex = 3
	hint.Position = UDim2.fromOffset(2, HEADER_HEIGHT + TOUCH + 2 * GAP)
	hint.Size = UDim2.new(1, -4, 0, HINT_HEIGHT)

	local listTop = HEADER_HEIGHT + TOUCH + HINT_HEIGHT + 3 * GAP
	local list = Instance.new("ScrollingFrame")
	list.Name = "Offers"
	list.Position = UDim2.fromOffset(0, listTop)
	list.Size = UDim2.new(1, 0, 1, -listTop)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = SCROLLBAR
	list.ScrollBarImageColor3 = COLORS.accent
	-- The scrollbar takes its own strip beside the cards, so it never covers them.
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	list.Parent = window
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.Parent = list

	-- The latest view and coins from the server; a button checks its card again before it sends.
	local latest: any = nil
	local latestCoins = 0
	local cardHeight = CARD_HEIGHT
	type CardUi = {
		frame: Frame,
		stroke: UIStroke,
		icon: TextLabel,
		title: TextLabel,
		info: TextLabel,
		status: TextLabel,
		action: TextButton,
		down: TextButton,
		up: TextButton,
		data: any,
	}
	local pool: { CardUi } = {}

	-- The text block of a card: the title across the top, then info and price or status beside the button (or across
	-- the card when it has no button).
	local function arrange(card: CardUi)
		local left = ICON + 2 * GAP + 2
		local hasButton = card.data ~= nil and card.data.button ~= nil
		local width = UDim.new(1, -(left + GAP + (if hasButton then BUTTON_WIDTH + GAP else 0)))
		card.title.Position = UDim2.fromOffset(left, 8)
		card.title.Size = UDim2.new(1, -(left + GAP), 0, 20)
		card.info.Position = UDim2.fromOffset(left, 30)
		card.info.Size = UDim2.new(width, UDim.new(0, cardHeight - 60))
		card.status.Position = UDim2.fromOffset(left, cardHeight - 28)
		card.status.Size = UDim2.new(width, UDim.new(0, 20))
		-- A card with steppers (a rule): one line of text, then the two steppers left of the switch at the bottom.
		if card.data ~= nil and card.data.steps ~= nil then
			card.info.Size = UDim2.new(width, UDim.new(0, 18))
			card.status.Visible = false
			card.down.Position = UDim2.new(0, left, 1, -GAP)
			card.up.Position = UDim2.new(0, left + STEP_WIDTH + GAP, 1, -GAP)
		else
			card.status.Visible = true
		end
	end

	local function act(button: any)
		if button == nil or not button.enabled then
			return
		end
		if button.tab ~= nil then
			setTab(button.tab)
		elseif button.remote ~= nil then
			(net:WaitForChild(button.remote) :: RemoteEvent):FireServer(button.payload)
		end
	end

	local function newCard(index: number): CardUi
		local frame = Instance.new("Frame")
		frame.Name = "Card"
		frame.LayoutOrder = index
		frame.BorderSizePixel = 0
		Theme.round(frame)
		local tile = Instance.new("TextLabel")
		tile.Name = "Icon"
		tile.AnchorPoint = Vector2.new(0, 0.5)
		tile.Position = UDim2.new(0, GAP, 0.5, 0)
		tile.Size = UDim2.fromOffset(ICON, ICON)
		tile.BackgroundColor3 = COLORS.iconTile
		tile.BorderSizePixel = 0
		tile.Font = Theme.fonts.bold
		tile.TextSize = 28
		tile.TextColor3 = COLORS.accent
		Theme.round(tile)
		tile.Parent = frame
		local info = text(frame, Theme.fonts.body, 13, COLORS.textMuted)
		info.TextWrapped = true
		info.TextYAlignment = Enum.TextYAlignment.Top
		local action = pill(frame, 16)
		action.Name = "Action"
		action.AnchorPoint = Vector2.new(1, 1)
		action.Position = UDim2.new(1, -GAP, 1, -GAP)
		action.Size = UDim2.fromOffset(BUTTON_WIDTH, TOUCH)
		local function step(name: string): TextButton
			local control = pill(frame, 16)
			control.Name = name
			control.AnchorPoint = Vector2.new(0, 1)
			control.Size = UDim2.fromOffset(STEP_WIDTH, TOUCH)
			control.Visible = false
			return control
		end
		local card: CardUi = {
			frame = frame,
			stroke = Theme.outline(frame, COLORS.stroke),
			icon = tile,
			title = text(frame, Theme.fonts.bold, 16, COLORS.text),
			info = info,
			status = text(frame, Theme.fonts.bold, 14, COLORS.accent),
			action = action,
			down = step("Down"),
			up = step("Up"),
			data = nil,
		}
		arrange(card)
		action.Activated:Connect(function()
			act(card.data ~= nil and card.data.button or nil)
		end)
		card.down.Activated:Connect(function()
			act(card.data ~= nil and card.data.steps ~= nil and card.data.steps.down or nil)
		end)
		card.up.Activated:Connect(function()
			act(card.data ~= nil and card.data.steps ~= nil and card.data.steps.up or nil)
		end)
		frame.Parent = list
		return card
	end

	-- Paints one card from its data. The state picks the colours: green buys, grey waits for coins, cyan leads on.
	local function paintCard(card: CardUi, data: any)
		card.data = data
		local locked = data.state == "locked"
		card.frame.BackgroundColor3 = if locked then COLORS.cardDim else COLORS.card
		card.icon.Text = Theme.icon(data.icon)
		card.icon.TextTransparency = if locked then 0.5 else 0
		card.title.Text = data.title
		card.title.TextColor3 = if locked then COLORS.textMuted else COLORS.text
		card.info.Text = data.info
		card.status.Text = data.price or data.status or ""
		local strokeColor = COLORS.stroke
		local statusColor = COLORS.textMuted
		if data.state == "affordable" then
			strokeColor = COLORS.good
			statusColor = COLORS.accent
		elseif data.state == "short" then
			statusColor = COLORS.bad
		elseif data.state == "owned" then
			statusColor = COLORS.good
		elseif data.state == "active" then
			strokeColor = COLORS.energy
			statusColor = COLORS.energy
		elseif data.state == "hint" then
			statusColor = COLORS.energy
		end
		card.stroke.Color = strokeColor
		card.status.TextColor3 = statusColor
		local button = data.button
		local steps = data.steps
		card.down.Visible = steps ~= nil
		card.up.Visible = steps ~= nil
		if steps ~= nil then
			for control, item in { [card.down] = steps.down, [card.up] = steps.up } do
				control.Text = item.text
				control.Active = item.enabled
				control.AutoButtonColor = item.enabled
				control.BackgroundColor3 = if item.enabled then COLORS.panel else COLORS.disabled
				control.TextColor3 = if item.enabled then COLORS.text else COLORS.textMuted
			end
		end
		arrange(card)
		card.action.Visible = button ~= nil
		if button ~= nil then
			card.action.Text = button.text
			card.action.Active = button.enabled
			card.action.AutoButtonColor = button.enabled
			if not button.enabled then
				card.action.BackgroundColor3 = COLORS.disabled
				card.action.TextColor3 = COLORS.textMuted
			elseif data.state == "hint" or data.state == "idle" or data.state == "active" then
				card.action.BackgroundColor3 = COLORS.energy
				card.action.TextColor3 = COLORS.textDark
			else
				card.action.BackgroundColor3 = COLORS.good
				card.action.TextColor3 = COLORS.textDark
			end
		end
	end

	-- Paints the open tab from the latest view. Cards are reused, so the list keeps its scroll position.
	local function render()
		title.Text = `{Theme.icons.fallback} {t("market.title")}`
		coins.Text = t("hud.coins", { value = ShopView.short(math.floor(latestCoins)) })
		for _, tab in ShopView.tabs do
			local control = tabButtons[tab.id]
			local active = tab.id == currentTab
			control.Text = t(tab.key)
			control.BackgroundColor3 = if active then COLORS.accent else COLORS.panel
			control.TextColor3 = if active then COLORS.textDark else COLORS.text
			if active then
				hint.Text = t(tab.hint)
			end
		end
		local cards = ShopView.cards(currentTab, {
			view = latest,
			coins = latestCoins,
			plants = Plants,
			upgrades = Upgrades,
			land = Land,
			ruleStep = Effects.ruleStep,
			t = t,
		})
		for index, data in cards do
			local card = pool[index]
			if card == nil then
				card = newCard(index)
				pool[index] = card
			end
			paintCard(card, data)
			card.frame.Visible = true
		end
		for index = #cards + 1, #pool do
			pool[index].frame.Visible = false
			pool[index].data = nil
		end
	end

	setTab = function(tab: string)
		currentTab = tab
		list.CanvasPosition = Vector2.zero
		render()
	end

	-- Fits the window to the screen: full size where there is room, the screen minus a margin on a phone, enlarged
	-- on a big screen. Below the top bar, so the Roblox buttons stay free.
	local function fit()
		local screen = gui.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		local factor = math.clamp(math.min(screen.X / SCALE_WIDTH, screen.Y / SCALE_HEIGHT), 1, MAX_SCALE)
		local width = math.min(WINDOW_WIDTH, (screen.X - 2 * SCREEN_MARGIN) / factor)
		local height = math.min(WINDOW_HEIGHT, (screen.Y - inset.Y - 2 * SCREEN_MARGIN) / factor)
		scale.Scale = factor
		window.Size = UDim2.fromOffset(width, height)
		window.Position = UDim2.new(0.5, 0, 0.5, inset.Y / 2)
		local columns = if width >= TWO_COLUMNS_FROM then 2 else 1
		cardHeight = if columns == 1 then CARD_HEIGHT_NARROW else CARD_HEIGHT
		-- 2 px spare on each side for the card outlines.
		local room = width - 2 * PADDING - SCROLLBAR - 4
		grid.CellSize = UDim2.fromOffset(math.floor((room - GAP * (columns - 1)) / columns), cardHeight)
		for _, card in pool do
			arrange(card)
		end
	end
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 2)
	listPadding.PaddingTop = UDim.new(0, 2)
	listPadding.PaddingBottom = UDim.new(0, 2)
	listPadding.Parent = list
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- Counts the openings, so the leave check of an earlier opening stops when the popup was closed and opened again.
	local opening = 0
	-- The Roblox hotbar is hidden while the popup shows and always restored by close (the gate says which).
	local gate = PopupGate.new()
	local function applyHotbar()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not PopupGate.hidden(gate))
		end)
	end
	close = function()
		opening += 1
		gui.Enabled = false
		PopupGate.close(gate, "market")
		applyHotbar()
	end

	-- The place of the prompt that opened the popup, or nil when it is gone.
	local function placeOf(prompt: ProximityPrompt): Vector3?
		local parent = prompt.Parent
		if parent == nil or not prompt:IsDescendantOf(workspace) then
			return nil
		elseif parent:IsA("BasePart") then
			return parent.Position
		elseif parent:IsA("Attachment") then
			return parent.WorldPosition
		end
		return nil
	end

	local function open(prompt: ProximityPrompt?, tab: string?)
		opening += 1
		local mine = opening
		fit()
		setTab(tab or ShopView.tabs[1].id)
		gui.Enabled = true
		PopupGate.open(gate, "market")
		applyHotbar()
		if prompt == nil then
			return
		end
		local source: ProximityPrompt = prompt
		-- Leaving closes the popup: the player walked out of the prompt's reach, or the market is gone.
		task.spawn(function()
			while opening == mine do
				local place = placeOf(source)
				local character = player.Character
				local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
				if place == nil then
					close()
				elseif root ~= nil and root:IsA("BasePart") then
					if (root.Position - place).Magnitude > source.MaxActivationDistance + LEAVE_SLACK then
						close()
					end
				end
				task.wait(LEAVE_CHECK_SECONDS)
			end
		end)
	end

	-- Escape (it also opens the Roblox menu) and the B button of a gamepad close the popup.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			close()
		end
	end)
	GuiService.MenuOpened:Connect(function()
		if gui.Enabled then
			close()
		end
	end)
	-- Death, respawn or a removed gui also close the popup, so the hotbar never stays hidden.
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(close)
		end
	end
	player.CharacterAdded:Connect(function(character)
		close()
		watchCharacter(character)
	end)
	if player.Character ~= nil then
		task.spawn(watchCharacter, player.Character)
	end
	gui.Destroying:Connect(close)

	return {
		open = open,
		close = close,
		isOpen = function(): boolean
			return gui.Enabled
		end,
		delta = function(change: any)
			latest = change.view
			latestCoins = change.coins
			if gui.Enabled then
				render()
			end
		end,
	}
end

return Market
