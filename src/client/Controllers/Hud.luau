--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends, and its buttons only send intents. No game rules here.
-- Prices, affordability, the crank value, the upgrade nodes, storage, rules and the grid expansion come from
-- Delta.view (GameCore.view). A button checks that view before it sends; the server checks again. Labels are English.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Effects = require(Config:WaitForChild("Effects") :: ModuleScript) :: any
local Plants = require(Config:WaitForChild("Plants") :: ModuleScript) :: any
local Phases = require(Config:WaitForChild("Phases") :: ModuleScript) :: any
local Upgrades = require(Config:WaitForChild("Upgrades") :: ModuleScript) :: any
local Weather = require(Config:WaitForChild("Weather") :: ModuleScript) :: any

local Hud = {}

local DIMMED = 0.6 -- transparency of a button the player cannot use right now
local SUFFIXES = { "", "K", "M", "B", "T" }
local STORAGE_MODES = {
	{ id = "charge", caption = "Charge" },
	{ id = "sell", caption = "Sell" },
	{ id = "auto", caption = "Auto" },
}
local RULE_NAMES = { charge = "charge cheap", sell = "sell high" }
-- Placeholder rule thresholds: charge while the price factor is at most 0.8, sell while it is at least 1.2.
local CHARGE_BELOW = 0.8
local SELL_ABOVE = 1.2

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 28)
	text.BackgroundTransparency = 0.3
	text.TextScaled = true
	text.LayoutOrder = order
	text.Parent = parent
	return text
end

local function button(parent: Instance, caption: string, order: number, onClick: () -> ()): TextButton
	local control = Instance.new("TextButton")
	control.Size = UDim2.new(1, 0, 0, 32)
	control.Text = caption
	control.TextScaled = true
	control.LayoutOrder = order
	control.Parent = parent
	control.Activated:Connect(onClick)
	return control
end

-- Dims a button the player cannot use right now; it still shows its caption.
local function dim(control: TextButton, usable: boolean)
	local transparency = if usable then 0 else DIMMED
	control.TextTransparency = transparency
	control.BackgroundTransparency = transparency
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

-- The English label of a phase or weather id from its Config table.
local function labelOf(list: { any }, id: string): string
	for _, entry in list do
		if entry.id == id then
			return entry.label
		end
	end
	return id
end

