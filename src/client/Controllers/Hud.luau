--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends, and its buttons only send intents. No game rules here.
-- Prices, affordability, the crank value, the upgrade nodes, storage, rules and the grid expansion come from
-- Delta.view (GameCore.view). A button checks that view before it sends; the server checks again. Every label comes
-- from the Locale tables in the current language: the player's locale at the start, switched by the Language button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Effects = require(Config:WaitForChild("Effects") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local Plants = require(Config:WaitForChild("Plants") :: ModuleScript) :: any
local Upgrades = require(Config:WaitForChild("Upgrades") :: ModuleScript) :: any
local BoostView = require(script.Parent.BoostView)

local Hud = {}

-- A control the player cannot use right now: its text stays readable, its background fades.
local DIMMED_TEXT = 0.3
local DIMMED_BACKGROUND = 0.6
-- The panel is at most this wide; on a narrow screen it shrinks to the screen width instead.
local PANEL_MAX_WIDTH = 300
-- Every row and button uses the same fixed text size. Long text wraps onto a second line and the row grows with it.
local ROW_TEXT = 14
local ROW_MIN_HEIGHT = 36
-- Inner padding: left and right it keeps text off the edge and off the scrollbar; top and bottom it gives wrapped lines air.
local ROW_SIDE_PADDING = 8
local ROW_VERTICAL_PADDING = 4
local SUFFIXES = { "", "K", "M", "B", "T" }
local STORAGE_MODES = {
	{ id = "charge", key = "mode.charge" },
	{ id = "sell", key = "mode.sell" },
	{ id = "auto", key = "mode.auto" },
}
-- Placeholder rule thresholds: charge while the price factor is at most 0.8, sell while it is at least 1.2.
local CHARGE_BELOW = 0.8
local SELL_ABOVE = 1.2
-- The fixed detail area under the upgrade list (name, effect, reason, Buy), the gap above Buy, and the border of the selected row.
local DETAIL_HEIGHT = 160
local DETAIL_GAP = 4
local SELECTED_BORDER = 3
local SELECTED_COLOR = Color3.fromRGB(255, 200, 0)
-- The market tabs in order (Technik, Upgrades, Speicher, Werkzeuge): id and Locale key. Tab buttons are touch sized.
local TABS = {
	{ id = "plants", key = "tab.plants" },
	{ id = "upgrades", key = "tab.upgrades" },
	{ id = "storage", key = "tab.storage" },
	{ id = "tools", key = "tab.tools" },
}
local TAB_HEIGHT = 44

-- Gives a row or button the shared look: fixed text size, wrapped text, inner padding, and a height that grows with the text.
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

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 0.3
	text.TextSize = ROW_TEXT
	text.TextWrapped = true
	text.LayoutOrder = order
	fitRow(text)
	text.Parent = parent
	return text
end

local function button(parent: Instance, caption: string, order: number, onClick: () -> ()): TextButton
	local control = Instance.new("TextButton")
	control.Text = caption
	control.TextSize = ROW_TEXT
	control.TextWrapped = true
	control.LayoutOrder = order
	fitRow(control)
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

-- 10000000 is "10M", 1100 is "1.1K": at most one decimal and one suffix.
local function short(value: number): string
	local scaled = value
	local index = 1
	while scaled >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local text = string.gsub(string.format("%.1f", scaled), "%.0$", "")
	return text .. SUFFIXES[index]
end

