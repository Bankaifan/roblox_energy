--!strict
-- The ground of a plot: a tidy square of bare earth with a light frame, written into the terrain meadow. Grass blades
-- (Terrain.Decoration) grow on the Grass material only, so nothing hides the crank, the panels and the other units.
-- Only the material changes, never the occupancy: the surface stays at Assets.GROUND_Y. Terrain edits replicate by
-- themselves; a plot that is freed gets its meadow back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any

local PlotGround = {}

local CELL = 4 -- terrain voxel in studs (Landscape.CELL)
local BORDER = 1 -- cells of the frame
local DEPTH = 8 -- studs below y = 0 that change: the two top layers of the meadow
local COVER: { [string]: Enum.Material } = { inner = Enum.Material.Ground, border = Enum.Material.Sand }

type Saved = { region: Region3, materials: any, occupancies: any }

-- WorldService writes the whole terrain at server start; a plot painted before that would be overwritten.
local worldReady = false
-- slot -> the meadow as it was (false while the plot waits for the world).
local slots: { [number]: Saved | false } = {}

local function write(slot: number)
	local place = PlotLayout.slot(slot, Assets.PLOT_SPACING, Assets.PLOT_ROW_Z)
	local ground = PlotLayout.ground(place, Assets.PLOT_SIZE, CELL)
	local terrain = workspace.Terrain
	local region =
		Region3.new(Vector3.new(ground.minX, -DEPTH, ground.minZ), Vector3.new(ground.maxX, CELL, ground.maxZ))
	local materials, occupancies = terrain:ReadVoxels(region, CELL)
	slots[slot] = { region = region, materials = materials, occupancies = occupancies }
	local size = materials.Size
	local painted = table.create(size.X)
	for ix = 1, size.X do
		painted[ix] = table.create(size.Y)
		for iy = 1, size.Y do
			local row = table.create(size.Z)
			for iz = 1, size.Z do
				local old = materials[ix][iy][iz]
				row[iz] = if old == Enum.Material.Air
					then old
					else COVER[PlotLayout.groundCover(ix, iz, ground.cells, BORDER)]
			end
			painted[ix][iy] = row
		end
	end
	terrain:WriteVoxels(region, CELL, painted, occupancies)
end

-- Turns the ground of a slot into bare earth (once the world is built).
function PlotGround.paint(slot: number)
	if slots[slot] ~= nil then
		return
	end
	slots[slot] = false
	if worldReady then
		write(slot)
	end
end

-- Gives the slot its meadow back.
function PlotGround.restore(slot: number)
	local saved = slots[slot]
	slots[slot] = nil
	if saved then
		workspace.Terrain:WriteVoxels(saved.region, CELL, saved.materials, saved.occupancies)
	end
end

-- Called by WorldService when the terrain is written: paints the plots that were created before.
function PlotGround.ready()
	worldReady = true
	for slot, saved in slots do
		if saved == false then
			write(slot)
		end
	end
end

return PlotGround
