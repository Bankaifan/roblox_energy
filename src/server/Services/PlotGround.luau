--!strict
-- The ground of a plot (issue #111): the plot stays a meadow. Only the cleared patches (around the crank and the market,
-- under prepared sites and units) are written into the terrain as bare earth with a wobbly outline (Core/Meadow), and a
-- field that waits for its tool is marked with stakes and a rope. Grass blades (Terrain.Decoration) grow on the Grass
-- material only, so nothing hides what stands on a patch. Only the material changes, never the occupancy: the surface
-- stays at Assets.GROUND_Y. Terrain edits replicate by themselves; a plot that is freed gets its meadow back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any
local Meadow = require(Shared:WaitForChild("Core"):WaitForChild("Meadow") :: ModuleScript) :: any
local River = require(Shared:WaitForChild("Core"):WaitForChild("River") :: ModuleScript) :: any

local PlotGround = {}

local CELL = 4 -- terrain voxel in studs (Landscape.CELL)
local DEPTH = 8 -- studs below y = 0 that change: the two top layers of the meadow
local STAKE_SIDE = 0.35
local STAKE_SUNK = 0.5 -- studs of a stake below the surface
local ROPE_SIDE = 0.12
local STAKE_COLOR = Color3.fromRGB(124, 92, 60)
local ROPE_COLOR = Color3.fromRGB(222, 204, 160)

type Saved = { region: Region3, materials: any, occupancies: any }
type Entry = {
	patches: { any }, -- the cleared patches in world orientation, relative to the plot centre
	key: string, -- what the patches stand for
	facing: number, -- 1, or -1 when the plot is mirrored in z
	river: { number }?, -- the dig stage of each river segment (River.stages), nil = none
	riverKey: string,
	meadow: Enum.Material?, -- the material of the meadow in a theme (Snow, Mud), nil = grass
	written: string?, -- the key the terrain shows now
	saved: Saved?, -- the meadow as it was
}

-- WorldService writes the whole terrain at server start; a plot painted before that would be overwritten.
local worldReady = false
local slots: { [number]: Entry } = {}

local function write(slot: number, entry: Entry)
	local fullKey = entry.key .. "|" .. entry.riverKey .. "|" .. (if entry.meadow ~= nil then entry.meadow.Name else "")
	if entry.written == fullKey then
		return
	end
	local terrain = workspace.Terrain
	local saved = entry.saved
	if saved == nil then
		local place = PlotLayout.slot(slot, Assets.PLOT_SPACING, Assets.PLOT_ROW_Z)
		local ground = PlotLayout.ground(place, Assets.PLOT_SIZE, CELL)
		local region =
			Region3.new(Vector3.new(ground.minX, -DEPTH, ground.minZ), Vector3.new(ground.maxX, CELL, ground.maxZ))
		local materials, occupancies = terrain:ReadVoxels(region, CELL)
		saved = { region = region, materials = materials, occupancies = occupancies }
		entry.saved = saved
	end
	local materials = saved.materials
	local size = materials.Size
	local mask = Meadow.mask(entry.patches, slot, size.X, CELL)
	local meadow = entry.meadow
	-- The river: a trench of its dug segments, 3 studs under the meadow, and water 1 stud under it for the flooded ones.
	-- The trench empties the top layer [-4, 0] to a quarter, the water fills the layer below and a quarter of the layer above.
	local course = if entry.river ~= nil then River.course(Assets.river, slot) else nil
	local cells = size.X
	local trench = if course ~= nil then River.mask(course, entry.river, River.DRY, cells, CELL) else nil
	local water = if course ~= nil then River.mask(course, entry.river, River.FLOODED, cells, CELL) else nil
	local top = size.Y - 1 -- the layer [-4, 0]
	local occupied = saved.occupancies
	if trench ~= nil then
		occupied = table.create(size.X)
		for ix = 1, size.X do
			occupied[ix] = table.create(size.Y)
			for iy = 1, size.Y do
				occupied[ix][iy] = table.clone(saved.occupancies[ix][iy])
			end
		end
	end
	local painted = table.create(size.X)
	for ix = 1, size.X do
		painted[ix] = table.create(size.Y)
		for iy = 1, size.Y do
			local row = table.create(size.Z)
			for iz = 1, size.Z do
				local old = materials[ix][iy][iz]
				row[iz] = if old ~= Enum.Material.Air and mask[ix][iz] then Enum.Material.Ground else old
				if old == Enum.Material.Grass and meadow ~= nil and not mask[ix][iz] then
					row[iz] = meadow
				end
				if trench ~= nil then
					local rz = if entry.facing == -1 then size.Z - iz + 1 else iz -- the course is unmirrored
					if trench[ix][rz] then
						if iy == top then
							row[iz] = if water[ix][rz] then Enum.Material.Water else Enum.Material.Ground
							occupied[ix][iy][iz] = if water[ix][rz] then 1 else 0.25
						elseif iy == top + 1 then
							row[iz] = if water[ix][rz] then Enum.Material.Water else Enum.Material.Air
							occupied[ix][iy][iz] = if water[ix][rz] then 0.25 else 0
						end
					end
				end
			end
			painted[ix][iy] = row
		end
	end
	terrain:WriteVoxels(saved.region, CELL, painted, occupied)
	entry.written = fullKey
