--!strict
-- Shop effects (Bauplan.md, section 4): owned passes, the booster queue, the daily limits and what a purchase does.
-- Pure: no Roblox APIs, no clock, no DataStore. The day is passed in (whole days since the epoch, from the server) and
-- the catalogue is Config/Shop, passed in because core modules do not require each other. The input is never changed:
-- purchase and advance return a new profile; an invalid request returns the input and a reason.
-- Multipliers: premium sale ×1,5; booster ×2 on generation (Sunshine Hour) or own income (Turbo Feed-in); the bought
-- multipliers together are capped at multiplierCap. Only the first entry of the queue is active, so boosters never
-- stack in strength, only in duration.
local Shop = {}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isDay(value: any): boolean
	return isFinite(value) and value >= 0 and value == math.floor(value)
end

local function findOffer(shop: any, id: any): any?
	for _, offer in shop.offers do
		if offer.id == id then
			return offer
		end
	end
	return nil
end

-- Seconds in the booster queue, all entries together.
function Shop.boosterStock(profile: any): number
	local total = 0
	for _, entry in profile.boosters do
		total += entry.left
	end
	return total
end

-- The kind of the active booster ("sunshine" or "turbo"), or nil when the queue is empty.
function Shop.activeBooster(profile: any): string?
	local first = profile.boosters[1]
	if first == nil then
		return nil
	end
	return first.kind
end

-- The sparks still missing for every permanent node and spark item: their total cost minus the sparks earned and bought
-- so far (`profile.sparks` holds both). `upgrades` is Config/Upgrades. Never below 0.
function Shop.sparksMissing(profile: any, upgrades: any): number
	local total = 0
	for _, list in { upgrades.permanent, upgrades.spark or {} } do
		for _, node in list do
			total += node.sparks
		end
	end
	return math.max(0, total - profile.sparks)
end

-- The sparks a pack gives (0 for any other offer).
function Shop.packSparks(shop: any, offerId: any): number
	local offer = findOffer(shop, offerId)
	if offer == nil or offer.sparks == nil then
		return 0
	end
	return offer.sparks
end

-- Skips still allowed on this day. With dailyLimits off, there is no limit.
function Shop.skipsLeft(profile: any, day: number, shop: any): number
	if not shop.dailyLimits then
		return math.huge
	end
	local used = 0
	if profile.daily.day == day then
		used = profile.daily.skips
	end
	return math.max(0, shop.skipsPerDay - used)
end

-- Grid VIP: one free Turbo Feed-in per server day. True when the pass is owned and today's Turbo is not taken yet.
function Shop.freeTurboReady(profile: any, day: number): boolean
	return isDay(day) and profile.passes.grid_vip == true and profile.daily.turboDay ~= day
end

-- Takes today's free Turbo: the profile with the day written, and nil; or the input and the reason ("invalid day", "no
-- pass", "already taken"). Starting the Turbo itself is up to the caller (the same booster the shop sells).
function Shop.claimFreeTurbo(profile: any, day: any): (any, string?)
	if not isDay(day) then
		return profile, "invalid day"
	end
	if profile.passes.grid_vip ~= true then
		return profile, "no pass"
	end
	if profile.daily.turboDay == day then
		return profile, "already taken"
	end
	local result = copy(profile)
	result.daily.turboDay = day
	return result, nil
end

-- What the Extras tab needs from the profile: the passes owned, the seconds in the booster queue and the Time Skips left
-- today (nil without a daily limit). `shown`: the tab may show at all, i.e. the shop is allowed for this player, the
-- tutorial is done and the time played reached the first hint minute (Config/Shop). That time is `playSeconds` of this session
-- plus what earlier sessions left in the profile, so the wait is once, not after every start.
function Shop.extrasView(
	profile: any,
	day: number,
	shop: any,
	allowed: boolean,
	playSeconds: number,
	upgrades: any?
): any
	local owned = {}
	for id, flag in profile.passes do
		if flag == true then
			owned[id] = true
		end
	end
	local skipsLeft = Shop.skipsLeft(profile, day, shop)
	return {
		shown = allowed
			and profile.tutorialDone == true
			and playSeconds + (profile.playSeconds or 0) >= shop.firstHintSeconds,
		owned = owned,
		stock = Shop.boosterStock(profile),
		freeTurbo = Shop.freeTurboReady(profile, day), -- Grid VIP: today's free Turbo can be taken (HUD button)
		skipsLeft = if skipsLeft == math.huge then nil else skipsLeft,
		-- Spark packs: shown from grid stage 1 on, and only while the sparks still missing cover the pack.
		level = profile.level,
		sparksMissing = if upgrades ~= nil then Shop.sparksMissing(profile, upgrades) else 0,
		-- Permanent plants: the units owned per plant and the offers that can be bought now (by offer id).
		permanent = Shop.permanentOffers(profile, shop),
	}
end

-- The plant id and the units of a permanent plant offer ({ id, count }), or nil for any other offer.
function Shop.permanentPlant(shop: any, offerId: any): { id: number, count: number }?
	local offer = findOffer(shop, offerId)
	if offer == nil or offer.plant == nil then
		return nil
	end
	return { id = offer.plant, count = offer.count }
