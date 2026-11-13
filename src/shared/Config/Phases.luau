--!strict
-- Day phases from Bauplan.md, section 2 (day and night). One day lasts 480 seconds.
return {
	{ id = "Morgen", duration = 60, solar = 0.5, price = 1.2 },
	{ id = "Mittag", duration = 150, solar = 1.0, price = 0.7 },
	{ id = "Abend", duration = 90, solar = 0.3, price = 1.8 },
	{ id = "Nacht", duration = 180, solar = 0.1, price = 1.0 },
}
