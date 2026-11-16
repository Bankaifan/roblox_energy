--!strict
-- Plant models (issue #80): plant id -> model file in assets/models (ServerStorage.Models), a size factor and a cap for
-- the visible copies. No entry or no file: the plot builds the primitive column. Pure functions, no Roblox APIs.
export type Entry = { file: string, scale: number, cap: number }

local Assets = {}

-- Plot size (issue #90): one constant for the ground of a plot. The world (terrain meadow) follows it too.
Assets.PLOT_SIZE = 120
-- Distance between the centres of two neighbouring plots (a walkway of 40 studs between the grounds).
Assets.PLOT_SPACING = Assets.PLOT_SIZE + 40

-- Side length of the pad a plant gets, the grid of pads (3 columns, 34 studs apart) and the layout of copies on a pad.
Assets.SLOT = 28
Assets.PAD_COLUMNS = 3
Assets.PAD_PITCH = 34
Assets.COPY_GAP = 4
Assets.MAX_CELL = 14
-- Side of the primitive fallback column.
Assets.COLUMN = 12

-- Visible copies per pad: at most 4 (2 x 2), so a pad never looks crowded.
Assets.plants = {
	[1] = { file = "plant1_panel", scale = 1, cap = 4 },
	[2] = { file = "plant2_waterwheel", scale = 1, cap = 4 },
	[3] = { file = "plant3_house", scale = 1, cap = 4 },
	[4] = { file = "plant4_miniturbine", scale = 0.4, cap = 4 },
	[5] = { file = "plant5_solarfarm", scale = 1, cap = 4 },
	[6] = { file = "plant6_windturbine", scale = 1, cap = 4 },
} :: { [number]: Entry }

-- Plot furniture: file, centre (x, z) relative to the plot centre and the longest footprint side in studs.
-- The pads fill x -48..48, z -31..31 of the 120 x 120 ground; the furniture stands around them (the market at the
-- front in +z, its facade towards the plot centre) with walking room between.
-- `depth` (optional) is the assumed footprint depth in z of a wide piece; layout checks use it instead of `size`.
export type Furniture = { file: string, x: number, z: number, size: number, depth: number? }
Assets.furniture = {
	crank = { file = "crank", x = 0, z = -48, size = 4 },
	market = { file = "market", x = -20, z = 48, size = 40, depth = 20 },
	control = { file = "control", x = 35, z = 46, size = 5 },
	battery = { file = "battery", x = 50, z = -48, size = 3 },
} :: { [string]: Furniture }

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
