--!strict
-- Plant models (issue #80): plant id -> model file in assets/models (ServerStorage.Models), a size factor and a cap for
-- the visible copies. No entry or no file: the plot builds the primitive column. Pure functions, no Roblox APIs.
-- `flat`: the model is a slab that lies on the ground with its glass side up (Core/Flat).
-- `lean`: degrees about the world's Z the model is turned before it is placed (the solar farm was modelled on a 15 degree
-- slope: legs normal to the slope, rails along it, so turned by 15 the legs stand upright and the panels tilt with the frame).
export type Entry = { file: string, scale: number, cap: number, flat: boolean?, lean: number? }

local Assets = {}

-- Land grid (design 0018): a tile is 8 studs, a plot 24 x 24 tiles = 192 studs. The world (terrain meadow) follows it.
Assets.TILE = 8
Assets.PLOT_TILES = 24
Assets.PLOT_SIZE = Assets.TILE * Assets.PLOT_TILES
-- Plots stand in two rows of PLOT_COLUMNS at z = +-PLOT_ROW_Z beside the road, their centres PLOT_SPACING apart in x
-- (48 studs between two grounds). PlotLayout.slot gives the place of a slot.
Assets.PLOT_SPACING = 240
Assets.PLOT_COLUMNS = 4
Assets.PLOT_ROW_Z = 128
-- Walkable surface of the meadow: a full terrain cell below y = 0 renders its surface half a cell (2 studs) higher
-- (measured in Studio with a raycast). Everything on a plot stands on this height.
Assets.GROUND_Y = 2

-- Side length of the pad a plant gets, the grid of pads (3 columns, 34 studs apart) and the layout of copies on a pad.
Assets.SLOT = 28
Assets.PAD_COLUMNS = 3
Assets.PAD_PITCH = 34
Assets.COPY_GAP = 4
Assets.MAX_CELL = 14
-- Side of the primitive fallback column.
Assets.COLUMN = 12

-- Parts budget of all plants on a full plot, and the parts per model (counted in assets/models).
Assets.MAX_PLANT_PARTS = 1400
Assets.partsPerModel = { [1] = 9, [2] = 47, [3] = 49, [4] = 4, [5] = 75, [6] = 20 } :: { [number]: number }

-- Fields by plant id (land design v2, section 3). A field is `size` x `size` tiles per cell and a list of cells; a cell
-- is the (column, row) of its top-left tile and its number is its index in the list, which is also the fill order.
-- Column 0 is the left edge, row 0 the back, row 23 the road side. F2 is the river: its seven cells stand in for the
-- river segments (the tile under the middle of each segment) until the river course takes over (Assets.river).
Assets.fields = {
	[1] = {
		size = 1,
		cells = {
			{ 1, 13 },
			{ 2, 13 },
			{ 3, 13 },
			{ 4, 13 },
			{ 5, 13 },
			{ 1, 14 },
			{ 2, 14 },
			{ 3, 14 },
			{ 4, 14 },
			{ 5, 14 },
			{ 1, 15 },
			{ 2, 15 },
			{ 3, 15 },
			{ 4, 15 },
			{ 5, 15 },
			{ 1, 16 },
			{ 2, 16 },
			{ 3, 16 },
			{ 4, 16 },
			{ 5, 16 },
			{ 1, 17 },
			{ 2, 17 },
			{ 3, 17 },
			{ 4, 17 },
			{ 5, 17 },
		},
	},
	[2] = {
		size = 1,
		river = true,
		cells = { { 2, 9 }, { 5, 9 }, { 8, 9 }, { 11, 10 }, { 14, 11 }, { 17, 12 }, { 20, 12 } },
	},
	[3] = { size = 2, cells = { { 14, 14 }, { 17, 14 }, { 20, 14 }, { 12, 17 }, { 15, 17 }, { 18, 17 }, { 21, 17 } } },
	[4] = { size = 1, cells = { { 9, 12 }, { 7, 13 }, { 9, 14 }, { 7, 15 }, { 9, 16 }, { 7, 17 }, { 9, 18 } } },
	[5] = { size = 2, cells = { { 17, 6 }, { 19, 6 }, { 17, 8 }, { 19, 8 } } },
	[6] = { size = 4, cells = { { 1, 1 }, { 7, 1 }, { 13, 1 }, { 19, 1 } } },
} :: { [number]: { size: number, cells: { { number } }, river: boolean? } }
-- Tiles that may carry land: columns 1 to 22 and rows 1 to 22 (column 0, column 23 and row 0 stay meadow, rows 19 to 23
-- are the yard).
Assets.USABLE = { first = 1, last = 22 }
-- Studs kept free between two things of the site map (fields, river band, furniture).
Assets.CLEARANCE = 4

