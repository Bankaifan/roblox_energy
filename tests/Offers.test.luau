--!strict
-- Offers.visible: only offers with a Roblox ID and a fetched price are shown, with the price Roblox reported.
return function(t, load)
	local Offers = load("Core/Offers")
	local shop = {
		offers = {
			{ id = "a", type = "pass", robux = 59, robloxId = 11, en = "Alpha", de = "Alfa" },
			{ id = "b", type = "pass", robux = 99, robloxId = 0, en = "Beta", de = "Beta" },
			{ id = "c", type = "product", robux = 29, robloxId = 33, en = "Gamma", de = "Gamma" },
		},
	}

	local shown = Offers.visible(shop, { [11] = 47, [33] = 29.4 }, "en")
	t.equal(#shown, 2, "the offer without an ID is hidden")
	t.equal(shown[1].priceText, "R$ 47", "the price is the fetched one, not the planned 59")
	t.equal(shown[2].id, "c", "catalogue order is kept")
	t.equal(shown[2].priceText, "R$ 29", "a fractional price is rounded")
	t.equal(Offers.visible(shop, { [11] = 47 }, "de")[1].name, "Alfa", "German name")

	t.equal(#Offers.visible(shop, {}, "en"), 0, "nothing is shown before a price is fetched")
	t.equal(#Offers.visible(shop, { [0] = 10, [11] = -1 }, "en"), 0, "ID 0 and a bad price never show")
	t.truthy(Offers.canPrompt(shop, "a", { [11] = 47 }), "a priced offer can be prompted")
	t.truthy(not Offers.canPrompt(shop, "a", {}), "no price, no prompt")
	t.truthy(not Offers.canPrompt(shop, "b", { [0] = 10 }), "ID 0 cannot be prompted")
	t.truthy(not Offers.canPrompt(shop, "zzz", { [11] = 47 }), "an unknown offer cannot be prompted")
end
