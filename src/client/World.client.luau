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

local MOOD_SECONDS = 0.25
local ROTOR_SPEED = 0.8 -- radians per second

-- Wind turbine rotors (models tagged "Rotor") and the pivot each one turns around.
local rotors: { [Model]: CFrame } = {}
local function addRotor(instance: Instance)
	if instance:IsA("Model") then
		rotors[instance] = instance:GetPivot()
	end
end
CollectionService:GetInstanceAddedSignal("Rotor"):Connect(addRotor)
CollectionService:GetInstanceRemovedSignal("Rotor"):Connect(function(instance: Instance)
	rotors[instance :: Model] = nil
end)
for _, instance in CollectionService:GetTagged("Rotor") do
	addRotor(instance)
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
	for rotor, pivot in rotors do
		rotor:PivotTo(pivot * CFrame.Angles(0, 0, (now * ROTOR_SPEED + pivot.Position.X) % (2 * math.pi)))
	end

	sinceMood += delta
	if sinceMood >= MOOD_SECONDS then
		sinceMood = 0
		local mood = DayCycle.mood(clock)
		Ambience.apply(mood)
		glowProps(mood.glow)
		glowPlants(mood.glow)
	end
end)
