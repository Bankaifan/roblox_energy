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

	-- The template: version 1, the default profile of Bauplan section 5.
	local template = Data.template()
	t.equal(template.v, 1, "the template is version 1")
	t.equal(#template.plants, 6, "six plants")
	t.equal(template.storage.mode, "auto", "storage starts in auto")
	t.equal(template.settings.lang, "auto", "the language follows the player")
	t.equal(template.grants.founder, false, "no founder grant by default")
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
	run.rules = { [1] = { id = "charge", th = 0.7, on = true }, [2] = { id = "sell", th = 1.2, on = false } }
	run.lastSeen = 1700000000
	run.playSeconds = 3600
	run.sessions = 4
	run.firstJoin = 1690000000
	run.purchases = { "receipt-1", "receipt-2" }
	run.grants = { founder = true, boostSeconds = 600, skipDay = 2, skipCount = 1 }
	run.cosmetics = { [1] = "gold" }
	run.settings = { lang = "de", sfx = false, music = true }
	run.tutorial = 3
	local state = Data.toState(run)
	local loaded, reason = Data.migrate(Data.fromState(state, run), Steps)
	t.equal(reason, nil, "a current profile loads")
	t.truthy(same(loaded, run), "the saved profile comes back exactly")
	t.truthy(same(Data.toState(loaded), state), "the run comes back exactly")

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
	broken.rules = { [1] = { id = "charge", th = 0 / 0, on = true } }
	broken.lastSeen = -1
	local cleaned = Data.migrate(broken, Steps)
	t.truthy(countsOnly(cleaned), "no negative, NaN or infinite number after a load")
	t.equal(cleaned.coins, 0, "negative coins become 0")
	t.equal(cleaned.plants[1], 0, "a negative plant count becomes 0")
	t.equal(cleaned.plants[3], 2, "a valid plant count is kept")
	t.equal(cleaned.rules[1], nil, "a rule with a NaN threshold is dropped")

	-- A profile of a newer version, or without a version, is rejected.
	local newer = Data.template()
	newer.v = 2
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
	}
	local upgraded = Data.migrate(old, example)
	t.equal(upgraded.v, 1, "the profile is version 1 afterwards")
	t.equal(upgraded.coins, 50, "step 0 to 1 renames the field")
	t.equal(upgraded.money, nil, "the old field is gone")
	t.equal(upgraded.plants[1], 0, "fields new in version 1 come from the template")
	t.equal(old.money, 50, "the input profile is not changed")
	local stranded, strandedReason = Data.migrate(old, {})
	t.equal(stranded, nil, "without a step the load fails")
	t.equal(strandedReason, "no migration from version 0", "the reason names the version")

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
end
