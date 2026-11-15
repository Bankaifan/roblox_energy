--!strict
-- Plant models from ServerStorage.Models (Rojo: assets/models), issue #80. Clones are sanitised before use:
-- no code, sound or effect comes in with a third-party model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any

local PlantModels = {}

-- True for an instance the sanitiser removes: scripts, sounds, particles, beams, trails, constraints (WeldConstraint
-- included; every part is anchored, so welds do nothing), legacy welds, bindable/remote events and value objects.
local function isRemoved(item: Instance): boolean
	return item:IsA("LuaSourceContainer")
		or item:IsA("Sound")
		or item:IsA("ParticleEmitter")
		or item:IsA("Beam")
		or item:IsA("Trail")
		or item:IsA("Constraint")
		or item:IsA("JointInstance")
		or item:IsA("BindableEvent")
		or item:IsA("RemoteEvent")
		or item:IsA("ValueBase")
end

-- Removes the unwanted instances from `root` (and below) and anchors every part without collision or queries.
function PlantModels.sanitise(root: Instance)
	for _, item in root:GetDescendants() do
		if isRemoved(item) then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
		end
	end
end

-- The files present in ServerStorage.Models as a set (file name -> true).
local function available(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local folder = ServerStorage:FindFirstChild("Models")
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				set[child.Name] = true
			end
		end
	end
	return set
end

-- Whether the plant is built from a model (entry and file present) rather than the primitive column.
function PlantModels.has(plantId: number): boolean
	return Assets.useModel(plantId, available())
end

-- A sanitised clone of the plant's model, or nil (the caller builds the primitive).
function PlantModels.clone(plantId: number): Model?
	local entry = Assets.entry(plantId)
	if entry == nil then
		return nil
	end
	local folder = ServerStorage:FindFirstChild("Models")
	local source = if folder ~= nil then folder:FindFirstChild(entry.file) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	PlantModels.sanitise(copy)
	return copy
end

-- Fits `copy` into a cell of `cell` studs centred on `centre` (x, z), standing on `groundY`.
function PlantModels.place(copy: Model, plantId: number, cell: number, centre: Vector3, groundY: number)
	local entry = Assets.entry(plantId)
	local _, size = copy:GetBoundingBox()
	local factor = if entry ~= nil then entry.scale else 1
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(size.X, size.Z, cell, factor))
	local boxCFrame, scaled = copy:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - scaled.Y / 2
	local shift = Vector3.new(centre.X - boxCFrame.Position.X, groundY - bottom, centre.Z - boxCFrame.Position.Z)
	copy:PivotTo(copy:GetPivot() + shift)
end

return PlantModels
