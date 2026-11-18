--!strict
-- Foam on the river of the plots (land design v2, step 12): thin white strips drift down every flooded segment.
-- Client only, no game state: the server tells the stages of the river in attributes of the plot model. Only plots within
-- RANGE studs of the camera get foam, all strips move with one BulkMoveTo at 20 Hz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local River = require(Shared:WaitForChild("Core"):WaitForChild("River") :: ModuleScript) :: any
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any

local PlotFx = {}

local RANGE = 150
local STEP = 1 / 20
local MAX_PARTS = River.FOAM_STRIPS * Assets.river.segments
local STRIP = Vector3.new(0.4, 0.1, 3.2)

-- Prompts on a plot that belongs to another player are switched off here, so only the own plot offers work and the market.
local function guardPrompts()
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		while model ~= nil and model:GetAttribute("OwnerId") == nil do
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		if model ~= nil and model:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
			prompt.Enabled = false
		end
	end)
end

function PlotFx.start()
	guardPrompts()
	local folder = Instance.new("Folder")
	folder.Name = "Foam"
	folder.Parent = workspace
	local pool: { Part } = {}
	for i = 1, MAX_PARTS do
		local part = Instance.new("Part")
		part.Name = "FoamStrip"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1)
		part.Size = STRIP
		part.Transparency = 1
		part.Parent = folder
		pool[i] = part
	end
	local courses: { [number]: any } = {}

	local since = 0
	RunService.Heartbeat:Connect(function(delta: number)
		since += delta
		if since < STEP then
			return
		end
		since = 0
		local camera = workspace.CurrentCamera
		local plots = workspace:FindFirstChild("Plots")
		if camera == nil or plots == nil then
			return
		end
		local eye = camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		local parts: { BasePart }, frames: { CFrame } = {}, {}
		local used = 0
		for _, model in plots:GetChildren() do
			local origin, slot, facing =
				model:GetAttribute("Origin"), model:GetAttribute("Slot"), model:GetAttribute("Facing")
			local key = model:GetAttribute("RiverStages")
			if
				typeof(origin) ~= "Vector3"
				or type(slot) ~= "number"
				or type(facing) ~= "number"
				or type(key) ~= "string"
			then
				continue
			end
			if (origin - eye).Magnitude > RANGE + Assets.PLOT_SIZE / 2 or string.find(key, "2", 1, true) == nil then
				continue
			end
			local course = courses[slot]
			if course == nil then
				course = River.course(Assets.river, slot)
				courses[slot] = course
			end
			local stages = {}
			for i = 1, #key do
				stages[i] = tonumber(string.sub(key, i, i)) or 0
			end
			for _, strip in River.foam(course, stages, now) do
				if used >= MAX_PARTS then
					break
				end
				used += 1
				local part = pool[used]
				local point = origin + Vector3.new(strip.x, -River.WATER_DROP + 0.1, strip.z * facing)
				table.insert(parts, part)
				table.insert(frames, CFrame.lookAt(point, point + Vector3.new(strip.tx, 0, strip.tz * facing)))
				part.Transparency = 1 - 0.7 * strip.fade
			end
		end
		for i = used + 1, MAX_PARTS do
			pool[i].Transparency = 1
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PlotFx
