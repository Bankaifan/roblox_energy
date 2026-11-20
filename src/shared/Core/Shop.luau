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
-- (nil without the Smart Hub: the core keeps its base) and autoBuild. `sunshine` and `turbo` say which boosters run.
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
	}
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

-- What buying an offer does, on the given day. Returns the new profile, the seconds of cut yield to pay out now
-- (0 for none) and nil. A refused purchase returns the input profile, 0 and the reason: "invalid day",
-- "unknown offer", "already owned", "booster stock full", "daily limit".
-- Paying out the yield is up to the caller (GameCore.offline); a receipt is handled once, in ProcessReceipt.
function Shop.purchase(profile: any, offerId: any, day: any, shop: any): (any, number, string?)
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
function Shop.receipt(profile: any, receiptId: any, offerId: any, day: any, shop: any): (any, string, number)
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
	local result, seconds, reason = Shop.purchase(profile, offerId, day, shop)
	if reason ~= nil then
		return profile, "refused", 0
	end
	table.insert(result.purchases, receiptId)
	return result, "granted", seconds
end

return Shop
