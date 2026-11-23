--!strict
-- The plain parts of the theme decoration kinds (docs/themes-design.md, section 4.2): one list of part descriptors per kind,
-- built from Roblox parts only. Sizes and offsets are in studs at scale 1, y up, on the ground at the centre of the piece;
-- the server scales and turns them (ThemeProps). A part: `shape` (Block, Ball, Cylinder, Sphere, Wedge, CornerWedge),
-- `size` and `at` ({ x, y, z }), `yaw` in degrees, `rgb` and `material` (an Enum.Material name). A Cylinder stands upright:
-- its size is { diameter, height, diameter }. A Sphere is a Block with a sphere mesh. No Roblox APIs.
local ThemeParts = {}

export type Part = { shape: string, size: { number }, at: { number }, yaw: number, rgb: { number }, material: string }

local WOOD = { 110, 78, 45 }
local DARK = { 70, 50, 35 }
local GREEN = { 34, 120, 60 }
local SNOW = { 248, 250, 255 }
local BLACK = { 25, 25, 28 }
local SLATE = { 95, 100, 110 }
local STONE = { 150, 150, 155 }
local RED = { 200, 40, 45 }
local GOLD = { 235, 190, 60 }
local BLUE = { 60, 120, 230 }
local PUMPKIN = { 235, 115, 25 }
local FLAME = { 255, 140, 30 }
local GLOW = { 255, 230, 90 }
local WEB = { 235, 235, 240 }

local function part(
	shape: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rgb: { number },
	material: string,
	yaw: number?
): Part
	return { shape = shape, size = { sx, sy, sz }, at = { x, y, z }, yaw = yaw or 0, rgb = rgb, material = material }
end

local BUILD: { [string]: (number) -> { Part } } = {}

-- Christmas tree, 12 studs: a trunk, three tiers of four corner wedges, a star and eight baubles.
function BUILD.tree(_n: number): { Part }
	local parts = { part("Cylinder", 1.6, 3, 1.6, 0, 1.5, 0, WOOD, "Wood") }
	for tier = 0, 2 do
		local w = 5 - 1.2 * tier
		for corner = 0, 3 do
			local x = if corner % 2 == 0 then -w / 2 else w / 2
			local z = if corner < 2 then -w / 2 else w / 2
			local y = 3 + 3 * tier + 1.75
			table.insert(parts, part("CornerWedge", w, 3.5, w, x, y, z, GREEN, "SmoothPlastic", 90 * corner))
		end
	end
	table.insert(parts, part("Ball", 1.2, 1.2, 1.2, 0, 13.1, 0, GLOW, "Neon"))
	local baubles = { RED, GOLD, BLUE }
	for i = 0, 7 do
		local tier = i % 3
		local r = 2.2 - 0.5 * tier
		local angle = math.rad(45 * i)
		table.insert(
			parts,
			part(
				"Ball",
				0.9,
				0.9,
				0.9,
				r * math.cos(angle),
				4 + 3 * tier,
				r * math.sin(angle),
				baubles[i % 3 + 1],
				"Neon"
			)
		)
	end
	return parts
end

-- Snowman, 6.6 studs: three snow balls, two coal eyes, a carrot nose and a black hat of two cylinders.
function BUILD.snowman(_n: number): { Part }
	return {
		part("Ball", 2.4, 2.4, 2.4, 0, 1.2, 0, SNOW, "Snow"),
		part("Ball", 1.8, 1.8, 1.8, 0, 3.3, 0, SNOW, "Snow"),
		part("Ball", 1.2, 1.2, 1.2, 0, 4.9, 0, SNOW, "Snow"),
		part("Ball", 0.2, 0.2, 0.2, -0.3, 5.1, 0.6, BLACK, "SmoothPlastic"),
		part("Ball", 0.2, 0.2, 0.2, 0.3, 5.1, 0.6, BLACK, "SmoothPlastic"),
		part("Wedge", 0.4, 0.3, 0.6, 0, 4.8, 0.9, PUMPKIN, "SmoothPlastic"),
		part("Cylinder", 1.4, 0.2, 1.4, 0, 5.6, 0, BLACK, "Slate"),
		part("Cylinder", 0.9, 0.9, 0.9, 0, 6.15, 0, BLACK, "Slate"),
	}
end

-- A gift, 2 studs: a box with a ribbon across it, red, green or gold in turn.
function BUILD.gift(n: number): { Part }
	local boxes = { RED, GREEN, GOLD }
	return {
		part("Block", 2, 1.6, 2, 0, 0.8, 0, boxes[n % 3 + 1], "SmoothPlastic"),
		part("Block", 0.3, 1.62, 2.1, 0, 0.8, 0, GOLD, "SmoothPlastic"),
		part("Block", 2.1, 1.62, 0.3, 0, 0.8, 0, GOLD, "SmoothPlastic"),
	}
end

