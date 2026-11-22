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
			storageFactor = bought.storageFactor,
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
		state.rules.autobuild = { th = 0.2, on = true }
		return (GameCore.apply(state, { type = "AutoBuild" }, envOf(profile))).coins
	end

	local function owned(id: string): any
		local profile = Data.template()
		profile.passes[id] = true
		return profile
	end

	-- The storage capacity the game core reports for a profile (stage 2 owned: U17 and U18).
	local function storageCapacity(profile: any): number
		local state = run()
		state.nodes.U18 = true
		state.storage.charge = 1e-3
		local fill = GameCore.view(state, envOf(profile)).storage.fill
		return 1e-3 / fill
	end

	local base = Data.template()
	local baseIncome, baseOffline = income(base), offline(base)

	-- What each gameplay offer changes, as a measured value of the run: before (nothing bought) and after.
	local measures: { [string]: () -> (any, any) } = {
		premium = function()
			return baseIncome, income(owned("premium"))
		end,
		auto_crank = function()
			return (Shop.autoCranks(base, Catalogue, 1, 0, 0)),
				(Shop.autoCranks(owned("auto_crank"), Catalogue, 1, 0, 0))
		end,
		mega_battery = function()
			return storageCapacity(base), storageCapacity(owned("mega_battery"))
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

	-- Time Skip and Founder Pack pay their yield (issue 242): 20 and 30 minutes of average yield at the full rate, no
	-- offline efficiency and no offline cap; it counts as run revenue; a Time Skip receipt pays once.
	local skipEnv = envOf(base)
	local perSecond = GameCore.yield(run(), 1, skipEnv)
	t.truthy(perSecond > 0, "the run has an average yield")
	local timeskip: any = nil
	for _, offer in Catalogue.offers do
		if offer.id == "timeskip" then
			timeskip = offer
		end
	end
	t.truthy(timeskip ~= nil, "the Time Skip is an offer")
	t.equal(timeskip.seconds, 1200, "a Time Skip is 20 minutes")
	local skipCoins = GameCore.yield(run(), timeskip.seconds, skipEnv)
	t.truthy(math.abs(skipCoins - (perSecond * 1200)) < 1e-6, "a Time Skip is 20 minutes of yield")
	t.truthy(skipCoins > GameCore.offline(run(), 1200, skipEnv).coins, "full rate: more than the offline credit")
	local longAway = GameCore.offline(run(), 1e9, skipEnv).coins
	t.truthy(GameCore.yield(run(), 3600 * 100, skipEnv) > longAway, "and not limited by the offline cap")
	local paid = GameCore.payout(run(), skipCoins)
	t.truthy(math.abs(paid.coins - skipCoins) < 1e-6, "the yield is paid as coins")
	t.truthy(math.abs(paid.runEarned - skipCoins) < 1e-6, "it counts as run revenue")
	t.truthy(math.abs(paid.lifetimeEarned - skipCoins) < 1e-6, "and as lifetime revenue")
	t.equal(GameCore.payout(paid, -skipCoins * 2).coins, 0, "taking a payout back never goes below 0")
	local receipted, status, receiptSeconds = Shop.receipt(base, "r1", "timeskip", DAY, Catalogue)
	t.equal(status, "granted", "a Time Skip receipt is granted")
	t.equal(receiptSeconds, 1200, "with its 20 minutes")
	local _, dupStatus, dupSeconds = Shop.receipt(receipted, "r1", "timeskip", DAY, Catalogue)
	t.equal(dupStatus, "duplicate", "the same receipt again is a duplicate")
	t.equal(dupSeconds, 0, "and pays nothing")
	local founderSeconds = select(2, Shop.claimPassYield(owned("founder"), "founder", Catalogue))
	t.truthy(
		math.abs(GameCore.yield(run(), founderSeconds, skipEnv) - perSecond * 1800) < 1e-6,
		"the Founder Pack pays 30 minutes"
	)

	-- Spark packs add their sparks to the profile (and so to what the run can spend); the sparks left to spend grow by
	-- exactly the pack size.
	for _, size in { 5, 15, 40 } do
		measures[`sparks{size}`] = function()
			local after = Shop.purchase(base, `sparks{size}`, DAY, Catalogue, Config.upgrades)
			return base.sparks, after.sparks
		end
	end

	-- Permanent plants: the count of the type in the profile, which the run start turns into units (GameCore tests).
	for _, offer in Catalogue.offers do
		if offer.plant ~= nil then
			measures[offer.id] = function()
				local builder = Data.template()
				builder.built[offer.plant] = true
				local after = Shop.purchase(builder, offer.id, DAY, Catalogue)
				return builder.permanent[offer.plant], after.permanent[offer.plant]
			end
		end
	end

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

	-- Mega Battery: the capacity of every stage is 1.5 times as large, and the sold-out charge scales with it.
	near(storageCapacity(owned("mega_battery")), 1.5 * storageCapacity(base), "Mega Battery: capacity x1.5")
	t.equal(Shop.storageFactor(base, Catalogue), 1, "without the pass the factor is 1")
	t.equal(Shop.storageFactor(owned("mega_battery"), Catalogue), 1.5, "with the pass the factor is 1.5")
	t.equal(Shop.envValues(owned("mega_battery"), Catalogue, false, false).storageFactor, 1.5, "the env carries it")

	-- Auto Crank: 4 cranks per second with the pass, none without; with hand cranks the total stays at 8 per second;
	-- the fraction of a short step is carried.
	local crankPass = owned("auto_crank")
	t.equal(Shop.autoCranks(base, Catalogue, 1, 0, 0), 0, "without the pass nobody cranks")
	t.equal(Shop.autoCranks(crankPass, Catalogue, 1, 0, 0), 4, "the pass turns the crank 4 times per second")
	t.equal(Shop.autoCranks(crankPass, Catalogue, 1, 3, 0), 4, "3 hand cranks leave room for all 4")
	t.equal(Shop.autoCranks(crankPass, Catalogue, 1, 6, 0), 2, "6 hand cranks leave room for 2")
	t.equal(Shop.autoCranks(crankPass, Catalogue, 1, 8, 0), 0, "8 hand cranks fill the limit")
	t.equal(Shop.autoCranks(crankPass, Catalogue, 1, 20, 0), 0, "more hand cranks than the limit leave nothing")
	local first, carry = Shop.autoCranks(crankPass, Catalogue, 0.3, 0, 0)
	local second = Shop.autoCranks(crankPass, Catalogue, 0.3, 0, carry)
	t.truthy(first + second == 2, "short steps add up to 4 per second (0.6 s: 2 cranks)")
	t.equal(select(2, Shop.autoCranks(crankPass, Catalogue, 1, 8, 0)), 4, "a blocked second carries at most one second")
end
