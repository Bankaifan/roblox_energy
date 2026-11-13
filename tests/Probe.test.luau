--!strict
-- The runner (Lune or Studio) passes `t` and `load`. The file itself is identical in both.
return function(t, load)
	local Probe = load("Core/Probe")
	t.equal(Probe.add(2, 3), 5, "add")
end
