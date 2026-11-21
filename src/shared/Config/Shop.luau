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
	permanentLimit = 10, -- permanent plants per type, bought with Robux

	-- Effects
	premiumSale = 1.5, -- Premium-Tarif: sale price ×1,5
	booster = 2, -- Sunshine Hour (generation) and Turbo Feed-in (own income): ×2
	multiplierCap = 3, -- the bought multipliers together, at most ×3
	smartHubRuleSlots = 3, -- Smart-Zentrale: third rule slot
	longMeterHours = 4, -- Langzeit-Zähler: offline cap +4 hours
	autoCrankRate = 4, -- Kurbelmotor: cranks per second added by the server while the owner is online
	megaBatteryFactor = 1.5, -- Riesenbatterie: storage capacity ×1,5 (measured at stage 4, docs/balance/report.md)
	handCrankRate = 2, -- turns per second a player cranking by hand is assumed to make (for the crank readout)
	crankLimit = 8, -- cranks per second at most, hand and Kurbelmotor together (the Net limit of "Crank")

	-- type: "pass" (owned once) or "product" (bought again and again). seconds: cut yield or booster length.
	-- queued: the booster joins the queue. daily: counted against skipsPerDay. sparks: a spark pack, adds that many
	-- sparks; granted only while the sparks still missing for all permanent nodes and spark items are at least that many.
	offers = {
		{
			id = "founder",
			type = "pass",
			robux = 59,
			robloxId = 2096875000,
			en = "Founder Pack",
			de = "Gründer-Paket",
			seconds = 1800,
		},
		{
			id = "smart_hub",
			type = "pass",
			robux = 199,
			robloxId = 2092415147,
			en = "Smart Hub",
			de = "Smart-Zentrale",
		},
		{
			id = "long_meter",
			type = "pass",
			robux = 129,
			robloxId = 2092793166,
			en = "Long Meter",
			de = "Langzeit-Zähler",
		},
		{ id = "auto_crank", type = "pass", robux = 129, robloxId = 2096623036, en = "Auto Crank", de = "Kurbelmotor" },
		{
			id = "mega_battery",
			type = "pass",
			robux = 249,
			robloxId = 2092751131,
			en = "Mega Battery",
			de = "Riesenbatterie",
		},
		{
			id = "premium",
			type = "pass",
			robux = 349,
			robloxId = 2092673252,
			en = "Premium Tariff",
			de = "Premium-Tarif",
		},
		{
			id = "grid_vip",
			type = "pass",
			robux = 399,
			robloxId = 2092403157,
			en = "Grid VIP",
			de = "Netzbetreiber-VIP",
		},
		{ id = "neon", type = "pass", robux = 99, robloxId = 2094533031, en = "Neon Plants", de = "Neon-Anlagen" },
		{
			id = "fireworks",
			type = "pass",
			robux = 79,
			robloxId = 2092283063,
			en = "Upgrade Fireworks",
			de = "Ausbau-Feuerwerk",
		},
		{
			id = "themes",
			type = "pass",
			robux = 129,
			robloxId = 2097016970,
			en = "Plot Themes",
			de = "Themen-Grundstück",
		},
		{
			id = "sunshine",
			type = "product",
			robux = 99,
			robloxId = 3734134439,
			en = "Sunshine Hour",
			de = "Sonnenstunde für alle",
			seconds = 600,
			queued = true,
		},
		{
			id = "turbo",
			type = "product",
			robux = 39,
			robloxId = 3734134487,
			en = "Turbo Feed-in",
			de = "Turbo-Einspeisung",
			seconds = 900,
			queued = true,
		},
		{
			id = "sparks5",
			type = "product",
			robux = 79,
			robloxId = 3734138157,
			en = "5 Sparks",
			de = "5 Funken",
			sparks = 5,
		},
		{
			id = "sparks15",
			type = "product",
			robux = 199,
			robloxId = 3734138182,
			en = "15 Sparks",
			de = "15 Funken",
			sparks = 15,
		},
		{
			id = "sparks40",
			type = "product",
			robux = 449,
			robloxId = 3734138203,
			en = "40 Sparks",
			de = "40 Funken",
			sparks = 40,
		},
		{
			id = "timeskip",
			type = "product",
			robux = 49,
			robloxId = 3734134518,
			en = "Time Skip",
			de = "Zeitsprung",
			seconds = 1200, -- 20 minutes of average yield at the full rate
			daily = true,
		},

		-- Permanent plants (issue 252): `plant` is the plant id, `count` the units granted. A bought unit is kept across grid
		-- expansions; at most permanentLimit per type, and a type can be bought once it has been built.
		{
			id = "perm1",
			type = "product",
			robux = 2,
			robloxId = 0,
			en = "Permanent Balcony Panel",
			de = "Stamm-Balkonmodul",
			plant = 1,
			count = 1,
		},
		{
			id = "perm1x10",
			type = "product",
			robux = 19,
			robloxId = 0,
			en = "10 Permanent Balcony Panels",
			de = "10 Stamm-Balkonmodul",
			plant = 1,
			count = 10,
		},
		{
			id = "perm2",
			type = "product",
			robux = 5,
			robloxId = 0,
			en = "Permanent Water Wheel",
			de = "Stamm-Wasserrad",
			plant = 2,
			count = 1,
		},
		{
			id = "perm2x10",
			type = "product",
			robux = 45,
			robloxId = 0,
			en = "10 Permanent Water Wheels",
			de = "10 Stamm-Wasserrad",
			plant = 2,
			count = 10,
		},
		{
			id = "perm3",
			type = "product",
			robux = 12,
			robloxId = 0,
			en = "Permanent Rooftop Solar",
			de = "Stamm-Dach-PV",
			plant = 3,
			count = 1,
		},
		{
			id = "perm3x10",
			type = "product",
			robux = 109,
			robloxId = 0,
			en = "10 Permanent Rooftop Solars",
			de = "10 Stamm-Dach-PV",
			plant = 3,
			count = 10,
		},
		{
			id = "perm4",
			type = "product",
			robux = 29,
			robloxId = 0,
			en = "Permanent Mini Turbine",
			de = "Stamm-Kleinwindrad",
			plant = 4,
			count = 1,
		},
		{
			id = "perm4x10",
			type = "product",
			robux = 259,
			robloxId = 0,
			en = "10 Permanent Mini Turbines",
			de = "10 Stamm-Kleinwindrad",
			plant = 4,
			count = 10,
		},
		{
			id = "perm5",
			type = "product",
			robux = 69,
			robloxId = 0,
			en = "Permanent Solar Farm",
			de = "Stamm-Solarpark",
			plant = 5,
			count = 1,
		},
		{
			id = "perm5x10",
			type = "product",
			robux = 619,
			robloxId = 0,
			en = "10 Permanent Solar Farms",
			de = "10 Stamm-Solarpark",
			plant = 5,
			count = 10,
		},
		{
			id = "perm6",
			type = "product",
			robux = 159,
			robloxId = 0,
			en = "Permanent Wind Turbine",
			de = "Stamm-Windrad",
			plant = 6,
			count = 1,
		},
		{
			id = "perm6x10",
			type = "product",
			robux = 1429,
			robloxId = 0,
			en = "10 Permanent Wind Turbines",
			de = "10 Stamm-Windrad",
			plant = 6,
			count = 10,
		},
	},
}