-- Crank energy per click: whole numbers as they are, otherwise two decimals.
local function energy(value: number): string
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.2f", value)
end

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
	-- Fills the screen minus the margin and the detail area, at most PANEL_MAX_WIDTH wide; the list scrolls.
	frame.Size = UDim2.new(1, -32, 1, -(48 + DETAIL_HEIGHT))
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
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	-- Each control gets the next layout order, so the list shows them top to bottom.
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- The shop panel (the list and the detail area) can be shown or hidden; the Shop button toggles it and the market's
	-- prompt opens it. `detail` is created below, so the setter is filled in after it.
	local setShop: (boolean) -> () = function() end
	local shopOpen = true
	local shopButton = button(gui, "", 0, function()
		setShop(not shopOpen)
	end)
	shopButton.AutomaticSize = Enum.AutomaticSize.None
	shopButton.AnchorPoint = Vector2.new(1, 0)
	shopButton.Position = UDim2.new(1, -16, 0, 16)
	shopButton.Size = UDim2.fromOffset(96, ROW_MIN_HEIGHT)

	-- Changes the language and paints every label again. Declared here, written below once the labels exist.
	local paint: () -> ()
	local language = button(frame, "", nextOrder(), function()
		lang = if lang == "en" then "de" else "en"
		paint()
	end)
	local coins = label(frame, nextOrder())
	local rate = label(frame, nextOrder())
	local storage = label(frame, nextOrder())
	local storageHint = label(frame, nextOrder())
	local grid = label(frame, nextOrder())
	local env = label(frame, nextOrder())
	-- The Sunshine Hour button and banner, right under the weather line.
	local boost = BoostView.build(frame, nextOrder, function(): string
		return lang
	end)
	local goal = label(frame, nextOrder())

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	-- The latest view from the server; buttons check it before they send.
	local latest: any = nil
	-- The open market tab, and the controls that belong to each tab (shown only while their tab is open).
	local currentTab = "plants"
	local tabControls: { [string]: { GuiObject } } = { plants = {}, upgrades = {}, storage = {}, tools = {} }
	local tabButtons: { [string]: TextButton } = {}
	local setTab: (string) -> () = function() end
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.LayoutOrder = nextOrder()
	tabBar.Size = UDim2.new(1, 0, 0, TAB_HEIGHT)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar
	tabBar.Parent = frame
	for index, tab in TABS do
		local control = button(tabBar, "", index, function()
			setTab(tab.id)
		end)
		control.AutomaticSize = Enum.AutomaticSize.None
		control.Size = UDim2.new(1 / #TABS, 0, 0, TAB_HEIGHT)
		control.TextTruncate = Enum.TextTruncate.AtEnd
		tabButtons[tab.id] = control
	end
	-- Puts a control on a tab; it stays hidden while another tab is open.
	local function onTab(tab: string, control: any): any
		table.insert(tabControls[tab], control)
		control.Visible = tab == currentTab
		return control
	end
	-- The upgrade the player tapped (an index into Upgrades.run), and the row buttons to highlight it.
	local selected: number? = nil
	local nodeButtons: { [number]: TextButton } = {}
	-- The last Snapshot, Delta and Env, kept so a language change can paint them again without waiting for the server.
	local lastSnapshot: any = nil
	local lastDelta: any = nil
	local lastEnv: any = nil

	-- Fixed detail area under the list: it is a sibling of the scrolled frame, so it stays visible on a phone.
	local detail = Instance.new("Frame")
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.new(0, 16, 1, -16)
	detail.Size = UDim2.new(1, -32, 0, DETAIL_HEIGHT)
	detail.BackgroundTransparency = 1
	local detailWidth = Instance.new("UISizeConstraint")
	detailWidth.MaxSize = Vector2.new(PANEL_MAX_WIDTH, math.huge)
	detailWidth.Parent = detail
	detail.Parent = gui
	-- The detail area (name, effect, Buy) belongs to the upgrade list, so only the Upgrades tab shows it.
	local function showShop()
		frame.Visible = shopOpen
		detail.Visible = shopOpen and currentTab == "upgrades"
	end
	setShop = function(open: boolean)
		shopOpen = open
		showShop()
	end
	-- Name, effect and reason scroll inside the detail area when they wrap long; Buy stays pinned to its bottom edge.
	local detailText = Instance.new("ScrollingFrame")
	detailText.Size = UDim2.new(1, 0, 1, -(ROW_MIN_HEIGHT + DETAIL_GAP))
	detailText.BackgroundTransparency = 1
	detailText.CanvasSize = UDim2.new()
	detailText.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailText.ScrollBarThickness = 6
	detailText.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	detailText.Parent = detail
	local detailLayout = Instance.new("UIListLayout")
	detailLayout.Padding = UDim.new(0, 4)
	detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailLayout.Parent = detailText
	local detailName = label(detailText, 1)
	local detailEffect = label(detailText, 2)
	local detailReason = label(detailText, 3)
	local detailBuy = button(detail, t("action.buy"), 4, function()
		if selected ~= nil and latest ~= nil and latest.nodes[selected].state == "affordable" then
			send("BuyNode", { node = Upgrades.run[selected].id })
		end
	end)
	detailBuy.AutomaticSize = Enum.AutomaticSize.None
	detailBuy.TextTruncate = Enum.TextTruncate.AtEnd
	detailBuy.AnchorPoint = Vector2.new(0, 1)
	detailBuy.Position = UDim2.fromScale(0, 1)
	detailBuy.Size = UDim2.new(1, 0, 0, ROW_MIN_HEIGHT)

	-- The name of a plant or upgrade node in the current language.
	local function plantName(index: number): string
		return t(`plant.{Plants[index].id}`)
	end
	local function nodeName(node: any): string
		return t(`node.{node.id}.name`)
	end

	-- Why a locked upgrade is locked: the plant or the upgrade it needs.
	local function requirementOf(node: any): string
		if node.requiresPlant ~= nil then
			for _, plant in Plants do
				if plant.id == node.requiresPlant then
					return t(`plant.{plant.id}`)
				end
			end
		end
		for _, other in Upgrades.run do
			if other.id == node.requiresNode then
				return `{other.id} {nodeName(other)}`
			end
		end
		return t("reason.prerequisite")
	end

	-- Shows the selected upgrade: name and cost, effect text, state or reason, and its Buy button.
	local function showDetail()
		local index = selected
		if index == nil or latest == nil then
			detailName.Text = t("detail.hint")
			detailEffect.Text = ""
			detailReason.Text = ""
			detailBuy.Text = t("action.buy")
			dim(detailBuy, false)
			return
		end
		local node = Upgrades.run[index]
		local item = latest.nodes[index]
		detailName.Text = t("detail.title", { id = node.id, name = nodeName(node), cost = short(node.cost) })
		detailEffect.Text = t(`node.{node.id}.info`)
		if item.state == "bought" then
			detailReason.Text = t("reason.bought")
		elseif item.state == "locked" then
			detailReason.Text = t("reason.locked", { requirement = requirementOf(node) })
		elseif item.state == "open" then
			detailReason.Text = t("reason.open")
		else
			detailReason.Text = t("reason.affordable")
		end
		local affordable = item.state == "affordable"
		detailBuy.Text = if affordable then t("action.buyNamed", { name = nodeName(node) }) else t("action.buy")
		dim(detailBuy, affordable)
	end

	-- The selected row has a coloured border; the others have none.
	local function highlightRows()
		for index, control in nodeButtons do
			control.BorderSizePixel = if index == selected then SELECTED_BORDER else 0
			control.BorderColor3 = SELECTED_COLOR
		end
	end

	local function selectNode(index: number)
		selected = index
		highlightRows()
		showDetail()
	end

	local crank = button(frame, "", nextOrder(), function()
		send("Crank")
	end)
	local buyButtons: { [number]: TextButton } = {}
	for index in Plants do
		buyButtons[index] = onTab(
			"plants",
			button(frame, "", nextOrder(), function()
				if latest ~= nil and latest.plants[index].needsSite == true then
					-- No site yet: the row names the tool, a tap leads to the Tools tab instead of buying.
					setTab("tools")
				else
					send("BuyPlant", { plant = index, qty = 1 })
				end
			end)
		)
	end

	local upgradeTitle = onTab("upgrades", label(frame, nextOrder()))
	-- A row only selects its upgrade; the Buy button in the detail area buys it.
	for index, node in Upgrades.run do
		nodeButtons[index] = onTab(
			"upgrades",
			button(frame, node.id, nextOrder(), function()
				selectNode(index)
			end)
		)
	end

	-- The Storage tab starts with the container; U17 needs it once the land rules are on.
	local containerRow = onTab(
		"storage",
		button(frame, "", nextOrder(), function()
			local land = if latest ~= nil then latest.land else nil
			if land ~= nil and not land.container then
				send("Prepare", { target = "container" })
			end
		end)
	)
	local modeTitle = onTab("storage", label(frame, nextOrder()))
	local modeButtons: { [string]: TextButton } = {}
	for _, mode in STORAGE_MODES do
		modeButtons[mode.id] = onTab(
			"storage",
			button(frame, "", nextOrder(), function()
				if latest ~= nil and latest.storage.stage >= 1 then
					send("SetStorageMode", { mode = mode.id })
				end
			end)
		)
	end

	local rulesTitle = onTab("storage", label(frame, nextOrder()))
	-- One row per rule slot the Control Center can give (three with P8); the rows beyond the owned slots are hidden.
	local ruleRows: { [number]: any } = {}
	for slot = 1, Effects.ruleSlotsP8 do
		local status = label(frame, nextOrder())
		local charge = button(frame, "", nextOrder(), function()
			if latest ~= nil and slot <= latest.storage.ruleSlots then
				send("SetRule", { slot = slot, rule = "charge", th = CHARGE_BELOW, on = true })
			end
		end)
		local sell = button(frame, "", nextOrder(), function()
			if latest ~= nil and slot <= latest.storage.ruleSlots then
				send("SetRule", { slot = slot, rule = "sell", th = SELL_ABOVE, on = true })
			end
		end)
		local toggle = button(frame, "", nextOrder(), function()
			local rule = if latest ~= nil then latest.storage.rules[slot] else nil
			if rule ~= nil then
				send("SetRule", { slot = slot, rule = rule.id, th = rule.th, on = not rule.on })
			end
		end)
		ruleRows[slot] = { status = status, charge = charge, sell = sell, toggle = toggle }
	end

	-- The Tools tab: one row per tool of Config/Land; a tap buys it when the view says it is buyable.
	local toolRows: { [string]: TextButton } = {}
	for _, tool in Land.tools do
		toolRows[tool.id] = onTab(
			"tools",
			button(frame, "", nextOrder(), function()
				if latest == nil then
					return
				end
				for _, item in latest.tools or {} do
					if item.id == tool.id and item.buyable then
						send("BuyTool", { tool = tool.id })
					end
				end
			end)
		)
	end

	local expand = button(frame, "", nextOrder(), function()
		if latest ~= nil and latest.goal ~= nil and latest.goal.allowed then
			send("Prestige")
		end
	end)

	-- Captions and dimming from the server's view: prices, the crank value, the nodes and the grid expansion.
	local function shop(view: any)
		crank.Text = t("shop.crank", { energy = energy(view.crank) })
		for index, control in buyButtons do
			local item = view.plants[index]
			if item.needsSite == true then
				-- A plant without a site names the tool that prepares its ground instead of a price.
				local toolId = Land.fieldTools[index]
				local toolKey = "tool." .. toolId
				for _, tool in Land.tools do
					if tool.id == toolId then
						toolKey = tool.textKey
					end
				end
				control.Text = `{plantName(index)}: {t("hint.needTool", { tool = t(toolKey) })}`
				dim(control, false)
			else
				control.Text = t("shop.plantPrice", { name = plantName(index), cost = short(item.cost) })
				dim(control, item.affordable)
			end
		end
		if view.tools ~= nil then
			for _, item in view.tools do
				local control = toolRows[item.id]
				local name = t(item.textKey)
				if item.owned then
					control.Text = t("tool.owned", { name = name })
				elseif item.revealed then
					control.Text = t("tool.line", {
						name = name,
						cost = short(item.price),
						info = t(item.textKey .. ".info"),
					})
				else
					control.Text = t("tool.locked", { name = name })
				end
				dim(control, item.buyable)
			end
		end
		if view.land ~= nil then
			if view.land.container then
				containerRow.Text = t("container.owned")
			else
				containerRow.Text = t("container.line", { cost = short(Land.containerCost) })
			end
			local affordable = lastDelta ~= nil and lastDelta.coins >= Land.containerCost
			dim(containerRow, not view.land.container and affordable)
		end
		for index, control in nodeButtons do
			local node = Upgrades.run[index]
			local item = view.nodes[index]
			control.Text = t("node.line", {
				id = node.id,
				name = nodeName(node),
				cost = short(item.cost),
				state = t("state." .. item.state),
			})
			dim(control, item.state == "affordable")
		end
		if view.goal ~= nil then
			goal.Text = t("goal.next", { required = short(view.goal.required), earned = short(view.goal.earned) })
			expand.Text = t("goal.expand", { sparks = view.goal.sparks })
			dim(expand, view.goal.allowed)
		else
			goal.Text = t("goal.done")
			expand.Text = t("goal.done")
			dim(expand, false)
		end
	end

	-- Storage modes and rules from the server's view. Modes need U17; rule slots need U21 (shown per slot).
	local function storageSection(view: any)
		local stored = view.storage
		if stored.stage >= 1 then
			modeTitle.Text = t("storage.mode", { mode = t("mode." .. stored.mode) })
		else
			modeTitle.Text = t("storage.locked")
		end
		for _, mode in STORAGE_MODES do
			dim(modeButtons[mode.id], stored.stage >= 1)
		end
		rulesTitle.Text = if stored.ruleSlots > 0 then t("rules.title") else t("rules.locked")
		for slot, row in ruleRows do
			local visible = slot <= stored.ruleSlots and currentTab == "storage"
			local rule = stored.rules[slot]
			row.status.Visible = visible
			row.charge.Visible = visible
			row.sell.Visible = visible
			row.toggle.Visible = visible
			if rule ~= nil then
				local state = if rule.on then "state.on" else "state.off"
				row.status.Text = t("rule.status", {
					slot = slot,
					rule = t("rule." .. rule.id),
					threshold = rule.th,
					state = t(state),
				})
			else
				row.status.Text = t("rule.empty", { slot = slot })
			end
			dim(row.toggle, rule ~= nil)
		end
	end

	-- Opens a tab: its controls show, the others hide, the active tab button gets the selection border.
	setTab = function(tab: string)
		currentTab = tab
		for id, controls in tabControls do
			for _, control in controls do
				control.Visible = id == tab
			end
		end
		for id, control in tabButtons do
			control.BorderSizePixel = if id == tab then SELECTED_BORDER else 0
			control.BorderColor3 = SELECTED_COLOR
		end
		if latest ~= nil then
			storageSection(latest)
		else
			for _, row in ruleRows do
				row.status.Visible = false
				row.charge.Visible = false
				row.sell.Visible = false
				row.toggle.Visible = false
			end
		end
		frame.CanvasPosition = Vector2.zero
		showShop()
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
		shop(change.view)
		storageSection(change.view)
		showDetail()
	end
	local function applyEnv(change: any)
		env.Text = t("phase." .. change.phase) .. " / " .. t("weather." .. change.weather)
	end

	-- Sets every caption in the current language, then paints the last server data in it. The server data is
	-- painted again on purpose: shop, storage and env texts are not kept anywhere else.
	paint = function()
		language.Text = t("hud.language", { name = t("language." .. lang) })
		shopButton.Text = t("hud.shop")
		for _, tab in TABS do
			tabButtons[tab.id].Text = t(tab.key)
		end
		containerRow.Text = t("container.line", { cost = short(Land.containerCost) })
		for _, tool in Land.tools do
			toolRows[tool.id].Text = t("tool.locked", { name = t(tool.textKey) })
		end
		crank.Text = t("action.crank")
		for index, control in buyButtons do
			control.Text = t("action.buyNamed", { name = plantName(index) })
		end
		upgradeTitle.Text = t("upgrades.title")
		for _, mode in STORAGE_MODES do
			modeButtons[mode.id].Text = t("mode.hint." .. mode.id)
		end
		storageHint.Text = t("hud.storageHint")
		for slot, row in ruleRows do
			row.charge.Text = t("rule.slotCharge", { slot = slot, threshold = CHARGE_BELOW })
			row.sell.Text = t("rule.slotSell", { slot = slot, threshold = SELL_ABOVE })
			row.toggle.Text = t("rule.slotToggle", { slot = slot })
		end
		expand.Text = t("action.expand")
		if lastSnapshot ~= nil then
			applySnapshot(lastSnapshot)
		end
		if lastDelta ~= nil then
			applyDelta(lastDelta)
		end
		if lastEnv ~= nil then
			applyEnv(lastEnv)
		end
		showDetail()
		boost.relabel()
	end
	paint()
	setTab(currentTab)

	return {
		language = function(): string
			return lang
		end,
		openShop = function()
			setShop(true)
			frame.CanvasPosition = Vector2.zero
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
		env = function(change: any)
			lastEnv = change
			applyEnv(change)
			boost.env(change)
		end,
	}
end

return Hud
