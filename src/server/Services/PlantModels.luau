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

-- A sanitised clone of the model file `file`, or nil when it is missing.
function PlantModels.cloneFile(file: string): Model?
	local folder = ServerStorage:FindFirstChild("Models")
	local source = if folder ~= nil then folder:FindFirstChild(file) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	PlantModels.sanitise(copy)
	return copy
end

-- A sanitised clone of the plant's model, or nil (the caller builds the primitive).
function PlantModels.clone(plantId: number): Model?
	local entry = Assets.entry(plantId)
	if entry == nil then
		return nil
	end
	return PlantModels.cloneFile(entry.file)
end

-- Whether the furniture piece is built from a model (entry and file present).
function PlantModels.hasFurniture(name: string): boolean
	return Assets.useFurniture(name, available())
end

-- Sanitised clone of a furniture piece, fitted to its footprint and standing on `groundY` at (x, z) around `origin`.
-- `turn` rotates it about Y first (degrees). Nil when the file is missing.
function PlantModels.furniture(name: string, origin: Vector3, groundY: number, turn: number?): Model?
	local entry = Assets.furniture[name]
	if entry == nil then
		return nil
	end
	local copy = PlantModels.cloneFile(entry.file)
	if copy == nil then
		return nil
	end
	if turn ~= nil then
		copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, math.rad(turn), 0))
	end
	local _, size = copy:GetBoundingBox()
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(size.X, size.Z, entry.size, 1))
	local boxCFrame, scaled = copy:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - scaled.Y / 2
	local target = origin + Vector3.new(entry.x, 0, entry.z)
	copy:PivotTo(
		copy:GetPivot()
			+ Vector3.new(target.X - boxCFrame.Position.X, groundY - bottom, target.Z - boxCFrame.Position.Z)
	)
	return copy
end

-- A small lightning symbol from two primitive bars, centred at `centre` on a face looking along +Z.
local function lightning(parent: Instance, centre: Vector3, height: number)
	local yellow = Color3.fromRGB(255, 240, 80)
	local specs = { { 12, 0.5 }, { -12, -0.5 } }
	for index, spec in specs do
		local bar = Instance.new("Part")
		bar.Name = "Lightning" .. index
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.Color = yellow
		bar.Material = Enum.Material.Neon
		bar.Size = Vector3.new(height * 0.12, height * 0.6, height * 0.05)
		local at = centre + Vector3.new(spec[2] * height * 0.15, 0, 0)
		bar.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(spec[1]))
		bar.Parent = parent
	end
end

-- One green battery unit standing on `groundY` at the furniture spot, its thinnest axis pointing up. `level` is the
-- 0-based place in the stack; nil when the file is missing.
function PlantModels.battery(origin: Vector3, groundY: number, level: number): Model?
	local entry = Assets.furniture.battery
	local copy = PlantModels.cloneFile(entry.file)
	if copy == nil then
		return nil
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = Color3.fromRGB(60, 190, 80)
		end
	end
	local _, size = copy:GetBoundingBox()
	if size.X <= size.Y and size.X <= size.Z then
		copy:PivotTo(copy:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
	elseif size.Z <= size.X and size.Z <= size.Y then
		copy:PivotTo(copy:GetPivot() * CFrame.Angles(math.rad(90), 0, 0))
	end
	local _, flat = copy:GetBoundingBox()
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(flat.X, flat.Z, entry.size, 1))
	local boxCFrame, scaled = copy:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - scaled.Y / 2
	local lift = level * (scaled.Y + Assets.BATTERY_GAP)
	local target = origin + Vector3.new(entry.x, 0, entry.z)
	copy:PivotTo(
		copy:GetPivot()
			+ Vector3.new(target.X - boxCFrame.Position.X, groundY + lift - bottom, target.Z - boxCFrame.Position.Z)
	)
	local front = Vector3.new(target.X, groundY + lift + scaled.Y / 2, target.Z + scaled.Z / 2 + 0.05)
	lightning(copy, front, math.max(scaled.Y, 0.5))
	return copy
end

-- Market clean-up: removes the meme cube, the "Shop Now!" labels and the poster decals (no other brands on a plot).
function PlantModels.cleanMarket(market: Model)
	for _, item in market:GetDescendants() do
		if Assets.marketRemovedParts[item.Name] and item:IsA("BasePart") then
			item:Destroy()
		end
	end
	for _, item in market:GetDescendants() do
		if item:IsA("SurfaceGui") or (item:IsA("Decal") and Assets.marketPosterTextures[item.Texture]) then
			item:Destroy()
		end
	end
end

-- Mounts two small solar panels (clones of the plant 1 model) on the market's front, the side facing the plot centre.
function PlantModels.mountPanels(market: Model)
	-- The building's own box: small add-ons (sign poster, banner posts) would stretch the whole-model box.
	local boxes: { any } = {}
	for _, item in market:GetDescendants() do
		if item:IsA("BasePart") then
			local half = item.Size / 2
			local right, up, look = item.CFrame.RightVector, item.CFrame.UpVector, item.CFrame.LookVector
			local reach = right:Abs() * half.X + up:Abs() * half.Y + look:Abs() * half.Z
			local at = item.Position
			table.insert(boxes, {
				minX = at.X - reach.X,
				minY = at.Y - reach.Y,
				minZ = at.Z - reach.Z,
				maxX = at.X + reach.X,
				maxY = at.Y + reach.Y,
				maxZ = at.Z + reach.Z,
			})
		end
	end
	local building = Assets.buildingBox(boxes, Assets.BUILDING_SHARE)
	if building == nil then
		return
	end
	local low = Vector3.new(building.minX, building.minY, building.minZ)
	local high = Vector3.new(building.maxX, building.maxY, building.maxZ)
	local boxCFrame = CFrame.new((low + high) / 2)
	local size = high - low
	for i = 1, 2 do
		local panel = PlantModels.clone(1)
		if panel == nil then
			return
		end
		-- Lay the panel flat on the wall: its thinnest axis points along Z (towards the plot centre).
		local _, raw = panel:GetBoundingBox()
		if raw.Y <= raw.X and raw.Y <= raw.Z then
			panel:PivotTo(panel:GetPivot() * CFrame.Angles(math.rad(90), 0, 0))
		elseif raw.X <= raw.Y and raw.X <= raw.Z then
			panel:PivotTo(panel:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		end
		local _, panelSize = panel:GetBoundingBox()
		panel:ScaleTo(panel:GetScale() * Assets.fitScale(panelSize.X, panelSize.Y, size.X / 4, 1))
		local pivot, scaled = panel:GetBoundingBox()
		local x = boxCFrame.Position.X + (i - 1.5) * size.X / 3
		-- Touching the facade: the back of the panel sits 0.05 studs inside the wall, never floating.
		local z = boxCFrame.Position.Z - size.Z / 2 - scaled.Z / 2 + 0.05
		local y = boxCFrame.Position.Y - size.Y / 2 + size.Y * 0.6
		panel:PivotTo(panel:GetPivot() + Vector3.new(x, y, z) - pivot.Position)
		panel.Parent = market
	end
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
