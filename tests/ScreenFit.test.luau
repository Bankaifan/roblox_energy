--!strict
-- The UI scale factor of a viewport: 1 at the design size and above, shrinking with the smaller side, never below 0.5.
return function(t, load)
	local ScreenFit = load("Core/ScreenFit")
	t.equal(ScreenFit.factor(800, 500), 1, "the design size needs no scaling")
	t.equal(ScreenFit.factor(1920, 1080), 1, "a larger screen is clamped to 1")
	t.equal(ScreenFit.factor(400, 500), 0.5, "half the width halves the UI")
	t.truthy(math.abs(ScreenFit.factor(667, 375) - 0.75) < 1e-9, "a phone in landscape: the height limits")
	t.equal(ScreenFit.factor(200, 100), 0.5, "a tiny screen is clamped to 0.5")
end
