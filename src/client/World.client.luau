--!strict
-- Day and night on the client (issue 85): the sun follows the server clock every frame, the mood four times a second.
-- At night lamps, glowing flowers and the power plants on the plots light up; the wind turbines turn. Holds no game state.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("Core"):WaitForChild("DayCycle") :: ModuleScript) :: any
local Phases = require(Shared:WaitForChild("Config"):WaitForChild("Phases") :: ModuleScript) :: any
local Ambience = require(Shared:WaitForChild("Ambience") :: ModuleScript) :: any
local TurnRange = require(Shared:WaitForChild("Core"):WaitForChild("TurnRange") :: ModuleScript) :: any
local WeatherLook = require(Shared:WaitForChild("Core"):WaitForChild("WeatherLook") :: ModuleScript) :: any
local Weathers = require(Shared:WaitForChild("Config"):WaitForChild("Weather") :: ModuleScript) :: any
local UserInputService = game:GetService("UserInputService")

local MOOD_SECONDS = 0.25
local ROTOR_SPEED = 0.8 -- radians per second
local WHEEL_SPEED = 0.6 -- water wheels, radians per second

-- Turning models (issue 113, 342): all of them move in one BulkMoveTo per tick. Models on the local player's own plot always
-- turn; the others only within TurnRange.RANGE studs of the camera. Each entry keeps its parts with their offset to the REST
-- pivot (`base`), so a turn is one multiplication per part. Parts that stream in later get their offset from the rest pivot
-- (they arrive at rest pose), parts that leave are dropped, and a model moved by someone else shifts the rest pivot.
type Turner = {
	parts: { BasePart },
	offsets: { CFrame },
	base: CFrame,
	shift: CFrame,
	reach: number,
	dirty: boolean,
	last: CFrame?, -- the frame we last gave parts[1], to notice a move by others
}

local function rescan(model: Model, turner: Turner)
	local parts, offsets = {}, {}
	local oldOffset: { [BasePart]: CFrame } = {}
	for i, part in turner.parts do
		oldOffset[part] = turner.offsets[i]
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			-- A known part keeps its rest offset; a new one is still at rest pose, so measure it against the rest pivot.
			table.insert(offsets, oldOffset[part] or turner.base:ToObjectSpace(part.CFrame))
		end
	end
	turner.parts, turner.offsets, turner.dirty = parts, offsets, false
	turner.reach = model:GetExtentsSize().Magnitude / 2
end

local function newTurner(model: Model): Turner
	local turner: Turner = {
		parts = {},
		offsets = {},
		base = model:GetPivot(),
		shift = CFrame.identity,
		reach = 0,
		dirty = false,
		last = nil,
	}
	rescan(model, turner)
	return turner
end

-- True when the model sits on the local player's plot (the plot model carries OwnerId).
local function onOwnPlot(model: Model): boolean
	local me = Players.LocalPlayer
	local node: Instance? = model
	while node ~= nil and node ~= workspace do
		if node:GetAttribute("OwnerId") == me.UserId then
			return true
		end
		node = node.Parent
	end
	return false
end

local function track(tag: string): { [Model]: Turner }
	local list: { [Model]: Turner } = {}
	local function add(instance: Instance)
		if instance:IsA("Model") and list[instance] == nil then
			local turner = newTurner(instance)
			list[instance] = turner
			local function dirty()
				turner.dirty = true
			end
			instance.DescendantAdded:Connect(dirty)
			instance.DescendantRemoving:Connect(dirty)
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

