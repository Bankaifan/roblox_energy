--!strict
-- The monetisation catalogue (Bauplan.md, section 4): the 11 offers with their Robux prices and English and German
-- names, and the product defaults of section 10 (open questions 1 and 2), which Daniel can flip here. Pass and product
-- IDs are 0 until Daniel fills them in from the Creator Hub. Read by Core/Shop and Core/Hints.
return {
	-- Product defaults: daily limits on, Smart Hub extras immediately.
	dailyLimits = true, -- off: Time Skips are not limited per day
	skipsPerDay = 3, -- Zeitsprung per day
	boosterStockSeconds = 3600, -- the booster queue holds at most 60 minutes
	smartHubImmediate = true, -- off: the Smart Hub gives no extras, they come from P3 and P8 only
	firstHintSeconds = 720, -- no purchase hint before minute 12 of play

	-- Effects
	premiumSale = 1.5, -- Premium-Tarif: sale price ×1,5
	booster = 2, -- Sunshine Hour (generation) and Turbo Feed-in (own income): ×2
	multiplierCap = 3, -- the bought multipliers together, at most ×3
	smartHubRuleSlots = 3, -- Smart-Zentrale: third rule slot
	longMeterHours = 4, -- Langzeit-Zähler: offline cap +4 hours

	-- type: "pass" (owned once) or "product" (bought again and again). seconds: cut yield or booster length.
	-- queued: the booster joins the queue. daily: counted against skipsPerDay.
	offers = {
		{
			id = "founder",
			type = "pass",
			robux = 59,
			robloxId = 0,
			en = "Founder Pack",
			de = "Gründer-Paket",
			seconds = 1800,
		},
		{ id = "smart_hub", type = "pass", robux = 149, robloxId = 0, en = "Smart Hub", de = "Smart-Zentrale" },
		{ id = "long_meter", type = "pass", robux = 99, robloxId = 0, en = "Long Meter", de = "Langzeit-Zähler" },
		{ id = "premium", type = "pass", robux = 249, robloxId = 0, en = "Premium Tariff", de = "Premium-Tarif" },
		{ id = "grid_vip", type = "pass", robux = 299, robloxId = 0, en = "Grid VIP", de = "Netzbetreiber-VIP" },
		{ id = "neon", type = "pass", robux = 99, robloxId = 0, en = "Neon Plants", de = "Neon-Anlagen" },
		{
			id = "fireworks",
			type = "pass",
			robux = 79,
			robloxId = 0,
			en = "Upgrade Fireworks",
			de = "Ausbau-Feuerwerk",
		},
		{ id = "themes", type = "pass", robux = 129, robloxId = 0, en = "Plot Themes", de = "Themen-Grundstück" },
		{
			id = "sunshine",
			type = "product",
			robux = 79,
			robloxId = 0,
			en = "Sunshine Hour",
			de = "Sonnenstunde für alle",
			seconds = 600,
			queued = true,
		},
		{
			id = "turbo",
			type = "product",
			robux = 29,
			robloxId = 0,
			en = "Turbo Feed-in",
			de = "Turbo-Einspeisung",
			seconds = 900,
			queued = true,
		},
		{
			id = "timeskip",
			type = "product",
			robux = 49,
			robloxId = 0,
			en = "Time Skip",
			de = "Zeitsprung",
			seconds = 3600,
			daily = true,
		},
	},
}
