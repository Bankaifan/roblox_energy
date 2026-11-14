--!strict
-- Upgrade tree from Bauplan.md, section 2. Effects stay in the Bauplan; numbers, prerequisites, the English HUD name
-- and the short English effect text (info, at most 60 characters) here.
-- run: 22 run nodes, cost coins, reset on grid expansion.
-- permanent: 8 permanent nodes, cost sparks, kept forever.
-- requiresPlant: plant ID that must be owned once. requiresNode: ID of another run node.
local Upgrades = {}

Upgrades.run = {
	{ id = "U01", name = "Clean Modules", cost = 150, requiresPlant = 1, info = "Balcony Panel output x2" },
	{ id = "U02", name = "Ball Bearings", cost = 1200, requiresPlant = 2, info = "Water Wheel output x2" },
	{ id = "U03", name = "Tracking", cost = 12000, requiresPlant = 3, info = "Rooftop Solar output x2" },
	{ id = "U04", name = "Light Blades", cost = 130000, requiresPlant = 4, info = "Mini Turbine output x2" },
	{ id = "U05", name = "Cleaning Robot", cost = 1500000, requiresPlant = 5, info = "Solar Farm output x2" },
	{ id = "U06", name = "Gearless", cost = 16000000, requiresPlant = 6, info = "Wind Turbine output x2" },
	{ id = "U07", name = "Double Glass", cost = 60000, requiresNode = "U03", info = "Solar plants output x1.5" },
	{ id = "U08", name = "Taller Towers", cost = 700000, requiresNode = "U04", info = "Wind plants output x1.5" },
	{ id = "U09", name = "Grid Boost I", cost = 5000, info = "All output x1.25" },
	{ id = "U10", name = "Grid Boost II", cost = 250000, requiresNode = "U09", info = "All output x1.25" },
	{ id = "U11", name = "Grid Boost III", cost = 8000000, requiresNode = "U10", info = "All output x1.5" },
	{ id = "U12", name = "Crank Gear", cost = 50, info = "Crank gives 3 energy per click" },
	{ id = "U13", name = "Flywheel", cost = 2000, requiresNode = "U12", info = "Crank +2% of output per second" },
	{ id = "U14", name = "Direct Sales", cost = 3000, info = "Sale price +10%" },
	{ id = "U15", name = "Exchange Access", cost = 40000, requiresNode = "U14", info = "Sale +10%, next weather" },
	{ id = "U16", name = "Peak Contract", cost = 400000, requiresNode = "U15", info = "Evening price x1.25" },
	{ id = "U17", name = "Home Battery", cost = 2000, info = "Storage 1: 30 s of sun" },
	{ id = "U18", name = "Battery Expansion", cost = 30000, requiresNode = "U17", info = "Storage 2: 60 s of sun" },
	{ id = "U19", name = "District Storage", cost = 400000, requiresNode = "U18", info = "Storage 3: 100 s of sun" },
	{ id = "U20", name = "Large Storage", cost = 5000000, requiresNode = "U19", info = "Storage 4: 150 s of sun" },
	{ id = "U21", name = "Control Center", cost = 3000, requiresNode = "U17", info = "Two rule slots: charge, sell" },
	{ id = "U22", name = "New Cell Chemistry", cost = 150000, requiresNode = "U17", info = "Storage efficiency 95%" },
}

Upgrades.permanent = {
	{ id = "P1", sparks = 3, info = "Every run starts with 1,000 coins" },
	{ id = "P2", sparks = 5, info = "Offline cap 4 hours" },
	{ id = "P3", sparks = 8, info = "Unlocks auto-build" },
	{ id = "P4", sparks = 12, info = "Offline efficiency 75%" },
	{ id = "P5", sparks = 18, info = "Storage nodes and Control Center kept on grid expansion" },
	{ id = "P6", sparks = 25, info = "Offline cap 8 hours" },
	{ id = "P7", sparks = 44, info = "Milestones give x2.5 instead of x2" },
	{ id = "P8", sparks = 70, info = "All three rules run at the same time" },
}

return Upgrades
