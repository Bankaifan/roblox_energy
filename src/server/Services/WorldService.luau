--!strict
-- The world around the plots (issue 85): terrain, water, props and the light mood, built at runtime from
-- Core/Landscape and Core/DayCycle. Every prop is a handful of anchored parts without scripts; the part count is
-- capped by Landscape.MAX_PARTS. The ground under the plots is flat; PlotGround paints it per plot.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any
-- Two rows of plots: one plot per player of a full server (PlotService).
local Landscape = (require(Shared:WaitForChild("Core"):WaitForChild("Landscape") :: ModuleScript) :: any).new(
	Assets.PLOT_SIZE,
	Assets.PLOT_SPACING,
	Assets.PLOT_COLUMNS,
	Assets.PLOT_ROW_Z
)
local DayCycle = require(Shared:WaitForChild("Core"):WaitForChild("DayCycle") :: ModuleScript) :: any
local Phases = require(Shared:WaitForChild("Config"):WaitForChild("Phases") :: ModuleScript) :: any
local Ambience = require(Shared:WaitForChild("Ambience") :: ModuleScript) :: any
local PlotGround = require(script.Parent.PlotGround) :: any

local WorldService = {}

local SEED = 85
local CHUNK = 32 -- terrain cells per side of one write

local GROUND: { [string]: Enum.Material } = {
	Asphalt = Enum.Material.Asphalt,
	Ground = Enum.Material.Ground,
	Sand = Enum.Material.Sand,
	Rock = Enum.Material.Rock,
	LeafyGrass = Enum.Material.LeafyGrass,
	Grass = Enum.Material.Grass,
}
-- Warm, slightly dry palette for the terrain.
local GROUND_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = Color3.fromRGB(98, 130, 62),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(122, 138, 60),
	[Enum.Material.Sand] = Color3.fromRGB(214, 190, 142),
	[Enum.Material.Rock] = Color3.fromRGB(122, 114, 108),
	[Enum.Material.Ground] = Color3.fromRGB(128, 100, 72),
	[Enum.Material.Asphalt] = Color3.fromRGB(72, 70, 74),
}

local OAK_LEAVES = {
	Color3.fromRGB(86, 122, 58),
	Color3.fromRGB(112, 138, 60),
	Color3.fromRGB(150, 142, 58),
	Color3.fromRGB(178, 124, 50),
	Color3.fromRGB(74, 104, 62),
}
local BIRCH_LEAVES = { Color3.fromRGB(196, 170, 60), Color3.fromRGB(170, 160, 64), Color3.fromRGB(214, 146, 52) }
local BUSH_LEAVES = { Color3.fromRGB(78, 112, 60), Color3.fromRGB(104, 126, 58), Color3.fromRGB(140, 110, 62) }
local FLOWERS = { Color3.fromRGB(130, 240, 215), Color3.fromRGB(255, 206, 120), Color3.fromRGB(190, 170, 255) }
local BARK = Color3.fromRGB(96, 72, 52)
local BIRCH_BARK = Color3.fromRGB(226, 222, 208)
local POLE_WOOD = Color3.fromRGB(88, 66, 50)
local JETTY_WOOD = Color3.fromRGB(122, 94, 68)
local LAMP = Color3.fromRGB(255, 196, 124)
local TURBINE = Color3.fromRGB(236, 236, 232)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder runs along X; this stands it up

local built = 0