-- A fairy light on the road rail: a neon ball, red, green, gold or blue in turn.
function BUILD.fairy(n: number): { Part }
	local colours = { RED, GREEN, GOLD, BLUE }
	return { part("Ball", 0.6, 0.6, 0.6, 0, 2.6, 0, colours[n % 4 + 1], "Neon") }
end

-- A small pine, 6 studs: a trunk and four corner wedges.
function BUILD.pine(_n: number): { Part }
	local parts = { part("Cylinder", 0.8, 1.5, 0.8, 0, 0.75, 0, WOOD, "Wood") }
	for corner = 0, 3 do
		local x = if corner % 2 == 0 then -0.8 else 0.8
		local z = if corner < 2 then -0.8 else 0.8
		table.insert(parts, part("CornerWedge", 3, 4, 3, x, 3.5, z, GREEN, "SmoothPlastic", 90 * corner))
	end
	return parts
end

-- A jack-o'-lantern, 3 studs: a pumpkin ball with a stem, glowing eyes and mouth.
function BUILD.jack(_n: number): { Part }
	return {
		part("Sphere", 2.6, 2.2, 2.6, 0, 1.1, 0, PUMPKIN, "SmoothPlastic"),
		part("Block", 0.4, 0.6, 0.4, 0, 2.5, 0, GREEN, "Wood"),
		part("Wedge", 0.6, 0.6, 0.1, -0.6, 1.5, 1.25, GLOW, "Neon"),
		part("Wedge", 0.6, 0.6, 0.1, 0.6, 1.5, 1.25, GLOW, "Neon"),
		part("Block", 1.4, 0.4, 0.1, 0, 0.7, 1.25, GLOW, "Neon"),
	}
end

-- The giant jack-o'-lantern at the corner, 7 studs.
function BUILD.giant(_n: number): { Part }
	return {
		part("Sphere", 6.5, 6.5, 6.5, 0, 3.25, 0, PUMPKIN, "SmoothPlastic"),
		part("Block", 1, 1.5, 1, 0, 7.25, 0, DARK, "Wood"),
		part("Wedge", 1.2, 1.2, 0.2, -1.5, 3.8, 3.2, FLAME, "Neon"),
		part("Wedge", 1.2, 1.2, 0.2, 1.5, 3.8, 3.2, FLAME, "Neon"),
		part("Block", 3, 1, 0.2, 0, 2.2, 3.2, FLAME, "Neon"),
		part("Wedge", 1.8, 0.4, 1.8, 0.8, 7.9, 0, GREEN, "SmoothPlastic"),
	}
end

-- A plain pumpkin, 2 studs: a ball with a stem.
function BUILD.pumpkin(_n: number): { Part }
	return {
		part("Sphere", 1.8, 1.4, 1.8, 0, 0.7, 0, PUMPKIN, "SmoothPlastic"),
		part("Block", 0.3, 0.4, 0.3, 0, 1.6, 0, GREEN, "Wood"),
	}
end

-- A tombstone, 3 studs: a slate slab with a rounded top.
function BUILD.tombstone(_n: number): { Part }
	return {
		part("Block", 1.8, 2.2, 0.5, 0, 1.1, 0, SLATE, "Slate"),
		part("Cylinder", 1.8, 0.5, 1.8, 0, 2.45, 0, SLATE, "Slate"),
	}
end

-- A cobweb in a fence corner, 2 studs: four thin white bars.
function BUILD.cobweb(_n: number): { Part }
	return {
		part("Block", 2, 0.1, 0.1, 0, 2, 0, WEB, "Glass", 0),
		part("Block", 2, 0.1, 0.1, 0, 2, 0, WEB, "Glass", 90),
		part("Block", 2, 0.1, 0.1, 0, 1.2, 0, WEB, "Glass", 45),
		part("Block", 2, 0.1, 0.1, 0, 1.2, 0, WEB, "Glass", -45),
	}
end

-- A dead tree, 6 studs: a dark trunk and three branches.
function BUILD.deadtree(_n: number): { Part }
	return {
		part("Cylinder", 0.9, 5, 0.9, 0, 2.5, 0, DARK, "Wood"),
		part("Block", 2.5, 0.3, 0.3, 0.8, 4, 0, DARK, "Wood", 30),
		part("Block", 2, 0.3, 0.3, -0.7, 3.2, 0.5, DARK, "Wood", -40),
		part("Block", 1.8, 0.3, 0.3, 0.2, 2.2, -0.6, DARK, "Wood", 70),
	}
end

-- A post lantern, 1 stud: a glowing orange block.
function BUILD.lantern(_n: number): { Part }
	return { part("Block", 0.8, 0.8, 0.8, 0, 2.6, 0, FLAME, "Neon") }
end

-- The parts of site `n` (counted from 1 within its kind) of `kind`; nil for a kind without parts.
function ThemeParts.kind(kind: string, n: number): { Part }?
	local build = BUILD[kind]
	if build == nil then
		return nil
	end
	return build(n)
end

return ThemeParts
