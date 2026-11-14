--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends, and its buttons only send intents. No game rules here.
-- Prices, affordability, the crank value and the goal come from Delta.view (GameCore.view). Labels are English.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Plants = require(Config:WaitForChild("Plants") :: ModuleScript) :: any
local Phases = require(Config:WaitForChild("Phases") :: ModuleScript) :: any
local Weather = require(Config:WaitForChild("Weather") :: ModuleScript) :: any

local Hud = {}

local DIMMED = 0.6 -- transparency of a buy button the player cannot afford
local SUFFIXES = { "", "K", "M", "B", "T" }

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
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(260, 460)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local coins = label(frame, 1)
	local rate = label(frame, 2)
	local storage = label(frame, 3)
	local grid = label(frame, 4)
	local env = label(frame, 5)
	local goal = label(frame, 6)

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	local crank = button(frame, "Crank", 7, function()
		send("Crank")
	end)
	local buyButtons: { [number]: TextButton } = {}
	for index in Plants do
		buyButtons[index] = button(frame, `Buy {Plants[index].name}`, 7 + index, function()
			send("BuyPlant", { plant = index, qty = 1 })
		end)
	end

	-- Captions and dimming from the server's view: prices, the crank value and the next grid expansion.
	local function shop(view: any)
		crank.Text = `Crank: +{energy(view.crank)} energy per click`
		for index, control in buyButtons do
			local item = view.plants[index]
			control.Text = `Buy {Plants[index].name}: {short(item.cost)}`
			local dim = if item.affordable then 0 else DIMMED
			control.TextTransparency = dim
			control.BackgroundTransparency = dim
		end
		if view.goal ~= nil then
			goal.Text =
				`Next: Grid expansion at {short(view.goal.required)} run earnings (now {short(view.goal.earned)})`
		else
			goal.Text = "Grid expansion: all levels done"
		end
	end

	return {
		snapshot = function(state: any)
			coins.Text = `Coins {format(state.coins)}`
			storage.Text = `Storage {format(state.storage.charge)}`
			grid.Text = `Grid level {state.level}`
		end,
		delta = function(change: any)
			coins.Text = `Coins {format(change.coins)}`
			rate.Text = `Rate {format(change.rate)} / s`
			storage.Text = `Storage {format(change.charge)}`
			shop(change.view)
		end,
		env = function(change: any)
			env.Text = `{labelOf(Phases, change.phase)} / {labelOf(Weather, change.weather)}`
		end,
	}
end

return Hud
