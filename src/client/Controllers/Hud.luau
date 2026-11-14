--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends, and its buttons only send intents. No game rules here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Plants") :: ModuleScript
) :: any

local Hud = {}

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 28)
	text.BackgroundTransparency = 0.3
	text.TextScaled = true
	text.LayoutOrder = order
	text.Parent = parent
	return text
end

local function button(parent: Instance, caption: string, order: number, onClick: () -> ())
	local control = Instance.new("TextButton")
	control.Size = UDim2.new(1, 0, 0, 32)
	control.Text = caption
	control.TextScaled = true
	control.LayoutOrder = order
	control.Parent = parent
	control.Activated:Connect(onClick)
end

local function format(value: number): string
	return string.format("%.1f", value)
end

-- Builds the HUD in the player's GUI. `net` is ReplicatedStorage.Net. Returns the handlers for the server messages.
function Hud.build(net: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(260, 420)
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

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	button(frame, "Crank", 6, function()
		send("Crank")
	end)
	for index in Plants do
		button(frame, `Buy plant {index}`, 6 + index, function()
			send("BuyPlant", { plant = index, qty = 1 })
		end)
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
		end,
		env = function(change: any)
			env.Text = `{change.phase} / {change.weather}`
		end,
	}
end

return Hud
