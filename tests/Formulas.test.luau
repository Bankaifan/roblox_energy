--!strict
-- Formulas (Bauplan section 2): expected income per plant type, factors, costs, storage, prestige.
return function(t, load)
	local Formulas = load("Core/Formulas")
	local Phases = load("Config/Phases")
	local Weather = load("Config/Weather")
	local Prestige = load("Config/Prestige")

	local function near(actual: number, expected: number, tolerance: number, label: string)
		t.truthy(math.abs(actual - expected) < tolerance, `{label}: expected {expected}, got {actual}`)
	end

	-- Expected values per unit of nominal power, Coins per second (Bauplan: 0,382 / 1,151 / 1,129, rounded to 3 digits)
	near(Formulas.expectedIncome("Solar", Phases, Weather), 0.382, 0.0005, "solar expected income")
	near(Formulas.expectedIncome("Wind", Phases, Weather), 1.151, 0.0005, "wind expected income")
	near(Formulas.expectedIncome("Grundlast", Phases, Weather), 1.129, 0.0005, "base load expected income")

	-- Factors: Faktor_solar = Phase.solar × Wetter.solar, Faktor_wind = Wetter.wind, Faktor_grund = 1
	local noon, evening = Phases[2], Phases[3]
	local sunny, cloudy, storm = Weather[1], Weather[2], Weather[4]
	near(Formulas.factor("Solar", noon, sunny), 1.0, 1e-9, "solar at noon, sunny")
	near(Formulas.factor("Solar", evening, cloudy), 0.15, 1e-9, "solar in the evening, cloudy")
	near(Formulas.factor("Wind", noon, sunny), 0.6, 1e-9, "wind ignores the phase")
	near(Formulas.factor("Grundlast", evening, storm), 1.0, 1e-9, "base load is always 1")

	-- Price: Phase.preis × Wetter.preis × Markt
	near(Formulas.price(evening, storm, 1.0), 2.16, 1e-9, "evening price in a storm")
	near(Formulas.price(noon, sunny, 1.1), 0.77, 1e-9, "noon price with market 1.1")

	-- Production: Basis × Anzahl × M × Faktor. Milestones at 10, 25, 50, 100, 150, 200 pieces
	t.equal(Formulas.milestones(9), 0, "no milestone below 10")
	t.equal(Formulas.milestones(25), 2, "two milestones at 25 pieces")
	t.equal(Formulas.milestones(200), 6, "six milestones at 200 pieces")
	t.equal(Formulas.nextMilestone(9), 10, "the first milestone is at 10")
	t.equal(Formulas.nextMilestone(10), 25, "at a threshold the next one counts")
	t.equal(Formulas.nextMilestone(200), nil, "no milestone after 200")
	local hits = Formulas.reachedMilestones({ 9, 24, 5 }, { 10, 50, 5 })
	t.equal(#hits, 3, "10 for plant 1, 25 and 50 for plant 2")
	t.equal(hits[1].plant, 1, "plant order")
	t.equal(hits[3].units, 50, "the threshold in units")
	t.equal(hits[3].milestone, 3, "the milestone number")
	t.equal(#Formulas.reachedMilestones({ 10 }, { 10 }), 0, "no change, no milestone")
	t.equal(#Formulas.reachedMilestones({ 0 }, { 0 }), 0, "a start kit below 10 fires nothing")
	near(Formulas.plantMultiplier(25, 2, 2), 8, 1e-9, "two milestones and one node doubling")
	near(Formulas.plantMultiplier(25, 2.5, 1), 6.25, 1e-9, "P7 gives 2.5 per milestone")
	near(Formulas.globalMultiplier(1, 1.25), 2, 1e-9, "grid level 1 with reinforcement I")
	near(Formulas.production(1300, 2, 1, 1), 2600, 1e-9, "two wind turbines at factor 1")

	-- Cost: Basiskosten × 1,15^Anzahl
	near(Formulas.cost(15, 0), 15, 1e-9, "first balcony module costs its base price")
	near(Formulas.cost(1100, 1), 1265, 1e-6, "second rooftop solar costs 1.15 times the base")

	-- Storage: Sekunden_Stufe × Mittagserzeugung
	near(Formulas.storageCapacity(1, 100), 4500, 1e-9, "stage 1 holds 45 s of midday output")
	near(Formulas.storageCapacity(4, 100), 22500, 1e-9, "stage 4 holds 225 s of midday output")
	near(Formulas.storageCapacity(0, 100), 0, 1e-9, "no storage at stage 0")
	-- Mega Battery: the capacity times 1.5 (67.5, 135, 225, 337.5 seconds of sun); a missing factor is 1.
	for stage, seconds in { 67.5, 135, 225, 337.5 } do
		near(Formulas.storageCapacity(stage, 100, 1.5), seconds * 100, 1e-9, `Mega Battery at stage {stage}`)
	end
	near(Formulas.storageCapacity(2, 100, nil), 9000, 1e-9, "no factor: the plain capacity")
	near(Formulas.storageCapacity(0, 100, 1.5), 0, 1e-9, "no storage stays no storage")

	-- Prestige: each threshold is 10 Mio. × 6^(level − 1). Bauplan rounds the table, so allow 2 %.
	for _, level in Prestige do
		near(Formulas.prestigeThreshold(level.level) / level.requiredRevenue, 1, 0.02, `threshold level {level.level}`)
	end
	t.equal(Formulas.prestigeSparks(0), 8, "first expansion gives 8 sparks")
	t.equal(Formulas.prestigeSparks(9), 35, "tenth expansion gives 35 sparks")
	local sparks = 0
	for current = 0, 9 do
		sparks += Formulas.prestigeSparks(current)
	end
	t.equal(sparks, 215, "expansions 1 to 10 give the Bauplan total of 215 sparks")
	for _, level in Prestige do
		t.equal(
			Formulas.prestigeSparks(level.level - 1),
			level.sparks,
			`formula and config agree at level {level.level}`
		)
	end
end
