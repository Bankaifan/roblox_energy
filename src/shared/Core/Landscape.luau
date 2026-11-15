--!strict
-- Shape of the world around the plots (issue 85): a valley with a flat meadow for the plots, a country road, a lake
-- and a ring of hills. Pure functions: ground height, ground cover and the list of props, the same in Lune and Studio.
export type Prop = { kind: string, x: number, y: number, z: number, yaw: number, scale: number, tone: number }

local Module = {}

-- The landscape for `slots` plots of side `plotSize` whose centres stand at x = slot * plotSpacing, z = 0, on ground
-- height 0 (PlotService, Config/Assets). Everything else follows from these three numbers.
function Module.new(plotSize: number, plotSpacing: number, slots: number)
	local Landscape = {}
	local half = plotSize / 2

	Landscape.PLOTS = { minX = plotSpacing - half, maxX = slots * plotSpacing + half, minZ = -half, maxZ = half }
	-- Flat meadow at height 0: the plots, the spawn at the origin and the road beside them.
	Landscape.MEADOW = { minX = -48, maxX = Landscape.PLOTS.maxX + 48, minZ = -half - 16, maxZ = half + 44 }
	local MEADOW = Landscape.MEADOW
	-- CELL is the terrain voxel size. The road centre lies on a cell centre, so the asphalt is three cells wide.
	Landscape.CELL = 4
	local ROAD_Z = math.floor((half + 26) / 4) * 4 + 2
	local LAKE =
		{ x = (Landscape.PLOTS.minX + Landscape.PLOTS.maxX) / 2, z = MEADOW.minZ - 165, radiusX = 260, radiusZ = 95 }

	-- World box in studs: the meadow plus room for the hills and the lake. Every bound is a multiple of CHUNK studs.
	local CHUNK = 128
	Landscape.MIN_X = math.floor((MEADOW.minX - 208) / CHUNK) * CHUNK
	Landscape.MAX_X = math.ceil((MEADOW.maxX + 220) / CHUNK) * CHUNK
	Landscape.MIN_Z = math.floor((LAKE.z - LAKE.radiusZ - 110) / CHUNK) * CHUNK
	Landscape.MAX_Z = math.ceil((MEADOW.maxZ + 280) / CHUNK) * CHUNK
	Landscape.FLOOR, Landscape.CEILING = -24, 72
	Landscape.WATER = -4

	-- Parts per prop kind, and the cap for the whole world (phone friendly).
	Landscape.PARTS = {
		oak = 4,
		birch = 3,
		bush = 2,
		rock = 1,
		flower = 1,
		pole = 2,
		lamppole = 4,
		turbine = 7,
		bale = 1,
		jetty = 9,
	} :: { [string]: number }
	Landscape.MAX_PARTS = 600

	local MODULUS = 2147483647
	local MULTIPLIER = 16807

	-- 0 at `from`, 1 at `to`, smooth in between. `from` may be larger than `to`.
	local function smooth(from: number, to: number, value: number): number
		local share = math.clamp((value - from) / (to - from), 0, 1)
		return share * share * (3 - 2 * share)
	end

	-- Rolling value in 0..1 from three layers of noise.
	local function roll(x: number, z: number): number
		local sum = math.noise(x / 190 + 1.7, z / 190 - 3.1, 5.5)
			+ 0.5 * math.noise(x / 90 + 0.3, z / 90 + 0.6, 16.5)
			+ 0.25 * math.noise(x / 40 + 0.9, z / 40 + 0.2, 28.5)
		return math.clamp(0.5 + 0.62 * sum, 0, 1)
	end

	-- Distance in studs to the flat meadow; 0 on it.
	function Landscape.meadowDistance(x: number, z: number): number
		local dx = math.max(MEADOW.minX - x, 0, x - MEADOW.maxX)
		local dz = math.max(MEADOW.minZ - z, 0, z - MEADOW.maxZ)
		return math.sqrt(dx * dx + dz * dz)
	end

	-- z of the road centre line at x. Straight beside the plots, a gentle S bend beyond the meadow.
	function Landscape.roadZ(x: number): number
		if x < MEADOW.minX then
			return ROAD_Z + 70 * smooth(0, 240, MEADOW.minX - x)
		elseif x > MEADOW.maxX then
			return ROAD_Z - 100 * smooth(0, 260, x - MEADOW.maxX)
		end
		return ROAD_Z
	end

	function Landscape.roadDistance(x: number, z: number): number
		return math.abs(z - Landscape.roadZ(x))
	end

	-- Lake distance: below 1 is inside the lake, the shore line wobbles with noise.
	local function lakeDistance(x: number, z: number): number
		local nx, nz = (x - LAKE.x) / LAKE.radiusX, (z - LAKE.z) / LAKE.radiusZ
		return math.sqrt(nx * nx + nz * nz) + 0.14 * math.noise(x / 70 + 0.4, z / 70 + 0.8, 7.3)
	end

	-- Ground height in studs at (x, z). Exactly 0 on the meadow, so plots stay flat.
	function Landscape.height(x: number, z: number): number
		local distance = Landscape.meadowDistance(x, z)
		if distance == 0 then
			return 0
		end
		local rolling = roll(x, z)
		-- Hills grow with the distance from the meadow, and a rim at the world border hides the edge.
		local height = smooth(0, 96, distance) * (3 + 50 * rolling ^ 1.5)
		local border = math.min(x - Landscape.MIN_X, Landscape.MAX_X - x, z - Landscape.MIN_Z, Landscape.MAX_Z - z)
		height += smooth(150, 0, border) * (10 + 26 * rolling)
		-- The lake: the land flattens towards it, then drops below the water level.
		local lake = lakeDistance(x, z)
		height = height * smooth(1, 2.1, lake) - 18 * smooth(1, 0.4, lake)
		-- The road cuts a level band through the hills and climbs slowly beyond the meadow.
		local beyond = math.max(MEADOW.minX - x, x - MEADOW.maxX, 0)
		local band = smooth(30, 9, Landscape.roadDistance(x, z))
		height += (7 * smooth(0, 220, beyond) - height) * band
		return math.clamp(height, Landscape.FLOOR + 4, Landscape.CEILING - 6)
	end

	-- Steepness at (x, z): rise per stud.
	function Landscape.slope(x: number, z: number): number
		local dx = Landscape.height(x + 2, z) - Landscape.height(x - 2, z)
		local dz = Landscape.height(x, z + 2) - Landscape.height(x, z - 2)
		return math.sqrt(dx * dx + dz * dz) / 4
	end

	-- Ground cover at (x, z): the name of a terrain material.
	function Landscape.surface(x: number, z: number): string
		local road = Landscape.roadDistance(x, z)
		if road < 6 then
			return "Asphalt"
		elseif road < 9 then
			return "Ground"
		elseif Landscape.height(x, z) < Landscape.WATER + 2.5 then
			return "Sand"
		elseif Landscape.slope(x, z) > 0.95 then
			return "Rock"
		elseif math.noise(x / 45 + 0.5, z / 45 + 0.1, 91.5) > 0.18 then
			return "LeafyGrass"
		end
		return "Grass"
	end

	-- Every prop of the world for one seed: trees, bushes, rocks, glowing flowers, power poles along the road, wind
	-- turbines behind the lake, hay bales and a jetty. Nothing stands on the meadow or on the road.
	function Landscape.props(seed: number): { Prop }
		local state = seed % (MODULUS - 1) + 1
		local function random(): number
			state = (state * MULTIPLIER) % MODULUS
			return state / MODULUS
		end

		local props: { Prop } = {}
		local function add(kind: string, x: number, z: number, yaw: number?): Prop
			local prop = {
				kind = kind,
				x = x,
				y = Landscape.height(x, z),
				z = z,
				yaw = yaw or random() * 2 * math.pi,
				scale = 0.75 + 0.6 * random(),
				tone = random(),
			}
			table.insert(props, prop)
			return prop
		end

		-- Places up to `count` props at least `spacing` studs apart. `near` is the share placed close to the meadow,
		-- where players see them; pick names the kind for a spot or returns nil to reject it.
		local function scatter(count: number, spacing: number, near: number, pick: (number, number, number) -> string?)
			local placed: { Prop } = {}
			local tries = 0
			while #placed < count and tries < count * 60 do
				tries += 1
				local x, z
				if random() < near then
					x = MEADOW.minX - 120 + (MEADOW.maxX - MEADOW.minX + 240) * random()
					z = MEADOW.minZ - 115 + (MEADOW.maxZ - MEADOW.minZ + 240) * random()
				else
					x = Landscape.MIN_X + 16 + (Landscape.MAX_X - Landscape.MIN_X - 32) * random()
					z = Landscape.MIN_Z + 16 + (Landscape.MAX_Z - Landscape.MIN_Z - 32) * random()
				end
				local kind = pick(x, z, Landscape.height(x, z))
				for _, other in placed do
					if (other.x - x) ^ 2 + (other.z - z) ^ 2 < spacing * spacing then
						kind = nil
					end
				end
				if kind ~= nil then
					table.insert(placed, add(kind, x, z))
				end
			end
		end

		local function clear(x: number, z: number, meadow: number, road: number): boolean
			return Landscape.meadowDistance(x, z) >= meadow and Landscape.roadDistance(x, z) >= road
		end

		scatter(76, 10, 0.55, function(x, z, height)
			if clear(x, z, 8, 16) and height >= Landscape.WATER + 3 and Landscape.slope(x, z) <= 0.8 then
				return if random() < 0.62 then "oak" else "birch"
			end
			return nil
		end)
		scatter(44, 6, 0.7, function(x, z, height)
			return if clear(x, z, 5, 12) and height >= Landscape.WATER + 2 then "bush" else nil
		end)
		scatter(34, 8, 0.5, function(x, z, height)
			return if clear(x, z, 6, 12) and height >= Landscape.WATER - 2 then "rock" else nil
		end)
		scatter(56, 4, 1, function(x, z, height)
			local shore = height >= Landscape.WATER + 0.5 and height <= Landscape.WATER + 5
			local meadowEdge = Landscape.meadowDistance(x, z) <= 70 and height >= 0
			return if clear(x, z, 3, 10) and (shore or meadowEdge) then "flower" else nil
		end)

		-- Power poles on the far side of the road, every second one with a lamp. yaw turns the pole along the road.
		local index = 0
		for x = Landscape.MIN_X + 34, Landscape.MAX_X - 30, 64 do
			index += 1
			local bend = (Landscape.roadZ(x + 1) - Landscape.roadZ(x - 1)) / 2
			add(if index % 2 == 0 then "lamppole" else "pole", x, Landscape.roadZ(x) + 12, -math.atan(bend))
		end

		for _, spot in { { -170, -55 }, { 0, -65 }, { 170, -50 } } do
			add("turbine", LAKE.x + spot[1], LAKE.z - LAKE.radiusZ + spot[2], 0)
		end
		for _, spot in { { 30, -30 }, { 46, -44 }, { 18, -52 }, { 58, -62 }, { 4, -36 }, { 74, -38 } } do
			add("bale", MEADOW.minX + spot[1], MEADOW.minZ + spot[2])
		end

		-- The jetty starts where the shore in front of the plots meets the water and runs out over the lake (towards -z).
		local shoreZ = MEADOW.minZ
		while shoreZ > LAKE.z and Landscape.height(LAKE.x, shoreZ) > Landscape.WATER + 1 do
			shoreZ -= 2
		end
		add("jetty", LAKE.x, shoreZ, 0).y = Landscape.WATER + 1.2

		return props
	end

	-- Number of parts the props need.
	function Landscape.partCount(props: { Prop }): number
		local count = 0
		for _, prop in props do
			count += Landscape.PARTS[prop.kind]
		end
		return count
	end

	return Landscape
end

return Module
