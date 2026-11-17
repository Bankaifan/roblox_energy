--!strict
-- Metrics: counts the measurement points of a session, and reports only numbers.
return function(t, load)
	local Metrics = load("Core/Metrics")
	local metrics = Metrics.new(100)
	Metrics.shopOpened(metrics)
	Metrics.shopOpened(metrics)
	Metrics.storageBought(metrics)
	Metrics.purchased(metrics)
	Metrics.gridExpanded(metrics, 130)
	Metrics.gridExpanded(metrics, 200)
	local report = Metrics.report(metrics, 400)
	t.equal(report.sessionSeconds, 300, "session length runs from the start to the report")
	t.equal(report.firstExpansionSeconds, 30, "the first expansion is timed from the start, later ones are ignored")
	t.equal(report.shopOpens, 2, "two shop opens")
	t.equal(report.storageBought, 1, "one storage bought")
	t.equal(report.purchases, 1, "one purchase")

	local fresh = Metrics.new(0)
	t.equal(Metrics.report(fresh, 10).firstExpansionSeconds, nil, "no expansion yet, no time")
	t.equal(Metrics.report(fresh, -5).sessionSeconds, 0, "a clock that goes backwards reads as no time")
end
