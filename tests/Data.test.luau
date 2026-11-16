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

	-- The template: version 4, the default profile of Bauplan section 5.
	local template = Data.template()
	t.equal(template.v, 4, "the template is version 4")
	t.equal(template.land.tools.scythe, true, "the scythe is owned from the start")
	t.equal(template.land.market, false, "the market is not yet opened")
	t.equal(next(template.passes), nil, "no pass owned by default")
	t.equal(#template.boosters, 0, "the booster queue starts empty")
	t.equal(template.daily.skips, 0, "no Time Skip used by default")
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
	run.daily = { day = 20000, skips = 2 }
	run.cosmetics = { [1] = "gold" }
	run.settings = { lang = "de", sfx = false, music = true }
	run.tutorial = 3
	run.land = {
		sites = { 4, 7, 0, 1, 0, 0 },
		cells = { { 5, 1, 24, 2 }, { 1, 2, 3, 4, 5, 6, 7 }, {}, { 6 }, {}, {} },
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
	t.equal(migrated.v, 4, "the profile is version 4 afterwards")
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

	-- A profile of a newer version, or without a version, is rejected.
	local newer = Data.template()
	newer.v = 5
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
	}
	local upgraded = Data.migrate(old, example)
	t.equal(upgraded.v, 4, "the profile is the current version afterwards")
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
	t.equal(v2.v, 4, "a version 1 profile loads as the current version")
	t.equal(v2.passes.founder, true, "a founder grant becomes the owned pass")
	t.equal(v2.daily.day, 20000, "the Time Skip day is kept")
	t.equal(v2.daily.skips, 2, "the Time Skip count is kept")
	t.equal(#v2.boosters, 0, "the booster queue starts empty")
	t.equal(v2.grants, nil, "grants is gone")
	local v1none = Data.migrate({ v = 1 }, Steps)
	t.equal(next(v1none.passes), nil, "a version 1 profile without a founder grant owns no pass")

	-- Migration 2 to 3: a profile that has earned coins gets the old game's land; a fresh one gets the template.
	local old2 = { v = 2, coins = 10, lifetimeEarned = 50, nodes = { U21 = true } }
	local v3 = Data.migrate(old2, Steps)
	t.equal(v3.v, 4, "a version 2 profile loads as the current version")
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
end
