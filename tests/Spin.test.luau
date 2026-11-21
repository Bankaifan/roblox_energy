--!strict
-- Water wheel spin: the flow direction of the river and the sense that moves the wheel bottom with the water.
return function(t, load)
	local Spin = load("Core/Spin")
	local Assets = load("Config/Assets")

	local fx, fz = Spin.flowAt({ { 0, 0 }, { 10, 0 }, { 10, 10 } }, 3, 2)
	t.truthy(math.abs(fx - 1) < 1e-9 and math.abs(fz) < 1e-9, "on the first leg the flow runs along +x")
	fx, fz = Spin.flowAt({ { 0, 0 }, { 10, 0 }, { 10, 10 } }, 11, 7)
	t.truthy(math.abs(fx) < 1e-9 and math.abs(fz - 1) < 1e-9, "on the second leg the flow runs along +z")
	fx, fz = Spin.flowAt({ { 0, 0 }, { 10, 0 } }, -50, 4)
	t.truthy(math.abs(fx - 1) < 1e-9, "beyond the end the nearest leg decides")
	t.equal(select(1, Spin.flowAt({ { 1, 1 } }, 0, 0)), 1, "a course without a leg falls back to +x")

	-- Axle along x, water flowing along +x: the bottom moves with the water when the wheel turns about -x... checked
	-- against the rule v = sense x (axis x down): axis (1,0,0) gives v = (0, 0, -1) for sense +1, so +z flow needs -1.
	t.equal(Spin.sense(1, 0, 0, 1), -1, "axle along x, flow along +z: turn about -x")
	t.equal(Spin.sense(1, 0, 0, -1), 1, "axle along x, flow along -z: turn about +x")
	t.equal(Spin.sense(0, 1, 1, 0), 1, "axle along z, flow along +x: turn about +z")
	t.equal(Spin.sense(0, 1, -1, 0), -1, "axle along z, flow against +x: turn about -z")
	t.equal(Spin.sense(0, 0, 1, 0), 1, "a vertical axle turns the default way")

	-- The river of the plot: every point is a leg, the flow is mostly along +x.
	local px, pz = Spin.flowAt(Assets.river.points, 0, -8)
	t.truthy(px > 0.5 and px * px + pz * pz > 0.99, "the plot river flows towards +x as a unit vector")
	-- A hub wins over the mean of the parts: a blade a little shorter than the others must not move the centre.	local mean = { 1, 2, 3 }	t.equal(Spin.centre({ 4, 5, 6 }, mean)[1], 4, "the hub is the centre")	t.equal(Spin.centre(nil, mean), mean, "without a hub the mean stays")
end
