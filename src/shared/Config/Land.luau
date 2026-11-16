--!strict
-- Land development (docs/design/0018-land-development.md, section 4). Plain tables, no logic.
-- required: the land gates (a site before the first plant, the container before U17, wiring before rule slots) apply
-- only when true; the last step of the design turns it on.
-- fields[plant id]: how many sites the field has (the units that can stand on it).
-- tools: id, the plant it serves (plant) or the node it needs (node), price in coins (run-1 cost, kept after a prestige),
--   hold seconds per prepared site, textKey for the one-line market text.
-- container: the storage container (coins, Speicher tab); U17 needs it.
-- start: the land of a fresh profile.
return {
	required = false,
	fields = { 24, 12, 8, 12, 4, 4 },
	tools = {
		{ id = "scythe", plant = 1, price = 0, hold = 1, textKey = "tool.scythe" },
		{ id = "rails", plant = 1, price = 300, hold = 0, textKey = "tool.rails" },
		{ id = "shovel", plant = 2, price = 30, hold = 1.5, textKey = "tool.shovel" },
		{ id = "hammer", plant = 3, price = 250, hold = 2.5, textKey = "tool.hammer" },
		{ id = "wrench", plant = 4, price = 2500, hold = 1.5, textKey = "tool.wrench" },
		{ id = "drum", plant = 5, price = 25000, hold = 3, textKey = "tool.cableDrum" },
		{ id = "tamper", plant = 6, price = 250000, hold = 4, textKey = "tool.tamper" },
		{ id = "pliers", node = "U21", price = 600, hold = 2, textKey = "tool.pliers" },
	},
	-- The tool that prepares each field (index = plant id).
	fieldTools = { "scythe", "shovel", "hammer", "wrench", "drum", "tamper" },
	containerCost = 500,
	start = {
		sites = { 0, 0, 0, 0, 0, 0 },
		tools = { scythe = true },
		container = false,
		wired = false,
		market = false,
	},
}
