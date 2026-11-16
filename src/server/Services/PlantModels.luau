--!strict
-- Plant models from ServerStorage.Models (Rojo: assets/models), issue #80. Clones are sanitised before use:
-- no code, sound or effect comes in with a third-party model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Core = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core")
local PlotLayout = require(Core:WaitForChild("PlotLayout") :: ModuleScript) :: any

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

-- Centre and size of the box along the world axes that holds every part of `model`. Model:GetBoundingBox follows the
-- model's pivot instead, which is turned for some files (the panel), so it cannot say which side points up.
local function worldBox(model: Model): (Vector3, Vector3)
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local half = item.Size / 2
			local frame = item.CFrame
			local reach = frame.RightVector:Abs() * half.X
				+ frame.UpVector:Abs() * half.Y
				+ frame.LookVector:Abs() * half.Z
			low = if low ~= nil then low:Min(item.Position - reach) else item.Position - reach
			high = if high ~= nil then high:Max(item.Position + reach) else item.Position + reach
		end
	end
	if low == nil or high == nil then
		return model:GetPivot().Position, Vector3.zero
	end
	return (low + high) / 2, high - low
end

-- Turns `model` by `rotation` about the world point `about`.
local function rotateAbout(model: Model, about: Vector3, rotation: CFrame)
	model:PivotTo(CFrame.new(about) * rotation * CFrame.new(-about) * model:GetPivot())
end

-- Turns `model` by `degrees` about the vertical axis through `about` (a plot that faces the other way).
function PlantModels.turn(model: Model, about: Vector3, degrees: number)
	if degrees ~= 0 then
		rotateAbout(model, about, CFrame.Angles(0, math.rad(degrees), 0))
	end
end

-- Sanitised clone of a furniture piece, fitted to its footprint and standing on the ground point `target`.
-- Nil when the file is missing.
function PlantModels.furniture(name: string, target: Vector3): Model?
	local entry = Assets.furniture[name]
	if entry == nil then
		return nil
	end
	local copy = PlantModels.cloneFile(entry.file)
	if copy == nil then
		return nil
	end
	local _, size = copy:GetBoundingBox()
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(size.X, size.Z, entry.size, 1))
	local boxCFrame, scaled = copy:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - scaled.Y / 2
	copy:PivotTo(
		copy:GetPivot()
			+ Vector3.new(target.X - boxCFrame.Position.X, target.Y - bottom, target.Z - boxCFrame.Position.Z)
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

-- One green battery unit standing on the ground point `target`, its thinnest axis pointing up. `level` is the
-- 0-based place in the stack; nil when the file is missing.
function PlantModels.battery(target: Vector3, level: number): Model?
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
	copy:PivotTo(
		copy:GetPivot()
			+ Vector3.new(target.X - boxCFrame.Position.X, target.Y + lift - bottom, target.Z - boxCFrame.Position.Z)
	)
	local front = Vector3.new(target.X, target.Y + lift + scaled.Y / 2, target.Z + scaled.Z / 2 + 0.05)
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

-- Mounts two small solar panels (clones of the plant 1 model) on the market's front (-z as built).
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
		-- Lay the panel flat on the wall: its thinnest axis points along Z.
		local centre, raw = worldBox(panel)
		local axis = PlotLayout.thinAxis(raw.X, raw.Y, raw.Z)
		if axis == "Y" then
			rotateAbout(panel, centre, CFrame.Angles(math.rad(90), 0, 0))
		elseif axis == "X" then
			rotateAbout(panel, centre, CFrame.Angles(0, math.rad(90), 0))
		end
		local _, panelSize = worldBox(panel)
		panel:ScaleTo(panel:GetScale() * Assets.fitScale(panelSize.X, panelSize.Y, size.X / 4, 1))
		local placed, scaled = worldBox(panel)
		local x = boxCFrame.Position.X + (i - 1.5) * size.X / 3
		-- Touching the facade: the back of the panel sits 0.05 studs inside the wall, never floating.
		local z = boxCFrame.Position.Z - size.Z / 2 - scaled.Z / 2 + 0.05
		local y = boxCFrame.Position.Y - size.Y / 2 + size.Y * 0.6
		panel:PivotTo(panel:GetPivot() + Vector3.new(x, y, z) - placed)
		panel.Parent = market
	end
end

-- Fits `copy` to a site of `cell` studs and stands it on the ground point `target`, turned by `yaw` degrees about
-- the vertical. The scale follows from the model and the site alone, so every unit of a plant has the same size.
-- A flat plant (Assets entry) is first laid down: its thinnest side points up. For the panel that is the glass side.
function PlantModels.place(copy: Model, plantId: number, cell: number, target: Vector3, yaw: number)
	local entry = Assets.entry(plantId)
	local centre, size = worldBox(copy)
	if entry ~= nil and entry.flat then
		local axis = PlotLayout.thinAxis(size.X, size.Y, size.Z)
		if axis == "X" then
			rotateAbout(copy, centre, CFrame.Angles(0, 0, math.rad(90)))
		elseif axis == "Z" then
			rotateAbout(copy, centre, CFrame.Angles(math.rad(90), 0, 0))
		end
		centre, size = worldBox(copy)
	end
	local factor = if entry ~= nil then entry.scale else 1
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(size.X, size.Z, cell, factor))
	PlantModels.turn(copy, centre, yaw)
	local placed, scaled = worldBox(copy)
	copy:PivotTo(
		copy:GetPivot() + Vector3.new(target.X - placed.X, target.Y - (placed.Y - scaled.Y / 2), target.Z - placed.Z)
	)
end

return PlantModels