end

-- Sets the cleared patches of a slot ({ x, z, r } relative to the plot centre, unmirrored). `key` names their content:
-- the terrain is written only when it changes, and only once the world is built.
function PlotGround.clear(slot: number, facing: number, key: string, patches: { any })
	local entry = slots[slot]
	if entry == nil then
		entry = { patches = {}, key = "", facing = facing, riverKey = "" }
		slots[slot] = entry
	end
	entry.facing = facing
	if entry.key == key and entry.written ~= nil then
		return
	end
	local turned = table.create(#patches)
	for i, patch in patches do
		turned[i] = { x = patch.x, z = patch.z * facing, r = patch.r }
	end
	entry.patches = turned
	entry.key = key
	if worldReady then
		write(slot, entry)
	end
end

-- Sets the dig stages of the river segments of a slot (River.stages: 0 meadow, 1 dry trench, 2 flooded).
function PlotGround.river(slot: number, facing: number, stages: { number })
	local entry = slots[slot]
	if entry == nil then
		entry = { patches = {}, key = "", facing = facing, riverKey = "" }
		slots[slot] = entry
	end
	local riverKey = table.concat(stages, "")
	entry.facing = facing
	if entry.riverKey == riverKey and entry.written ~= nil then
		return
	end
	entry.river = if string.find(riverKey, "[12]") ~= nil then stages else nil
	entry.riverKey = riverKey
	if worldReady then
		write(slot, entry)
	end
end

-- Sets the meadow material of a slot for its theme (Config/Themes.meadow: "Snow", "Mud"; nil = grass again). Snow and Mud are used
-- nowhere else in the world, so their terrain colours are set here once: white snow, dry orange-brown for autumn.
local meadowColours = { Snow = Color3.fromRGB(240, 245, 252), Mud = Color3.fromRGB(176, 118, 50) }
function PlotGround.meadow(slot: number, facing: number, name: string?)
	local entry = slots[slot]
	if entry == nil then
		entry = { patches = {}, key = "", facing = facing, riverKey = "" }
		slots[slot] = entry
	end
	local material = if name ~= nil then Enum.Material[name] else nil
	if entry.meadow == material and entry.written ~= nil then
		return
	end
	entry.meadow = material
	entry.facing = facing
	if name ~= nil and meadowColours[name] ~= nil then
		workspace.Terrain:SetMaterialColor(Enum.Material[name], meadowColours[name])
	end
	if worldReady then
		write(slot, entry)
	end
end

-- Gives the slot its meadow back.
function PlotGround.restore(slot: number)
	local entry = slots[slot]
	slots[slot] = nil
	local saved = if entry ~= nil then entry.saved else nil
	if saved ~= nil then
		workspace.Terrain:WriteVoxels(saved.region, CELL, saved.materials, saved.occupancies)
	end
end

-- Called by WorldService when the terrain is written: clears the patches of the plots that were created before.
function PlotGround.ready()
	worldReady = true
	for slot, entry in slots do
		write(slot, entry)
	end
end

local function marker(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Builds a low fence from Meadow.fence: leaning stakes with a rope from top to top. One part per stake and per rope,
-- none of them collides, so the player walks straight in.
function PlotGround.fence(
	parent: Instance,
	origin: Vector3,
	facing: number,
	stakes: { any },
	ropes: { any },
	ropeColor: Color3?
)
	local tops: { Vector3 } = table.create(#stakes)
	for i, stake in stakes do
		local foot = CFrame.new(origin + Vector3.new(stake.x, 0, stake.z * facing))
			* CFrame.Angles(0, math.rad(stake.turn), 0)
			* CFrame.Angles(math.rad(stake.lean), 0, 0)
		local length = stake.height + STAKE_SUNK
		local part =
			marker(parent, "Stake", Vector3.new(STAKE_SIDE, length, STAKE_SIDE), STAKE_COLOR, Enum.Material.Wood)
		part.CFrame = foot * CFrame.new(0, length / 2 - STAKE_SUNK, 0)
		tops[i] = (foot * CFrame.new(0, stake.height - 0.2, 0)).Position
	end
	for _, rope in ropes do
		local from, to = tops[rope.from], tops[rope.to]
		local length = (to - from).Magnitude
		local part = marker(
			parent,
			"Rope",
			Vector3.new(ROPE_SIDE, ROPE_SIDE, length),
			ropeColor or ROPE_COLOR,
			Enum.Material.Fabric
		)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
	end
end

return PlotGround