end

-- The permanent plant offers (offer id -> true) that can be bought now: the type was built and the units still fit.
function Shop.permanentOffers(profile: any, shop: any): { [string]: boolean }
	local open = {}
	for _, offer in shop.offers do
		if offer.plant ~= nil and Shop.permanentRefusal(profile, offer, shop) == nil then
			open[offer.id] = true
		end
	end
	return open
end

-- Premium Tariff: the sale price ×1,5, else ×1.
function Shop.saleMultiplier(profile: any, shop: any): number
	if profile.passes.premium == true then
		return shop.premiumSale
	end
	return 1
end

-- Sunshine Hour: generation ×2 while it is the active booster, else ×1.
function Shop.generationMultiplier(profile: any, shop: any): number
	if Shop.activeBooster(profile) == "sunshine" then
		return shop.booster
	end
	return 1
end

-- Own income: the sale price and Turbo Feed-in ×2, together at most multiplierCap (×3).
function Shop.incomeMultiplier(profile: any, shop: any): number
	local factor = Shop.saleMultiplier(profile, shop)
	if Shop.activeBooster(profile) == "turbo" then
		factor *= shop.booster
	end
	return math.min(factor, shop.multiplierCap)
end

-- The values the server passes into GameCore.env: income (sale price, Premium and Turbo, at most multiplierCap),
-- boost (generation, Sunshine Hour; cut so that income x boost stays within multiplierCap), longMeter, ruleSlots
-- (nil without the Smart Hub: the core keeps its base), autoBuild, storageFactor (Mega Battery) and permanent
-- (the permanent plants per plant id). `sunshine` and `turbo` say which boosters run.
function Shop.envValues(profile: any, shop: any, sunshine: boolean, turbo: boolean): { [string]: any }
	local income = Shop.saleMultiplier(profile, shop)
	if turbo then
		income *= shop.booster
	end
	income = math.min(income, shop.multiplierCap)
	local boost = 1
	if sunshine then
		boost = math.min(shop.booster, math.max(1, shop.multiplierCap / income))
	end
	local slots, auto = Shop.smartHub(profile, shop)
	return {
		income = income,
		boost = boost,
		longMeter = Shop.offlineBonusHours(profile, shop) > 0,
		ruleSlots = if slots > 0 then slots else nil,
		autoBuild = auto,
		storageFactor = Shop.storageFactor(profile, shop),
		permanent = if profile.permanent ~= nil then table.clone(profile.permanent) else nil,
	}
end

-- Mega Battery: the factor on the storage capacity, else 1.
function Shop.storageFactor(profile: any, shop: any): number
	if profile.passes.mega_battery == true then
		return shop.megaBatteryFactor
	end
	return 1
end

-- Smart Hub: the rule slots and the auto-build it gives at once. With smartHubImmediate off it gives nothing.
function Shop.smartHub(profile: any, shop: any): (number, boolean)
	if profile.passes.smart_hub ~= true or not shop.smartHubImmediate then
		return 0, false
	end
	return shop.smartHubRuleSlots, true
end

-- Long Meter: hours added to the offline cap, else 0.
function Shop.offlineBonusHours(profile: any, shop: any): number
	if profile.passes.long_meter == true then
		return shop.longMeterHours
	end
	return 0
end

-- Crank turns per second at the current speed: the hand rate, plus the Auto Crank rate with the pass, at most crankLimit.
function Shop.crankSpeed(profile: any, shop: any): number
	local rate = shop.handCrankRate
	if profile.passes.auto_crank == true then
		rate += shop.autoCrankRate
	end
	return math.min(rate, shop.crankLimit)
end

-- Auto Crank: the cranks the server adds in a step of `dt` seconds, and the fraction carried into the next step.
-- Without the pass: 0. With it: autoCrankRate per second, but hand and motor together at most crankLimit per second,
-- so `hand` (the hand cranks counted in this step) takes its share first. Nothing is owed for time offline.
function Shop.autoCranks(profile: any, shop: any, dt: number, hand: number, carry: number): (number, number)
	if profile.passes.auto_crank ~= true or not isFinite(dt) or dt <= 0 then
		return 0, 0
	end
	local want = carry + shop.autoCrankRate * dt
	local room = math.max(0, math.floor(shop.crankLimit * dt - hand + 1e-9))
	local count = math.min(math.floor(want + 1e-9), room)
	return count, math.min(want - count, shop.autoCrankRate)
end

-- Consumes `seconds` from the front of the booster queue. Finished entries are dropped; the rest keep their length.
function Shop.advance(profile: any, seconds: any): any
	if not isFinite(seconds) or seconds <= 0 then
		return profile
	end
	local result = copy(profile)
	local rest = seconds
	local queue = {}
	for _, entry in profile.boosters do
		if rest <= 0 then
			table.insert(queue, copy(entry))
		elseif entry.left > rest then
			table.insert(queue, { kind = entry.kind, left = entry.left - rest })
			rest = 0
		else
			rest -= entry.left
		end
	end
	result.boosters = queue
	return result
