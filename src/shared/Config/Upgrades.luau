--!strict
-- Upgrade tree from Bauplan.md, section 2. Names and effects stay in the Bauplan; only numbers and prerequisites here.
-- run: 22 run nodes, cost coins, reset on grid expansion.
-- permanent: 8 permanent nodes, cost sparks, kept forever.
-- requiresPlant: plant ID that must be owned once. requiresNode: ID of another run node.
local Upgrades = {}

Upgrades.run = {
	{ id = "U01", cost = 150, requiresPlant = 1 },
	{ id = "U02", cost = 1200, requiresPlant = 2 },
	{ id = "U03", cost = 12000, requiresPlant = 3 },
	{ id = "U04", cost = 130000, requiresPlant = 4 },
	{ id = "U05", cost = 1500000, requiresPlant = 5 },
	{ id = "U06", cost = 16000000, requiresPlant = 6 },
	{ id = "U07", cost = 60000, requiresNode = "U03" },
	{ id = "U08", cost = 700000, requiresNode = "U04" },
	{ id = "U09", cost = 5000 },
	{ id = "U10", cost = 250000, requiresNode = "U09" },
	{ id = "U11", cost = 8000000, requiresNode = "U10" },
	{ id = "U12", cost = 50 },
	{ id = "U13", cost = 2000, requiresNode = "U12" },
	{ id = "U14", cost = 3000 },
	{ id = "U15", cost = 40000, requiresNode = "U14" },
	{ id = "U16", cost = 400000, requiresNode = "U15" },
	{ id = "U17", cost = 2000 },
	{ id = "U18", cost = 30000, requiresNode = "U17" },
	{ id = "U19", cost = 400000, requiresNode = "U18" },
	{ id = "U20", cost = 5000000, requiresNode = "U19" },
	{ id = "U21", cost = 3000, requiresNode = "U17" },
	{ id = "U22", cost = 150000, requiresNode = "U17" },
}

Upgrades.permanent = {
	{ id = "P1", sparks = 3 },
	{ id = "P2", sparks = 5 },
	{ id = "P3", sparks = 8 },
	{ id = "P4", sparks = 12 },
	{ id = "P5", sparks = 18 },
	{ id = "P6", sparks = 25 },
	{ id = "P7", sparks = 44 },
	{ id = "P8", sparks = 70 },
}

return Upgrades
