--!strict
-- Shop effects in the game (issue 241): every offer of Config/Shop either changes a measured value of the run when it
-- is bought (income, generation, offline cap, rule slots, a cut yield) or is listed here as cosmetic. An offer that
-- changes nothing, and is not listed, fails the test.
return function(t, load)
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Shop = load("Core/Shop")
	local Data = load("Core/Data")
	local Catalogue = load("Config/Shop")
	local Config = {
		plants = load("Config/Plants"),
		upgrades = load("Config/Upgrades"),
		prestige = load("Config/Prestige"),
		phases = load("Config/Phases"),
		weathers = load("Config/Weather"),
		effects = load("Config/Effects"),
	}
	local DAY = 20000

	-- Offers that only change how the plot looks (Core/Cosmetics).
	local COSMETIC = { grid_vip = true, neon = true, fireworks = true, themes = true }

	local function run(): any
		return {
			v = 1,
			coins = 0,
			runEarned = 0,
			lifetimeEarned = 0,
			sparks = 0,
			level = 0,
			sparksSpent = 0,
			plants = { 10, 10, 0, 0, 0, 0 },
			nodes = { U17 = true, U21 = true },
			pnodes = {},
			storage = { charge = 0, mode = "auto" },
			rules = {},
		}
	end

	-- The env the server builds from a profile (Shop.envValues), with the booster flags given.
	local function envOf(profile: any, sunshine: boolean?, turbo: boolean?): any
		local bought = Shop.envValues(profile, Catalogue, sunshine == true, turbo == true)
		return {
			phase = Config.phases[2],
			weather = Config.weathers[1],
			longMeter = bought.longMeter,
			config = Config,
			formulas = Formulas,
			boost = bought.boost,
			income = bought.income,
			ruleSlots = bought.ruleSlots,
			autoBuild = bought.autoBuild,
		}
	end

	-- One second of the run: the coins earned.
	local function income(profile: any, sunshine: boolean?, turbo: boolean?): number
		return GameCore.tick(run(), envOf(profile, sunshine, turbo), 1).coins
	end

	-- Coins of a long absence: shows the offline cap.
	local function offline(profile: any): number
		return GameCore.offline(run(), 1e9, envOf(profile)).coins
	end

	-- Rule slots: whether the third rule can be set.
	local function thirdRule(profile: any): boolean
		local _, ok = GameCore.apply(run(), { type = "SetRule", rule = "reserve", th = 0.5, on = true }, envOf(profile))
		return ok
	end

	-- The coins left after an auto-build with 1e6 coins (1e6 when it does nothing).
	local function autoBuilt(profile: any): number
		local state = run()
		state.coins = 1e6
		return (GameCore.apply(state, { type = "AutoBuild" }, envOf(profile))).coins
	end

	local function owned(id: string): any
		local profile = Data.template()
		profile.passes[id] = true
		return profile
	end

	local base = Data.template()
	local baseIncome, baseOffline = income(base), offline(base)

	-- What each gameplay offer changes, as a measured value of the run: before (nothing bought) and after.
	local measures: { [string]: () -> (any, any) } = {
		premium = function()
			return baseIncome, income(owned("premium"))
		end,
		turbo = function()
			return baseIncome, income(base, false, true)
		end,
		sunshine = function()
			return baseIncome, income(base, true)
		end,
		long_meter = function()
			return baseOffline, offline(owned("long_meter"))
		end,
		smart_hub = function()
			return thirdRule(base), thirdRule(owned("smart_hub"))
		end,
		founder = function()
			local _, seconds = Shop.purchase(base, "founder", DAY, Catalogue)
			return 0, seconds
		end,
		timeskip = function()
			local _, seconds = Shop.purchase(base, "timeskip", DAY, Catalogue)
			return 0, seconds
		end,
	}

	for _, offer in Catalogue.offers do
		if COSMETIC[offer.id] then
			t.truthy(measures[offer.id] == nil, `{offer.id}: listed as cosmetic and as an effect`)
		else
			local measure = measures[offer.id]
			t.truthy(measure ~= nil, `{offer.id}: neither cosmetic nor measured`)
			if measure ~= nil then
				local before, after = measure()
				t.truthy(before ~= after, `{offer.id}: buying it changes nothing`)
			end
		end
	end

	local function near(actual: number, expected: number, label: string)
		t.truthy(
			math.abs(actual - expected) < 1e-6 * math.max(1, expected),
			`{label}: expected {expected}, got {actual}`
		)
	end
	-- Premium x1.5 on the sale price, Turbo x2 on income, Sunshine x2 on generation.
	near(income(owned("premium")), 1.5 * baseIncome, "Premium Tariff x1.5")
	near(income(base, false, true), 2 * baseIncome, "Turbo Feed-in x2")
	near(income(base, true), 2 * baseIncome, "Sunshine Hour x2")
	-- Together at most multiplierCap (x3).
	near(income(owned("premium"), false, true), 3 * baseIncome, "Premium and Turbo x3")
	near(income(owned("premium"), true, true), 3 * baseIncome, "all three stay at the cap")
	near(income(owned("premium"), true), 3 * baseIncome, "Premium and Sunshine x3")

	-- Long Meter: the offline cap grows by its hours (2 h + 4 h, 3 times the coins).
	near(offline(owned("long_meter")), 3 * baseOffline, "Long Meter adds 4 hours to the 2 hour cap")

	-- Smart Hub: the third rule slot and the auto-build; without it neither works.
	t.truthy(not thirdRule(base) and thirdRule(owned("smart_hub")), "Smart Hub opens the third rule slot")
	t.equal(autoBuilt(base), 1e6, "without the Smart Hub the auto-build does nothing")
	t.truthy(autoBuilt(owned("smart_hub")) < 1e6, "Smart Hub: the auto-build pays for a plant")

	-- The reserve rule keeps charge: selling stops at its share of the capacity.
	local hub = envOf(owned("smart_hub"))
	hub.phase = Config.phases[3] -- evening: the price factor passes the sell threshold
	local stocked = run()
	stocked.storage = { charge = 1e9, mode = "auto" }
	stocked.rules = { sell = { th = 1, on = true } }
	local reserved = run()
	reserved.storage = { charge = 1e9, mode = "auto" }
	reserved.rules = { sell = { th = 1, on = true }, reserve = { th = 0.9, on = true } }
	local sold, kept = stocked, reserved
	for _ = 1, 120 do
		sold, kept = GameCore.tick(sold, hub, 1), GameCore.tick(kept, hub, 1)
	end
	t.truthy(
		sold.storage.charge < 1e-6 and kept.storage.charge > 1,
		"the reserve rule keeps charge that selling alone empties"
	)
end
