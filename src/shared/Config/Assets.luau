--!strict
-- Plant models (issue #80): plant id -> model file in assets/models (ServerStorage.Models), a size factor and a cap for
-- the visible copies. No entry or no file: the plot builds the primitive column. Pure functions, no Roblox APIs.
export type Entry = { file: string, scale: number, cap: number }

local Assets = {}

-- Side length of the square a plant gets on the plot (the primitive column is 4 x 4).
Assets.SLOT = 4

Assets.plants = {
	[1] = { file = "plant1_panel", scale = 1, cap = 8 },
	[2] = { file = "plant2_waterwheel", scale = 1, cap = 8 },
	[3] = { file = "plant3_house", scale = 1, cap = 8 },
	[4] = { file = "plant4_miniturbine", scale = 0.4, cap = 8 },
	[5] = { file = "plant5_solarfarm", scale = 1, cap = 8 },
	[6] = { file = "plant6_windturbine", scale = 1, cap = 8 },
} :: { [number]: Entry }

-- Plot furniture (issue #82): file, centre (x, z) relative to the plot centre and the longest footprint side in studs.
-- The plants stand in x -14.5..14.5, z -2..2 on a 40 x 40 ground, so the furniture sits in z beyond 5 and clear of each other.
export type Furniture = { file: string, x: number, z: number, size: number }
Assets.furniture = {
	crank = { file = "crank", x = 0, z = -10, size = 4 },
	market = { file = "market", x = -10, z = 12, size = 12 },
	control = { file = "control", x = 10, z = 12, size = 8 },
	battery = { file = "battery", x = 15, z = -10, size = 3 },
} :: { [string]: Furniture }

-- Studs between stacked battery units (the unit's own height is added on top).
Assets.BATTERY_GAP = 3
-- Texture ids of the poster decals removed from the market (cola posters), and the part names removed whole.
Assets.marketPosterTextures = { ["rbxassetid://7977205851"] = true }
Assets.marketRemovedParts = { ["Floppa Cube"] = true, ["Floppa cube"] = true }

-- True when the furniture piece has an entry and its file is present (`available` maps file name -> true).
function Assets.useFurniture(name: string, available: { [string]: boolean }): boolean
	local entry = Assets.furniture[name]
	return entry ~= nil and available[entry.file] == true
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

-- Grid for `copies` models inside a square of side `slot`: the cell size and the (x, z) centre of each cell.
function Assets.layout(copies: number, slot: number): (number, { { x: number, z: number } })
	local offsets: { { x: number, z: number } } = {}
	if copies <= 0 then
		return slot, offsets
	end
	local side = math.ceil(math.sqrt(copies))
	local cell = slot / side
	for i = 0, copies - 1 do
		table.insert(offsets, {
			x = (i % side + 0.5) * cell - slot / 2,
			z = (i // side + 0.5) * cell - slot / 2,
		})
	end
	return cell, offsets
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
