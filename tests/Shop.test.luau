--!strict
-- Shop (Bauplan.md, section 4): the 16 offers, the effects of passes and boosters (caps, queue, no stacking), the
-- daily limit of Time Skips with its reset, the one-time Founder Pack, and no negative or NaN values after a load.
return function(t, load)
	local Shop = load("Core/Shop")
	local Data = load("Core/Data")
	local Steps = load("Migrations/Steps")
	local Catalogue = load("Config/Shop")
	local Upgrades = load("Config/Upgrades")

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

	-- The catalogue: 28 offers, unique IDs, the Robux prices and names the Bauplan gives.
	t.equal(#Catalogue.offers, 28, "28 offers")
	-- Crank speed: the hand rate, plus the Auto Crank rate with the pass, never above the limit.
	t.equal(Shop.crankSpeed({ passes = {} }, Catalogue), Catalogue.handCrankRate, "by hand only")
	t.equal(
		Shop.crankSpeed({ passes = { auto_crank = true } }, Catalogue),
		math.min(Catalogue.handCrankRate + Catalogue.autoCrankRate, Catalogue.crankLimit),
		"hand and motor together"
	)

	t.equal(Shop.crankSpeed({ passes = { auto_crank = true } }, with({ crankLimit = 3 })), 3, "capped by the limit")
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
	t.equal(passes, 10, "ten passes")
	t.equal(products, 18, "18 products: two boosters, the Time Skip, three spark packs and twelve permanent plants")
	-- The Creator Hub IDs (issue 281, the owner's update): every offer is pinned to its exact ID.
	local creatorHubIds: { [string]: number } = {
		founder = 2096875000,
		smart_hub = 2092415147,
		long_meter = 2092793166,
		auto_crank = 2096623036,
		mega_battery = 2092751131,
		premium = 2092673252,
		grid_vip = 2092403157,
		neon = 2094533031,
		fireworks = 2092283063,
		themes = 2097016970,
		sunshine = 3734134439,
		turbo = 3734134487,
		timeskip = 3734134518,
		sparks5 = 3734138157,
		sparks15 = 3734138182,
		sparks40 = 3734138203,
		perm1 = 3734152391,
		perm1x10 = 3734152514,
		perm2 = 3734152579,
		perm2x10 = 3734152954,
		perm3 = 3734153153,
		perm3x10 = 3734153895,
		perm4 = 3734154151,
		perm4x10 = 3734154228,
		perm5 = 3734154380,
		perm5x10 = 3734154462,
		perm6 = 3734154528,
		perm6x10 = 3734154630,
	}
	for _, offer in Catalogue.offers do
		t.equal(offer.robloxId, creatorHubIds[offer.id], `{offer.id}: its Creator Hub ID`)
	end

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
	t.equal(paid, 3600, "three Time Skips give one hour of yield")
	t.equal(Shop.skipsLeft(skip, DAY, Catalogue), 0, "no Time Skip left today")
	local refused, refusedYield, refusedReason = buy(skip, "timeskip")
	t.equal(refusedReason, "daily limit", "a fourth Time Skip on the same day is refused")
	t.equal(refusedYield, 0, "a refused Time Skip pays nothing")
	t.equal(refused, skip, "a refused Time Skip returns the same profile")
	t.equal(Shop.skipsLeft(skip, DAY + 1, Catalogue), 3, "the next day the limit is three again")
	local nextDay, nextYield, nextReason = buy(skip, "timeskip", DAY + 1)
	t.equal(nextReason, nil, "a Time Skip on the next day is bought")
	t.equal(nextYield, 1200, "and pays 20 minutes")
	t.equal(Shop.skipsLeft(nextDay, DAY + 1, Catalogue), 2, "one used on the new day")
	-- Extras tab view: owned passes, booster stock, Time Skips left, and when the tab may show at all.
	local extrasBase = Data.template()
	extrasBase.tutorialDone = true
	extrasBase.passes.neon = true
	local extrasQueued = buy(extrasBase, "sunshine")
	local view = Shop.extrasView(extrasQueued, DAY, Catalogue, true, 720)
	t.equal(view.shown, true, "tutorial done, minute 12 and allowed: the tab shows")
	t.equal(view.owned.neon, true, "an owned pass is listed")
	t.equal(view.stock, 600, "the booster stock is the queue")
	t.equal(view.skipsLeft, 3, "three Time Skips left")
	t.equal(Shop.extrasView(extrasBase, DAY, Catalogue, true, 719).shown, false, "hidden before minute 12")
	t.equal(Shop.extrasView(extrasBase, DAY, Catalogue, false, 720).shown, false, "hidden when the shop is not allowed")
	local unfinished = table.clone(extrasBase)
	unfinished.tutorialDone = false
	t.equal(Shop.extrasView(unfinished, DAY, Catalogue, true, 720).shown, false, "hidden during the tutorial")
	t.equal(Shop.extrasView(extrasBase, DAY, with({ dailyLimits = false }), true, 720).skipsLeft, nil, "no limit: nil")

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

	-- The Founder yield is claimed once per profile: the flag is kept, a later claim (a new session) pays nothing.
	local claimed, claimedSeconds = Shop.claimPassYield(founder, "founder", Catalogue)
	t.equal(claimedSeconds, 1800, "the owned Founder Pack pays 30 minutes the first time")
	t.equal(claimed.paid.founder, true, "and the profile remembers it")
	local _, secondClaim = Shop.claimPassYield(claimed, "founder", Catalogue)
	t.equal(secondClaim, 0, "a second claim pays nothing")
	local _, unowned = Shop.claimPassYield(base, "founder", Catalogue)
	t.equal(unowned, 0, "a pass that is not owned pays nothing")
	local _, noYield = Shop.claimPassYield(buy(base, "premium"), "premium", Catalogue)
	t.equal(noYield, 0, "a pass without a yield pays nothing")

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

	-- ProcessReceipt: the catalogue with Roblox IDs set for some offers (the shipped IDs are placeholders, 0).
	local function withIds(ids: { [string]: number }): any
		local config: any = table.clone(Catalogue)
		config.offers = {}
		for _, offer in Catalogue.offers do
			local copy = table.clone(offer)
			copy.robloxId = ids[offer.id] or copy.robloxId
			table.insert(config.offers, copy)
		end
		return config
	end
	local ids = withIds({ sunshine = 5001, timeskip = 5002, premium = 5003 })
	t.equal(Shop.offerForProduct(ids, 5001), "sunshine", "a product ID finds its offer")
	t.equal(Shop.offerForProduct(ids, 9999), nil, "an unknown product ID is not found")
	t.equal(Shop.offerForProduct(ids, 5003), nil, "a pass ID is never a product")
	t.equal(Shop.offerForProduct(Catalogue, 0), nil, "placeholder IDs match nothing")
	t.equal(Shop.offerForProduct(ids, 0 / 0), nil, "a NaN product ID matches nothing")

	-- A receipt is credited once: the credit and the receipt ID are written together, a repeat changes nothing.
	local first, firstStatus, firstYield = Shop.receipt(base, "r-1", "timeskip", DAY, ids)
	t.equal(firstStatus, "granted", "a new receipt is granted")
	t.equal(firstYield, 1200, "the Time Skip pays 20 minutes")
	t.equal(first.purchases[1], "r-1", "the receipt ID is kept with the credit")
	t.equal(first.daily.skips, 1, "the daily count goes up with the credit")
	local repeated, repeatStatus, repeatYield = Shop.receipt(first, "r-1", "timeskip", DAY, ids)
	t.equal(repeatStatus, "duplicate", "the same receipt again is a duplicate")
	t.equal(repeatYield, 0, "a duplicate pays nothing")
	t.equal(repeated, first, "a duplicate returns the same profile")
	t.equal(repeated.daily.skips, 1, "the credit is written once")

	-- A booster receipt joins the queue, the same for any product.
	local queued, queuedStatus = Shop.receipt(base, "r-2", "sunshine", DAY, ids)
	t.equal(queuedStatus, "granted", "a booster receipt is granted")
	t.equal(Shop.boosterStock(queued), 600, "the Sunshine Hour joins the queue")

	-- Refused: a pass, an unknown offer, an empty or non-text receipt ID, and a limit (stock full, three skips a day).
	local _, passStatus, passYield = Shop.receipt(base, "r-3", "premium", DAY, ids)
	t.equal(passStatus, "refused", "a pass is not a product: refused")
	t.equal(passYield, 0, "a refused receipt pays nothing")
	local _, bogusStatus = Shop.receipt(base, "r-4", "bogus", DAY, ids)
	t.equal(bogusStatus, "refused", "an unknown offer is refused")
	local _, emptyStatus = Shop.receipt(base, "", "timeskip", DAY, ids)
	t.equal(emptyStatus, "refused", "an empty receipt ID is refused")
	local _, numberStatus = Shop.receipt(base, 7, "timeskip", DAY, ids)
	t.equal(numberStatus, "refused", "a receipt ID that is not text is refused")
	local _, fullStatus, fullYield = Shop.receipt(full, "r-5", "sunshine", DAY, ids)
	t.equal(fullStatus, "refused", "a booster that does not fit is refused")
	t.equal(fullYield, 0, "and pays nothing")
	local _, limitStatus = Shop.receipt(skip, "r-6", "timeskip", DAY, ids)
	t.equal(limitStatus, "refused", "a fourth Time Skip on the same day is refused")

	-- Spark packs (issue 251): 5, 15 and 40 sparks for 79, 199 and 449 Robux, granted only while the sparks still missing
	-- for all permanent nodes and spark items (215 in total) are at least the pack size.
	local packs = { sparks5 = { 5, 79 }, sparks15 = { 15, 199 }, sparks40 = { 40, 449 } }
	for id, expected in packs do
		local offer: any = nil
		for _, candidate in Catalogue.offers do
			if candidate.id == id then
				offer = candidate
			end
		end
		t.truthy(offer ~= nil and offer.type == "product", `{id}: a product`)
		t.equal(offer.sparks, expected[1], `{id}: its spark count`)
		t.equal(offer.robux, expected[2], `{id}: its Robux price`)
	end
	local sparkIds = withIds({ sparks5 = 6001, sparks15 = 6002, sparks40 = 6003 })
	t.equal(Shop.sparksMissing(base, Upgrades), 215, "all permanent nodes and spark items cost 215 sparks")
	local earned = Data.template()
	earned.sparks = 10
	t.equal(Shop.sparksMissing(earned, Upgrades), 205, "earned sparks are no longer missing")
	local packed, packedStatus, packedYield = Shop.receipt(earned, "p-1", "sparks15", DAY, sparkIds, Upgrades)
	t.equal(packedStatus, "granted", "a spark pack receipt is granted")
	t.equal(packedYield, 0, "a pack pays no yield")
	t.equal(packed.sparks, 25, "the pack adds its sparks")
	t.equal(packed.sparksBought, 15, "and counts them as bought")
	t.equal(earned.sparks, 10, "the input profile is not changed")
	t.equal(Shop.sparksMissing(packed, Upgrades), 190, "bought sparks are no longer missing either")
	t.equal(Shop.packSparks(Catalogue, "sparks40"), 40, "packSparks gives the size of a pack")
	t.equal(Shop.packSparks(Catalogue, "timeskip"), 0, "and 0 for another offer")
	-- A duplicate receipt credits nothing.
	local packAgain, againStatus = Shop.receipt(packed, "p-1", "sparks15", DAY, sparkIds, Upgrades)
	t.equal(againStatus, "duplicate", "the same pack receipt again is a duplicate")
	t.equal(packAgain.sparks, 25, "and adds no sparks")
	t.equal(packAgain.sparksBought, 15, "or bought count")
	-- The rule: never more than the player still needs.
	local nearly = Data.template()
	nearly.sparks = 200 -- 15 missing
	local _, exactStatus = Shop.receipt(nearly, "p-2", "sparks15", DAY, sparkIds, Upgrades)
	t.equal(exactStatus, "granted", "a pack of exactly the missing sparks is granted")
	local _, largeStatus = Shop.receipt(nearly, "p-3", "sparks40", DAY, sparkIds, Upgrades)
	t.equal(largeStatus, "refused", "a pack larger than the missing sparks is refused")
	local packOver, overStatus = Shop.receipt(nearly, "p-4", "sparks15", DAY, sparkIds, Upgrades)
	t.equal(overStatus, "granted", "the missing sparks are met")
	local _, doneStatus = Shop.receipt(packOver, "p-5", "sparks5", DAY, sparkIds, Upgrades)
	t.equal(doneStatus, "refused", "nothing is missing any more: even the small pack is refused")
	local _, _, noneReason = Shop.purchase(packOver, "sparks5", DAY, Catalogue, Upgrades)
	t.equal(noneReason, "sparks not needed", "the reason says the sparks are not needed")
	local _, _, blindReason = Shop.purchase(base, "sparks5", DAY, Catalogue)
	t.equal(blindReason, "no upgrades", "without the upgrade list a pack is refused")
	-- The Extras facts: the grid level and the missing sparks.
	local facts = Shop.extrasView(nearly, DAY, Catalogue, true, 0, Upgrades)
	t.equal(facts.sparksMissing, 15, "the Extras facts hold the missing sparks")
	t.equal(facts.level, 0, "and the grid level")

	-- Permanent plants (issue 252): 2, 5, 12, 29, 69 and 159 Robux each, ten for 19, 45, 109, 259, 619 and 1429.
	local single = { 2, 5, 12, 29, 69, 159 }
	local tens = { 19, 45, 109, 259, 619, 1429 }
	-- Product IDs read from the Creator Hub (permanent plant products), keyed by offer id.
	local productIds = {
		perm1 = 3734152391,
		perm1x10 = 3734152514,
		perm2 = 3734152579,
		perm2x10 = 3734152954,
		perm3 = 3734153153,
		perm3x10 = 3734153895,
		perm4 = 3734154151,
		perm4x10 = 3734154228,
		perm5 = 3734154380,
		perm5x10 = 3734154462,
		perm6 = 3734154528,
		perm6x10 = 3734154630,
	}
	local seenPlants = 0
	for _, offer in Catalogue.offers do
		if offer.plant ~= nil then
			seenPlants += 1
			local price = if offer.count == 1 then single[offer.plant] else tens[offer.plant]
			t.truthy(offer.count == 1 or offer.count == 10, `{offer.id}: one plant or ten`)
			t.equal(offer.robux, price, `{offer.id}: its Robux price`)
			t.equal(offer.robloxId, productIds[offer.id], `{offer.id}: its Creator Hub product ID`)
			t.equal(offer.type, "product", `{offer.id}: a product`)
		end
	end
	t.equal(seenPlants, 12, "twelve permanent plant products")
	t.equal(Catalogue.permanentLimit, 10, "at most ten permanent plants per type")

	-- The unlock rule: a type can be bought only after it was built once.
	local fresh = Data.template()
	local _, _, notBuilt = Shop.purchase(fresh, "perm1", DAY, Catalogue)
	t.equal(notBuilt, "not built", "a type never built cannot be bought")
	local _, notBuiltStatus = Shop.receipt(fresh, "q-0", "perm1", DAY, Catalogue)
	t.equal(notBuiltStatus, "refused", "and its receipt is refused")
	t.equal(next(Shop.permanentOffers(fresh, Catalogue)), nil, "no permanent plant offer before something was built")
	local builder = Data.template()
	builder.built[1], builder.built[3] = true, true
	t.truthy(Shop.permanentOffers(builder, Catalogue).perm1x10 == true, "a built type offers its pack")
	t.truthy(Shop.permanentOffers(builder, Catalogue).perm2 == nil, "a type not built offers nothing")
	t.equal(Shop.purchase(builder, "perm2", DAY, Catalogue), builder, "a refused purchase returns the input")

	-- The grant: the count of that type goes up by the units of the offer, only that type, the input stays.
	local permIds = withIds({ perm1 = 7001, perm1x10 = 7002, perm3 = 7003 })
	local one, oneStatus, oneYield = Shop.receipt(builder, "q-1", "perm1", DAY, permIds)
	t.equal(oneStatus, "granted", "a permanent plant receipt is granted")
	t.equal(oneYield, 0, "it pays no yield")
	t.equal(one.permanent[1], 1, "one unit of plant 1")
	t.equal(one.permanent[3], 0, "no other type changes")
	t.equal(builder.permanent[1], 0, "the input profile is not changed")
	local repeated2, againPermStatus = Shop.receipt(one, "q-1", "perm1", DAY, permIds)
	t.equal(againPermStatus, "duplicate", "the same receipt again is a duplicate")
	t.equal(repeated2.permanent[1], 1, "and grants nothing more")
	local pack = Shop.receipt(builder, "q-2", "perm1x10", DAY, permIds)
	t.equal(pack.permanent[1], 10, "a pack grants ten")

	-- The limit: never more than ten per type; the pack is offered only while ten still fit.
	t.truthy(Shop.permanentOffers(one, Catalogue).perm1x10 == nil, "with one owned the pack of ten no longer fits")
	t.truthy(Shop.permanentOffers(one, Catalogue).perm1 == true, "but a single unit does")
	local nine = Data.template()
	nine.built[3], nine.permanent[3] = true, 9
	local ten, tenStatus = Shop.receipt(nine, "q-3", "perm3", DAY, permIds)
	t.equal(tenStatus, "granted", "the tenth unit is granted")
	t.equal(ten.permanent[3], 10, "ten permanent plants")
	local overLimit, overPermStatus = Shop.receipt(ten, "q-4", "perm3", DAY, permIds)
	t.equal(overPermStatus, "refused", "an eleventh unit is refused")
	t.equal(overLimit, ten, "and nothing changes")
	local _, _, limitReason = Shop.purchase(pack, "perm1", DAY, Catalogue)
	t.equal(limitReason, "permanent limit", "the reason names the limit")
	t.equal(next(Shop.permanentOffers(ten, Catalogue)), nil, "a full type has no offer")

	-- The env carries the counts to the run start; the Extras facts carry the open offers.
	t.equal(Shop.envValues(one, Catalogue, false, false).permanent[1], 1, "envValues holds the permanent plants")
	t.truthy(
		Shop.extrasView(builder, DAY, Catalogue, true, 0).permanent.perm1 == true,
		"the Extras facts hold the offers"
	)
	local planted = Shop.permanentPlant(Catalogue, "perm3x10")
	t.truthy(planted ~= nil and planted.id == 3 and planted.count == 10, "permanentPlant names plant and units")
	t.equal(Shop.permanentPlant(Catalogue, "timeskip"), nil, "another offer is no permanent plant")
end