-- Builds the HUD in the player's GUI. `net` is ReplicatedStorage.Net. Returns the handlers for the server messages.
function Hud.build(net: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.fromOffset(300, 560)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = 6
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

	local coins = label(frame, nextOrder())
	local rate = label(frame, nextOrder())
	local storage = label(frame, nextOrder())
	local grid = label(frame, nextOrder())
	local env = label(frame, nextOrder())
	local goal = label(frame, nextOrder())

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	-- The latest view from the server; buttons check it before they send.
	local latest: any = nil

	local crank = button(frame, "Crank", nextOrder(), function()
		send("Crank")
	end)
	local buyButtons: { [number]: TextButton } = {}
	for index in Plants do
		buyButtons[index] = button(frame, `Buy {Plants[index].name}`, nextOrder(), function()
			send("BuyPlant", { plant = index, qty = 1 })
		end)
	end

	local upgradeTitle = label(frame, nextOrder())
	upgradeTitle.Text = "Upgrades (this run)"
	local nodeButtons: { [number]: TextButton } = {}
	for index, node in Upgrades.run do
		nodeButtons[index] = button(frame, node.id, nextOrder(), function()
			if latest ~= nil and latest.nodes[index].state == "affordable" then
				send("BuyNode", { node = node.id })
			end
		end)
	end

	local modeTitle = label(frame, nextOrder())
	local modeButtons: { [string]: TextButton } = {}
	for _, mode in STORAGE_MODES do
		modeButtons[mode.id] = button(frame, mode.caption, nextOrder(), function()
			if latest ~= nil and latest.storage.stage >= 1 then
				send("SetStorageMode", { mode = mode.id })
			end
		end)
	end

	local rulesTitle = label(frame, nextOrder())
	-- One row per rule slot the Control Center can give (three with P8); the rows beyond the owned slots are hidden.
	local ruleRows: { [number]: any } = {}
	for slot = 1, Effects.ruleSlotsP8 do
		local status = label(frame, nextOrder())
		local charge = button(frame, `Slot {slot}: charge below {CHARGE_BELOW}`, nextOrder(), function()
			if latest ~= nil and slot <= latest.storage.ruleSlots then
				send("SetRule", { slot = slot, rule = "charge", th = CHARGE_BELOW, on = true })
			end
		end)
		local sell = button(frame, `Slot {slot}: sell high above {SELL_ABOVE}`, nextOrder(), function()
			if latest ~= nil and slot <= latest.storage.ruleSlots then
				send("SetRule", { slot = slot, rule = "sell", th = SELL_ABOVE, on = true })
			end
		end)
		local toggle = button(frame, `Slot {slot}: switch on or off`, nextOrder(), function()
			local rule = if latest ~= nil then latest.storage.rules[slot] else nil
			if rule ~= nil then
				send("SetRule", { slot = slot, rule = rule.id, th = rule.th, on = not rule.on })
			end
		end)
		ruleRows[slot] = { status = status, charge = charge, sell = sell, toggle = toggle }
	end

	local expand = button(frame, "Grid expansion", nextOrder(), function()
		if latest ~= nil and latest.goal ~= nil and latest.goal.allowed then
			send("Prestige")
		end
	end)

	-- Captions and dimming from the server's view: prices, the crank value, the nodes and the grid expansion.
	local function shop(view: any)
		crank.Text = `Crank: +{energy(view.crank)} energy per click`
		for index, control in buyButtons do
			local item = view.plants[index]
			control.Text = `Buy {Plants[index].name}: {short(item.cost)}`
			dim(control, item.affordable)
		end
		for index, control in nodeButtons do
			local node = Upgrades.run[index]
			local item = view.nodes[index]
			control.Text = `{node.id} {node.name}: {short(item.cost)} ({item.state})`
			dim(control, item.state == "affordable")
		end
		if view.goal ~= nil then
			goal.Text =
				`Next: Grid expansion at {short(view.goal.required)} run earnings (now {short(view.goal.earned)})`
			expand.Text = `Grid expansion: +{view.goal.sparks} sparks`
			dim(expand, view.goal.allowed)
		else
			goal.Text = "Grid expansion: all levels done"
			expand.Text = "Grid expansion: all levels done"
			dim(expand, false)
		end
	end

	-- Storage modes and rules from the server's view. Modes need U17; rule slots need U21 (shown per slot).
	local function storageSection(view: any)
		local stored = view.storage
		modeTitle.Text = if stored.stage >= 1 then `Storage mode: {stored.mode}` else "Storage: needs U17"
		for _, mode in STORAGE_MODES do
			dim(modeButtons[mode.id], stored.stage >= 1)
		end
		rulesTitle.Text = if stored.ruleSlots > 0 then "Rules" else "Rules: needs U21 Control Center"
		for slot, row in ruleRows do
			local visible = slot <= stored.ruleSlots
			local rule = stored.rules[slot]
			row.status.Visible = visible
			row.charge.Visible = visible
			row.sell.Visible = visible
			row.toggle.Visible = visible
			if rule ~= nil then
				local switch = if rule.on then "on" else "off"
				row.status.Text = `Slot {slot}: {RULE_NAMES[rule.id]} at {rule.th}, {switch}`
			else
				row.status.Text = `Slot {slot}: empty`
			end
			dim(row.toggle, rule ~= nil)
		end
	end

	return {
		snapshot = function(state: any)
			coins.Text = `Coins {format(state.coins)}`
			storage.Text = `Storage {format(state.storage.charge)}`
			grid.Text = `Grid level {state.level}`
		end,
		delta = function(change: any)
			latest = change.view
			coins.Text = `Coins {format(change.coins)}`
			rate.Text = `Rate {format(change.rate)} / s`
			storage.Text = `Storage {format(change.charge)}`
			shop(change.view)
			storageSection(change.view)
		end,
		env = function(change: any)
			env.Text = `{labelOf(Phases, change.phase)} / {labelOf(Weather, change.weather)}`
		end,
	}
end

return Hud
