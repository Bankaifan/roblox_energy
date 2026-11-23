--!strict
-- Builds the decoration of a plot theme (docs/themes-design.md, section 4.2): the sites of Core/ThemeDecor become plain
-- anchored parts, one Model per site, in the Theme folder of the plot. Lights and particles come with step 6.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any
local Themes = require(Shared:WaitForChild("Config"):WaitForChild("Themes") :: ModuleScript) :: any
local Cosmetics = require(Shared:WaitForChild("Core"):WaitForChild("Cosmetics") :: ModuleScript) :: any
local Cable = require(Shared:WaitForChild("Core"):WaitForChild("Cable") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any
local River = require(Shared:WaitForChild("Core"):WaitForChild("River") :: ModuleScript) :: any
local ThemeDecor = require(Shared:WaitForChild("Core"):WaitForChild("ThemeDecor") :: ModuleScript) :: any

local ThemeProps = {}

type Ctx = {
	parent: Instance,
	cf: CFrame,
	flip: Vector3,
	scale: number,
	n: number,
}

local RED = Color3.fromRGB(200, 40, 40)
local GREEN = Color3.fromRGB(40, 140, 60)
local GOLD = Color3.fromRGB(240, 190, 60)
local BLUE = Color3.fromRGB(60, 120, 220)
local YELLOW = Color3.fromRGB(255, 220, 60)
local WHITE = Color3.fromRGB(245, 245, 250)
local BLACK = Color3.fromRGB(25, 25, 25)
local BROWN = Color3.fromRGB(110, 75, 40)
local DARK = Color3.fromRGB(60, 46, 40)
local ORANGE = Color3.fromRGB(240, 130, 30)
local SLATE = Color3.fromRGB(110, 110, 120)
local HAY = Color3.fromRGB(215, 180, 90)
local SAND = Color3.fromRGB(230, 210, 150)
local WOOD = Color3.fromRGB(150, 110, 70)
local PINK = Color3.fromRGB(240, 160, 190)
local LIGHTPINK = Color3.fromRGB(250, 205, 220)
local TULIPS = { RED, YELLOW, PINK, ORANGE }
local EGGS = {
	Color3.fromRGB(250, 200, 215),
	Color3.fromRGB(200, 230, 250),
	Color3.fromRGB(255, 240, 170),
	Color3.fromRGB(205, 240, 200),
}
local BLOOMS = { RED, YELLOW, WHITE, PINK, BLUE }
local GIFTS = { RED, GREEN, GOLD }
local LIGHTS = { RED, GREEN, GOLD, BLUE }

-- One part at `at` (local studs, scaled and mirrored by the site), with `tilt` applied on top.
local function make(
	ctx: Ctx,
	class: string,
	name: string,
	size: Vector3,
	at: Vector3,
	tint: Color3,
	material: Enum.Material,
	tilt: CFrame?
): any
	local p = Instance.new(class) :: any
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size * ctx.scale
	p.CFrame = ctx.cf * CFrame.new(at * ctx.scale * ctx.flip) * (tilt or CFrame.identity)
	p.Color = tint
	p.Material = material
	p.Parent = ctx.parent
	return p
end

-- A round part (a squashed sphere when the sizes differ).
local function ball(ctx: Ctx, name: string, size: Vector3, at: Vector3, tint: Color3, material: Enum.Material)
	local p = make(ctx, "Part", name, size, at, tint, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

-- An upright cylinder: `height` along y, `width` across.
local function upright(
	ctx: Ctx,
	name: string,
	height: number,
	width: number,
	at: Vector3,
	tint: Color3,
	material: Enum.Material
)
	local p = make(
		ctx,
		"Part",
		name,
		Vector3.new(height, width, width),
		at,
		tint,
		material,
		CFrame.Angles(0, 0, math.rad(90))
	)
	p.Shape = Enum.PartType.Cylinder
end

-- Four wedges in the quarters of a square of `width` studs: a stepped cone tier, `height` high and centred at `y`.
local function quarters(
	ctx: Ctx,
	name: string,
	width: number,
	height: number,
	y: number,
	tint: Color3,
	material: Enum.Material
)
	local q = width / 4
	for k = 0, 3 do
		local x = if k == 0 or k == 3 then q else -q
		local z = if k < 2 then q else -q
		make(
			ctx,
			"WedgePart",
			name,
			Vector3.new(width / 2, height, width / 2),
			Vector3.new(x, y, z),
			tint,
			material,
			CFrame.Angles(0, math.rad(90 * k), 0)
		)
	end
end

local function tree(ctx: Ctx)
	upright(ctx, "Trunk", 3, 1.2, Vector3.new(0, 1.5, 0), BROWN, Enum.Material.Wood)
	for tier = 0, 2 do
		quarters(ctx, "Tier", 6 - tier * 1.5, 2.5, 4.25 + tier * 2.5, GREEN, Enum.Material.Grass)
	end
	ball(ctx, "Star", Vector3.one * 1.2, Vector3.new(0, 11.1, 0), GOLD, Enum.Material.Neon)
	for i = 0, 7 do
		local angle = math.rad(45 * i)
		local at = Vector3.new(2.6 * math.cos(angle), 4 + (i % 3) * 2, 2.6 * math.sin(angle))
		ball(ctx, "Bauble", Vector3.one * 0.8, at, GIFTS[i % 3 + 1], Enum.Material.Neon)
	end
end

local function snowman(ctx: Ctx)
	ball(ctx, "Base", Vector3.one * 2, Vector3.new(0, 1, 0), WHITE, Enum.Material.SmoothPlastic)
	ball(ctx, "Middle", Vector3.one * 1.5, Vector3.new(0, 2.6, 0), WHITE, Enum.Material.SmoothPlastic)
	ball(ctx, "Head", Vector3.one * 1.1, Vector3.new(0, 3.7, 0), WHITE, Enum.Material.SmoothPlastic)
	make(ctx, "Part", "Eye", Vector3.one * 0.2, Vector3.new(0.25, 3.8, -0.55), BLACK, Enum.Material.SmoothPlastic)
	make(ctx, "Part", "Eye", Vector3.one * 0.2, Vector3.new(-0.25, 3.8, -0.55), BLACK, Enum.Material.SmoothPlastic)
	local nose = Vector3.new(0, 3.65, -0.7)
	make(ctx, "Part", "Nose", Vector3.new(0.25, 0.25, 0.6), nose, ORANGE, Enum.Material.SmoothPlastic)
	upright(ctx, "Brim", 0.15, 1.4, Vector3.new(0, 4.2, 0), BLACK, Enum.Material.SmoothPlastic)
	upright(ctx, "Crown", 0.9, 0.9, Vector3.new(0, 4.75, 0), BLACK, Enum.Material.SmoothPlastic)
end

local function gift(ctx: Ctx)
	local tint = GIFTS[ctx.n % 3 + 1]
	make(ctx, "Part", "Box", Vector3.new(2, 1.6, 2), Vector3.new(0, 0.8, 0), tint, Enum.Material.SmoothPlastic)
	make(ctx, "Part", "RibbonX", Vector3.new(2.1, 1.7, 0.35), Vector3.new(0, 0.8, 0), GOLD, Enum.Material.SmoothPlastic)
	make(ctx, "Part", "RibbonZ", Vector3.new(0.35, 1.7, 2.1), Vector3.new(0, 0.8, 0), GOLD, Enum.Material.SmoothPlastic)
end

local function fairy(ctx: Ctx)
	ball(ctx, "Light", Vector3.one * 0.6, Vector3.new(0, 2.8, 0), LIGHTS[ctx.n % 4 + 1], Enum.Material.Neon)
end

local function pine(ctx: Ctx)
	upright(ctx, "Trunk", 1.5, 0.8, Vector3.new(0, 0.75, 0), BROWN, Enum.Material.Wood)
	quarters(ctx, "Tier", 4.5, 4, 3.5, GREEN, Enum.Material.Grass)
end

-- One strip of snow on top of one of the four fence rails (the fixed piece: no site, `n` is the rail).
local function railsnow(ctx: Ctx)
	local f = Themes.FENCE
	local strips = {
		{ Vector3.new(0, 2.7, -f), Vector3.new(2 * f, 0.2, 0.6) },
		{ Vector3.new(0, 2.7, f), Vector3.new(2 * f, 0.2, 0.6) },
		{ Vector3.new(-f, 2.7, 0), Vector3.new(0.6, 0.2, 2 * f) },
		{ Vector3.new(f, 2.7, 0), Vector3.new(0.6, 0.2, 2 * f) },
	}
	local strip = strips[ctx.n]
	make(ctx, "Part", "RailSnow", strip[2], strip[1], WHITE, Enum.Material.Snow)
end

local function jack(ctx: Ctx)
	ball(ctx, "Body", Vector3.new(2.4, 2, 2.4), Vector3.new(0, 1.1, 0), ORANGE, Enum.Material.SmoothPlastic)
	upright(ctx, "Stem", 0.5, 0.4, Vector3.new(0, 2.2, 0), BROWN, Enum.Material.Wood)
	make(ctx, "Part", "Eye", Vector3.new(0.6, 0.6, 0.2), Vector3.new(0.55, 1.3, -1.25), YELLOW, Enum.Material.Neon)
	make(ctx, "Part", "Eye", Vector3.new(0.6, 0.6, 0.2), Vector3.new(-0.55, 1.3, -1.25), YELLOW, Enum.Material.Neon)
	make(ctx, "Part", "Mouth", Vector3.new(1.4, 0.4, 0.2), Vector3.new(0, 0.8, -1.25), YELLOW, Enum.Material.Neon)
end

local function giant(ctx: Ctx)
	ball(ctx, "Body", Vector3.new(5.5, 4.5, 5.5), Vector3.new(0, 2.7, 0), ORANGE, Enum.Material.SmoothPlastic)
	upright(ctx, "Stem", 0.8, 0.7, Vector3.new(0, 5.3, 0), BROWN, Enum.Material.Wood)
	make(ctx, "Part", "Leaf", Vector3.new(0.8, 0.6, 0.8), Vector3.new(0.6, 5.9, 0), GREEN, Enum.Material.Grass)
	make(ctx, "Part", "Eye", Vector3.new(1.2, 0.9, 0.3), Vector3.new(1.4, 3.2, -2.6), YELLOW, Enum.Material.Neon)
	make(ctx, "Part", "Eye", Vector3.new(1.2, 0.9, 0.3), Vector3.new(-1.4, 3.2, -2.6), YELLOW, Enum.Material.Neon)
	make(ctx, "Part", "Mouth", Vector3.new(3, 1, 0.3), Vector3.new(0, 1.7, -2.6), YELLOW, Enum.Material.Neon)
end

local function pumpkin(ctx: Ctx)
	ball(ctx, "Body", Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, 0.7, 0), ORANGE, Enum.Material.SmoothPlastic)
	upright(ctx, "Stem", 0.4, 0.3, Vector3.new(0, 1.5, 0), BROWN, Enum.Material.Wood)
end

local function tombstone(ctx: Ctx)
	make(ctx, "Part", "Slab", Vector3.new(1.6, 2.2, 0.4), Vector3.new(0, 1.1, 0), SLATE, Enum.Material.Slate)
	local top = make(
		ctx,
		"Part",
		"Top",
		Vector3.new(0.4, 1.6, 1.6),
		Vector3.new(0, 2.2, 0),
		SLATE,
		Enum.Material.Slate,
		CFrame.Angles(0, math.rad(90), 0)
	)
	top.Shape = Enum.PartType.Cylinder
end

local function cobweb(ctx: Ctx)
	for k = 0, 3 do
		local strand = make(
			ctx,
			"Part",
			"Strand",
			Vector3.new(1.4, 0.1, 0.1),
			Vector3.new(0, 1.5, 0),
			WHITE,
			Enum.Material.SmoothPlastic,
			CFrame.Angles(0, math.rad(45 * k), 0)
		)
		strand.Transparency = 0.3
	end
end

local function deadtree(ctx: Ctx)
	make(ctx, "Part", "Trunk", Vector3.new(0.8, 4, 0.8), Vector3.new(0, 2, 0), DARK, Enum.Material.Wood)
	for k = 1, 3 do
		local angle = math.rad(120 * k)
		local at = Vector3.new(0.35 * math.cos(angle), 2.5 + k * 0.5, 0.35 * math.sin(angle))
		make(
			ctx,
			"Part",
			"Branch",
			Vector3.new(0.3, 1.8, 0.3),
			at,
			DARK,
			Enum.Material.Wood,
			CFrame.Angles(0, angle, math.rad(40))
		)
	end
end

local function lantern(ctx: Ctx)
	make(ctx, "Part", "Lantern", Vector3.one * 0.8, Vector3.new(0, 2.8, 0), ORANGE, Enum.Material.Neon)
end

local MAPLES = { ORANGE, RED, YELLOW }

local function maple(ctx: Ctx)
	upright(ctx, "Trunk", 4, 1.4, Vector3.new(0, 2, 0), BROWN, Enum.Material.Wood)
	ball(ctx, "Crown", Vector3.one * 5, Vector3.new(0, 6.5, 0), MAPLES[ctx.n % 3 + 1], Enum.Material.LeafyGrass)
	ball(ctx, "Crown", Vector3.one * 4, Vector3.new(1.8, 5.5, 1), MAPLES[(ctx.n + 1) % 3 + 1], Enum.Material.LeafyGrass)
	ball(
		ctx,
		"Crown",
		Vector3.one * 4,
		Vector3.new(-1.8, 5.5, -1),
		MAPLES[(ctx.n + 2) % 3 + 1],
		Enum.Material.LeafyGrass
	)
end

local function leaves(ctx: Ctx)
	ball(ctx, "Pile", Vector3.new(3.2, 0.7, 3.2), Vector3.new(0, 0.3, 0), ORANGE, Enum.Material.Grass)
	ball(ctx, "Pile", Vector3.new(2.2, 0.6, 2.2), Vector3.new(0.6, 0.6, 0.4), RED, Enum.Material.Grass)
end

local function hay(ctx: Ctx)
	local bale = make(ctx, "Part", "Bale", Vector3.new(3, 2.4, 2.4), Vector3.new(0, 1.2, 0), HAY, Enum.Material.Grass)
	bale.Shape = Enum.PartType.Cylinder
end

local function scarecrow(ctx: Ctx)
	make(ctx, "Part", "Post", Vector3.new(0.5, 5, 0.5), Vector3.new(0, 2.5, 0), BROWN, Enum.Material.Wood)
	make(ctx, "Part", "Arms", Vector3.new(4, 0.4, 0.4), Vector3.new(0, 4, 0), BROWN, Enum.Material.Wood)
	ball(ctx, "Head", Vector3.one * 1.1, Vector3.new(0, 5.5, 0), HAY, Enum.Material.Fabric)
	make(ctx, "Part", "Shirt", Vector3.new(1.6, 1.8, 0.9), Vector3.new(0, 3.5, 0), BLUE, Enum.Material.Fabric)
	upright(ctx, "Brim", 0.15, 1.8, Vector3.new(0, 6.0, 0), DARK, Enum.Material.Fabric)
	upright(ctx, "Crown", 0.7, 1, Vector3.new(0, 6.4, 0), DARK, Enum.Material.Fabric)
	make(ctx, "Part", "Straw", Vector3.new(0.8, 0.5, 0.3), Vector3.new(0, 2.5, -0.5), HAY, Enum.Material.Grass)
end

local function crate(ctx: Ctx)
	make(ctx, "Part", "Box", Vector3.new(2.4, 1.6, 2.4), Vector3.new(0, 0.8, 0), BROWN, Enum.Material.Wood)
	ball(ctx, "Apple", Vector3.one * 0.7, Vector3.new(0.3, 1.8, 0.2), RED, Enum.Material.SmoothPlastic)
end

local function blossom(ctx: Ctx)
	upright(ctx, "Trunk", 3.5, 1.2, Vector3.new(0, 1.75, 0), BROWN, Enum.Material.Wood)
	ball(ctx, "Bloom", Vector3.one * 5, Vector3.new(0, 5.5, 0), PINK, Enum.Material.LeafyGrass)
	ball(ctx, "Bloom", Vector3.one * 3.5, Vector3.new(2, 4.5, 1), LIGHTPINK, Enum.Material.LeafyGrass)
	ball(ctx, "Bloom", Vector3.one * 3.5, Vector3.new(-2, 4.5, -1), LIGHTPINK, Enum.Material.LeafyGrass)
end

local function tulips(ctx: Ctx)
	make(ctx, "Part", "Soil", Vector3.new(5, 0.4, 2), Vector3.new(0, 0.2, 0), DARK, Enum.Material.Ground)
	for i = 0, 4 do
		local x = -2 + i
		make(ctx, "Part", "Stem", Vector3.new(0.12, 1.2, 0.12), Vector3.new(x, 1, 0), GREEN, Enum.Material.Grass)
		ball(
			ctx,
			"Bloom",
			Vector3.new(0.5, 0.6, 0.5),
			Vector3.new(x, 1.7, 0),
			TULIPS[(i + ctx.n) % 4 + 1],
			Enum.Material.SmoothPlastic
		)
	end
end

local function egg(ctx: Ctx)
	ball(ctx, "Egg", Vector3.new(1, 1.3, 1), Vector3.new(0, 0.65, 0), EGGS[ctx.n % 4 + 1], Enum.Material.SmoothPlastic)
end

local function birdhouse(ctx: Ctx)
	make(ctx, "Part", "Post", Vector3.new(0.3, 2.2, 0.3), Vector3.new(0, 1.1, 0), BROWN, Enum.Material.Wood)
	make(ctx, "Part", "House", Vector3.new(1.2, 1, 1.2), Vector3.new(0, 2.7, 0), PINK, Enum.Material.Wood)
	make(
		ctx,
		"WedgePart",
		"Roof",
		Vector3.new(1.4, 0.6, 1.4),
		Vector3.new(0, 3.5, 0),
		RED,
		Enum.Material.Wood,
		CFrame.Angles(0, math.rad(90), 0)
	)
end

local function umbrella(ctx: Ctx, x: number, z: number, tint: Color3)
	make(ctx, "Part", "Pole", Vector3.new(0.2, 5, 0.2), Vector3.new(x, 2.5, z), WHITE, Enum.Material.SmoothPlastic)
	upright(ctx, "Canopy", 0.3, 5, Vector3.new(x, 5, z), tint, Enum.Material.Fabric)
	ball(ctx, "Top", Vector3.one * 0.5, Vector3.new(x, 5.3, z), WHITE, Enum.Material.SmoothPlastic)
end

local function deckchair(ctx: Ctx, x: number, z: number, tint: Color3)
	make(ctx, "Part", "Seat", Vector3.new(1.4, 0.2, 2.2), Vector3.new(x, 0.7, z), tint, Enum.Material.Fabric)
	make(
		ctx,
		"Part",
		"Back",
		Vector3.new(1.4, 0.2, 1.8),
		Vector3.new(x, 1.5, z + 1.3),
		tint,
		Enum.Material.Fabric,
		CFrame.Angles(math.rad(-55), 0, 0)
	)
	make(ctx, "WedgePart", "Leg", Vector3.new(1.2, 0.7, 1.2), Vector3.new(x, 0.35, z - 0.4), WOOD, Enum.Material.Wood)
end

local function beach(ctx: Ctx)
	upright(ctx, "Sand", 0.2, 18, Vector3.new(0, 0.1, 0), SAND, Enum.Material.Sand)
	umbrella(ctx, -4, 2, RED)
	umbrella(ctx, 4, 3, BLUE)
	deckchair(ctx, -4, -1, BLUE)
	deckchair(ctx, 4, 0, YELLOW)
	make(ctx, "Part", "Towel", Vector3.new(2, 0.1, 3.4), Vector3.new(0, 0.3, -4), RED, Enum.Material.Fabric)
	make(ctx, "Part", "Stripe", Vector3.new(2.05, 0.12, 0.8), Vector3.new(0, 0.32, -4), WHITE, Enum.Material.Fabric)
	ball(ctx, "Ball", Vector3.one * 1.2, Vector3.new(-1, 0.8, 5), YELLOW, Enum.Material.SmoothPlastic)
end

local function palm(ctx: Ctx)
	make(
		ctx,
		"Part",
		"Trunk",
		Vector3.new(0.8, 3.6, 0.8),
		Vector3.new(0.3, 1.7, 0),
		BROWN,
		Enum.Material.Wood,
		CFrame.Angles(0, 0, math.rad(-8))
	)
	make(
		ctx,
		"Part",
		"Trunk",
		Vector3.new(0.7, 3.6, 0.7),
		Vector3.new(1.0, 5, 0),
		BROWN,
		Enum.Material.Wood,
		CFrame.Angles(0, 0, math.rad(-12))
	)
	for k = 0, 3 do
		make(
			ctx,
			"WedgePart",
			"Frond",
			Vector3.new(0.3, 0.5, 3.4),
			Vector3.new(1.4, 7.2, 0),
			GREEN,
			Enum.Material.Grass,
			CFrame.Angles(0, math.rad(90 * k), 0) * CFrame.Angles(math.rad(-20), 0, 0)
		)
	end
end

local function flower(ctx: Ctx)
	make(ctx, "Part", "Stem", Vector3.new(0.12, 1.1, 0.12), Vector3.new(0, 0.55, 0), GREEN, Enum.Material.Grass)
	ball(ctx, "Bloom", Vector3.one * 0.6, Vector3.new(0, 1.2, 0), BLOOMS[ctx.n % 5 + 1], Enum.Material.SmoothPlastic)
end

local function sandcastle(ctx: Ctx)
	make(ctx, "Part", "Base", Vector3.new(3, 1, 3), Vector3.new(0, 0.5, 0), SAND, Enum.Material.Sand)
	upright(ctx, "Tower", 1.6, 0.9, Vector3.new(-1.1, 1.8, -1.1), SAND, Enum.Material.Sand)
	upright(ctx, "Tower", 1.6, 0.9, Vector3.new(1.1, 1.8, 1.1), SAND, Enum.Material.Sand)
	make(ctx, "WedgePart", "Flag", Vector3.new(0.1, 0.6, 0.8), Vector3.new(1.1, 3.0, 1.1), RED, Enum.Material.Fabric)
end

local function tiki(ctx: Ctx)
	make(ctx, "Part", "Pole", Vector3.new(0.3, 3.6, 0.3), Vector3.new(0, 1.8, 0), BROWN, Enum.Material.Wood)
	make(ctx, "Part", "Flame", Vector3.new(0.5, 0.7, 0.5), Vector3.new(0, 4, 0), ORANGE, Enum.Material.Neon)
end

local function cactus(ctx: Ctx)
	local cactusGreen = Color3.fromRGB(70, 130, 70)
	upright(ctx, "Body", 4.5, 1.1, Vector3.new(0, 2.25, 0), cactusGreen, Enum.Material.Grass)
	upright(ctx, "Arm", 1.8, 0.7, Vector3.new(0.9, 3, 0), cactusGreen, Enum.Material.Grass)
	upright(ctx, "Arm", 1.4, 0.7, Vector3.new(-0.9, 2.4, 0), cactusGreen, Enum.Material.Grass)
end

local function rock(ctx: Ctx)
	local tilt = CFrame.Angles(math.rad(8), math.rad(25), math.rad(-6))
	make(ctx, "Part", "Rock", Vector3.new(2.2, 1.4, 1.8), Vector3.new(0, 0.6, 0), SLATE, Enum.Material.Slate, tilt)
end

local function lamp(ctx: Ctx)
	make(ctx, "Part", "Base", Vector3.new(0.9, 0.4, 0.9), Vector3.new(0, 0.2, 0), DARK, Enum.Material.Metal)
	make(ctx, "Part", "Pole", Vector3.new(0.3, 4.6, 0.3), Vector3.new(0, 2.5, 0), DARK, Enum.Material.Metal)
	ball(ctx, "Head", Vector3.one * 0.9, Vector3.new(0, 5.1, 0), YELLOW, Enum.Material.Neon)
end

local function bench(ctx: Ctx)
	make(ctx, "Part", "Seat", Vector3.new(3.6, 0.3, 1.2), Vector3.new(0, 1, 0), WOOD, Enum.Material.Wood)
	make(ctx, "Part", "Back", Vector3.new(3.6, 1, 0.25), Vector3.new(0, 1.7, 0.5), WOOD, Enum.Material.Wood)
	make(ctx, "Part", "Legs", Vector3.new(3.2, 0.9, 0.9), Vector3.new(0, 0.45, 0), DARK, Enum.Material.Metal)
end

local BUILDERS: { [string]: (Ctx) -> () } = {
	cactus = cactus,
	rock = rock,
	lamp = lamp,
	bench = bench,
	maple = maple,
	leaves = leaves,
	hay = hay,
	scarecrow = scarecrow,
	crate = crate,
	blossom = blossom,
	tulips = tulips,
	egg = egg,
	birdhouse = birdhouse,
	beach = beach,
	palm = palm,
	flower = flower,
	sandcastle = sandcastle,
	tiki = tiki,
	tree = tree,
	snowman = snowman,
	gift = gift,
	fairy = fairy,
	pine = pine,
	railsnow = railsnow,
	jack = jack,
	giant = giant,
	pumpkin = pumpkin,
	tombstone = tombstone,
	cobweb = cobweb,
	deadtree = deadtree,
	lantern = lantern,
}

-- The keep-out boxes and the lines of the real site map, as in tests/ThemeDecor.test.luau (the river course of this slot).
local function layout(seed: number): (any, { any })
	local cells, lines = {}, {}
	local board = Assets.furniture.control
	for index, field in Assets.fields do
		local sites = PlotLayout.cellSites(
			field,
			PlotLayout.mown(nil, #field.cells, #field.cells),
			Assets.TILE,
			Assets.PLOT_TILES
		)
		for _, site in sites do
			table.insert(cells, { site.x, site.z, field.size * Assets.TILE })
		end
		if Assets.cables[index] then
			for _, link in Cable.links(sites, { x = board.x, z = board.z }) do
				table.insert(lines, { points = { { link.a.x, link.a.z }, { link.b.x, link.b.z } }, distance = 2 })
			end
		end
	end
	local furniture = {}
	for name, spot in Assets.furniture do
		local w, d = spot.size, spot.depth or spot.size
		if name == "battery" then
			w = Assets.container.size * Cosmetics.MEGA_CONTAINER_SCALE
			d = Assets.container.depth * Cosmetics.MEGA_CONTAINER_SCALE
		end
		table.insert(furniture, { spot.x, spot.z, w, d })
	end
	table.insert(furniture, { 9, 72, 3, 3 }) -- founder sign
	table.insert(furniture, { 0, 88, 12, 12 }) -- spawn pad
	table.insert(furniture, { 24, 91, 14, 3 }) -- name sign
	local course = River.course(Assets.river, seed)
	local centre = {}
	for _, sample in course.samples do
		table.insert(centre, { sample.x, sample.z })
	end
	table.insert(lines, { points = centre, distance = Assets.river.band + Assets.CLEARANCE })
	local input = { cells = cells, furniture = furniture, lanes = Themes.lanes, furnitureGap = Assets.CLEARANCE }
	return { low = ThemeDecor.keepOut(input, 1.5), tall = ThemeDecor.keepOut(input, Assets.CLEARANCE) }, lines
end

-- Builds the decoration of `theme` into `folder` (the Theme folder of the plot, plot-relative `origin` on the ground, `facing`
-- mirrors z). `seed` is the plot slot: each plot gets its own layout. Themes without builders show no decoration.
function ThemeProps.add(folder: Folder, theme: string, origin: Vector3, facing: number, seed: number)
	local set = Themes.sets[theme]
	if set == nil then
		return
	end
	local keep, lines = layout(seed)
	local flip = Vector3.new(1, 1, facing)
	local counts: { [string]: number } = {}
	for _, site in ThemeDecor.sites(set, keep, lines, seed, Themes.FENCE) do
		local builder = BUILDERS[site.kind]
		if builder ~= nil then
			local n = (counts[site.kind] or 0) + 1
			counts[site.kind] = n
			local model = Instance.new("Model")
			model.Name = site.kind
			local yaw = if facing < 0 then -site.yaw else site.yaw
			local at = origin + Vector3.new(site.x, 0, site.z * facing)
			builder({
				parent = model,
				cf = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0),
				flip = flip,
				scale = site.scale,
				n = n,
			})
			model.Parent = folder
		end
	end
	for _, piece in set.pieces do
		local builder = BUILDERS[piece.kind]
		if piece.zone == "fixed" and builder ~= nil then
			local model = Instance.new("Model")
			model.Name = piece.kind
			for n = 1, piece.count do
				builder({ parent = model, cf = CFrame.new(origin), flip = flip, scale = 1, n = n })
			end
			model.Parent = folder
		end
	end
end

return ThemeProps
