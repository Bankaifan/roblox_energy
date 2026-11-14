--!strict
-- Day phases from Bauplan.md, section 2 (day and night). One day lasts 480 seconds. label: the English name in the HUD.
return {
	{ id = "Morgen", label = "Morning", duration = 60, solar = 0.5, price = 1.2 },
	{ id = "Mittag", label = "Midday", duration = 150, solar = 1.0, price = 0.7 },
	{ id = "Abend", label = "Evening", duration = 90, solar = 0.3, price = 1.8 },
	{ id = "Nacht", label = "Night", duration = 180, solar = 0.1, price = 1.0 },
}
