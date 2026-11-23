--!strict
-- Plant models from ServerStorage.Models (Rojo: assets/models), issue #80. Clones are sanitised before use:
-- no code, sound or effect comes in with a third-party model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Core = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core")
local Flat = require(Core:WaitForChild("Flat") :: ModuleScript) :: any
local Spin = require(Core:WaitForChild("Spin") :: ModuleScript) :: any
local Cosmetics = require(Core:WaitForChild("Cosmetics") :: ModuleScript) :: any

local PlantModels = {}

local function vec(v: Vector3): any
	return { x = v.X, y = v.Y, z = v.Z }
end

-- The parts of `root` as oriented boxes for Core/Flat.
local function describe(root: Instance, skip: Instance?): { any }
	local parts: { any } = {}
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") and not (skip ~= nil and item:IsDescendantOf(skip)) then
			local frame = item.CFrame
			table.insert(parts, {
				pos = vec(item.Position),
				size = vec(item.Size),
				right = vec(frame.RightVector),
				up = vec(frame.UpVector),
				back = vec(frame.ZVector),
			})
		end
	end
	return parts
end

-- Centre and size of the model's box along the world axes. Model:GetBoundingBox follows the pivot's rotation instead
-- (measured: the upright panel reports 5.2 x 0.13 x 8.2 there, 8.2 x 5.2 x 0.12 in the world).
local function worldBox(model: Model, skip: Instance?): (Vector3, Vector3)
	local box = Flat.box(describe(model, skip))
	if box == nil then
		return model:GetPivot().Position, Vector3.zero
	end
	local low = Vector3.new(box.minX, box.minY, box.minZ)
	local high = Vector3.new(box.maxX, box.maxY, box.maxZ)
	return (low + high) / 2, high - low
end

-- Turns a slab-shaped model in the world so that its glass side looks along the unit vector `toward`.
local function lay(model: Model, toward: Vector3)
	local normal = Flat.normal(describe(model), vec(toward))
	if normal == nil then
		return
	end
	local axis, angle = Flat.turn(normal, vec(toward))
	if angle ~= 0 then
		model:PivotTo(CFrame.fromAxisAngle(Vector3.new(axis.x, axis.y, axis.z), angle) * model:GetPivot())
	end
end

-- True for an instance the sanitiser removes: scripts, sounds, particles, beams, trails, constraints (WeldConstraint
-- included; every part is anchored, so welds do nothing), legacy welds, bindable/remote events and value objects.
local function isRemoved(item: Instance): boolean
	return item:IsA("LuaSourceContainer")
		or item:IsA("Sound")
		or item:IsA("ParticleEmitter")
		or item:IsA("Beam")
		or item:IsA("Trail")
		or item:IsA("Constraint")
		or item:IsA("WeldConstraint")
		or item:IsA("NoCollisionConstraint")
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
	local copy = PlantModels.cloneFile(entry.file)
	if copy ~= nil and entry.dropRgb ~= nil then
		-- A part of this colour in the file is a modelling leftover (the yellow block on the house roof): it is not drawn.
		for _, item in copy:GetDescendants() do
			if
				item:IsA("BasePart")
				and item.Color == Color3.fromRGB(entry.dropRgb[1], entry.dropRgb[2], entry.dropRgb[3])
			then
				item:Destroy()
			end
		end
	end
	return copy
end

-- Whether the furniture piece is built from a model (entry and file present).
function PlantModels.hasFurniture(name: string): boolean
	return Assets.useFurniture(name, available())
end