local function pick(colors: { Color3 }, tone: number): Color3
	return colors[math.min(#colors, 1 + math.floor(tone * #colors))]
end

-- One anchored part. solid: players collide with it. shadow: it casts a shadow.
local function part(
	parent: Instance,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	solid: boolean,
	shadow: boolean
): Part
	local new = Instance.new("Part")
	new.Shape = shape
	new.Size = size
	new.CFrame = cframe
	new.Color = color
	new.Material = material
	new.Anchored = true
	new.CanCollide = solid
	new.CanQuery = solid
	new.CanTouch = false
	new.CastShadow = shadow
	new.Parent = parent
	built += 1
	return new
end

local function ball(parent: Instance, size: number, cframe: CFrame, color: Color3, shadow: boolean): Part
	return part(parent, Enum.PartType.Ball, Vector3.one * size, cframe, color, Enum.Material.LeafyGrass, false, shadow)
end

-- A part that glows at night (the client switches it, see World.client). strength: brightness of its light, or nil
-- for no light.
local function glowing(parent: Instance, size: number, cframe: CFrame, color: Color3, strength: number?, range: number?)
	local new =
		part(parent, Enum.PartType.Ball, Vector3.one * size, cframe, color, Enum.Material.SmoothPlastic, false, false)
	if strength ~= nil then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range or 30
		light.Brightness = 0
		light.Shadows = false
		light.Parent = new
		new:SetAttribute("Glow", strength)
	end
	CollectionService:AddTag(new, "NightGlow")
end

local function writeTerrain(terrain: Terrain)
	local cell = Landscape.CELL
	local layers = (Landscape.CEILING - Landscape.FLOOR) / cell
	local side = CHUNK * cell
	for chunkX = Landscape.MIN_X, Landscape.MAX_X - 1, side do
		for chunkZ = Landscape.MIN_Z, Landscape.MAX_Z - 1, side do
			local materials, occupancies = table.create(CHUNK), table.create(CHUNK)
			for ix = 1, CHUNK do
				local x = chunkX + (ix - 0.5) * cell
				local materialSlice, occupancySlice = table.create(layers), table.create(layers)
				for iy = 1, layers do
					materialSlice[iy] = table.create(CHUNK, Enum.Material.Air)
					occupancySlice[iy] = table.create(CHUNK, 0)
				end
				for iz = 1, CHUNK do
					local z = chunkZ + (iz - 0.5) * cell
					local height = Landscape.height(x, z)
					local ground = GROUND[Landscape.surface(x, z)]
					for iy = 1, layers do
						-- The surface lies where the occupancy crosses one half between two cell centres.
						local centre = Landscape.FLOOR + (iy - 0.5) * cell
						local solid = math.clamp((height - centre) / cell + 0.5, 0, 1)
						if solid >= 0.5 or (solid > 0 and centre > Landscape.WATER) then
							materialSlice[iy][iz] = ground
							occupancySlice[iy][iz] = solid
						elseif centre < Landscape.WATER then
							materialSlice[iy][iz] = Enum.Material.Water
							occupancySlice[iy][iz] = 1
						end
					end
				end
				materials[ix], occupancies[ix] = materialSlice, occupancySlice
			end
			local low = Vector3.new(chunkX, Landscape.FLOOR, chunkZ)
			terrain:WriteVoxels(
				Region3.new(low, low + Vector3.new(side, Landscape.CEILING - Landscape.FLOOR, side)),
				cell,
				materials,
				occupancies
			)
		end
		task.wait()
	end
end

local function buildTerrain()
	local terrain = workspace.Terrain
	for material, color in GROUND_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = Color3.fromRGB(34, 92, 112)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6

	-- The meadow first and in one call, so a player who spawns during the build stands on ground.
	local meadow = Landscape.MEADOW
	terrain:FillBlock(
		CFrame.new((meadow.minX + meadow.maxX) / 2, -8, (meadow.minZ + meadow.maxZ) / 2),
		Vector3.new(meadow.maxX - meadow.minX, 16, meadow.maxZ - meadow.minZ),
		Enum.Material.Grass
	)
	writeTerrain(terrain)

	-- A default baseplate would cut through the lake and the hills.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil then
		baseplate:Destroy()
	end
end

local function tree(parent: Instance, base: CFrame, prop: any)
	local scale = prop.scale
	if prop.kind == "oak" then
		local leaves = pick(OAK_LEAVES, prop.tone)
		local trunk = Vector3.new(10 * scale, 1.8 * scale, 1.8 * scale)
		part(
			parent,
			Enum.PartType.Cylinder,
			trunk,
			base * CFrame.new(0, 4 * scale, 0) * UPRIGHT,
			BARK,
			Enum.Material.Wood,
			true,
			true
		)
		ball(parent, 11 * scale, base * CFrame.new(0, 11.5 * scale, 0), leaves, true)
		ball(parent, 8 * scale, base * CFrame.new(3.4 * scale, 9.5 * scale, 1.6 * scale), leaves:Lerp(BARK, 0.12), true)
		ball(parent, 7 * scale, base * CFrame.new(-3 * scale, 13 * scale, -2 * scale), leaves:Lerp(LAMP, 0.12), true)
	else
		local leaves = pick(BIRCH_LEAVES, prop.tone)
		local trunk = Vector3.new(14 * scale, 0.9 * scale, 0.9 * scale)
		part(
			parent,
			Enum.PartType.Cylinder,
			trunk,
			base * CFrame.new(0, 6 * scale, 0) * UPRIGHT,
			BIRCH_BARK,
			Enum.Material.SmoothPlastic,
			true,
			true
		)
		ball(parent, 6.5 * scale, base * CFrame.new(0, 13.5 * scale, 0), leaves, true)
		ball(
			parent,
			5 * scale,
			base * CFrame.new(1.6 * scale, 16.5 * scale, 0.8 * scale),
			leaves:Lerp(LAMP, 0.15),
			true
		)
	end
end

local function bush(parent: Instance, base: CFrame, prop: any)
	local leaves = pick(BUSH_LEAVES, prop.tone)
	ball(parent, 4.6 * prop.scale, base * CFrame.new(0, 1.2 * prop.scale, 0), leaves, false)
	ball(
		parent,
		3.2 * prop.scale,
		base * CFrame.new(2.1 * prop.scale, 0.9 * prop.scale, 0.6 * prop.scale),
		leaves:Lerp(BARK, 0.15),
		false
	)
end

local function rock(parent: Instance, base: CFrame, prop: any)
	local size = Vector3.new(5 * (0.8 + prop.tone), 3.6, 4 * (1.4 - 0.5 * prop.tone)) * prop.scale
	local tilt = CFrame.Angles(0.5 * prop.tone, 0, 0.4 * (1 - prop.tone))
	local color = Color3.fromRGB(116, 110, 108):Lerp(Color3.fromRGB(152, 140, 126), prop.tone)
	part(
		parent,
		Enum.PartType.Block,
		size,
		base * CFrame.new(0, 0.5 * prop.scale, 0) * tilt,
		color,
		Enum.Material.Slate,
		true,
		true
	)
end

-- Post and cross arm; with a lamp on an arm towards the road. Returns the two points the wires hang from.
local function pole(parent: Instance, base: CFrame, prop: any): { Vector3 }
	part(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(24, 1.1, 1.1),
		base * CFrame.new(0, 11.5, 0) * UPRIGHT,
		POLE_WOOD,
		Enum.Material.Wood,
		true,
		true
	)
	part(
		parent,
		Enum.PartType.Block,
		Vector3.new(0.6, 0.6, 7),
		base * CFrame.new(0, 21.5, 0),
		POLE_WOOD,
		Enum.Material.Wood,
		false,
		false
	)
	if prop.kind == "lamppole" then
		part(
			parent,
			Enum.PartType.Block,
			Vector3.new(0.3, 0.3, 5),
			base * CFrame.new(0, 16, -2.5),
			POLE_WOOD,
			Enum.Material.Metal,
			false,
			false
		)
		glowing(parent, 1.2, base * CFrame.new(0, 15.5, -5), LAMP, 2, 44)
	end
	return { (base * CFrame.new(0, 22, -3)).Position, (base * CFrame.new(0, 22, 3)).Position }
end

-- An attachment whose X axis points along `direction`: a Beam leaves and arrives along that axis.
local function wireEnd(parent: Instance, position: Vector3, direction: Vector3): Attachment
	local side = direction:Cross(Vector3.yAxis).Unit
	local attachment = Instance.new("Attachment")
	attachment.Parent = parent
	attachment.WorldCFrame = CFrame.fromMatrix(position, direction, side:Cross(direction).Unit)
	return attachment
end

-- A sagging wire between two points: a curved Beam, no parts.
local function wire(parent: Instance, from: Vector3, to: Vector3)
	local along = (to - from).Unit
	local beam = Instance.new("Beam")
	beam.Attachment0 = wireEnd(parent, from, (along - Vector3.yAxis * 0.22).Unit)
	beam.Attachment1 = wireEnd(parent, to, (along + Vector3.yAxis * 0.22).Unit)
	beam.CurveSize0 = (to - from).Magnitude / 3
	beam.CurveSize1 = beam.CurveSize0
	beam.Segments = 10
	beam.Width0 = 0.16
	beam.Width1 = 0.16
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(34, 32, 36))
	beam.LightEmission = 0
	beam.LightInfluence = 1
	beam.Parent = parent
end

-- Tower, nacelle and a rotor model facing the plots. The client turns models tagged "Rotor".
local function turbine(parent: Instance, base: CFrame)
	part(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(52, 2.6, 2.6),
		base * CFrame.new(0, 24, 0) * UPRIGHT,
		TURBINE,
		Enum.Material.SmoothPlastic,
		true,
		true
	)
	part(
		parent,
		Enum.PartType.Block,
		Vector3.new(2.6, 2.6, 6),
		base * CFrame.new(0, 50, 0.6),
		TURBINE,
		Enum.Material.SmoothPlastic,
		false,
		false
	)
	glowing(parent, 0.9, base * CFrame.new(0, 51.6, -1), Color3.fromRGB(255, 76, 64), nil, nil)

	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	local hubFrame = base * CFrame.new(0, 50, 4.4)
	part(rotor, Enum.PartType.Ball, Vector3.one * 2.6, hubFrame, TURBINE, Enum.Material.SmoothPlastic, false, false)
	for blade = 0, 2 do
		local frame = hubFrame * CFrame.Angles(0, 0, math.rad(120 * blade)) * CFrame.new(0, 11.5, 0)
		part(
			rotor,
			Enum.PartType.Block,
			Vector3.new(1.5, 22, 0.4),
			frame,
			TURBINE,
			Enum.Material.SmoothPlastic,
			false,
			false
		)
	end
	rotor.WorldPivot = hubFrame
	rotor.Parent = parent
	CollectionService:AddTag(rotor, "Rotor")
end

-- Three planks out over the water on four posts, and a lantern at the end.
local function jetty(parent: Instance, base: CFrame)
	for plank = 0, 2 do
		part(
			parent,
			Enum.PartType.Block,
			Vector3.new(6, 0.4, 7.8),
			base * CFrame.new(0, 0, -4 - 8 * plank),
			JETTY_WOOD,
			Enum.Material.WoodPlanks,
			true,
			true
		)
	end
	for _, spot in
		{
			Vector3.new(-2.7, -2.4, -8),
			Vector3.new(2.7, -2.4, -8),
			Vector3.new(-2.7, -2.4, -23),
			Vector3.new(2.7, -2.4, -23),
		}
	do
		part(
			parent,
			Enum.PartType.Cylinder,
			Vector3.new(6, 0.7, 0.7),
			base * CFrame.new(spot) * UPRIGHT,
			POLE_WOOD,
			Enum.Material.Wood,
			false,
			false
		)
	end
	part(
		parent,
		Enum.PartType.Block,
		Vector3.new(0.4, 5, 0.4),
		base * CFrame.new(2.7, 2.7, -23),
		POLE_WOOD,
		Enum.Material.Wood,
		false,
		false
	)
	glowing(parent, 1.1, base * CFrame.new(2.7, 5.6, -23), LAMP, 1.6, 30)
end

local function buildProps()
	local world = Instance.new("Folder")
	world.Name = "World"
	local previous: { Vector3 }? = nil
	for _, prop in Landscape.props(SEED) do
		local base = CFrame.new(prop.x, prop.y, prop.z) * CFrame.Angles(0, prop.yaw, 0)
		if prop.kind == "oak" or prop.kind == "birch" then
			tree(world, base, prop)
		elseif prop.kind == "bush" then
			bush(world, base, prop)
		elseif prop.kind == "rock" then
			rock(world, base, prop)
		elseif prop.kind == "flower" then
			glowing(world, 1.2 * prop.scale, base * CFrame.new(0, 0.5, 0), pick(FLOWERS, prop.tone), nil, nil)
		elseif prop.kind == "pole" or prop.kind == "lamppole" then
			local ends = pole(world, base, prop)
			if previous ~= nil then
				wire(workspace.Terrain, previous[1], ends[1])
				wire(workspace.Terrain, previous[2], ends[2])
			end
			previous = ends
		elseif prop.kind == "turbine" then
			turbine(world, base)
		elseif prop.kind == "bale" then
			part(
				world,
				Enum.PartType.Cylinder,
				Vector3.new(4.6, 5, 5),
				base * CFrame.new(0, 2.2, 0),
				Color3.fromRGB(214, 180, 104),
				Enum.Material.Sand,
				true,
				true
			)
		elseif prop.kind == "jetty" then
			jetty(world, base)
		end
	end
	world.Parent = workspace
	if built > Landscape.MAX_PARTS then
		warn(`WorldService: {built} parts, the cap is {Landscape.MAX_PARTS}`)
	end
end

-- Builds the whole world once. The light is set first, so the first frame already has the mood.
function WorldService.build()
	local clock = DayCycle.clockAt(workspace:GetServerTimeNow(), Phases)
	Ambience.setup()
	Lighting.ClockTime = clock
	Ambience.apply(DayCycle.mood(clock))
	buildTerrain()
	PlotGround.ready()
	buildProps()
end

return WorldService
