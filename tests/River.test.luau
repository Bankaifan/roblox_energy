--!strict
-- River course (land design v2, step 5): organic curve, seven segments, axle and four wheels per segment, dig stages,
-- terrain masks, bridges and the clearance to the site map.
return function(t, load)
	local Assets = load("Config/Assets")
	local PlotLayout = load("Core/PlotLayout")
	local River = load("Core/River")
	local river = Assets.river
	local tile, tiles = Assets.TILE, Assets.PLOT_TILES
	local half = Assets.PLOT_SIZE / 2
	local slots = 2 * Assets.PLOT_COLUMNS

	local function dot(ax: number, az: number, bx: number, bz: number): number
		return ax * bx + az * bz
	end

	-- Deterministic, and the plot slot changes the wobble.
	local one, again, other = River.course(river, 3), River.course(river, 3), River.course(river, 4)
	t.equal(#one.samples, #again.samples, "same sample count")
	local same, moved = true, false
	for i, s in one.samples do
		same = same and s.x == again.samples[i].x and s.z == again.samples[i].z and s.minus == again.samples[i].minus
		moved = moved or s.x ~= other.samples[i].x or s.z ~= other.samples[i].z
	end
	t.truthy(same, "the same seed gives the same course")
	t.truthy(moved, "another plot slot wobbles differently")
	t.equal(one.segments, river.segments, "seven segments")
	t.equal(one.segments, 7, "design: seven segments")

	for seed = 1, slots do
		local course = River.course(river, seed)
		local list = course.samples
		-- Spring and pond stay where the data puts them; the flow runs from the spring to the pond.
		t.equal(list[1].x, river.points[1][1], `slot {seed}: the spring stays put (x)`)
		t.equal(list[1].z, river.points[1][2], `slot {seed}: the spring stays put (z)`)
		t.truthy(math.abs(list[#list].x - river.points[#river.points][1]) < 1e-6, `slot {seed}: the pond stays put`)
		t.truthy(list[#list].x > list[1].x, `slot {seed}: the water runs from the spring to the pond`)
		-- The course is a curve: no turn above 30 degrees between samples, samples about PITCH studs apart.
		for i = 2, #list do
			local a, b = list[i - 1], list[i]
			local turn = math.deg(math.acos(math.clamp(dot(a.tx, a.tz, b.tx, b.tz), -1, 1)))
			t.truthy(turn <= 30, `slot {seed}: sample {i} turns {turn} degrees`)
			local step = b.arc - a.arc
			t.truthy(
				step > River.PITCH * 0.5 and step < River.PITCH * 1.5,
				`slot {seed}: sample {i} is {step} studs on`
			)
			t.truthy(math.abs(dot(b.tx, b.tz, b.nx, b.nz)) < 1e-9, `slot {seed}: the normal is across the flow`)
		end
		-- The course is organic: it is not the straight line between the points.
		local bent = 0
		for _, s in list do
			bent = math.max(bent, math.abs(s.z - (list[1].z + (s.x - list[1].x) * 0.2)))
		end
		t.truthy(bent > 2, `slot {seed}: the river is not straight`)
		-- Banks wobble within a stud and stay in the plot.
		for i, s in list do
			t.truthy(
				math.abs(s.minus - river.width / 2) <= River.BANK_WOBBLE + 1e-9,
				`slot {seed}: bank {i} within its wobble`
			)
			local left, right = River.banks(s)
			for _, p in { left, right } do
				t.truthy(math.abs(p[1]) < half and math.abs(p[2]) < half, `slot {seed}: bank {i} lies in the plot`)
			end
		end
		-- Seven segments of about the same length that tile the whole course.
		local total = 0
		for k = 1, course.segments do
			local seg = River.segment(course, k)
			total += seg.length
			t.truthy(
				math.abs(seg.length - course.length / course.segments) < 2,
				`slot {seed}: segment {k} is {seg.length} long`
			)
			t.equal(seg.first, (k - 1) * course.perSegment + 1, `slot {seed}: segment {k} starts where the last ends`)
			t.equal(seg.halves[1].last, seg.halves[2].first, `slot {seed}: the two halves meet`)
			t.equal(seg.halves[1].first, seg.first, "first half starts the segment")
			t.equal(seg.halves[2].last, seg.last, "second half ends the segment")

			-- One axle across the flow, from bank to bank, with four wheels in the plane of the flow.
			local axle = seg.axle
			local mid = River.at(course, (list[seg.first].arc + list[seg.last].arc) / 2)
			t.truthy(math.abs(axle.x - mid.x) < 1e-9 and math.abs(axle.z - mid.z) < 1e-9, "the axle is in the middle")
			local flowX, flowZ = -math.sin(axle.yaw), -math.cos(axle.yaw)
			t.truthy(math.abs(flowX - mid.tx) < 1e-9 and math.abs(flowZ - mid.tz) < 1e-9, "yaw is the flow direction")
			t.truthy(
				math.abs(dot(axle.axisX, axle.axisZ, flowX, flowZ)) < 1e-9,
				`slot {seed}: axle {k} is across the flow`
			)
			local spanX, spanZ = axle.to.x - axle.from.x, axle.to.z - axle.from.z
			t.truthy(math.abs(math.sqrt(spanX ^ 2 + spanZ ^ 2) - axle.length) < 1e-9, "axle length bank to bank")
			t.truthy(math.abs(axle.length - course.width) <= 2 * River.BANK_WOBBLE + 1e-9, "axle spans the water")
			t.truthy(math.abs(dot(spanX, spanZ, flowX, flowZ)) < 1e-9, "both bank ends lie across the flow")
			t.equal(#axle.wheels, 4, `segment {k} has four wheels`)
			local lowest, highest = math.huge, -math.huge
			for i, w in axle.wheels do
				t.equal(w.yaw, axle.yaw, "a wheel faces the flow")
				t.truthy(
					math.abs(dot(w.axisX, w.axisZ, flowX, flowZ)) < 1e-9,
					`slot {seed}: wheel {i} turns about a shaft across the flow`
				)
				-- On the axle line.
				local off = dot(w.x - axle.x, w.z - axle.z, flowX, flowZ)
				t.truthy(math.abs(off) < 1e-9, "wheel on the axle line")
				local along = dot(w.x - axle.x, w.z - axle.z, axle.axisX, axle.axisZ)
				lowest, highest = math.min(lowest, along - w.width / 2), math.max(highest, along + w.width / 2)
				if i > 1 then
					local p = axle.wheels[i - 1]
					local gap = math.sqrt((w.x - p.x) ^ 2 + (w.z - p.z) ^ 2) - w.width
					t.truthy(gap >= 0, "wheels do not overlap")
				end
				t.truthy(w.width <= 2.6, "a wheel is at most 2.6 studs wide")
			end
			t.truthy(lowest > -mid.minus and highest < mid.plus, `slot {seed}: four wheels fit between the banks`)
			t.truthy(math.abs(lowest + highest) < 1e-9, "the wheels are centred on the axle")
		end
		t.truthy(math.abs(total - course.length) < 1e-6, "segments cover the course")

		-- Banks keep clear of every cell of every field and of the furniture, with room to spare.
		local function check(box: { number }, name: string)
			local gap = River.gap(course, box)
			t.truthy(gap >= 1, `slot {seed}: {name} is {gap} studs from the water`)
		end
		for id, field in Assets.fields do
			if field.river ~= true then
				for n = 1, #field.cells do
					local c = PlotLayout.cellCentre(field, n, tile, tiles)
					local h = field.size * tile / 2
					check({ c.x - h, c.x + h, c.z - h, c.z + h }, `field {id} cell {n}`)
				end
			end
		end
		for name, piece in Assets.furniture do
			local w, d = piece.size / 2, (piece.depth or piece.size) / 2
			check({ piece.x - w, piece.x + w, piece.z - d, piece.z + d }, name)
		end
	end

	-- The clearance helper: positive away from the water, negative on it.
	local course = River.course(river, 1)
	local s5 = River.segment(course, 5).axle
	t.truthy(River.gap(course, { s5.x - 1, s5.x + 1, s5.z - 1, s5.z + 1 }) < 0, "a box in the water has no gap")
	t.truthy(River.gap(course, { -90, -80, 80, 90 }) > 50, "a far box has a large gap")

	-- Arc positions.
	t.equal(River.at(course, -5).arc, 0, "before the spring clamps to the spring")
	t.truthy(
		math.abs(River.at(course, 1e9).x - course.samples[#course.samples].x) < 1e-9,
		"after the pond clamps to the pond"
	)
	t.equal(River.segmentAt(course, 0), 1, "arc 0 is in segment 1")
	t.equal(River.segmentAt(course, course.length), 7, "the pond end is in segment 7")

	-- Bridges: two, across the water near the design x, in flooded-segment terms, clear of every axle.
	for seed = 1, slots do
		local c = River.course(river, seed)
		local bridges = River.bridges(c)
		t.equal(#bridges, 2, "two bridges")
		for i, b in bridges do
			t.truthy(math.abs(b.x - River.BRIDGE_X[i]) < 4, `slot {seed}: bridge {i} is near x {River.BRIDGE_X[i]}`)
			t.equal(b.parts, 5, "five plank parts")
			t.truthy(
				b.length > c.width + 2 * River.BRIDGE_OVERHANG - 1,
				"the bridge spans the water and lands on both banks"
			)
			t.truthy(
				math.abs(dot(b.axisX, b.axisZ, -math.sin(b.yaw), -math.cos(b.yaw))) < 1e-9,
				"planks run across the flow"
			)
			for k = 1, c.segments do
				local axle = River.segment(c, k).axle
				t.truthy(
					math.sqrt((axle.x - b.x) ^ 2 + (axle.z - b.z) ^ 2) >= 4,
					`slot {seed}: bridge {i} stands clear of axle {k}`
				)
			end
		end
		t.truthy(bridges[1].segment < bridges[2].segment, "the bridges follow the flow")
	end
	local bridges = River.bridges(course)

	-- Dig stages: the water comes from the spring, so only the next segment can be worked.
	local stages = River.stages(nil, 7)
	t.equal(River.flooded(stages), 0, "a fresh plot has no water")
	t.truthy(River.canWork(stages, 1), "the first segment can be dug")
	t.truthy(not River.canWork(stages, 2), "segment 2 waits for segment 1")
	stages[1] = River.DRY
	t.truthy(River.canWork(stages, 1), "a dry trench still waits for the second hold")
	t.truthy(not River.canWork(stages, 2), "a dry segment does not feed the next one")
	stages[1] = River.FLOODED
	t.truthy(River.canWork(stages, 2), "segment 2 opens when segment 1 is flooded")
	t.truthy(not River.canWork(stages, 1), "a flooded segment is finished")
	t.truthy(not River.canWork(stages, 0) and not River.canWork(stages, 8), "outside the river nothing can be worked")
	t.equal(River.wheelCount(stages, 1), 4, "a flooded segment has four wheels")
	t.equal(River.wheelCount(stages, 2), 0, "a segment without water has none")
	t.truthy(River.bridgeVisible(River.fromCount(2, 7), bridges[1]), "a bridge shows when its segment is flooded")
	t.truthy(not River.bridgeVisible(River.fromCount(1, 7), bridges[1]), "and not before")
	local fixed = River.stages({ 2, 2, 0, 2, 5, -3, 1.7 }, 7)
	t.equal(table.concat(fixed, ","), "2,2,0,1,1,0,1", "stages are clamped and water needs the spring side flooded")
	t.equal(table.concat(River.stages({ 2 }, 3), ","), "2,0,0", "missing segments are meadow")
	t.equal(River.flooded(River.fromCount(5, 7)), 5, "fromCount round-trips")
	local total = 0
	for k = 1, 7 do
		total += River.wheelCount(River.fromCount(7, 7), k)
	end
	t.equal(total, 28, "a full river carries 28 wheels")

	-- Terrain masks: dry trench cells for stage 1 and 2, water cells for stage 2 only; every one inside the plot,
	-- inside the band, and growing downstream with the flooded segments.
	local cell = 4
	local cells = Assets.PLOT_SIZE // cell
	local function count(mask): number
		local n = 0
		for ix = 1, cells do
			for iz = 1, cells do
				n += if mask[ix][iz] then 1 else 0
			end
		end
		return n
	end
	t.equal(count(River.mask(course, River.fromCount(0, 7), 1, cells, cell)), 0, "no digging, no trench")
	local previous = 0
	for flooded = 1, 7 do
		local water = River.mask(course, River.fromCount(flooded, 7), 2, cells, cell)
		local n = count(water)
		t.truthy(n > previous, `{flooded} flooded segments have more water than {flooded - 1}`)
		previous = n
		t.equal(
			count(River.mask(course, River.fromCount(flooded, 7), 1, cells, cell)),
			n,
			"flooded segments are also trench"
		)
	end
	local dry = River.mask(course, River.stages({ 1 }, 7), 1, cells, cell)
	t.truthy(count(dry) > 0, "a dry segment is a trench")
	t.equal(count(River.mask(course, River.stages({ 1 }, 7), 2, cells, cell)), 0, "a dry trench holds no water")
	for seed = 1, slots do
		local c = River.course(river, seed)
		local mask = River.mask(c, River.fromCount(7, 7), 2, cells, cell)
		local area = 0
		for ix = 1, cells do
			for iz = 1, cells do
				if mask[ix][iz] then
					area += 1
					local box = { (ix - 1) * cell - half, ix * cell - half, (iz - 1) * cell - half, iz * cell - half }
					t.truthy(
						box[1] >= -half and box[2] <= half and box[3] >= -half and box[4] <= half,
						"dug cell inside the plot"
					)
					for id, field in Assets.fields do
						if field.river ~= true then
							for n = 1, #field.cells do
								local ct = PlotLayout.cellCentre(field, n, tile, tiles)
								local h = field.size * tile / 2
								local over = box[1] < ct.x + h
									and box[2] > ct.x - h
									and box[3] < ct.z + h
									and box[4] > ct.z - h
								t.truthy(not over, `slot {seed}: river cell ({ix}, {iz}) overlaps field {id} cell {n}`)
							end
						end
					end
				end
			end
		end
		-- About 175 studs of 12-stud water: 2100 square studs, 131 cells of 16.
		t.truthy(area > 100 and area < 190, `slot {seed}: the river covers {area} cells`)
	end
	-- The stages from a saved land: steps say what is done, finished cells without steps are flooded, others dry.
	local function equal(a: { number }, b: { number }): boolean
		return table.concat(a, ",") == table.concat(b, ",")
	end
	t.truthy(equal(River.fromLand({ 1, 2, 3 }, { 2, 2, 1 }, 2, 7), { 2, 2, 1, 0, 0, 0, 0 }), "steps give the stages")
	t.truthy(equal(River.fromLand({ 1, 2 }, nil, 1, 7), { 2, 1, 0, 0, 0, 0, 0 }), "finished flooded, in work dry")
	t.truthy(equal(River.fromLand({ 2 }, { 2 }, 1, 7), { 0, 1, 0, 0, 0, 0, 0 }), "no water without the spring flooded")
	t.truthy(equal(River.fromLand(nil, nil, 0, 7), { 0, 0, 0, 0, 0, 0, 0 }), "nothing dug")

	-- Wheel pairs: two bought wheels make a pair side by side on the axle, across the flow, in flooded water only.
	local pairCourse = River.course(river, 1)
	t.equal(#River.wheelSpots(pairCourse, River.fromCount(0, 7), 4), 0, "no water, no wheels")
	local spots = River.wheelSpots(pairCourse, River.fromCount(2, 7), 5)
	t.equal(#spots, 5, "one spot per wheel")
	t.equal(spots[1].side, -1, "the first wheel of a pair is on the minus side")
	t.equal(spots[2].side, 1, "the second wheel is on the plus side")
	t.equal(spots[1].x, spots[2].x, "a pair shares its place on the river")
	t.truthy(spots[3].pair == 2 and spots[3].x ~= spots[1].x, "the second pair stands elsewhere")
	for _, spot in spots do
		t.truthy(math.abs(spot.nx * spot.tx + spot.nz * spot.tz) < 1e-6, "the axle is across the flow")
		local depth = River.gap(pairCourse, { spot.x, spot.x, spot.z, spot.z })
		t.truthy(depth < 0, "the pair stands in the water")
	end

	-- Foam: three strips per flooded segment only, inside the water, fading at the segment ends.
	local foamCourse = River.course(river, 1)
	t.equal(#River.foam(foamCourse, River.fromCount(0, 7), 5), 0, "no water, no foam")
	local strips = River.foam(foamCourse, River.fromCount(2, 7), 5)
	t.equal(#strips, 2 * River.FOAM_STRIPS, "three strips per flooded segment")
	for _, strip in strips do
		t.truthy(River.gap(foamCourse, { strip.x, strip.x, strip.z, strip.z }) < 0, "foam floats on the water")
		t.truthy(strip.fade >= 0 and strip.fade <= 1, "fade is a fraction")
	end
	local later = River.foam(foamCourse, River.fromCount(2, 7), 6)
	t.truthy(later[1].x ~= strips[1].x or later[1].z ~= strips[1].z, "foam drifts with time")
end
