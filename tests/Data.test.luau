--!strict
-- Data (Bauplan.md, "Datenmodell, Version 1" and "Offline-Ertrag"): template, round trip, defaults, migrations,
-- and the offline income after a save and a load.
return function(t, load)
	local Data = load("Core/Data")
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Steps = load("Migrations/Steps")
	local Config = {}
	Config.plants = load("Config/Plants")
	Config.upgrades = load("Config/Upgrades")
	Config.prestige = load("Config/Prestige")
	Config.phases = load("Config/Phases")
	Config.weathers = load("Config/Weather")
	Config.effects = load("Config/Effects")

	local function same(a: any, b: any): boolean
		if type(a) ~= "table" or type(b) ~= "table" then
			return a == b
		end
		for key, item in a do
			if not same(item, b[key]) then
				return false
			end
		end
		for key in b do
			if a[key] == nil then
				return false
			end
		end
		return true
	end

	local function countsOnly(value: any): boolean
		if type(value) == "number" then
			return value == value and value >= 0 and value < math.huge
		end
		if type(value) == "table" then
			for _, item in value do
				if not countsOnly(item) then
					return false
				end
			end
		end
		return true
	end

	local function near(actual: number, expected: number, label: string)
		local tolerance = 1e-9 * math.max(1, math.abs(expected))
		t.truthy(math.abs(actual - expected) <= tolerance, `{label}: expected {expected}, got {actual}`)
	end

	-- Save and load as the server will: GameCore state -> profile -> migrated profile -> GameCore state.
	local function reload(state: { [string]: any }): { [string]: any }
		local loaded = Data.migrate(Data.fromState(state), Steps)
		return Data.toState(loaded)
	end

	-- A run with these plant counts and permanent nodes, saved and loaded.
	local function savedRun(plants: { number }, pnodes: { [string]: boolean }): { [string]: any }
		local state = Data.toState(Data.template())
		state.plants = plants
		state.pnodes = pnodes
		return reload(state)
	end

	-- The template: version 11, the default profile of Bauplan section 5.
	local template = Data.template()
	t.equal(template.v, 11, "the template is version 11")
	t.equal(template.tutorial, 1, "a new profile starts the tutorial at its first step")
	t.equal(template.tutorialDone, false, "a new profile has not finished the tutorial")
	t.equal(template.land.tools.scythe, true, "the scythe is owned from the start")
	t.equal(template.land.market, false, "the market is not yet opened")
	t.equal(next(template.passes), nil, "no pass owned by default")
	t.equal(next(template.paid), nil, "no pass yield paid by default")
	t.equal(#template.boosters, 0, "the booster queue starts empty")
	t.equal(template.daily.skips, 0, "no Time Skip used by default")
	t.equal(template.daily.turboDay, 0, "no free Turbo taken by default")
	t.equal(#template.plants, 6, "six plants")
	t.equal(template.storage.mode, "auto", "storage starts in auto")
	t.equal(template.settings.lang, "auto", "the language follows the player")
	t.equal(template.grants, nil, "the version 1 grants table is gone")
	template.coins = 5
	t.equal(Data.template().coins, 0, "every call returns a new template")

	-- Round trip: a run with every saved kind of field comes back exactly.
	local run = Data.template()
	run.coins = 1234.5
	run.runEarned = 98765.25
	run.lifetimeEarned = 500000
	run.level = 2
	run.sparks = 8
	run.sparksSpent = 3
	run.plants = { 5, 2, 0, 1, 0, 0 }
	run.built = { true, true, false, true, false, false }
	run.permanent = { 3, 0, 0, 0, 0, 0 }
	run.nodes = { U01 = true, U12 = true }
	run.pnodes = { P1 = true, P2 = true }
	run.storage = { charge = 40.5, mode = "charge" }
	run.rules = { charge = { th = 0.7, on = true }, sell = { th = 1.2, on = false } }
	run.lastSeen = 1700000000
	run.playSeconds = 3600
	run.sessions = 4
	run.firstJoin = 1690000000
	run.purchases = { "receipt-1", "receipt-2" }
	run.passes = { founder = true, premium = true }
	run.boosters = { { kind = "turbo", left = 900 }, { kind = "sunshine", left = 600 } }
	run.daily = { day = 20000, skips = 2, turboDay = 19999 }
	run.cosmetics = { [1] = "gold" }
	run.settings = { lang = "de", sfx = false, music = true }
	run.tutorial = 3
	run.tutorialDone = true
	run.land = {
		sites = { 4, 7, 0, 1, 0, 0 },
		cells = { { 5, 1, 24, 2 }, { 1, 2, 3, 4, 5, 6, 7 }, { 3 }, { 6 }, {}, {} },
		steps = { { 1, 1, 1, 1 }, { 2, 2, 2, 2, 2, 2, 2 }, { 1 }, { 2 }, {}, {} },
		aligned = { 24, 5 },
		tools = { scythe = true, shovel = true },
		container = true,
		wired = false,
		market = true,
	}
	local state = Data.toState(run)
	local loaded, reason = Data.migrate(Data.fromState(state, run), Steps)
	t.equal(reason, nil, "a current profile loads")
	t.truthy(same(loaded, run), "the saved profile comes back exactly")
	t.truthy(same(Data.toState(loaded), state), "the run comes back exactly")
	t.truthy(same(state.land, run.land), "land is part of the run state")
	t.truthy(same(Data.fromState(state).land, run.land), "land survives fromState")
	local legacy = Data.toState(Data.migrate({ v = 3, land = { sites = { 3, 0, 0, 0, 0, 0 } } }, Steps))
	t.truthy(same(legacy.land.cells[1], { 1, 2, 3 }), "a profile with only a count gets the first cells")
	local messy = Data.toState(
		Data.migrate({ v = 3, land = { sites = { 3, 0, 0, 0, 0, 0 }, cells = { { 9, 9, 99, 4 } } } }, Steps)
	)
	t.truthy(same(messy.land.cells[1], { 9, 4, 1 }), "repeated or foreign cells are dropped and the count is kept")
	local junk = Data.toState(
		Data.migrate(
			{ v = 7, land = { sites = { 2, 0, 0, 0, 0, 0 }, cells = { { 4, 6 } }, aligned = { 6, 6, 9, "x" } } },
			Steps
		)
	)
	t.truthy(same(junk.land.aligned, { 6 }), "aligned keeps prepared cells once and drops the rest")
	state.land.sites[1] = 5
	t.equal(run.land.sites[1], 4, "toState copies the land")

	-- Unknown fields are dropped; missing fields and wrongly typed values get their defaults.
	local partial =
		{ v = 1, coins = 50, plants = { 3 }, bogus = true, storage = { mode = "sell" }, settings = { lang = 7 } }
	local filled = Data.migrate(partial, Steps)
	t.equal(filled.coins, 50, "a known field is kept")
	t.equal(filled.bogus, nil, "an unknown field is dropped")
	t.equal(filled.level, 0, "a missing field comes from the template")
	t.equal(filled.plants[1], 3, "a given plant count is kept")
	t.equal(filled.plants[2], 0, "a missing plant count is 0")
	t.equal(filled.storage.mode, "sell", "a given nested field is kept")
	t.equal(filled.storage.charge, 0, "a missing nested field comes from the template")
	t.equal(filled.settings.lang, "auto", "a value of the wrong type gets the default")
	t.equal(filled.settings.sfx, true, "a missing setting is on")

	-- Nothing negative, NaN or infinite survives a load.
	local broken = Data.template()
	broken.coins = -5
	broken.runEarned = 0 / 0
	broken.lifetimeEarned = math.huge
	broken.plants = { -1, 0 / 0, 2, 0, 0, 0 }
	broken.storage = { charge = -3, mode = "charge" }
	broken.rules = { charge = { th = 0 / 0, on = true } }
	broken.lastSeen = -1
	local cleaned = Data.migrate(broken, Steps)
	t.truthy(countsOnly(cleaned), "no negative, NaN or infinite number after a load")
	t.equal(cleaned.coins, 0, "negative coins become 0")
	t.equal(cleaned.plants[1], 0, "a negative plant count becomes 0")
	t.equal(cleaned.plants[3], 2, "a valid plant count is kept")
	t.equal(cleaned.rules.charge, nil, "a rule with a NaN threshold is dropped")

	-- A rule is saved under its id; one that is not charge or sell is dropped.
	local sellState = Data.toState(Data.template())
	sellState.rules = { sell = { th = 1.5, on = true }, bogus = { th = 1, on = true } }
	local sellBack = Data.toState(Data.migrate(Data.fromState(sellState), Steps))
	t.truthy(same(sellBack.rules.sell, { th = 1.5, on = true }), "the sell rule comes back exactly")
	t.equal(sellBack.rules.bogus, nil, "an unknown rule id is dropped")
	t.equal(sellBack.rules.charge, nil, "a rule never set stays unset")

	-- Version 3 -> 4: the slots become one rule per id, thresholds clamped into the range of their rule.
	local slotted = {
		v = 3,
		rules = {
			["1"] = { id = "charge", th = 0.5, on = false },
			["2"] = { id = "sell", th = 1.2, on = true },
			["3"] = { id = "charge", th = 0.8, on = true },
		},
	}
	local migrated = Data.migrate(slotted, Steps)
	t.equal(migrated.v, 11, "the profile is version 11 afterwards")
	t.truthy(same(migrated.rules.charge, { th = 0.8, on = true }), "of two charge slots the switched-on one wins")
	t.truthy(same(migrated.rules.sell, { th = 1.2, on = true }), "the sell slot becomes the sell rule")
	t.equal(migrated.rules["1"], nil, "no slot key is left")
	t.equal(slotted.rules["1"].id, "charge", "the input profile is not changed")
	local clamped = Data.migrate({
		v = 3,
		rules = {
			["1"] = { id = "charge", th = 1.4, on = true },
			["2"] = { id = "sell", th = 0.5, on = false },
			["3"] = { id = "other", th = 1, on = true },
		},
	}, Steps)
	t.equal(clamped.rules.charge.th, 1, "a charge threshold above 1,0 is clamped to 1,0")
	t.equal(clamped.rules.sell.th, 1, "a sell threshold below 1,0 is clamped to 1,0")
	t.equal(clamped.rules.sell.on, false, "the switch is kept")
	t.equal(clamped.rules.other, nil, "an unknown rule id is dropped")
	t.truthy(same(Data.migrate({ v = 3 }, Steps).rules, {}), "a profile without rules gets none")

	-- Version 6 -> 7: a profile gets paint 0; a saved colour 1 to 6 stays, anything else is 0; spark items are kept.
	local paint5 = Data.migrate({ v = 5, pnodes = { S1 = true, P2 = true } }, Steps)
	t.equal(paint5.paint, 0, "a version 5 profile gets no colour")
	t.truthy(paint5.pnodes.S1 == true and paint5.pnodes.P2 == true, "spark items are kept in pnodes")
	local owned = Data.migrate({ v = 8, passes = { premium = true, smart_hub = true } }, Steps)
	t.equal(next(owned.passes), nil, "saved pass flags are dropped by the 8 to 9 migration")
	t.equal(owned.v, 11, "the pass fixture ends at version 11")
	-- Version 9 -> 10: a profile gets sparksBought 0; a saved count stays, a bad one is 0, and it is not part of the run.
	t.equal(Data.migrate({ v = 9, sparks = 4 }, Steps).sparksBought, 0, "a version 9 profile has bought no sparks")
	t.equal(Data.migrate({ v = 9, sparksBought = 15 }, Steps).sparksBought, 15, "a saved count of bought sparks stays")
	t.equal(Data.migrate({ v = 9, sparksBought = -3 }, Steps).sparksBought, 0, "a negative count is dropped")
	t.equal(Data.toState(Data.template()).sparksBought, nil, "bought sparks are not a run field")
	-- Version 10 -> 11 (issue 252): permanent plants start at 0; a type the saved run holds counts as built; a saved count
	-- stays, a bad one is dropped; the flags are not part of the run, but sync sets a type built when the run holds a plant.
	local v10 = Data.migrate({ v = 10, plants = { 3, 0, 2, 0, 0, 0 }, permanent = { 2, 99, -1, "x" } }, Steps)
	t.equal(v10.v, 11, "a version 10 profile is lifted to version 11")
	t.truthy(same(v10.permanent, { 2, 99, 0, 0, 0, 0 }), "saved permanent plants stay, bad ones are 0")
	t.truthy(same(v10.built, { true, false, true, false, false, false }), "the types of the saved run count as built")
	t.truthy(same(Data.migrate({ v = 10 }, Steps).permanent, { 0, 0, 0, 0, 0, 0 }), "no permanent plants before")
	t.truthy(same(Data.migrate({ v = 10 }, Steps).built, Data.template().built), "nothing built in an empty profile")
	t.equal(Data.toState(v10).permanent, nil, "permanent plants are not a run field")
	local synced = Data.template()
	synced.built[2] = true
	local running = Data.toState(synced)
	running.plants = { 0, 0, 0, 1, 0, 0 }
	t.truthy(
		same(Data.fromState(running, synced).built, { false, true, false, true, false, false }),
		"a built type stays built"
	)
	local noBase = Data.fromState(running, { v = 11 })
	t.truthy(
		same(noBase.built, { false, false, false, true, false, false }),
		"a base without flags gets them from the run"
	)
	t.equal(Data.migrate({ v = 6, paint = 4 }, Steps).paint, 4, "a saved colour stays")
	t.equal(Data.migrate({ v = 6, paint = 9 }, Steps).paint, 0, "a colour out of range is dropped")
	t.equal(Data.migrate({ v = 6, paint = 2.5 }, Steps).paint, 0, "a fractional colour is dropped")
	t.equal(Data.toState(Data.migrate({ v = 6, paint = 4 }, Steps)).paint, 4, "paint is part of the run state")

	-- A profile of a newer version, or without a version, is rejected.
	local newer = Data.template()
	newer.v = 12
	local rejected, rejectedReason = Data.migrate(newer, Steps)
	t.equal(rejected, nil, "a profile of a newer version is rejected")
	t.equal(rejectedReason, "newer version", "the reason says newer version")
	local unversioned = Data.migrate({ coins = 5 }, Steps)
	t.equal(unversioned, nil, "a profile without a version is rejected")

	-- A migration step: version 0 stored the coins as "money". Step 0 renames it; the rest comes from the template.
	local old = { v = 0, money = 50 }
	local example = {
		[0] = function(profile)
			profile.coins = profile.money
			profile.money = nil
			return profile
		end,
		[1] = Steps[1],
		[2] = Steps[2],
		[3] = Steps[3],
		[4] = Steps[4],
		[5] = Steps[5],
		[6] = Steps[6],
		[7] = Steps[7],
		[8] = Steps[8],
		[9] = Steps[9],
		[10] = Steps[10],
	}
	local upgraded = Data.migrate(old, example)
	t.equal(upgraded.v, 11, "the profile is the current version afterwards")
	t.equal(upgraded.coins, 50, "step 0 to 1 renames the field")
	t.equal(upgraded.money, nil, "the old field is gone")
	t.equal(upgraded.plants[1], 0, "fields new in version 2 come from the template")
	t.equal(old.money, 50, "the input profile is not changed")
	local stranded, strandedReason = Data.migrate(old, {})
	t.equal(stranded, nil, "without a step the load fails")
	t.equal(strandedReason, "no migration from version 0", "the reason names the version")

	-- Migration 1 to 2: the granted founder pass, the Time Skip counter and the empty booster queue come from the
	-- version 1 grants; grants itself is gone.
	local v1 = {
		v = 1,
		coins = 10,
		grants = { founder = true, boostSeconds = 0, skipDay = 20000, skipCount = 2 },
	}
	local v2 = Data.migrate(v1, Steps)
	t.equal(v2.v, 11, "a version 1 profile loads as the current version")
	t.equal(v2.passes.founder, nil, "a founder grant is no saved pass (migration 8 to 9 drops it)")
	t.equal(v2.daily.day, 20000, "the Time Skip day is kept")
	t.equal(v2.daily.skips, 2, "the Time Skip count is kept")
	t.equal(#v2.boosters, 0, "the booster queue starts empty")
	t.equal(v2.grants, nil, "grants is gone")
	local v1none = Data.migrate({ v = 1 }, Steps)
	t.equal(next(v1none.passes), nil, "a version 1 profile without a founder grant owns no pass")

	-- Migration 2 to 3: a profile that has earned coins gets the old game's land; a fresh one gets the template.
	local old2 = { v = 2, coins = 10, lifetimeEarned = 50, nodes = { U21 = true } }
	local v3 = Data.migrate(old2, Steps)
	t.equal(v3.v, 11, "a version 2 profile loads as the current version")
	t.truthy(same(v3.land.sites, { 4, 4, 4, 4, 4, 4 }), "the first row of every field is prepared")
	t.equal(v3.land.tools.shovel, true, "the tools are owned")
	t.equal(v3.land.tools.pliers, true, "the cable pliers are owned")
	t.equal(v3.land.tools.rails, nil, "the mounting rails are not owned")
	t.equal(v3.land.market, true, "the market is open")
	t.equal(v3.land.container, true, "the container is owned")
	t.equal(v3.land.wired, true, "U21 owned means wired")
	t.equal(old2.land, nil, "the input profile is not changed")
	local unwired = Data.migrate({ v = 2, lifetimeEarned = 1, nodes = {} }, Steps)
	t.equal(unwired.land.wired, false, "without U21 the board is not wired")
	local fresh = Data.migrate({ v = 2, coins = 3 }, Steps)
	t.truthy(same(fresh.land, Data.template().land), "a fresh version 2 profile gets the template land")

	-- Migration 5 to 6: the tutorial starts at its first step; a profile that has earned coins has it done.
	local newTutorial = Data.migrate({ v = 5, coins = 0, lifetimeEarned = 0, tutorial = 0 }, Steps)
	t.equal(newTutorial.tutorial, 1, "a new profile starts the tutorial at step 1")
	t.equal(newTutorial.tutorialDone, false, "a new profile still gets the tutorial")
	local earned = Data.migrate({ v = 5, lifetimeEarned = 50, tutorial = 0 }, Steps)
	t.equal(earned.tutorial, 1, "a profile that has earned coins keeps step 1")
	t.equal(earned.tutorialDone, true, "a profile that has earned coins never sees the tutorial")

	-- A broken land is repaired: counts clamp to the field, unknown tools go, the scythe stays, flags are booleans.
	local brokenLand = Data.template()
	brokenLand.land = {
		sites = { 99, -1, 2.7, 0 / 0, 9, 50 },
		tools = { shovel = true, hoe = true, hammer = "yes" },
		container = "yes",
		wired = true,
	}
	local repaired = Data.migrate(brokenLand, Steps).land
	t.truthy(same(repaired.sites, { 25, 0, 2, 0, 4, 4 }), "site counts are whole numbers within their own field cap")
	t.truthy(same(repaired.tools, { scythe = true, shovel = true }), "unknown tools go, the scythe stays")
	t.equal(repaired.container, false, "a flag of the wrong type becomes false")
	t.equal(repaired.wired, true, "a valid flag is kept")
	t.equal(repaired.market, false, "a missing flag is false")
	t.truthy(
		same(Data.migrate({ v = 4, land = 5 }, Steps).land, Data.template().land),
		"a land that is no table gets the default"
	)

	-- Migration 4 to 5 (design v2, section 10): a version 4 profile gets the stages and enough prepared cells for its units.
	local v4 = Data.template()
	v4.v = 4
	v4.plants = { 40, 10, 3, 0, 0, 0 }
	v4.land.sites = { 4, 4, 4, 0, 0, 0 }
	v4.land.cells = { { 7, 3, 12, 20 }, { 1, 2, 3, 4 }, { 5, 1, 2, 6 }, {}, {}, {} }
	v4.land.steps = nil
	local v5 = Data.migrate(v4, Steps)
	t.truthy(
		same(v5.land.sites, { 10, 4, 4, 0, 0, 0 }),
		"ceil(owned / capacity) prepared cells, at least the old sites"
	)
	t.truthy(
		same(v5.land.cells[1], { 7, 3, 12, 20, 1, 2, 4, 5, 6, 8 }),
		"field 1 keeps its cells and pads the lowest free"
	)
	t.truthy(same(v5.land.cells[2], { 1, 2, 3, 4 }), "the river has its first segments")
	t.truthy(same(v5.land.steps[1], { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }), "every prepared cell has all stages done")
	t.truthy(same(v5.land.steps[3], { 2, 2, 2, 2 }), "a two stage field has both stages done")
	t.equal(v5.land.tools.scythe, true, "tools stay")
	t.equal(v4.land.sites[1], 4, "the input profile is not changed")

	-- Partial cells survive a save and a load; a broken stage count is cut to the chain.
	local working = Data.template()
	working.land.sites = { 0, 0, 1, 0, 1, 0 }
	working.land.cells = { {}, {}, { 4, 6 }, {}, { 2, 3, 1 }, {} }
	working.land.steps = { {}, {}, { 2, 1 }, {}, { 3, 2, 9 }, {} }
	local kept = Data.migrate(working, Steps).land
	t.truthy(same(kept.cells[3], { 4, 6 }) and same(kept.steps[3], { 2, 1 }), "a cell in work keeps its stage")
	t.truthy(same(kept.cells[5], { 2, 3 }) and same(kept.steps[5], { 3, 2 }), "a stage past the chain drops the cell")

	-- Booster queue and passes: broken entries are dropped on load, a good one is kept.
	local queued = Data.template()
	queued.boosters = {
		{ kind = "turbo", left = 0 / 0 },
		{ kind = 5, left = 60 },
		{ kind = "sunshine", left = -1 },
		{ kind = "turbo", left = 300 },
	}
	queued.passes = { premium = true, neon = false }
	local clean = Data.migrate(queued, Steps)
	t.equal(#clean.boosters, 1, "only the valid booster entry is kept")
	t.equal(clean.boosters[1].kind, "turbo", "the kept entry is the valid one")
	t.equal(clean.boosters[1].left, 300, "its time left is kept")
	t.equal(clean.passes.premium, true, "an owned pass is kept")
	t.equal(clean.passes.neon, nil, "a pass that is not owned is dropped")

	-- Offline income after a save and a load: Schnittrate × min(Abwesenheit, Deckel) × Wirkungsgrad.
	-- Plant multipliers here have no nodes and no grid expansion (level 0).
	local function env(longMeter: boolean)
		return {
			phase = Config.phases[2],
			weather = Config.weathers[1],
			longMeter = longMeter,
			config = Config,
			formulas = Formulas,
		}
	end
	local function formula(saved: { [string]: any }, seconds: number, hours: number, efficiency: number): number
		local rate = 0
		for _, plant in Config.plants do
			local count = saved.plants[plant.id]
			local expected = Formulas.expectedIncome(plant.kind, Config.phases, Config.weathers)
			local multiplier = Formulas.plantMultiplier(count, 2, 1) * Formulas.globalMultiplier(saved.level, 1)
			rate += Formulas.production(plant.nominalPower, count, multiplier, expected)
		end
		return rate * math.min(seconds, hours * 3600) * efficiency
	end

	local base = savedRun({ 10, 4, 0, 0, 0, 0 }, {})
	local p2 = savedRun({ 10, 4, 0, 0, 0, 0 }, { P2 = true })
	local p4 = savedRun({ 10, 4, 0, 0, 0, 0 }, { P4 = true })
	local p6 = savedRun({ 10, 4, 0, 0, 0, 0 }, { P6 = true })
	local p2p4 = savedRun({ 10, 4, 0, 0, 0, 0 }, { P2 = true, P4 = true })
	local seconds = 1000000000
	near(
		GameCore.offline(base, seconds, env(false)).coins,
		formula(base, seconds, 2, 0.5),
		"the cap is 2 hours at 50 %"
	)
	near(GameCore.offline(p2, seconds, env(false)).coins, formula(p2, seconds, 4, 0.5), "P2: the cap is 4 hours")
	near(GameCore.offline(p4, seconds, env(false)).coins, formula(p4, seconds, 2, 0.75), "P4: 75 % efficiency")
	near(GameCore.offline(p6, seconds, env(false)).coins, formula(p6, seconds, 8, 0.5), "P6: the cap is 8 hours")
	near(GameCore.offline(p2p4, seconds, env(false)).coins, formula(p2p4, seconds, 4, 0.75), "P2 and P4 together")
	near(GameCore.offline(base, seconds, env(true)).coins, formula(base, seconds, 6, 0.5), "Langzeit-Zähler: 6 hours")
	t.equal(GameCore.offline(base, 59, env(false)).coins, 0, "under a minute pays nothing")

	-- Away time at the join: now minus the last save; a clock that went back or a profile never saved gives 0.
	t.equal(Data.awaySeconds(1000, 1500), 500, "away time is now minus the last save")
	t.equal(Data.awaySeconds(1000, 900), 0, "a clock that went back gives 0")
	t.equal(Data.awaySeconds(0, 1500), 0, "a profile never saved is away for 0 seconds")

	-- Migration 7 to 8: an unfinished tutorial starts again, a finished one stays finished.
	local again = Data.migrate({ v = 7, coins = 0, tutorial = 5, tutorialDone = false }, Steps)
	t.equal(again.tutorial, 1, "an unfinished tutorial starts at its first step")
	local finished = Data.migrate({ v = 7, coins = 0, tutorial = 6, tutorialDone = true }, Steps)
	t.equal(finished.tutorialDone, true, "a finished tutorial stays finished")
end
