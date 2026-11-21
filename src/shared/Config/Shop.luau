--!strict
-- The monetisation catalogue (Bauplan.md, section 4): the 14 offers with their Robux prices and English and German
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
	autoCrankRate = 4, -- Kurbelmotor: cranks per second added by the server while the owner is online
	megaBatteryFactor = 1.5, -- Riesenbatterie: storage capacity ×1,5 (measured at stage 4, docs/balance/report.md)
	crankLimit = 8, -- cranks per second at most, hand and Kurbelmotor together (the Net limit of "Crank")

	-- type: "pass" (owned once) or "product" (bought again and again). seconds: cut yield or booster length.
	-- queued: the booster joins the queue. daily: counted against skipsPerDay. sparks: a spark pack, adds that many
	-- sparks; granted only while the sparks still missing for all permanent nodes and spark items are at least that many.
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
		{ id = "smart_hub", type = "pass", robux = 199, robloxId = 0, en = "Smart Hub", de = "Smart-Zentrale" },
		{ id = "long_meter", type = "pass", robux = 129, robloxId = 0, en = "Long Meter", de = "Langzeit-Zähler" },
		{ id = "auto_crank", type = "pass", robux = 129, robloxId = 0, en = "Auto Crank", de = "Kurbelmotor" },
		{ id = "mega_battery", type = "pass", robux = 249, robloxId = 0, en = "Mega Battery", de = "Riesenbatterie" },
		{ id = "premium", type = "pass", robux = 349, robloxId = 0, en = "Premium Tariff", de = "Premium-Tarif" },
		{ id = "grid_vip", type = "pass", robux = 399, robloxId = 0, en = "Grid VIP", de = "Netzbetreiber-VIP" },
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
			robux = 99,
			robloxId = 0,
			en = "Sunshine Hour",
			de = "Sonnenstunde für alle",
			seconds = 600,
			queued = true,
		},
		{
			id = "turbo",
			type = "product",
			robux = 39,
			robloxId = 0,
			en = "Turbo Feed-in",
			de = "Turbo-Einspeisung",
			seconds = 900,
			queued = true,
		},
		{ id = "sparks5", type = "product", robux = 79, robloxId = 0, en = "5 Sparks", de = "5 Funken", sparks = 5 },
		{
			id = "sparks15",
			type = "product",
			robux = 199,
			robloxId = 0,
			en = "15 Sparks",
			de = "15 Funken",
			sparks = 15,
		},
		{
			id = "sparks40",
			type = "product",
			robux = 449,
			robloxId = 0,
			en = "40 Sparks",
			de = "40 Funken",
			sparks = 40,
		},
		{
			id = "timeskip",
			type = "product",
			robux = 49,
			robloxId = 0,
			en = "Time Skip",
			de = "Zeitsprung",
			seconds = 1200, -- 20 minutes of average yield at the full rate
			daily = true,
		},
	},
}
