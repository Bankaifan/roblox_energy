--!strict
-- River course of a plot (land design v2, sections 3 and 4): an organic curve through Assets.river.points, cut into
-- segments, with the axle and four wheels of each segment, wobbly banks, terrain masks and the plank bridges.
-- Pure functions, no Roblox APIs; x and z are studs relative to the plot centre, unmirrored (a plot with facing -1 is
-- mirrored in z by the caller). The water runs downstream: from the first point (the spring) to the last (the pond).
local River = {}

-- Number in [-1, 1] from (seed, a, b, salt): the same hash as Core/Meadow (core modules do not require each other), so
-- the banks wobble like the meadow edges.
local function noise(seed: number, a: number, b: number, salt: number): number
	local h = (seed * 73856093 + a * 19349663 + b * 83492791 + salt * 49979687) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	h = (h * 1103515245 + 12345) % 2147483647
	return (h // 1024) % 2001 / 1000 - 1
end

export type Config = { points: { { number } }, width: number, segments: number }
-- One sample of the centre line. (tx, tz) is the unit flow direction, (nx, nz) = (-tz, tx) the unit normal. `minus` and
-- `plus` are the half-widths of the water towards -n and +n (width / 2 plus a little bank wobble).
export type Sample = {
	x: number,
	z: number,
	tx: number,
	tz: number,
	nx: number,
	nz: number,
	arc: number,
	minus: number,
	plus: number,
}
export type Course = {
	samples: { Sample },
	width: number,
	segments: number,
	perSegment: number, -- sample intervals per segment
	length: number,
	seed: number,
}
export type Pose = { x: number, z: number, yaw: number }
export type Wheel = { x: number, z: number, yaw: number, axisX: number, axisZ: number, width: number }
export type Axle = {
	x: number,
	z: number,
	yaw: number, -- flow direction at the axle
	axisX: number, -- unit vector of the axle (across the flow)
	axisZ: number,
	from: Pose, -- the two bank ends, `from` on the -n side
	to: Pose,
	length: number,
	wheels: { Wheel },
}
export type Range = { first: number, last: number, x: number, z: number }
export type SegmentInfo = {
	k: number,
	first: number, -- sample indices (inclusive)
	last: number,
	length: number,
	halves: { Range },
	axle: Axle,
}
export type Bridge = {
	segment: number,
	x: number,
	z: number,
	yaw: number, -- flow direction; the planks run along (axisX, axisZ), across the water
	axisX: number,
	axisZ: number,
	length: number,
	parts: number,
}

-- Studs between two samples (a bit more or less after the wobble).
River.PITCH = 4
-- The course wobbles by up to WOBBLE studs from the smooth curve (about one bump every WOBBLE_PITCH studs); the ends stay put.
River.WOBBLE = 2
River.WOBBLE_PITCH = 22
River.WOBBLE_FADE = 8
-- Bank wobble: each bank moves in or out by up to BANK_WOBBLE studs per sample.
River.BANK_WOBBLE = 0.4
-- Dig stages of a segment: 0 meadow, 1 dry trench, 2 flooded (the bank is breached and water runs in).
River.DRY = 1
River.FLOODED = 2
-- The trench floor lies TRENCH_DEPTH below the meadow, the water surface WATER_DROP below it.
River.TRENCH_DEPTH = 3
River.WATER_DROP = 1
-- Studs per second the foam and the wheel rims travel downstream.
River.FLOW_SPEED = 4
-- Wheels: four per axle, each at most WHEEL_WIDTH wide, WHEEL_PITCH apart along the axle (four fit the 12-stud water).
River.WHEELS = 4
River.WHEEL_WIDTH = 2.6
River.WHEEL_PITCH = 2.8
-- Bridges (design: about x = -42 and x = 14), BRIDGE_OVERHANG studs of plank on each bank, five parts each.
River.BRIDGE_X = { -42, 14 }
River.BRIDGE_OVERHANG = 2
River.BRIDGE_PARTS = 5

local function flowYaw(tx: number, tz: number): number
	-- Roblox: a rotation of `yaw` about Y turns the look vector (0, 0, -1) to (-sin yaw, 0, -cos yaw).
	return math.atan2(-tx, -tz)
end

-- Smooth number in [-1, 1] along the course: noise on a grid of `pitch` studs, blended between its corners.
local function smooth(seed: number, s: number, pitch: number, salt: number): number
	local g = s / pitch
	local i = math.floor(g)
	local f = g - i
	f = f * f * (3 - 2 * f)
	return noise(seed, i, 0, salt) * (1 - f) + noise(seed, i + 1, 0, salt) * f
end

-- Uniform Catmull-Rom point at u in [0, 1] between p1 and p2 (p0 and p3 are the neighbours).
local function catmull(p0: { number }, p1: { number }, p2: { number }, p3: { number }, u: number): (number, number)
	local u2, u3 = u * u, u * u * u
	local function axis(i: number): number
		return 0.5
			* (
				2 * p1[i]
				+ (p2[i] - p0[i]) * u
				+ (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * u2
				+ (3 * p1[i] - p0[i] - 3 * p2[i] + p3[i]) * u3
			)
	end
	return axis(1), axis(2)
end

-- The course of a plot: the curve through `river.points`, resampled every River.PITCH studs, plus a wobble seeded by
-- the plot slot. Deterministic: the same (river, seed) gives the same course on every machine.
function River.course(river: Config, seed: number): Course
	local pts = river.points
	-- Dense smooth curve, 24 steps per span.
	local dense: { { number } } = {}
	for i = 1, #pts - 1 do
		local p0, p3 = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 2)]
		for step = 0, 23 do
			local x, z = catmull(p0, pts[i], pts[i + 1], p3, step / 24)
			table.insert(dense, { x, z })
		end
	end
	table.insert(dense, { pts[#pts][1], pts[#pts][2] })
	local cum = { 0 }
	for i = 2, #dense do
		local dx, dz = dense[i][1] - dense[i - 1][1], dense[i][2] - dense[i - 1][2]
		table.insert(cum, cum[i - 1] + math.sqrt(dx * dx + dz * dz))
	end
	local total = cum[#cum]
	local per = math.max(1, math.ceil(total / river.segments / River.PITCH))
	local count = river.segments * per
	local step = total / count
	-- Resample at equal arc length, then wobble sideways.
	local raw: { { number } } = {}
	local j = 1
	for i = 0, count do
		local s = i * step
		while j < #dense - 1 and cum[j + 1] < s do
			j += 1
		end
		local span = cum[j + 1] - cum[j]
		local u = if span > 0 then math.clamp((s - cum[j]) / span, 0, 1) else 0
		table.insert(raw, {
			dense[j][1] + (dense[j + 1][1] - dense[j][1]) * u,
			dense[j][2] + (dense[j + 1][2] - dense[j][2]) * u,
		})
	end
	local samples: { Sample } = {}
	for i = 1, #raw do
		local a, b = raw[math.max(1, i - 1)], raw[math.min(#raw, i + 1)]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local s = (i - 1) * step
		local fade = math.clamp(math.min(s, total - s) / River.WOBBLE_FADE, 0, 1)
		local shift = River.WOBBLE * smooth(seed, s, River.WOBBLE_PITCH, 21) * fade
		local tx, tz = dx / len, dz / len
		table.insert(samples, {
			x = raw[i][1] - tz * shift,
			z = raw[i][2] + tx * shift,
			tx = tx,
			tz = tz,
			nx = -tz,
			nz = tx,
			arc = 0,
			minus = river.width / 2 + noise(seed, i, 1, 22) * River.BANK_WOBBLE,
			plus = river.width / 2 + noise(seed, i, 2, 22) * River.BANK_WOBBLE,
		})
	end
	-- Heading from the wobbled positions, and the real arc length.
	for i, sample in samples do
		local a, b = samples[math.max(1, i - 1)], samples[math.min(#samples, i + 1)]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		sample.tx, sample.tz = dx / len, dz / len
		sample.nx, sample.nz = -sample.tz, sample.tx
		if i > 1 then
			local p = samples[i - 1]
			sample.arc = p.arc + math.sqrt((sample.x - p.x) ^ 2 + (sample.z - p.z) ^ 2)
		end
	end
	return {
		samples = samples,
		width = river.width,
		segments = river.segments,
		perSegment = per,
		length = samples[#samples].arc,
		seed = seed,
	}
end

-- The point of the course at arc length `s` from the spring (clamped), blended between the two samples around it.
function River.at(course: Course, s: number): Sample
	local list = course.samples
	s = math.clamp(s, 0, course.length)
	local lo, hi = 1, #list
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if list[mid].arc <= s then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = list[lo], list[hi]
	local span = b.arc - a.arc
	local u = if span > 0 then (s - a.arc) / span else 0
	local function mix(p: number, q: number): number
		return p + (q - p) * u
	end
	local tx, tz = mix(a.tx, b.tx), mix(a.tz, b.tz)
	local len = math.sqrt(tx * tx + tz * tz)
	tx, tz = tx / len, tz / len
	return {
		x = mix(a.x, b.x),
		z = mix(a.z, b.z),
		tx = tx,
		tz = tz,
		nx = -tz,
		nz = tx,
		arc = s,
		minus = mix(a.minus, b.minus),
		plus = mix(a.plus, b.plus),
	}
end

-- Yaw (radians) of the flow at a sample: CFrame.Angles(0, yaw, 0) looks downstream.
function River.yaw(sample: Sample): number
	return flowYaw(sample.tx, sample.tz)
end

-- The bank points of a sample: (x, z) on the -n side and on the +n side.
function River.banks(sample: Sample): ({ number }, { number })
	return { sample.x - sample.nx * sample.minus, sample.z - sample.nz * sample.minus }, {
		sample.x + sample.nx * sample.plus,
		sample.z + sample.nz * sample.plus,
	}
end

-- Four wheels on one axle across the flow, side by side and centred on the axle.
local function wheelsAt(mid: Sample): { Wheel }
	local wheels: { Wheel } = {}
	local yaw = flowYaw(mid.tx, mid.tz)
	for i = 1, River.WHEELS do
		local offset = (i - (River.WHEELS + 1) / 2) * River.WHEEL_PITCH
		table.insert(wheels, {
			x = mid.x + mid.nx * offset,
			z = mid.z + mid.nz * offset,
			yaw = yaw,
			axisX = mid.nx,
			axisZ = mid.nz,
			width = River.WHEEL_WIDTH,
		})
	end
	return wheels
end

-- Segment k (1 = at the spring): sample range, dig halves and the pose of its axle with the four wheels. The axle sits in
-- the middle of the segment, across the flow, from bank to bank; the wheels lie in the plane of the flow.
function River.segment(course: Course, k: number): SegmentInfo
	assert(k >= 1 and k <= course.segments and k % 1 == 0, "segment out of range")
	local per = course.perSegment
	local first, last = (k - 1) * per + 1, k * per + 1
	local a, b = course.samples[first], course.samples[last]
	local mid = River.at(course, (a.arc + b.arc) / 2)
	local cut = first + per // 2
	local function range(from: number, to: number): Range
		local m = River.at(course, (course.samples[from].arc + course.samples[to].arc) / 2)
		return { first = from, last = to, x = m.x, z = m.z }
	end
	local left, right = River.banks(mid)
	local yaw = flowYaw(mid.tx, mid.tz)
	return {
		k = k,
		first = first,
		last = last,
		length = b.arc - a.arc,
		halves = { range(first, cut), range(cut, last) },
		axle = {
			x = mid.x,
			z = mid.z,
			yaw = yaw,
			axisX = mid.nx,
			axisZ = mid.nz,
			from = { x = left[1], z = left[2], yaw = yaw },
			to = { x = right[1], z = right[2], yaw = yaw },
			length = mid.minus + mid.plus,
			wheels = wheelsAt(mid),
		},
	}
end

-- Segment (1-based) that contains arc length `s`.
function River.segmentAt(course: Course, s: number): number
	local per = course.perSegment
	for k = 1, course.segments do
		if s <= course.samples[k * per + 1].arc then
			return k
		end
	end
	return course.segments
end

-- The plank bridges: at the sample whose x is closest to each River.BRIDGE_X, across the water.
function River.bridges(course: Course): { Bridge }
	local result: { Bridge } = {}
	for _, wantX in River.BRIDGE_X do
		local best = course.samples[1]
		for _, sample in course.samples do
			if math.abs(sample.x - wantX) < math.abs(best.x - wantX) then
				best = sample
			end
		end
		table.insert(result, {
			segment = River.segmentAt(course, best.arc),
			x = best.x,
			z = best.z,
			yaw = flowYaw(best.tx, best.tz),
			axisX = best.nx,
			axisZ = best.nz,
			length = best.minus + best.plus + 2 * River.BRIDGE_OVERHANG,
			parts = River.BRIDGE_PARTS,
		})
	end
	return result
end

-- Dig state --------------------------------------------------------------------------------------------------------
-- `stages[k]` is the stage 0..2 of segment k as saved. Water only runs where it comes from the spring, so a stage-2
-- segment behind a segment that is not flooded counts as a dry trench at most.

-- The effective stages: whole numbers 0..2, one entry per segment, flooded only downstream of flooded segments.
function River.stages(saved: { number }?, segments: number): { number }
	local result: { number } = {}
	local open = true
	for k = 1, segments do
		local raw = if saved ~= nil and type(saved[k]) == "number" then saved[k] else 0
		local stage = math.clamp(math.floor(raw), 0, 2)
		if stage == River.FLOODED and not open then
			stage = River.DRY
		end
		open = open and stage == River.FLOODED
		result[k] = stage
	end
	return result
end

-- Stages for `flooded` segments flooded from the spring and nothing else (a profile that only knows a count).
function River.fromCount(flooded: number, segments: number): { number }
	local result: { number } = {}
	for k = 1, segments do
		result[k] = if k <= flooded then River.FLOODED else 0
	end
	return result
end

-- The stage of each segment from the saved land of field F2: `cells` are the started cells (the cell number is the segment),
-- `steps[i]` the stages done of cells[i], `sites` how many cells are finished (a finished cell is flooded). A state without
-- steps counts its finished cells as flooded and the others as dry trenches. Feed the result to River.stages.
function River.fromLand(cells: { number }?, steps: { number }?, sites: number, segments: number): { number }
	local saved: { number } = {}
	for index, cell in cells or {} do
		if type(cell) == "number" and cell >= 1 and cell <= segments then
			saved[cell] = if steps ~= nil and type(steps[index]) == "number"
				then steps[index]
				else (if index <= sites then River.FLOODED else River.DRY)
		end
	end
	return River.stages(saved, segments)
end

-- Where the bought wheels stand. Wheels come one at a time and two form a pair side by side on one axle across the flow:
-- wheel 1 and 2 are the first pair, 3 and 4 the second, and so on. Pair j stands at a quarter (odd j) or three quarters (even
-- j) of a flooded segment, two pairs per segment, taking the flooded segments in turn. Each spot gives the course point
-- (x, z), the flow (tx, tz), the axle direction (nx, nz) and `side` (-1 first wheel of the pair, +1 second); none when no
-- segment is flooded.
export type WheelSpot = {
	x: number,
	z: number,
	tx: number,
	tz: number,
	nx: number,
	nz: number,
	side: number,
	pair: number,
}
function River.wheelSpots(course: Course, stages: { number }, count: number): { WheelSpot }
	local spots: { WheelSpot } = {}
	local flooded = River.flooded(stages)
	if flooded == 0 then
		return spots
	end
	for i = 1, count do
		local pair = (i + 1) // 2
		local k = ((pair - 1) // 2) % flooded + 1
		local first = course.samples[(k - 1) * course.perSegment + 1]
		local last = course.samples[k * course.perSegment + 1]
		local fraction = if pair % 2 == 1 then 0.25 else 0.75
		local at = River.at(course, first.arc + (last.arc - first.arc) * fraction)
		table.insert(spots, {
			x = at.x,
			z = at.z,
			tx = at.tx,
			tz = at.tz,
			nx = at.nx,
			nz = at.nz,
			side = if i % 2 == 1 then -1 else 1,
			pair = pair,
		})
	end
	return spots
end

-- Number of flooded segments.
function River.flooded(stages: { number }): number
	local n = 0
	for _, stage in stages do
		if stage ~= River.FLOODED then
			break
		end
		n += 1
	end
	return n
end

-- Segment k can be worked (shovel: dig, then flood) only when it is not finished and k - 1 is flooded.
function River.canWork(stages: { number }, k: number): boolean
	return k >= 1 and k <= #stages and stages[k] < River.FLOODED and (k == 1 or stages[k - 1] == River.FLOODED)
end

-- Wheels standing on the river: four on every flooded segment's axle, none elsewhere.
function River.wheelCount(stages: { number }, k: number): number
	return if stages[k] == River.FLOODED then River.WHEELS else 0
end

-- A bridge shows once its segment is flooded.
function River.bridgeVisible(stages: { number }, bridge: Bridge): boolean
	return stages[bridge.segment] == River.FLOODED
end

-- Terrain ------------------------------------------------------------------------------------------------------------

-- The cells of a plot of `cells` x `cells` cells of `cell` studs that belong to the river at `level`: 1 = the trench
-- (dry or flooded segments), 2 = the water (flooded segments). mask[ix][iz] = true, 1-based from the corner at
-- (-half, -half), like Meadow.mask. The banks follow the per-sample half-widths, so they wobble.
function River.mask(course: Course, stages: { number }, level: number, cells: number, cell: number): { { boolean } }
	local mask: { { boolean } } = table.create(cells)
	for ix = 1, cells do
		mask[ix] = table.create(cells, false)
	end
	local half = cells * cell / 2
	local per = course.perSegment
	for k = 1, course.segments do
		if stages[k] >= level then
			for i = (k - 1) * per + 1, k * per do
				local a, b = course.samples[i], course.samples[i + 1]
				local reach = math.max(a.minus, a.plus, b.minus, b.plus) + cell
				local firstX = math.max(1, math.floor((math.min(a.x, b.x) - reach + half) / cell) + 1)
				local lastX = math.min(cells, math.ceil((math.max(a.x, b.x) + reach + half) / cell))
				local firstZ = math.max(1, math.floor((math.min(a.z, b.z) - reach + half) / cell) + 1)
				local lastZ = math.min(cells, math.ceil((math.max(a.z, b.z) + reach + half) / cell))
				local dx, dz = b.x - a.x, b.z - a.z
				for ix = firstX, lastX do
					local px = (ix - 0.5) * cell - half
					for iz = firstZ, lastZ do
						if not mask[ix][iz] then
							local pz = (iz - 0.5) * cell - half
							local u = math.clamp(((px - a.x) * dx + (pz - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
							local cx, cz = a.x + dx * u, a.z + dz * u
							-- Which side of the centre line, and so which bank's half-width, blended along the span.
							local side = (px - cx) * (a.nx + (b.nx - a.nx) * u) + (pz - cz) * (a.nz + (b.nz - a.nz) * u)
							local bank = if side < 0
								then a.minus + (b.minus - a.minus) * u
								else a.plus + (b.plus - a.plus) * u
							mask[ix][iz] = math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2) <= bank
						end
					end
				end
			end
		end
	end
	return mask
end

-- Clearance helper for the site map: studs between the water of the whole course and the box { minX, maxX, minZ, maxZ }
-- (0 or less when they touch). The box distance is taken to the centre line, every 1 stud, minus the local half-width.
function River.gap(course: Course, box: { number }): number
	local best = math.huge
	for i = 1, #course.samples - 1 do
		local a, b = course.samples[i], course.samples[i + 1]
		local steps = math.max(1, math.ceil(b.arc - a.arc))
		for n = 0, steps do
			local u = n / steps
			local px, pz = a.x + (b.x - a.x) * u, a.z + (b.z - a.z) * u
			local dx = math.max(box[1] - px, 0, px - box[2])
			local dz = math.max(box[3] - pz, 0, pz - box[4])
			local half = math.max(a.minus + (b.minus - a.minus) * u, a.plus + (b.plus - a.plus) * u)
			best = math.min(best, math.sqrt(dx * dx + dz * dz) - half)
		end
	end
	return best
end

-- Foam strips (client only): FOAM_STRIPS per flooded segment drift downstream with FLOW_SPEED and sit side by side across the water.
-- `fade` is 1 in the middle of the segment and 0 at its ends, so a strip appears and vanishes without a jump.
River.FOAM_STRIPS = 3
River.FOAM_SPACING = 2

export type Foam = { x: number, z: number, tx: number, tz: number, fade: number }

function River.foam(course: Course, stages: { number }, now: number): { Foam }
	local strips: { Foam } = {}
	for k = 1, course.segments do
		if stages[k] ~= River.FLOODED then
			continue
		end
		local per = course.perSegment
		local from, to = course.samples[(k - 1) * per + 1].arc, course.samples[k * per + 1].arc
		local length = to - from
		for i = 0, River.FOAM_STRIPS - 1 do
			local phase = ((now * River.FLOW_SPEED + i * length / River.FOAM_STRIPS) % length) / length
			local at = River.at(course, from + phase * length)
			local side = (i - (River.FOAM_STRIPS - 1) / 2) * River.FOAM_SPACING
			table.insert(strips, {
				x = at.x + at.nx * side,
				z = at.z + at.nz * side,
				tx = at.tx,
				tz = at.tz,
				fade = math.min(1, phase * 5, (1 - phase) * 5),
			})
		end
	end
	return strips
end

return River
