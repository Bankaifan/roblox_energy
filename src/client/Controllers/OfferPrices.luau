--!strict
-- Live Robux prices (issue 244): reads every offer's price from MarketplaceService once per session (pcall, cached), so
-- regional pricing shows the amount Roblox will charge. No game rules here: Core/Offers says which offers show and how
-- the price reads. An offer that failed to load stays hidden until the next fetch.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogue = require(Shared:WaitForChild("Config"):WaitForChild("Shop") :: ModuleScript) :: any
local Offers = require(Shared:WaitForChild("Core"):WaitForChild("Offers") :: ModuleScript) :: any

local OfferPrices = {}

local prices: { [number]: number } = {}
local icons: { [number]: string } = {}
local pending: { [number]: boolean } = {}

-- Fetches the price of every offer with an ID that has none yet. Blocks while Roblox answers; call it from a task.
function OfferPrices.fetch()
	for _, offer in Catalogue.offers do
		local id: number = offer.robloxId
		if id > 0 and prices[id] == nil and not pending[id] then
			pending[id] = true
			local kind = if offer.type == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, kind)
			end)
			pending[id] = nil
			if ok and type(info) == "table" and info.IsForSale ~= false and type(info.PriceInRobux) == "number" then
				prices[id] = info.PriceInRobux
				if type(info.IconImageAssetId) == "number" and info.IconImageAssetId > 0 then
					icons[id] = "rbxassetid://" .. info.IconImageAssetId
				end
			end
		end
	end
end

-- The store icon of an offer (its Creator Hub image), or nil while unknown.
function OfferPrices.icon(offerId: string): string?
	for _, offer in Catalogue.offers do
		if offer.id == offerId then
			return icons[offer.robloxId]
		end
	end
	return nil
end

-- The offers to show now, with their live price text.
function OfferPrices.visible(lang: string): { Offers.Entry }
	return Offers.visible(Catalogue, prices, lang)
end

-- Opens the purchase prompt for an offer, only when it is shown (an ID and a fetched price).
function OfferPrices.prompt(player: Player, offerId: string): boolean
	if not Offers.canPrompt(Catalogue, offerId, prices) then
		return false
	end
	for _, offer in Catalogue.offers do
		if offer.id == offerId then
			if offer.type == "pass" then
				MarketplaceService:PromptGamePassPurchase(player, offer.robloxId)
			else
				MarketplaceService:PromptProductPurchase(player, offer.robloxId)
			end
			return true
		end
	end
	return false
end

return OfferPrices