end

-- Why a permanent plant offer cannot be bought now, or nil: "not built" (the type has never been built) or "permanent
-- limit" (the units would pass shop.permanentLimit).
function Shop.permanentRefusal(profile: any, offer: any, shop: any): string?
	if profile.built[offer.plant] ~= true then
		return "not built"
	end
	if profile.permanent[offer.plant] + offer.count > shop.permanentLimit then
		return "permanent limit"
	end
	return nil
end

-- What buying an offer does, on the given day. Returns the new profile, the seconds of cut yield to pay out now
-- (0 for none) and nil. A refused purchase returns the input profile, 0 and the reason: "invalid day",
-- "unknown offer", "already owned", "booster stock full", "daily limit", "no upgrades", "sparks not needed" (a spark
-- pack needs `upgrades`, Config/Upgrades, and is bought only while the sparks still missing are at least its size).
-- Paying out the yield is up to the caller (GameCore.offline); a receipt is handled once, in ProcessReceipt.
function Shop.purchase(profile: any, offerId: any, day: any, shop: any, upgrades: any?): (any, number, string?)
	if not isDay(day) then
		return profile, 0, "invalid day"
	end
	local offer = findOffer(shop, offerId)
	if offer == nil then
		return profile, 0, "unknown offer"
	end
	local result = copy(profile)
	if offer.type == "pass" then
		if result.passes[offerId] == true then
			return profile, 0, "already owned"
		end
		result.passes[offerId] = true
		return result, offer.seconds or 0, nil
	end
	if offer.sparks ~= nil then
		if upgrades == nil then
			return profile, 0, "no upgrades"
		end
		if Shop.sparksMissing(profile, upgrades) < offer.sparks then
			return profile, 0, "sparks not needed"
		end
		result.sparks += offer.sparks
		result.sparksBought += offer.sparks
		return result, 0, nil
	end
	if offer.plant ~= nil then
		local reason = Shop.permanentRefusal(profile, offer, shop)
		if reason ~= nil then
			return profile, 0, reason
		end
		result.permanent[offer.plant] += offer.count
		return result, 0, nil
	end
	if offer.queued then
		if Shop.boosterStock(profile) + offer.seconds > shop.boosterStockSeconds then
			return profile, 0, "booster stock full"
		end
		table.insert(result.boosters, { kind = offerId, left = offer.seconds })
		return result, 0, nil
	end
	if offer.daily then
		if Shop.skipsLeft(profile, day, shop) < 1 then
			return profile, 0, "daily limit"
		end
		local used = 0
		if profile.daily.day == day then
			used = profile.daily.skips
		end
		result.daily = { day = day, skips = used + 1 }
	end
	return result, offer.seconds, nil
end

-- The yield of an owned pass that is still unpaid (Founder Pack: 30 minutes, once per profile). Returns the new profile
-- with the pass marked paid in `paid` (kept across sessions) and the seconds to pay out now; 0 and the input when the
-- pass is not owned, has no yield or was paid before. Paying out the coins is up to the caller.
function Shop.claimPassYield(profile: any, offerId: any, shop: any): (any, number)
	local offer = findOffer(shop, offerId)
	if offer == nil or offer.type ~= "pass" or offer.seconds == nil or profile.passes[offerId] ~= true then
		return profile, 0
	end
	if profile.paid[offerId] == true then
		return profile, 0
	end
	local result = copy(profile)
	result.paid[offerId] = true
	return result, offer.seconds
end

-- The product offer with this Roblox product ID, or nil. A placeholder ID (0) matches nothing, and passes never match.
function Shop.offerForProduct(shop: any, productId: any): string?
	if not isFinite(productId) then
		return nil
	end
	for _, offer in shop.offers do
		if offer.type == "product" and offer.robloxId > 0 and offer.robloxId == productId then
			return offer.id
		end
	end
	return nil
end

-- ProcessReceipt in the pure core: one receipt, one product offer. The receipt ID is written into `purchases` together
-- with the credit, so a receipt is credited once. Returns the new profile, the status and the seconds of cut yield:
-- "granted" (credited now), "duplicate" (the receipt is known: nothing changes), "refused" (no credit: no receipt ID, a
-- pass, an unknown offer or a limit; the input comes back). Paying out the yield is up to the caller.
function Shop.receipt(
	profile: any,
	receiptId: any,
	offerId: any,
	day: any,
	shop: any,
	upgrades: any?
): (any, string, number)
	if type(receiptId) ~= "string" or receiptId == "" then
		return profile, "refused", 0
	end
	for _, known in profile.purchases do
		if known == receiptId then
			return profile, "duplicate", 0
		end
	end
	local offer = findOffer(shop, offerId)
	if offer == nil or offer.type ~= "product" then
		return profile, "refused", 0
	end
	local result, seconds, reason = Shop.purchase(profile, offerId, day, shop, upgrades)
	if reason ~= nil then
		return profile, "refused", 0
	end
	table.insert(result.purchases, receiptId)
	return result, "granted", seconds
end

return Shop
