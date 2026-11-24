--!strict
-- The ground outline of Neon Plants: one pattern per plant, every bar inside the footprint.
return function(t, load)
	local GlowPattern = load("Core/GlowPattern")
	local expected = { [1] = "frame", [2] = "ring", [3] = "frame", [4] = "rotor", [5] = "frame", [6] = "rotor" }
	for plantId, kind in expected do
		t.equal(GlowPattern.kind(plantId), kind, `plant {plantId}: {kind}`)
	end
	t.equal(GlowPattern.kind(99), "ring", "an unknown plant gets the ring")

	t.equal(#GlowPattern.bars("frame", 20, 10), 4, "a frame is four bars")
	t.equal(#GlowPattern.bars("ring", 20, 20), GlowPattern.RING_SEGMENTS, "a ring is its segments")
	t.equal(#GlowPattern.bars("rotor", 20, 20), 4, "three blades and a hub")

	-- Every bar's centre lies inside the footprint, and the frame hugs its edges.
	for _, kind in { "frame", "ring", "rotor" } do
		for _, bar in GlowPattern.bars(kind, 24, 16) do
			t.truthy(math.abs(bar.x) <= 12 and math.abs(bar.z) <= 8, `{kind}: a bar inside the footprint`)
		end
	end
	local top = GlowPattern.bars("frame", 24, 16)[1]
	t.truthy(math.abs(top.z + 8 - GlowPattern.THICK / 2) < 1e-9, "the frame touches the edge")
	t.equal(top.sx, 24, "the top bar spans the width")

	-- The three blades are 120 degrees apart and one lies on the z axis.
	local blades = GlowPattern.bars("rotor", 20, 20)
	t.truthy(math.abs(blades[1].x) < 1e-9 and blades[1].z > 0, "the first blade lies on the z axis")
	t.truthy(
		math.abs(blades[2].x * blades[3].x) > 0 and blades[2].x * blades[3].x < 0,
		"the others lean left and right"
	)

	local w, d = GlowPattern.footprint("rotor", 57.3, 8.7)
	t.equal(w, 14, "a big rotor star is capped")
	t.equal(d, 14, "and square")
	w, d = GlowPattern.footprint("rotor", 8, 2)
	t.equal(w, 8, "a small rotor keeps its span")
	w, d = GlowPattern.footprint("frame", 5, 0.5)
	t.truthy(w == 8 and d == 5, "a frame lies 1.5 studs outside the box, which has a floor of 2")
	w = GlowPattern.footprint("rotor", 8, 2, 4.5)
	t.equal(w, 4.5, "a star stays inside the limit")
end
