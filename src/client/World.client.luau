--!strict
-- Day and night on the client (issue 85): the sun follows the server clock every frame, the mood four times a second.
-- At night lamps, glowing flowers and the power plants on the plots light up; the wind turbines turn. Holds no game state.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("Core"):WaitForChild("DayCycle") :: ModuleScript) :: any
local Phases = require(Shared:WaitForChild("Config"):WaitForChild("Phases") :: ModuleScript) :: any
local Ambience = require(Shared:WaitForChild("Ambience") :: ModuleScript) :: any
local TurnRange = require(Shared:WaitForChild("Core"):WaitForChild("TurnRange") :: ModuleScript) :: any

local MOOD_SECONDS = 0.25
local ROTOR_SPEED = 0.8 -- radians per second
local WHEEL_SPEED = 0.6 -- water wheels, radians per second

-- Turning models (issue 113): only those within TurnRange.RANGE studs of the camera move, all of them in one BulkMoveTo per tick.
-- Each entry keeps its parts with their offset to the base pivot, so a turn is one multiplication per part.
type Turner = { parts: { BasePart }, offsets: { CFrame }, base: CFrame, reach: number }

local function newTurner(model: Model): Turner
	local base = model:GetPivot()
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(offsets, base:ToObjectSpace(part.CFrame))
		end
	end
	return { parts = parts, offsets = offsets, base = base, reach = model:GetExtentsSize().Magnitude / 2 }
end

local function track(tag: string): { [Model]: Turner }
	local list: { [Model]: Turner } = {}
	local function add(instance: Instance)
		if instance:IsA("Model") then
			list[instance] = newTurner(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
		list[instance :: Model] = nil
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	return list
end

-- Wind turbine rotors (models tagged "Rotor") turn about their own pivot.
local rotors = track("Rotor")
-- Water wheels: the model tagged "WheelRotor" (only the wheel, never the stands) turns about its axle at the point the server
-- measured (attributes SpinAxis, SpinCentre, SpinSense). The angle follows the server clock, so every client agrees.
local wheels = track("WheelRotor")

local function queueTurn(turner: Turner, pivot: CFrame, outParts: { BasePart }, outFrames: { CFrame })
	for i, part in turner.parts do
		table.insert(outParts, part)
		table.insert(outFrames, pivot * turner.offsets[i])
	end
end

local function turnAll(now: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local range = TurnRange.RANGE
	local parts: { BasePart }, frames: { CFrame } = {}, {}
	for _, turner in rotors do
		local p = turner.base.Position
		if TurnRange.within(p.X, p.Y, p.Z, eye.X, eye.Y, eye.Z, range + turner.reach) then
			local angle = (now * ROTOR_SPEED + p.X) % (2 * math.pi)
			queueTurn(turner, turner.base * CFrame.Angles(0, 0, angle), parts, frames)
		end
	end
	for wheel, turner in wheels do
		local axis = wheel:GetAttribute("SpinAxis")
		local centre = wheel:GetAttribute("SpinCentre")
		if
			typeof(axis) == "Vector3"
			and typeof(centre) == "Vector3"
			and TurnRange.within(centre.X, centre.Y, centre.Z, eye.X, eye.Y, eye.Z, range + turner.reach)
		then
			local sense = (wheel:GetAttribute("SpinSense") :: number?) or 1
			local angle = (now * WHEEL_SPEED * sense) % (2 * math.pi)
			queueTurn(
				turner,
				CFrame.new(centre) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-centre) * turner.base,
				parts,
				frames
			)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Parts tagged "NightGlow" turn to neon at night; a PointLight inside follows with the strength in attribute "Glow".
local function glowProps(glow: number)
	for _, instance in CollectionService:GetTagged("NightGlow") do
		if instance:IsA("BasePart") then
			instance.Material = if glow > 0.4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local light = instance:FindFirstChildOfClass("PointLight")
			if light ~= nil then
				light.Brightness = glow * ((instance:GetAttribute("Glow") :: number?) or 1.5)
				light.Enabled = glow > 0.02
			end
		end
	end
end

-- Power plants on the plots (parts named "Plant...") get a soft light in their own color. Only a light is added here;
-- the plot itself is built and changed by the server.
local function glowPlants(glow: number)
	local plots = workspace:FindFirstChild("Plots")
	if plots == nil then
		return
	end
	for _, instance in plots:GetDescendants() do
		if instance:IsA("BasePart") and string.match(instance.Name, "^Plant") ~= nil then
			local light = instance:FindFirstChild("NightGlow") :: PointLight?
			if light == nil then
				local created = Instance.new("PointLight")
				created.Name = "NightGlow"
				created.Range = 24
				created.Shadows = false
				created.Parent = instance
				light = created
			end
			if light ~= nil then
				light.Color = instance.Color
				light.Brightness = glow * 1.2
				light.Enabled = glow > 0.02
			end
		end
	end
end

local sinceMood = math.huge
RunService.Heartbeat:Connect(function(delta: number)
	local now = workspace:GetServerTimeNow()
	local clock = DayCycle.clockAt(now, Phases)
	Lighting.ClockTime = clock
	turnAll(now)

	sinceMood += delta
	if sinceMood >= MOOD_SECONDS then
		sinceMood = 0
		local mood = DayCycle.mood(clock)
		Ambience.apply(mood)
		glowProps(mood.glow)
		glowPlants(mood.glow)
	end
end)
