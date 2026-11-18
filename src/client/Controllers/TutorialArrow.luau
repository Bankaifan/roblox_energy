--!strict
-- Tutorial arrow (design v2, step 15): a bobbing arrow above the prompt the current tutorial step points to. Crank step: the
-- crank; the market and buying steps: the market. Other steps have no arrow. Client only, no game state: the server names the
-- step (Tutorial message), the arrow finds the own plot's prompt by name.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TutorialArrow = {}

-- Step id -> the name of the prompt (made by PlotService) the arrow sits on.
local TARGETS: { [string]: string } = {
	crank = "CrankPrompt",
	market = "ShopPrompt",
	shovel = "ShopPrompt",
	container = "ShopPrompt",
	storage = "ShopPrompt",
}
local HEIGHT = 7 -- studs above the prompt's anchor
local BOB = 1 -- studs of up and down
local FIND_SECONDS = 0.5

-- The part holding the own plot's prompt with this name, or nil while the plot has not arrived.
local function anchorOf(name: string): BasePart?
	local plots = workspace:FindFirstChild("Plots")
	if plots == nil then
		return nil
	end
	local me = (Players.LocalPlayer :: Player).UserId
	for _, model in plots:GetChildren() do
		if model:GetAttribute("OwnerId") == me then
			local prompt = model:FindFirstChild(name, true)
			if
				prompt ~= nil
				and prompt:IsA("ProximityPrompt")
				and prompt.Parent ~= nil
				and prompt.Parent:IsA("BasePart")
			then
				return prompt.Parent
			end
		end
	end
	return nil
end

-- Returns `show(id)`: id is a tutorial step id or "" (no tutorial).
function TutorialArrow.build(): (string) -> ()
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "TutorialArrow"
	arrow.AlwaysOnTop = true
	arrow.Size = UDim2.fromOffset(48, 48)
	arrow.LightInfluence = 0
	arrow.Enabled = false
	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Text = "▼"
	glyph.TextScaled = true
	glyph.TextColor3 = Color3.fromRGB(255, 214, 64)
	glyph.TextStrokeTransparency = 0.3
	glyph.Parent = arrow

	local step = ""
	local placed = "" -- the prompt name the arrow sits on now
	local since = FIND_SECONDS
	RunService.Heartbeat:Connect(function(delta: number)
		local wanted = TARGETS[step]
		if wanted == nil then
			arrow.Enabled = false
			return
		end
		since += delta
		if since >= FIND_SECONDS and (arrow.Adornee == nil or arrow.Adornee.Parent == nil or placed ~= wanted) then
			since = 0
			local anchor = anchorOf(wanted)
			arrow.Adornee = anchor
			arrow.Parent = anchor
			placed = if anchor ~= nil then wanted else ""
		end
		arrow.Enabled = arrow.Adornee ~= nil
		arrow.StudsOffset = Vector3.new(0, HEIGHT + math.sin(os.clock() * 4) * BOB, 0)
	end)
	return function(id: string)
		step = id
		-- A new step may point somewhere else: look the target up again at once.
		placed = ""
		arrow.Adornee = nil
		since = FIND_SECONDS
	end
end

return TutorialArrow
