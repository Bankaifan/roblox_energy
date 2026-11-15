--!strict
-- Shop (Bauplan.md, section 4): the 11 offers, the effects of passes and boosters (caps, queue, no stacking), the
-- daily limit of Time Skips with its reset, the one-time Founder Pack, and no negative or NaN values after a load.
return function(t, load)
	local Shop = load("Core/Shop")
	local Data = load("Core/Data")
	local Steps = load("Migrations/Steps")
	local Catalogue = load("Config/Shop")

	local DAY = 20000

	-- A copy of the catalogue with some values changed, to check the flags and the cap.
	local function with(changes: { [string]: any }): any
		local config: any = table.clone(Catalogue)
		for key, value in changes do
			config[key] = value
		end
		return config
	end

	-- Buys one offer on a day (default DAY) with the catalogue (default): the new profile, the yield and the reason.
	local function buy(profile: any, id: string, day: number?, config: any?): (any, number, string?)
		return Shop.purchase(profile, id, day or DAY, config or Catalogue)
	end

	-- The catalogue: eleven offers, unique IDs, the Robux prices and names the Bauplan gives.
	t.equal(#Catalogue.offers, 11, "eleven offers")
	local seen: { [string]: boolean } = {}
	local passes, products = 0, 0
	for _, offer in Catalogue.offers do
		t.truthy(not seen[offer.id], `duplicate offer {offer.id}`)
		seen[offer.id] = true
		t.truthy(offer.type == "pass" or offer.type == "product", `{offer.id}: type pass or product`)
		t.truthy(offer.robux > 0 and offer.robux == math.floor(offer.robux), `{offer.id}: whole Robux price`)
		t.truthy(offer.robloxId >= 0, `{offer.id}: ID placeholder is 0 or more`)
		t.truthy(type(offer.en) == "string" and offer.en ~= "", `{offer.id}: English name`)
		t.truthy(type(offer.de) == "string" and offer.de ~= "", `{offer.id}: German name`)
		if offer.type == "pass" then
			passes += 1
			t.truthy(offer.robux >= 50 and offer.robux <= 800, `{offer.id}: a pass costs 50 to 800 Robux`)
		else
			products += 1
		end
	end
	t.equal(passes, 8, "eight passes")
	t.equal(products, 3, "three products")

	-- The product defaults (Bauplan section 10): daily limits on, Smart Hub extras at once.
	t.equal(Catalogue.dailyLimits, true, "daily limits are on")
	t.equal(Catalogue.skipsPerDay, 3, "three Time Skips a day")
	t.equal(Catalogue.boosterStockSeconds, 3600, "the booster stock is at most 60 minutes")
	t.equal(Catalogue.smartHubImmediate, true, "the Smart Hub extras come at once")

	-- Premium Tariff and the cap: premium ×1.5 on the sale, turbo ×2 on the income, together at most ×3.
	local base = Data.template()
	t.equal(Shop.saleMultiplier(base, Catalogue), 1, "without premium the sale price is ×1")
	local premium, premiumYield, premiumReason = buy(base, "premium")
	t.equal(premiumReason, nil, "the Premium Tariff is bought")
	t.equal(premiumYield, 0, "the Premium Tariff pays no yield")
	t.equal(Shop.saleMultiplier(premium, Catalogue), 1.5, "premium: the sale price ×1.5")
	t.equal(Shop.incomeMultiplier(premium, Catalogue), 1.5, "premium alone: the income ×1.5")
	t.equal(base.passes.premium, nil, "the input profile is not changed")
	local premiumTurbo = buy(premium, "turbo")
	t.equal(Shop.incomeMultiplier(premiumTurbo, Catalogue), 3, "premium and turbo: ×3, the cap")
	t.equal(Shop.incomeMultiplier(premiumTurbo, with({ booster = 5 })), 3, "the cap holds for any booster factor")
	t.equal(Shop.generationMultiplier(premiumTurbo, Catalogue), 1, "turbo does not change the generation")

	-- Sunshine Hour doubles the generation, not the income.
	local sunny = buy(base, "sunshine")
	t.equal(Shop.generationMultiplier(sunny, Catalogue), 2, "sunshine: the generation ×2")
	t.equal(Shop.incomeMultiplier(sunny, Catalogue), 1, "sunshine does not change the income")

	-- The booster queue: one active booster, the others wait; advance takes the seconds off the front.
	local queue = buy(base, "turbo") -- 900 seconds, then the sunshine below: 600 seconds
	queue = buy(queue, "sunshine")
	t.equal(Shop.boosterStock(queue), 1500, "the queue adds up: 900 + 600 seconds")
	t.equal(Shop.activeBooster(queue), "turbo", "the first booster is the active one")
	t.equal(Shop.generationMultiplier(queue, Catalogue), 1, "the sunshine waits: boosters do not stack")
	local later = Shop.advance(queue, 1000)
	t.equal(Shop.activeBooster(later), "sunshine", "the turbo has run out, the sunshine is next")
	t.equal(Shop.boosterStock(later), 500, "500 seconds of sunshine are left")
	t.equal(Shop.boosterStock(queue), 1500, "advance does not change the input")
	local empty = Shop.advance(later, 500)
	t.equal(Shop.activeBooster(empty), nil, "the queue is empty at the end")
	t.equal(Shop.boosterStock(empty), 0, "no stock left")
	t.equal(Shop.boosterStock(Shop.advance(queue, 0)), 1500, "advance by 0 keeps the queue")
	t.equal(Shop.boosterStock(Shop.advance(queue, -5)), 1500, "a negative advance keeps the queue")
	t.equal(Shop.boosterStock(Shop.advance(queue, 0 / 0)), 1500, "a NaN advance keeps the queue")

	-- The stock is at most 60 minutes: six Sunshine Hours fill it, a seventh is refused and changes nothing.
	local full = base
	for _ = 1, 6 do
		full = buy(full, "sunshine")
	end
	t.equal(Shop.boosterStock(full), 3600, "six Sunshine Hours fill the 60 minutes")
	local over, overYield, overReason = buy(full, "sunshine")
	t.equal(overReason, "booster stock full", "a seventh Sunshine Hour is refused")
	t.equal(overYield, 0, "a refused booster pays nothing")
	t.equal(over, full, "a refused purchase returns the same profile")
	local _, _, turboReason = buy(full, "turbo")
	t.equal(turboReason, "booster stock full", "a turbo does not fit either")

	-- Time Skip: one hour of yield, three a day. The limit comes back on the next day.
	local skip = base
	local paid = 0
	for _ = 1, 3 do
		local seconds, reason
		skip, seconds, reason = buy(skip, "timeskip")
		t.equal(reason, nil, "a Time Skip is bought")
		paid += seconds
	end
	t.equal(paid, 10800, "three Time Skips give three hours of yield")
	t.equal(Shop.skipsLeft(skip, DAY, Catalogue), 0, "no Time Skip left today")
	local refused, refusedYield, refusedReason = buy(skip, "timeskip")
	t.equal(refusedReason, "daily limit", "a fourth Time Skip on the same day is refused")
	t.equal(refusedYield, 0, "a refused Time Skip pays nothing")
	t.equal(refused, skip, "a refused Time Skip returns the same profile")
	t.equal(Shop.skipsLeft(skip, DAY + 1, Catalogue), 3, "the next day the limit is three again")
	local nextDay, nextYield, nextReason = buy(skip, "timeskip", DAY + 1)
	t.equal(nextReason, nil, "a Time Skip on the next day is bought")
	t.equal(nextYield, 3600, "and pays one hour")
	t.equal(Shop.skipsLeft(nextDay, DAY + 1, Catalogue), 2, "one used on the new day")
	local unlimited = with({ dailyLimits = false })
	local many = base
	for _ = 1, 5 do
		many = buy(many, "timeskip", DAY, unlimited)
	end
	t.equal(Shop.skipsLeft(many, DAY, unlimited), math.huge, "with the limit off there is no count")
	local _, _, manyReason = buy(many, "timeskip", DAY, unlimited)
	t.equal(manyReason, nil, "with the limit off a sixth Time Skip is bought")

	-- Founder Pack: once, 30 minutes of yield.
	local founder, founderYield, founderReason = buy(base, "founder")
	t.equal(founderReason, nil, "the Founder Pack is bought")
	t.equal(founderYield, 1800, "once, 30 minutes of cut yield")
	t.equal(founder.passes.founder, true, "the Founder Pack is owned")
	local again, againYield, againReason = buy(founder, "founder")
	t.equal(againReason, "already owned", "a second Founder Pack is refused")
	t.equal(againYield, 0, "and pays no yield again")
	t.equal(again, founder, "a refused pass returns the same profile")

	-- Smart Hub: a third rule slot and auto-build at once; with the flag off it gives nothing.
	local hub = buy(base, "smart_hub")
	local slots, autoBuild = Shop.smartHub(hub, Catalogue)
	t.equal(slots, 3, "Smart Hub: a third rule slot at once")
	t.equal(autoBuild, true, "Smart Hub: the auto-build at once")
	local noSlots, noAuto = Shop.smartHub(base, Catalogue)
	t.equal(noSlots, 0, "without Smart Hub no extra slot")
	t.equal(noAuto, false, "without Smart Hub no auto-build")
	local flagOff = Shop.smartHub(hub, with({ smartHubImmediate = false }))
	t.equal(flagOff, 0, "with the flag off the Smart Hub gives no slot")

	-- Long Meter: four more offline hours.
	t.equal(Shop.offlineBonusHours(base, Catalogue), 0, "without Long Meter no extra hours")
	t.equal(Shop.offlineBonusHours(buy(base, "long_meter"), Catalogue), 4, "Long Meter: +4 hours")

	-- Refused requests: an unknown offer, a day that is not a whole number of days.
	local _, unknownYield, unknownReason = buy(base, "bogus")
	t.equal(unknownReason, "unknown offer", "an unknown offer is refused")
	t.equal(unknownYield, 0, "an unknown offer pays nothing")
	local _, nanYield, nanReason = buy(base, "timeskip", 0 / 0)
	t.equal(nanReason, "invalid day", "a NaN day is refused")
	t.equal(nanYield, 0, "and pays nothing")
	local _, negativeYield, negativeReason = buy(base, "timeskip", -1)
	t.equal(negativeReason, "invalid day", "a negative day is refused")
	t.equal(negativeYield, 0, "and pays nothing")

	-- Broken saved values: the load drops bad booster entries and bad counts; every result stays finite and not negative.
	local dirty = Data.template()
	dirty.boosters =
		{ { kind = "turbo", left = 0 / 0 }, { kind = "sunshine", left = -4 }, { kind = "turbo", left = 60 } }
	dirty.daily = { day = DAY, skips = -2 }
	dirty.passes = { premium = true }
	local loaded = Data.migrate(dirty, Steps)
	t.equal(Shop.boosterStock(loaded), 60, "only the valid booster entry counts")
	t.equal(Shop.activeBooster(loaded), "turbo", "and it is the active one")
	t.equal(Shop.skipsLeft(loaded, DAY, Catalogue), 3, "a negative skip count is 0 on load")
	local income = Shop.incomeMultiplier(loaded, Catalogue)
	t.truthy(income == income and income >= 1 and income <= 3, "the income multiplier is finite and within ×1 to ×3")
	t.equal(Shop.boosterStock(Shop.advance(loaded, math.huge)), 60, "an infinite advance changes nothing")
end
