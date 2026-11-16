--!strict
-- Tool models for the tool belt (one Roblox Tool per owned tool of Config/Land). Plain tables, no logic, no assets.
-- parts: the first part is the Handle (at the origin, shaft along y; -z points away from the player); every other part
-- is welded to it. size and at are studs, turn is degrees about x, y, z, color is RGB, material an Enum.Material name,
-- shape "Cylinder" has its axis along x. grip: where the hand holds the Handle, in studs along y from its centre.
local WOOD = { 150, 105, 60 }
local STEEL = { 165, 170, 178 }
local DARK = { 60, 62, 66 }
local RED = { 190, 50, 45 }

return {
	scythe = {
		grip = -0.6,
		parts = {
			{ name = "Shaft", size = { 0.2, 4.2, 0.2 }, at = { 0, 0, 0 }, color = WOOD, material = "Wood" },
			{ name = "Grip", size = { 0.18, 0.18, 0.7 }, at = { 0, 0.4, -0.35 }, color = WOOD, material = "Wood" },
			{
				name = "Blade",
				size = { 0.08, 0.38, 1.3 },
				at = { 0, 2, -0.65 },
				turn = { -8, 0, 0 },
				color = STEEL,
				material = "Metal",
			},
			{
				name = "BladeTip",
				size = { 0.08, 0.26, 1 },
				at = { 0, 1.66, -1.73 },
				turn = { -30, 0, 0 },
				color = STEEL,
				material = "Metal",
			},
		},
	},
	rails = {
		grip = 0,
		parts = {
			{ name = "Rail", size = { 0.15, 3, 0.15 }, at = { 0, 0, 0 }, color = STEEL, material = "Metal" },
			{ name = "Rail2", size = { 0.15, 3, 0.15 }, at = { 0.25, 0, 0 }, color = STEEL, material = "Metal" },
			{ name = "Clamp", size = { 0.5, 0.15, 0.22 }, at = { 0.125, 0.8, 0 }, color = DARK, material = "Metal" },
			{ name = "Clamp2", size = { 0.5, 0.15, 0.22 }, at = { 0.125, -0.8, 0 }, color = DARK, material = "Metal" },
		},
	},
	shovel = {
		grip = -0.4,
		parts = {
			{ name = "Shaft", size = { 0.2, 3.4, 0.2 }, at = { 0, 0, 0 }, color = WOOD, material = "Wood" },
			{ name = "Grip", size = { 0.6, 0.16, 0.16 }, at = { 0, -1.75, 0 }, color = WOOD, material = "Wood" },
			{ name = "Blade", size = { 0.75, 0.95, 0.08 }, at = { 0, 2.1, 0 }, color = STEEL, material = "Metal" },
		},
	},
	hammer = {
		grip = -0.5,
		parts = {
			{ name = "Shaft", size = { 0.2, 1.8, 0.2 }, at = { 0, 0, 0 }, color = WOOD, material = "Wood" },
			{ name = "Head", size = { 0.45, 0.45, 1 }, at = { 0, 0.9, 0 }, color = DARK, material = "Metal" },
		},
	},
	wrench = {
		grip = -0.5,
		parts = {
			{ name = "Body", size = { 0.25, 1.8, 0.1 }, at = { 0, 0, 0 }, color = STEEL, material = "Metal" },
			{ name = "Head", size = { 0.65, 0.2, 0.1 }, at = { 0, 0.95, 0 }, color = STEEL, material = "Metal" },
			{ name = "Jaw", size = { 0.18, 0.4, 0.1 }, at = { -0.235, 1.2, 0 }, color = STEEL, material = "Metal" },
			{ name = "Jaw2", size = { 0.18, 0.4, 0.1 }, at = { 0.235, 1.2, 0 }, color = STEEL, material = "Metal" },
		},
	},
	drum = {
		grip = 0,
		parts = {
			{
				name = "Cable",
				size = { 0.8, 1.5, 1.5 },
				at = { 0, 0, 0 },
				color = DARK,
				material = "Plastic",
				shape = "Cylinder",
			},
			{
				name = "Flange",
				size = { 0.1, 2, 2 },
				at = { -0.45, 0, 0 },
				color = WOOD,
				material = "Wood",
				shape = "Cylinder",
			},
			{
				name = "Flange2",
				size = { 0.1, 2, 2 },
				at = { 0.45, 0, 0 },
				color = WOOD,
				material = "Wood",
				shape = "Cylinder",
			},
		},
	},
	tamper = {
		grip = 0.6,
		parts = {
			{ name = "Shaft", size = { 0.2, 3.4, 0.2 }, at = { 0, 0, 0 }, color = WOOD, material = "Wood" },
			{ name = "Grip", size = { 0.8, 0.16, 0.16 }, at = { 0, 1.75, 0 }, color = WOOD, material = "Wood" },
			{ name = "Plate", size = { 0.9, 0.3, 0.9 }, at = { 0, -1.85, 0 }, color = DARK, material = "Metal" },
		},
	},
	pliers = {
		grip = -0.1,
		parts = {
			{ name = "Leg", size = { 0.12, 1, 0.12 }, at = { 0, 0, 0 }, color = RED, material = "Plastic" },
			{
				name = "Leg2",
				size = { 0.12, 1, 0.12 },
				at = { 0.3, 0, 0 },
				turn = { 0, 0, 14 },
				color = RED,
				material = "Plastic",
			},
			{ name = "Jaws", size = { 0.24, 0.5, 0.1 }, at = { 0.1, 0.72, 0 }, color = STEEL, material = "Metal" },
		},
	},
} :: { [string]: { grip: number, parts: { any } } }
