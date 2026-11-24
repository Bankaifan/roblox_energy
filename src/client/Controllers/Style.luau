--!strict
-- Cosmetic choices of the owner (Core/Cosmetics): two small buttons, one for the glow colour of Neon Plants and one for
-- the Plot Themes design, shown only for an owned pass. A tap sends SetCosmetic with the next item of the list; the
-- server checks it again. Also shows the server's Notice messages (the Upgrade Fireworks announcement) in the chat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Core"):WaitForChild("Cosmetics") :: ModuleScript) :: any
local Locale = require(Shared:WaitForChild("Config"):WaitForChild("Locale") :: ModuleScript) :: any
local Theme = require(script.Parent.Parent.Theme)

local Style = {}

local SLOTS = {
	{ slot = Cosmetics.SLOT_NEON, key = "neon", title = "style.neon", item = "style.neon." },
	{ slot = Cosmetics.SLOT_THEME, key = "theme", title = "style.theme", item = "style.theme." },
}

function Style.build(net: Instance, language: () -> string)
	local player = Players.LocalPlayer :: Player
	local setCosmetic = net:WaitForChild("SetCosmetic") :: RemoteEvent
	local notice = net:WaitForChild("Notice") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Style"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	Theme.fitScreen(gui)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 16, 1, -68) -- above the Leaderboard button
	row.Size = UDim2.fromOffset(190, 100)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = row

	local current: { [string]: string } = {}
	local buttons: { [string]: TextButton } = {}
	for order, entry in SLOTS do
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 44)
		button.BackgroundColor3 = Theme.colors.panel
		button.TextColor3 = Theme.colors.text
		button.Font = Theme.fonts.bold
		button.TextSize = 16
		Theme.round(button)
		button.Visible = false
		button.Parent = row
		buttons[entry.key] = button
		button.Activated:Connect(function()
			local following = Cosmetics.nextItem(entry.slot, current[entry.key])
			if following ~= nil then
				setCosmetic:FireServer({ slot = entry.slot, item = following })
			end
		end)
	end

	-- Delta extras.style: the chosen items; "" means the pass is not owned.
	local function show(style: any)
		local shown = false
		for _, entry in SLOTS do
			local item = if type(style) == "table" then style[entry.key] else nil
			local owned = type(item) == "string" and item ~= ""
			local button = buttons[entry.key]
			button.Visible = owned
			if owned then
				shown = true
				current[entry.key] = item
				button.Text = `{Locale.t(entry.title, language())}: {Locale.t(entry.item .. item, language())}`
			end
		end
		gui.Enabled = shown
	end

	notice.OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.text) ~= "string" then
			return
		end
		pcall(function()
			local channel = TextChatService:FindFirstChild("TextChannels")
			local general = if channel ~= nil then channel:FindFirstChild("RBXGeneral") else nil
			if general ~= nil then
				(general :: TextChannel):DisplaySystemMessage(message.text)
			end
		end)
	end)

	return {
		delta = function(change: any)
			if type(change.extras) == "table" then
				show(change.extras.style)
			end
		end,
	}
end

return Style