-- Rebuild when the descendants changed; notice a model moved by someone else (its first part is not where we left it).
local function refresh(model: Model, turner: Turner)
	if turner.dirty then
		rescan(model, turner)
	end
	local first, last = turner.parts[1], turner.last
	if first ~= nil and last ~= nil and not first.CFrame:FuzzyEq(last, 0.01) then
		local moved = first.CFrame * last:Inverse()
		turner.base = moved * turner.base
		turner.shift = moved * turner.shift
	end
	turner.last = nil
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
	if #turner.parts > 0 then
		turner.last = outFrames[#outFrames - #turner.parts + 1]
	end
end

local function turnAll(now: number, rotorAngle: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local range = TurnRange.RANGE
	local parts: { BasePart }, frames: { CFrame } = {}, {}
	for rotor, turner in rotors do
		refresh(rotor, turner)
		local p = turner.base.Position
		if TurnRange.turns(onOwnPlot(rotor), p.X, p.Y, p.Z, eye.X, eye.Y, eye.Z, range + turner.reach) then
			local angle = (rotorAngle + p.X) % (2 * math.pi)
			queueTurn(turner, turner.base * CFrame.Angles(0, 0, angle), parts, frames)
		end
	end
	for wheel, turner in wheels do
		refresh(wheel, turner)
		local axis = wheel:GetAttribute("SpinAxis")
		local centre = wheel:GetAttribute("SpinCentre")
		if typeof(axis) == "Vector3" and typeof(centre) == "Vector3" then
			centre = turner.shift * centre
			axis = turner.shift:VectorToWorldSpace(axis)
		end
		if
			typeof(axis) == "Vector3"
			and typeof(centre) == "Vector3"
			and TurnRange.turns(
				onOwnPlot(wheel),
				centre.X,
				centre.Y,
				centre.Z,
				eye.X,
				eye.Y,
				eye.Z,
				range + turner.reach
			)
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

-- Weather (issue 288): the id comes from the server's Env message, the same one the HUD reads. The look blends from the previous
-- one to the new one over WeatherLook.BLEND_SECONDS; nothing here decides a weather.
local fromLook: any = nil
local toLook: any = nil
local blendStart = 0
local function currentLook(): any
	if toLook == nil then
		return nil
	end
	return WeatherLook.blend(fromLook, toLook, WeatherLook.share(os.clock() - blendStart))
end

local net = ReplicatedStorage:WaitForChild("Net")
local envRemote = net:WaitForChild("Env") :: RemoteEvent
envRemote.OnClientEvent:Connect(function(payload: any)
	local look = WeatherLook.of(Weathers, payload.weather)
	if look == nil then
		return
	end
	fromLook = currentLook() or look
	toLook = look
	blendStart = os.clock()
end)

-- At most two emitters, on one part that follows the camera; half the rate on touch devices.
local TOUCH_FACTOR = if UserInputService.TouchEnabled then 0.5 else 1
local weatherPart = Instance.new("Part")
weatherPart.Name = "WeatherParticles"
weatherPart.Anchored = true
weatherPart.CanCollide = false
weatherPart.CanQuery = false
weatherPart.CanTouch = false
weatherPart.Transparency = 1
weatherPart.Size = Vector3.new(80, 1, 80)

local rain = Instance.new("ParticleEmitter")
rain.Name = "Rain"
rain.Rate = 0
rain.Lifetime = NumberRange.new(0.9, 1.1)
rain.Speed = NumberRange.new(70, 80)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Size = NumberSequence.new(0.35)
rain.Color = ColorSequence.new(Color3.fromRGB(170, 190, 220))
rain.Transparency = NumberSequence.new(0.45)
rain.Parent = weatherPart

local streaks = Instance.new("ParticleEmitter")
streaks.Name = "WindStreaks"
streaks.Rate = 0
streaks.Lifetime = NumberRange.new(1.4, 1.8)
streaks.Speed = NumberRange.new(36, 44)
streaks.EmissionDirection = Enum.NormalId.Right
streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
streaks.Size = NumberSequence.new(0.5)
streaks.Color = ColorSequence.new(Color3.fromRGB(235, 240, 245))
streaks.Transparency = NumberSequence.new(0.7)
streaks.Parent = weatherPart
weatherPart.Parent = workspace

local rotorAngle = 0
local nextFlash = os.clock() + 8
local flashAt = -1

local function weatherEffects(look: any, delta: number)
	rotorAngle = (rotorAngle + ROTOR_SPEED * look.rotor * delta) % (2 * math.pi)
	rain.Rate = look.rain * TOUCH_FACTOR
	streaks.Rate = look.streaks * TOUCH_FACTOR
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		weatherPart.Position = camera.CFrame.Position + Vector3.new(0, 30, 0)
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction == nil then
		return
	end
	local clock = os.clock()
	if toLook ~= nil and toLook.flash and clock >= nextFlash then
		flashAt = clock
		nextFlash = clock + 8 + math.random() * 12
	end
	correction.Brightness = math.max(0, 1 - (clock - flashAt) / 0.25) * 0.35
end

local sinceMood = math.huge
RunService.Heartbeat:Connect(function(delta: number)
	local now = workspace:GetServerTimeNow()
	local clock = DayCycle.clockAt(now, Phases)
	Lighting.ClockTime = clock
	local look = currentLook()
	if look ~= nil then
		weatherEffects(look, delta)
	else
		rotorAngle = (rotorAngle + ROTOR_SPEED * delta) % (2 * math.pi)
	end
	turnAll(now, rotorAngle)

	sinceMood += delta
	if sinceMood >= MOOD_SECONDS then
		sinceMood = 0
		local mood = DayCycle.mood(clock)
		Ambience.apply(mood, look)
		glowProps(mood.glow)
		glowPlants(mood.glow)
	end
end)