-- The river (F2): centre line through `points` (plot-relative studs), water `width` studs wide, cut into `segments`.
-- Only the course is data here; the curve and the segments belong to Core/River (a later step).
Assets.river = {
	points = { { -84, -28 }, { -56, -16 }, { -28, -20 }, { 0, -8 }, { 28, -2 }, { 56, 2 }, { 80, 2 } },
	width = 12,
	segments = 7,
	-- Studs from the centre line that no other cell or furniture box may come closer than (plus CLEARANCE).
	band = 8,
} :: { points: { { number } }, width: number, segments: number, band: number }

-- Concrete foundations of the wind plants (fields F4 and F6): a round base of two steps appears on a cell once its `stage` is
-- done (the wrench anchors a mini turbine, the tamper a wind turbine). `radius` is the lower step in studs, the upper
-- step is two thirds of it; each step is STEP studs high.
Assets.foundations = {
	[4] = { stage = 2, radius = 3.4 },
	[6] = { stage = 2, radius = 11 },
} :: { [number]: { stage: number, radius: number } }
Assets.FOUNDATION_STEP = 0.6

-- Ground cables of the solar farm and the wind turbine (fields F5 and F6): once the cable drum has done its `stage` on a cell,
-- a thin dark cable runs from the cell to the grid box (the control board spot), first along z, then along x.
Assets.cables = {
	[5] = { stage = 3 },
	[6] = { stage = 3 },
} :: { [number]: { stage: number } }
Assets.CABLE_WIDTH = 0.5

-- Stage builds on a cell (design v2, step 10): `fence` is a post fence round the cell (the hammer on the solar farm), `mast` a guyed
-- mast with a cross arm (the wrench on the mini turbine). Each appears once the cell's `stage` is done.
Assets.stageBuilds = {
	[4] = { kind = "mast", stage = 2 },
	[5] = { kind = "fence", stage = 2 },
} :: { [number]: { kind: string, stage: number } }
Assets.MAST_HEIGHT = 11.9 -- the hub of the finished mini turbine above the ground: 1.05 foundation lift, then 10.9 to its hub
Assets.FENCE_POST = 4 -- studs between the posts of a farm fence
-- S5 Sign Paint: the six colours to choose from (Effects.paintColors says how many); the rope round the fields takes the chosen one.
Assets.paintColors = {
	{ 224, 72, 64 },
	{ 240, 150, 50 },
	{ 242, 212, 70 },
	{ 90, 180, 90 },
	{ 70, 140, 220 },
	{ 170, 100, 210 },
} :: { { number } }

-- Number of cells of a field.
function Assets.siteCount(plantId: number): number
	return #Assets.fields[plantId].cells
end

-- Water wheels shown in the river at most (8 pairs, about 750 parts); the river carries far more than the pad cap of 4.
Assets.WHEEL_MAX = 16

-- Visible copies per pad: at most 4 (2 x 2), so a pad never looks crowded.
Assets.plants = {
	[1] = { file = "plant1_panel", scale = 1, cap = 4, flat = true },
	[2] = { file = "plant2_waterwheel", scale = 0.4, cap = 4 },
	[3] = { file = "plant3_house", scale = 1, cap = 4 },
	[4] = { file = "plant4_miniturbine", scale = 1, cap = 4 },
	[5] = { file = "plant5_solarfarm", scale = 1, cap = 4, lean = 15 },
	[6] = { file = "plant6_windturbine", scale = 1, cap = 4 },
} :: { [number]: Entry }