-- Sanitised clone of a furniture piece, fitted to its footprint and standing on `groundY` at (x, z) around `origin`.
-- `turn` rotates it about Y first (degrees). `facing` (1 or -1, default 1) mirrors its z spot for a plot that faces the
-- other way. Nil when the file is missing.
function PlantModels.furniture(name: string, origin: Vector3, groundY: number, turn: number?, facing: number?): Model?
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
	local target = origin + Vector3.new(entry.x, 0, entry.z * (facing or 1))
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
function PlantModels.battery(origin: Vector3, groundY: number, level: number, facing: number?): Model?
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
	local lift = (level % Assets.STACK_HEIGHT) * (scaled.Y + Assets.BATTERY_GAP)
	-- Two stacks side by side: units 0 and 1 in the left stack, 2 and 3 in the right one.
	local column = (level // Assets.STACK_HEIGHT) - 0.5
	local target = origin + Vector3.new(entry.x + column * Assets.COLUMN_GAP, 0, entry.z * (facing or 1))
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

-- Mounts two small solar panels (clones of the plant 1 model) on the market's roof, tilted towards the plot centre, so door
-- and window stay free. `facing` -1: the market was turned by 180 degrees, so its front is on the +Z side.
local ROOF_TILT = 0.42 -- sideways share of the panel normal: about 25 degrees from the vertical
function PlantModels.mountPanels(market: Model, facing: number?)
	-- The building's own box: small add-ons (sign poster, banner posts) would stretch the whole-model box.
	local boxes: { any } = {}
	for _, part in describe(market) do
		table.insert(boxes, Flat.box({ part }))
	end
	local building = Assets.buildingBox(boxes, Assets.BUILDING_SHARE)
	if building == nil then
		return
	end
	local low = Vector3.new(building.minX, building.minY, building.minZ)
	local high = Vector3.new(building.maxX, building.maxY, building.maxZ)
	local boxCFrame = CFrame.new((low + high) / 2)
	local size = high - low
	local side = if facing == -1 then -1 else 1
	for i = 1, 2 do
		local panel = PlantModels.clone(1)
		if panel == nil then
			return
		end
		-- Glass up and tilted towards the front (the plot centre side).
		lay(panel, Vector3.new(0, 1 - ROOF_TILT * 0.2, -side * ROOF_TILT).Unit)
		local _, panelSize = worldBox(panel)
		panel:ScaleTo(panel:GetScale() * Assets.fitScale(panelSize.X, panelSize.Z, size.X / 4, 1))
		local centre, scaled = worldBox(panel)
		local x = boxCFrame.Position.X + (i - 1.5) * size.X / 3
		local z = boxCFrame.Position.Z - side * size.Z * 0.1
		-- Resting on the roof: the lowest edge sits 0.1 studs into it, never floating.
		local y = high.Y + scaled.Y / 2 - 0.1
		panel:PivotTo(panel:GetPivot() + Vector3.new(x, y, z) - centre)
		panel.Parent = market
	end
end

-- Marks the turning part of a water wheel model: its child model "Wheel" (the stands and the hub cylinder stay outside and
-- never turn). The axle is the thin direction of the biggest disc, the centre the middle of the biggest parts. The client
-- (World.client) turns the tagged model about that axle; attribute SpinSense (+1/-1) makes the bottom move with the water
-- flowing along (flowX, flowZ) in the world. Nothing happens for a model without a "Wheel" child.
function PlantModels.tagWheel(copy: Model, flowX: number, flowZ: number, childName: string?)
	local wheel = copy:FindFirstChild(childName or "Wheel")
	if wheel == nil or not wheel:IsA("Model") then
		return
	end
	local biggest: BasePart? = nil
	local radius = 0
	for _, item in wheel:GetDescendants() do
		if item:IsA("BasePart") then
			local span = math.max(item.Size.X, item.Size.Y, item.Size.Z)
			if span > radius then
				radius, biggest = span, item
			end
		end
	end
	if biggest == nil then
		return
	end
	local thin = biggest.Size.X
	local local_axis = Vector3.xAxis
	if biggest.Size.Y < thin then
		thin, local_axis = biggest.Size.Y, Vector3.yAxis
	end
	if biggest.Size.Z < thin then
		local_axis = Vector3.zAxis
	end
	local axis: Vector3 = biggest.CFrame:VectorToWorldSpace(local_axis)
	-- The big turbine names its axle: from the hub ("Mid") to the "Node" on the nacelle side. The thin side of a blade is not it.
	local hubPart, nodePart = wheel:FindFirstChild("Mid", true), wheel:FindFirstChild("Node", true)
	if hubPart ~= nil and nodePart ~= nil and hubPart:IsA("BasePart") and nodePart:IsA("BasePart") then
		local along = nodePart.Position - hubPart.Position
		if along.Magnitude > 0.01 then
			axis = along.Unit
		end
	end
	local sum, count = Vector3.zero, 0
	for _, item in wheel:GetDescendants() do
		if item:IsA("BasePart") and math.max(item.Size.X, item.Size.Y, item.Size.Z) >= radius * 0.9 then
			sum += item.Position
			count += 1
		end
	end
	wheel:SetAttribute("SpinAxis", axis)
	-- A model with a part named "Mid" (the hub of the big turbine) turns about it: the mean of the long parts moves when
	-- one blade is a little shorter than the others.
	local mid = wheel:FindFirstChild("Mid", true)
	local mean = sum / count
	local hub = if mid ~= nil and mid:IsA("BasePart") then { mid.Position.X, mid.Position.Y, mid.Position.Z } else nil
	local at = Spin.centre(hub, { mean.X, mean.Y, mean.Z })
	wheel:SetAttribute("SpinCentre", Vector3.new(at[1], at[2], at[3]))
	wheel:SetAttribute("SpinSense", Spin.sense(axis.X, axis.Z, flowX, flowZ))
	-- The client turns the model part by part: it must arrive whole (streaming), else it keeps a partial or stale part list.
	wheel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(wheel, "WheelRotor")
end

function PlantModels.stripPanels(copy: Model)
	for _, child in copy:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
end

-- Wind rotors: the model's rotor child ("Rotary" of the big turbine, "Model" of the mini turbine) turns like a wheel about its
-- axle; the sense is fixed. Only wind plants (4 and 6) have one.
local ROTOR_CHILD = { [4] = "Model", [6] = "Rotary" } :: { [number]: string }
function PlantModels.tagRotor(copy: Model, plantId: number)
	local child = ROTOR_CHILD[plantId]
	if child == nil then
		return
	end
	PlantModels.tagWheel(copy, 0, 0, child)
	local rotor = copy:FindFirstChild(child)
	if rotor ~= nil then
		rotor:SetAttribute("SpinSense", 1)
	end
end

-- S5 blade tips of the big wind turbine: a cap in `color` on the outer fifth of every blade, inside the rotor model so the
-- client turns it with the blades. Call it after tagRotor and before the copy gets its parent (the client collects the
-- turning parts when the model is added). The mini turbine (one Union rotor) is left out. Blades are the long parts of
-- "Rotary" (not the hub "Mid"); the cap end is the one farther from "Mid" (Cosmetics.bladeTip).
function PlantModels.paintTips(copy: Model, plantId: number, color: Color3)
	local rotor = copy:FindFirstChild(ROTOR_CHILD[plantId] or "")
	if plantId ~= 6 or rotor == nil then
		return
	end
	local mid = rotor:FindFirstChild("Mid", true)
	if mid == nil or not mid:IsA("BasePart") then
		return
	end
	local longest = 0
	for _, item in rotor:GetDescendants() do
		if item:IsA("BasePart") and item ~= mid and item.Name ~= "Tip" then
			longest = math.max(longest, item.Size.X)
		end
	end
	for _, blade in rotor:GetDescendants() do
		if
			blade:IsA("BasePart")
			and blade ~= mid
			and blade.Name ~= "Tip"
			and blade.Size.X >= longest * 0.8
			and blade.Size.X > 2 * math.max(blade.Size.Y, blade.Size.Z)
		then
			local hubAlong = (mid.Position - blade.Position):Dot(blade.CFrame.RightVector)
			local tip = Cosmetics.bladeTip(blade.Size.X, blade.Size.Y, blade.Size.Z, hubAlong)
			local cap = Instance.new("Part")
			cap.Name = "Tip"
			cap.Anchored = true
			cap.CanCollide = false
			cap.CanQuery = false
			cap.CastShadow = false
			cap.Material = Enum.Material.SmoothPlastic
			cap.Color = color
			cap.Size = Vector3.new(tip.size[1], tip.size[2], tip.size[3])
			cap.CFrame = blade.CFrame * CFrame.new(tip.offset, 0, 0)
			cap.Parent = rotor
		end
	end
end

-- The walk-in container around the battery spot: floor, roof, back and end walls and a front wall with a door opening.
-- `facing` mirrors z for a plot that faces the other way; the front always looks at the plot centre. `scale` (Cosmetics.containerScale,
-- default 1) grows footprint and height.
function PlantModels.container(origin: Vector3, groundY: number, facing: number?, scale: number?): Model
	local c = Assets.container
	local spot = Assets.furniture.battery
	local side = facing or 1
	local model = Instance.new("Model")
	model.Name = "Container"
	local centre = origin + Vector3.new(spot.x, 0, spot.z * side)
	local function box(
		name: string,
		dx: number,
		y: number,
		dz: number,
		sx: number,
		sy: number,
		sz: number,
		glow: boolean?
	)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanQuery = false
		part.Material = if glow then Enum.Material.Neon else Enum.Material.Metal
		part.Color = if glow then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(70, 110, 150)
		part.Size = Vector3.new(sx, sy, sz)
		part.Position = Vector3.new(centre.X + dx, groundY + y, centre.Z + dz * side)
		part.CanCollide = not glow
		part.Parent = model
	end
	local k = scale or 1 -- footprint and height only; the wall thickness and the door keep their size
	local w, d, h, t = c.size * k, c.depth * k, c.height * k, c.wall
	box("Floor", 0, t / 2, 0, w, t, d)
	box("Roof", 0, h - t / 2, 0, w, t, d)
	box("Back", 0, h / 2, d / 2 - t / 2, w, h, t) -- road side
	box("EndLeft", -w / 2 + t / 2, h / 2, 0, t, h, d)
	box("EndRight", w / 2 - t / 2, h / 2, 0, t, h, d)
	local gap = c.door
	local piece = (w - gap) / 2
	box("FrontLeft", -(gap / 2 + piece / 2), h / 2, -d / 2 + t / 2, piece, h, t)
	box("FrontRight", gap / 2 + piece / 2, h / 2, -d / 2 + t / 2, piece, h, t)
	box("Lintel", 0, (h + c.doorHeight) / 2, -d / 2 + t / 2, gap, h - c.doorHeight, t)
	box("Light", 0, h - t - 0.2, 0, w - 2, 0.2, 0.6, true)
	return model
end

-- Stands one water wheel of a pair in the river. `at` is the middle of the pair on the water (world XZ), (axisX, axisZ) the
-- axle across the flow and (flowX, flowZ) the flow, all in the world. The model's axle runs along world X, so the copy is
-- turned about Y to lie along the axle; the second wheel of a pair (`side` +1) is turned a further half turn so that the
-- stub of the axle shows on the outside of both. The wheel is shifted half its width to its side of the pair centre, its
-- lowest point sits at `bottomY` (under the water surface, so the wheel stands in the river) and it is tagged to turn.
function PlantModels.placeWheel(
	copy: Model,
	scale: number,
	at: Vector3,
	bottomY: number,
	axisX: number,
	axisZ: number,
	side: number,
	flowX: number,
	flowZ: number
)
	local wheel = copy:FindFirstChild("Wheel")
	if wheel == nil or not wheel:IsA("Model") then
		return
	end
	copy:ScaleTo(copy:GetScale() * scale)
	local _, straight = worldBox(wheel) -- the model's axle runs along world X: its width is the X size
	local half = straight.X / 2
	local yaw = math.atan2(-axisZ, axisX) + (if side > 0 then math.pi else 0)
	copy:PivotTo(CFrame.Angles(0, yaw, 0) * copy:GetPivot())
	local middle, size = worldBox(wheel)
	local shift = Vector3.new(axisX, 0, axisZ) * side * half
	copy:PivotTo(
		copy:GetPivot() + Vector3.new(at.X - middle.X, bottomY - (middle.Y - size.Y / 2), at.Z - middle.Z) + shift
	)
	PlantModels.tagWheel(copy, flowX, flowZ)
end

-- Fits `copy` into a cell of `cell` studs centred on `centre` (x, z), standing on `groundY`. A `flat` plant is laid
-- down first, glass side up. The size depends on the cell only; `angle` (degrees about the world's Y, optional) turns
-- the copy after it is scaled, so a turned copy keeps its size. All boxes are along the world axes.
function PlantModels.place(copy: Model, plantId: number, cell: number, centre: Vector3, groundY: number, angle: number?)
	local entry = Assets.entry(plantId)
	if entry ~= nil and entry.flat then
		lay(copy, Vector3.yAxis)
	end
	if entry ~= nil and entry.lean ~= nil then
		copy:PivotTo(CFrame.Angles(0, 0, math.rad(entry.lean)) * copy:GetPivot())
	end
	local _, size = worldBox(copy)
	local factor = if entry ~= nil then entry.scale else 1
	copy:ScaleTo(copy:GetScale() * Assets.fitScale(size.X, size.Z, cell, factor))
	if angle ~= nil and angle ~= 0 then
		copy:PivotTo(CFrame.Angles(0, math.rad(angle), 0) * copy:GetPivot())
	end
	local whole, scaled = worldBox(copy)
	-- A wind turbine stands on its tower: the rotor reaches to one side, so the box without it centres the foundation.
	local rotor = ROTOR_CHILD[plantId]
	local at = worldBox(copy, if rotor ~= nil then copy:FindFirstChild(rotor) else nil)
	local bottom = whole.Y - scaled.Y / 2
	copy:PivotTo(copy:GetPivot() + Vector3.new(centre.X - at.X, groundY - bottom, centre.Z - at.Z))
end

return PlantModels
