--!strict
-- Robux offers the shop may show (issue 244): an offer is shown only with a real Roblox ID and a price that Roblox
-- reported at runtime. Regional pricing makes the price differ per player, so `robux` in Config/Shop is only the plan
-- and never reaches the screen. Pure Luau, no Roblox APIs: the client controller fetches `prices` (Roblox ID -> Robux).
local Offers = {}

export type Entry = { id: string, type: string, robloxId: number, name: string, price: number, priceText: string }

local function validPrice(price: any): boolean
	return type(price) == "number" and price == price and price >= 0 and price < math.huge
end

-- The price Roblox reported for this offer, or nil when it has no ID or no fetched price.
function Offers.priceOf(offer: any, prices: { [number]: number }): number?
	if type(offer.robloxId) ~= "number" or offer.robloxId <= 0 then
		return nil
	end
	local price = prices[offer.robloxId]
	if validPrice(price) then
		return price
	end
	return nil
end

-- The price line of an offer, "R$ 59".
function Offers.priceText(price: number): string
	return `R$ {math.floor(price + 0.5)}`
end

-- The offers to show, in catalogue order: only those with a fetched price. `lang` picks the name ("de" or "en").
function Offers.visible(shop: any, prices: { [number]: number }, lang: string): { Entry }
	local list: { Entry } = {}
	for _, offer in shop.offers do
		local price = Offers.priceOf(offer, prices)
		if price ~= nil then
			table.insert(list, {
				id = offer.id,
				type = offer.type,
				robloxId = offer.robloxId,
				name = if lang == "de" then offer.de else offer.en,
				price = price,
				priceText = Offers.priceText(price),
			})
		end
	end
	return list
end

-- Whether a purchase prompt may open for this offer: the same rule as `visible`.
function Offers.canPrompt(shop: any, offerId: string, prices: { [number]: number }): boolean
	for _, offer in shop.offers do
		if offer.id == offerId then
			return Offers.priceOf(offer, prices) ~= nil
		end
	end
	return false
end

return Offers