-- Plot furniture: file, centre (x, z) relative to the plot centre and the longest footprint side in studs. All of it
-- stands in the yard (tile rows 19 to 23, z 56 to 96) on the road side, the market with its facade towards the plot.
-- `depth` (optional) is the assumed footprint depth in z of a wide piece; layout checks use it instead of `size`.
-- `battery` is the storage container, `control` the control board.
export type Furniture = { file: string, x: number, z: number, size: number, depth: number? }
Assets.furniture = {
	crank = { file = "crank", x = 0, z = 72, size = 4 },
	market = { file = "market", x = -56, z = 78, size = 40, depth = 20 },
	control = { file = "control", x = 52, z = 78, size = 8 },
	battery = { file = "battery", x = 36, z = 78, size = 3 },
} :: { [string]: Furniture }

-- The walk-in battery container (built from primitives once it is bought): a shell of `size` x `depth` studs, `height` high,
-- centred on the battery spot, with a door of `door` x `doorHeight` studs in the front wall (the side facing the plot centre).
Assets.container = { size = 14, depth = 8, height = 9, wall = 0.4, door = 4, doorHeight = 6.5 }

-- Battery units stand in two stacks side by side inside the container: STACK_HEIGHT units high, the stacks COLUMN_GAP apart.
Assets.STACK_HEIGHT = 2
Assets.COLUMN_GAP = 4

-- Studs between stacked battery units: none, the units sit directly on each other.
Assets.BATTERY_GAP = 0
-- Texture ids of the poster decals removed from the market (cola posters), and the part names removed whole.
Assets.marketPosterTextures = { ["rbxassetid://7977205851"] = true }
Assets.marketRemovedParts = { ["Floppa Cube"] = true, ["Floppa cube"] = true }

-- True when the furniture piece has an entry and its file is present (`available` maps file name -> true).
function Assets.useFurniture(name: string, available: { [string]: boolean }): boolean
	local entry = Assets.furniture[name]
	return entry ~= nil and available[entry.file] == true
end

-- A part counts as the market's building when its volume is at least this share of the largest part's volume.
Assets.BUILDING_SHARE = 0.1

export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }

-- The union of the boxes whose volume is at least `share` of the largest one: the building without small add-ons
-- such as a sign poster or a tall banner post. Nil for an empty list.
function Assets.buildingBox(boxes: { Box }, share: number): Box?
	local function volume(box: Box): number
		return (box.maxX - box.minX) * (box.maxY - box.minY) * (box.maxZ - box.minZ)
	end
	local largest = 0
	for _, box in boxes do
		largest = math.max(largest, volume(box))
	end
	local union: Box? = nil
	for _, box in boxes do
		if volume(box) >= largest * share then
			if union == nil then
				union = table.clone(box)
			else
				union.minX = math.min(union.minX, box.minX)
				union.minY = math.min(union.minY, box.minY)
				union.minZ = math.min(union.minZ, box.minZ)
				union.maxX = math.max(union.maxX, box.maxX)
				union.maxY = math.max(union.maxY, box.maxY)
				union.maxZ = math.max(union.maxZ, box.maxZ)
			end
		end
	end
	return union
end

-- Battery units shown for a storage stage (0 until U17, at most 4).
function Assets.batteryUnits(stage: number): number
	return math.max(0, math.min(math.floor(stage), 4))
end

-- The model entry for a plant, or nil.
function Assets.entry(plantId: number): Entry?
	return Assets.plants[plantId]
end

-- True when the plant has an entry and its file is present (`available` maps file name -> true).
function Assets.useModel(plantId: number, available: { [string]: boolean }): boolean
	local entry = Assets.plants[plantId]
	return entry ~= nil and available[entry.file] == true
end

-- How many copies are shown for `count` owned plants.
function Assets.visibleCopies(count: number, cap: number): number
	return math.max(0, math.min(math.floor(count), cap))
end

-- Scale that fits a footprint (sizeX x sizeZ) into a cell, times the per-plant factor.
function Assets.fitScale(sizeX: number, sizeZ: number, cell: number, factor: number): number
	local longest = math.max(sizeX, sizeZ)
	if longest <= 0 then
		return factor
	end
	return cell / longest * factor
end

return Assets
