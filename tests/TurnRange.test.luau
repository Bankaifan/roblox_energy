--!strict
-- Turning range: rotors and water wheels move only within 150 studs of the camera (issue 113).
return function(t, load)
	local TurnRange = load("Core/TurnRange")

	t.equal(TurnRange.RANGE, 150, "the turning range is 150 studs")
	t.truthy(TurnRange.within(0, 0, 0, 0, 0, 0, 150), "the eye itself is in range")
	t.truthy(TurnRange.within(150, 0, 0, 0, 0, 0, 150), "a point exactly 150 studs away is in range")
	t.truthy(not TurnRange.within(150.5, 0, 0, 0, 0, 0, 150), "a point beyond 150 studs is out of range")
	t.truthy(TurnRange.within(100, 100, 0, 0, 0, 0, 150), "a diagonal point 141 studs away is in range")
	t.truthy(not TurnRange.within(100, 100, 100, 0, 0, 0, 150), "a diagonal point 173 studs away is out of range")
	t.truthy(TurnRange.within(10, 20, 30, 10, 20, 30 + 150, 150), "the range counts in all three axes")
	t.truthy(TurnRange.turns(true, 5000, 0, 0, 0, 0, 0, 150), "a model on my own plot turns at any distance")
	t.truthy(not TurnRange.turns(false, 5000, 0, 0, 0, 0, 0, 150), "another plot's model stays out of range")
	t.truthy(TurnRange.turns(false, 10, 0, 0, 0, 0, 0, 150), "another plot's model in range turns")
end
