--!strict
-- Weather from Bauplan.md, section 3. share in percent, shares add up to 100.
-- Weather changes every 120 seconds (Bauplan, section 2).
return {
	{ id = "Sonnig", share = 40, solar = 1.0, wind = 0.6, price = 1.0 },
	{ id = "Bewoelkt", share = 25, solar = 0.5, wind = 1.0, price = 1.0 },
	{ id = "Windig", share = 20, solar = 0.8, wind = 1.6, price = 1.0 },
	{ id = "Gewitter", share = 10, solar = 0.2, wind = 2.0, price = 1.2 },
	{ id = "Flaute", share = 5, solar = 0.4, wind = 0.2, price = 1.5 },
}
