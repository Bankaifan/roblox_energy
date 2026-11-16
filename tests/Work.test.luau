--!strict
-- Hold timing check (issue 107): only a full hold on the target it began on counts.
return function(t, load)
	local Work = load("Core/Work")

	local session = Work.new()
	Work.begin(session, "market", 10)
	t.equal(Work.finish(session, "market", 11, 1), true, "a full hold is accepted")

	Work.begin(session, "market", 10)
	t.equal(Work.finish(session, "market", 10.9, 1), true, "exactly 0.9 x hold is accepted")

	Work.begin(session, "market", 10)
	t.equal(Work.finish(session, "market", 10.5, 1), false, "finish before 0.9 x hold is rejected")

	Work.begin(session, "market", 10)
	t.equal(Work.finish(session, "container", 12, 1), false, "finish for another target is rejected")

	t.equal(Work.finish(Work.new(), "market", 12, 1), false, "finish without begin is rejected")

	Work.begin(session, "market", 10)
	t.equal(Work.finish(session, "market", 11, 1), true, "a hold works again after a rejected one")
	t.equal(Work.finish(session, "market", 12, 1), false, "a finished hold cannot be finished twice")

	Work.begin(session, "market", 10)
	Work.begin(session, "container", 20)
	t.equal(Work.finish(session, "market", 22, 1), false, "a newer begin replaces the older hold")
end
