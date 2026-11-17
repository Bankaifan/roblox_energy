--!strict
-- Land development (docs/design/0018-land-development.md, section 4). Plain tables, no logic.
-- required: the land gates (a site before the first plant, the container before U17, wiring before rule slots) apply
-- only when true. Setting it to false is the rollback: buying works without sites again.
-- unitsPerSite: with a number, a plant can be bought only while owned < mown cells x unitsPerSite. The fields hold 54
-- cells in all, the balance bots own 40 to 70 units of every plant by stage 6, so 1 would stop the run at stage 3.
-- fields[plant id]: how many cells the field has (a prepared cell is one site).
-- chains[plant id]: the stages of one cell, each { tool, hold } (docs/land-development-design-v2.md, section 2). A cell is
--   worked stage by stage and each stage needs its tool; the cell is prepared when its last stage is done.
-- downstream[plant id]: true when cell k can be worked only after cell k - 1 is done (the river, dug from the spring).
-- tools: id, the plant it serves (plant) or the node it needs (node), price in coins (run-1 cost, kept after a prestige),
--   hold seconds per prepared site, textKey for the one-line market text.
-- container: the storage container (coins, Speicher tab); U17 needs it.
-- sites[field]: how many cells are prepared; cells[field]: the started cells (PlotLayout numbers), the prepared ones first in
--   the order they were finished, then those still in work; steps[field][i]: stages done of cells[field][i].
-- start: the land of a fresh profile.
return {
	required = true,
	unitsPerSite = nil, -- nil: a plant needs one mown cell, not one per unit. 1: every unit needs a mown cell of its own (see PR)
	fields = { 25, 7, 7, 7, 4, 4 },
	tools = {
		{ id = "scythe", plant = 1, price = 0, hold = 1, textKey = "tool.scythe" },
		{ id = "rails", plant = 1, price = 300, hold = 0, textKey = "tool.rails" },
		{ id = "shovel", plant = 2, price = 30, hold = 1, textKey = "tool.shovel" },
		{ id = "hammer", plant = 3, price = 250, hold = 2.5, textKey = "tool.hammer" },
		{ id = "wrench", plant = 4, price = 2500, hold = 1.5, textKey = "tool.wrench" },
		{ id = "drum", plant = 5, price = 25000, hold = 3, textKey = "tool.cableDrum" },
		{ id = "tamper", plant = 6, price = 250000, hold = 4, textKey = "tool.tamper" },
		{ id = "pliers", node = "U21", price = 600, hold = 2, textKey = "tool.pliers" },
	},
	chains = {
		{ { tool = "scythe", hold = 1 } },
		{ { tool = "shovel", hold = 1 }, { tool = "shovel", hold = 1 } },
		{ { tool = "scythe", hold = 1 }, { tool = "hammer", hold = 2.5 } },
		{ { tool = "scythe", hold = 1 }, { tool = "wrench", hold = 1.5 } },
		{ { tool = "scythe", hold = 1 }, { tool = "hammer", hold = 2.5 }, { tool = "drum", hold = 3 } },
		{ { tool = "scythe", hold = 1 }, { tool = "tamper", hold = 4 }, { tool = "drum", hold = 3 } },
	},
	downstream = { [2] = true },
	-- The tool that comes with each field (index = plant id): bought with its plant and named on its card.
	fieldTools = { "scythe", "shovel", "hammer", "wrench", "drum", "tamper" },
	containerCost = 500,
	start = {
		sites = { 0, 0, 0, 0, 0, 0 },
		cells = { {}, {}, {}, {}, {}, {} },
		steps = { {}, {}, {}, {}, {}, {} },
		tools = { scythe = true },
		container = false,
		wired = false,
		market = false,
	},
}
