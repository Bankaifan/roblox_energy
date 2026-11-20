--!strict
-- Tutorial arrow (design tutorial-v2, section 4.4): a bobbing arrow over the target the presentation names: the crank, the
-- market, or the spots of field 1 and of the river spring (invisible parts TutorialSpot1 and TutorialSpot2 in the own plot).
-- Client only, no game state. It fades out within FADE_NEAR studs of the target (the prompt itself takes over) and returns
-- beyond FADE_FAR.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TutorialArrow = {}

-- Target -> the name of the prompt or part the arrow sits on (all made by PlotService).
local TARGETS: { [string]: string } = {
	crank = "CrankPrompt",
	market = "ShopPrompt",
	field1 = "TutorialSpot1",
	field2 = "TutorialSpot2",
	wiring = "LandPromptwired",
}
local FADE_NEAR = 12
local FADE_FAR = 16
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
			local found = model:FindFirstChild(name, true)
			if found ~= nil and found:IsA("BasePart") then
				return found
			elseif
				found ~= nil
				and found:IsA("ProximityPrompt")
				and found.Parent ~= nil
				and found.Parent:IsA("BasePart")
			then
				return found.Parent
			end
		end
	end
	return nil
end

-- Returns `show(target)`: a target name of TARGETS or "" (no arrow).
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
	local faded = false
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
		-- Fade near the target; the prompt or the field itself is the pointer there.
		local anchor = arrow.Adornee
		local character = (Players.LocalPlayer :: Player).Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if anchor ~= nil and anchor:IsA("BasePart") and root ~= nil and root:IsA("BasePart") then
			local distance = (root.Position - anchor.Position).Magnitude
			if distance < FADE_NEAR then
				faded = true
			elseif distance > FADE_FAR then
				faded = false
			end
		end
		glyph.TextTransparency = if faded then 1 else 0
		glyph.TextStrokeTransparency = if faded then 1 else 0.3
		arrow.StudsOffset = Vector3.new(0, HEIGHT + math.sin(os.clock() * 4) * BOB, 0)
	end)
	return function(id: string)
		step = id
		faded = false
		-- A new step may point somewhere else: look the target up again at once.
		placed = ""
		arrow.Adornee = nil
		since = FIND_SECONDS
	end
end

return TutorialArrow
