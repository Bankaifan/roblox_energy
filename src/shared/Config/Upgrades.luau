--!strict
-- Upgrade tree from Bauplan.md, section 2. Effects stay in the Bauplan; numbers, prerequisites and the English HUD name here.
-- run: 22 run nodes, cost coins, reset on grid expansion.
-- permanent: 8 permanent nodes, cost sparks, kept forever.
-- requiresPlant: plant ID that must be owned once. requiresNode: ID of another run node.
local Upgrades = {}

Upgrades.run = {
	{ id = "U01", name = "Clean Modules", cost = 150, requiresPlant = 1 },
	{ id = "U02", name = "Ball Bearings", cost = 1200, requiresPlant = 2 },
	{ id = "U03", name = "Tracking", cost = 12000, requiresPlant = 3 },
	{ id = "U04", name = "Light Blades", cost = 130000, requiresPlant = 4 },
	{ id = "U05", name = "Cleaning Robot", cost = 1500000, requiresPlant = 5 },
	{ id = "U06", name = "Gearless", cost = 16000000, requiresPlant = 6 },
	{ id = "U07", name = "Double Glass", cost = 60000, requiresNode = "U03" },
	{ id = "U08", name = "Taller Towers", cost = 700000, requiresNode = "U04" },
	{ id = "U09", name = "Grid Boost I", cost = 5000 },
	{ id = "U10", name = "Grid Boost II", cost = 250000, requiresNode = "U09" },
	{ id = "U11", name = "Grid Boost III", cost = 8000000, requiresNode = "U10" },
	{ id = "U12", name = "Crank Gear", cost = 50 },
	{ id = "U13", name = "Flywheel", cost = 2000, requiresNode = "U12" },
	{ id = "U14", name = "Direct Sales", cost = 3000 },
	{ id = "U15", name = "Exchange Access", cost = 40000, requiresNode = "U14" },
	{ id = "U16", name = "Peak Contract", cost = 400000, requiresNode = "U15" },
	{ id = "U17", name = "Home Battery", cost = 2000 },
	{ id = "U18", name = "Battery Expansion", cost = 30000, requiresNode = "U17" },
	{ id = "U19", name = "District Storage", cost = 400000, requiresNode = "U18" },
	{ id = "U20", name = "Large Storage", cost = 5000000, requiresNode = "U19" },
	{ id = "U21", name = "Control Center", cost = 3000, requiresNode = "U17" },
	{ id = "U22", name = "New Cell Chemistry", cost = 150000, requiresNode = "U17" },
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
