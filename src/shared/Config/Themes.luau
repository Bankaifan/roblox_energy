--!strict
-- Plot theme decoration data (docs/themes-design.md, sections 4.2 and 4.5): what each theme puts on a plot, as data only.
-- Core/ThemeDecor places the pieces; the server builders (a later step) build them. No Roblox APIs.
-- A piece entry: `kind`, `count` pieces of `footprint` studs (square) each made of `parts` parts, standing in `zone`
-- (rim, yard, corner, open, corners, near:<kind>, fenceRoad with `every` studs, fixed = no site). `tall` pieces are higher
-- than 3 studs and keep the full clearance; `lights` is the number of PointLights of the whole entry.
export type Piece = {
	kind: string,
	count: number,
	footprint: number,
	parts: number,
	zone: string,
	tall: boolean?,
	lights: number?,
	every: number?,
}
export type Set = { pieces: { Piece }, emitter: { kind: string, rate: number }? }

local Themes = {}

-- The parts of the base theme (4 ground strips, 48 posts, 4 rails, the sign and its post) and the budget of one plot.
Themes.BASE_PARTS = 58
Themes.THEME_PARTS = 210
Themes.MAX_LIGHTS = 6
Themes.MAX_EMITTERS = 1
Themes.MAX_RATE = 10
-- The fence line (plot-relative studs) that decoration stays inside.
Themes.FENCE = 93

-- The material the meadow of the plot takes in a theme (terrain material name); a theme not listed keeps the grass.
-- Snow for Christmas, Mud (coloured dry orange-brown by PlotGround) for Autumn, Sand for Desert.
Themes.meadow = { christmas = "Snow", autumn = "Mud", desert = "Sand" } :: { [string]: string }

-- Walk lanes kept free (plot-relative studs { minX, maxX, minZ, maxZ }): the yard, the lane between F4 and F3, the back lane.
Themes.lanes = {
	{ -36, 60, 72, 90 },
	{ -16, 0, -56, 68 },
	{ -96, 96, -56, -48 },
} :: { { number } }

Themes.sets = {
	classic = { pieces = {} },
	desert = {
		pieces = {
			{ kind = "cactus", count = 5, footprint = 3, parts = 3, zone = "open", tall = true },
			{ kind = "rock", count = 6, footprint = 3, parts = 1, zone = "open" },
		},
	},
	night = {
		pieces = {
			{ kind = "lamp", count = 2, footprint = 1.5, parts = 3, zone = "yard", tall = true, lights = 2 },
			{
				kind = "lamp",
				count = 2,
				footprint = 1.5,
				parts = 3,
				zone = "fenceRoad",
				every = 60,
				tall = true,
				lights = 2,
			},
			{ kind = "bench", count = 2, footprint = 4, parts = 3, zone = "yard" },
		},
		emitter = { kind = "fireflies", rate = 3 },
	},
	spring = {
		pieces = {
			{ kind = "blossom", count = 1, footprint = 8, parts = 4, zone = "corner", tall = true },
			{ kind = "blossom", count = 2, footprint = 8, parts = 4, zone = "open", tall = true },
			{ kind = "tulips", count = 3, footprint = 5, parts = 11, zone = "rim" },
			{ kind = "egg", count = 10, footprint = 1.5, parts = 1, zone = "open" },
			{ kind = "birdhouse", count = 2, footprint = 1.5, parts = 3, zone = "yard", tall = true },
		},
		emitter = { kind = "petals", rate = 3 },
	},
	summer = {
		pieces = {
			{ kind = "beach", count = 1, footprint = 18, parts = 16, zone = "corner", tall = true },
			{ kind = "palm", count = 3, footprint = 7, parts = 6, zone = "rim", tall = true },
			{ kind = "flower", count = 12, footprint = 1.5, parts = 2, zone = "rim" },
			{ kind = "sandcastle", count = 1, footprint = 3, parts = 4, zone = "near:beach" },
			{
				kind = "tiki",
				count = 4,
				footprint = 1,
				parts = 2,
				zone = "fenceRoad",
				every = 40,
				tall = true,
				lights = 2,
			},
		},
	},
	autumn = {
		pieces = {
			{ kind = "maple", count = 1, footprint = 9, parts = 4, zone = "corner", tall = true },
			{ kind = "maple", count = 3, footprint = 9, parts = 4, zone = "open", tall = true },
			{ kind = "leaves", count = 4, footprint = 4, parts = 2, zone = "near:maple" },
			{ kind = "leaves", count = 6, footprint = 4, parts = 2, zone = "open" },
			{ kind = "hay", count = 4, footprint = 4, parts = 1, zone = "yard" },
			{ kind = "scarecrow", count = 1, footprint = 4, parts = 7, zone = "open", tall = true },
			{ kind = "pumpkin", count = 4, footprint = 2, parts = 2, zone = "near:hay" },
			{ kind = "crate", count = 3, footprint = 3, parts = 2, zone = "yard" },
		},
		emitter = { kind = "leaves", rate = 4 },
	},
	halloween = {
		pieces = {
			{ kind = "giant", count = 1, footprint = 7, parts = 6, zone = "corner", tall = true, lights = 1 },
			{ kind = "jack", count = 8, footprint = 3, parts = 5, zone = "rim", lights = 3 },
			{ kind = "pumpkin", count = 6, footprint = 2, parts = 2, zone = "near:giant" },
			{ kind = "tombstone", count = 6, footprint = 3, parts = 2, zone = "rim" },
			{ kind = "cobweb", count = 4, footprint = 2, parts = 4, zone = "corners" },
			{ kind = "deadtree", count = 3, footprint = 6, parts = 4, zone = "open", tall = true },
			{
				kind = "lantern",
				count = 6,
				footprint = 1,
				parts = 1,
				zone = "fenceRoad",
				every = 32,
				tall = true,
				lights = 2,
			},
		},
		emitter = { kind = "wisps", rate = 2 },
	},
	christmas = {
		pieces = {
			{ kind = "tree", count = 1, footprint = 12, parts = 22, zone = "corner", tall = true, lights = 1 },
			{ kind = "snowman", count = 2, footprint = 4, parts = 8, zone = "open", tall = true },
			{ kind = "gift", count = 4, footprint = 3, parts = 3, zone = "near:tree" },
			{ kind = "gift", count = 2, footprint = 3, parts = 3, zone = "yard" },
			{ kind = "fairy", count = 31, footprint = 0.6, parts = 1, zone = "fenceRoad", every = 6 },
			{ kind = "pine", count = 6, footprint = 6, parts = 5, zone = "open", tall = true },
			{ kind = "railsnow", count = 4, footprint = 0, parts = 1, zone = "fixed" },
		},
		emitter = { kind = "snow", rate = 8 },
	},
} :: { [string]: Set }

-- Parts, lights and emitter rate of a set at its largest (every fenceRoad piece placed).
function Themes.budget(set: Set): { parts: number, lights: number, rate: number }
	local parts, lights = Themes.BASE_PARTS, 0
	for _, piece in set.pieces do
		parts += piece.parts * piece.count
		lights += piece.lights or 0
	end
	return { parts = parts, lights = lights, rate = if set.emitter then set.emitter.rate else 0 }
end

return Themes
