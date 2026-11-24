--!strict
-- The cosmetics of a plot (Core/Cosmetics flags): Neon Plants (a glowing outline and light under every plant, in the chosen
-- colour), Plot Themes (ground strip, fence and name sign in the chosen design) and the Upgrade Fireworks. Parts are
-- created on the server, so every player sees them; none of them changes what the plot does. Called once a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any
local Cosmetics = require(Shared:WaitForChild("Core"):WaitForChild("Cosmetics") :: ModuleScript) :: any
local Cable = require(Shared:WaitForChild("Core"):WaitForChild("Cable") :: ModuleScript) :: any
local GlowPattern = require(Shared:WaitForChild("Core"):WaitForChild("GlowPattern") :: ModuleScript) :: any
local ThemeProps = require(script.Parent.ThemeProps)

local PlotStyle = {}

local STRIP = 3 -- width of the ground strip along the plot edge
local POST_EVERY = 16 -- studs between fence posts
local GLOW_HEIGHT = 0.2

local function colour(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function part(parent: Instance, name: string, size: Vector3, at: Vector3, tint: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Position = at
	p.Color = tint
	p.Material = material
	p.Parent = parent
	return p
end

-- The glow of one plant unit: flat bars on the ground in the pattern of the plant (Core/GlowPattern: frame, ring or rotor
-- blades), all named NeonGlow, the first with a point light; the colour is changed in place.
local function glow(unit: Instance, origin: Vector3, tint: Color3, plantId: number)
	local bars = {}
	for _, child in unit:GetChildren() do
		if child.Name == "NeonGlow" and child:IsA("BasePart") then
			table.insert(bars, child)
		end
	end
	if #bars == 0 and unit:IsA("Model") then
		local box, size = unit:GetBoundingBox()
		-- A plant on a foundation stands on top of its two steps (PlotService), the glow with it, inside the upper step.
		local foundation = Assets.foundations[plantId]
		local lift = if foundation ~= nil then 2 * Assets.FOUNDATION_STEP - 0.15 else 0
		local centre = Vector3.new(box.Position.X, origin.Y + lift + GLOW_HEIGHT, box.Position.Z)
		local kind = GlowPattern.kind(plantId)
		local width, depth =
			GlowPattern.footprint(kind, size.X, size.Z, if foundation ~= nil then foundation.radius * 4 / 3 else nil)
		for i, bar in GlowPattern.bars(kind, width, depth) do
			local p = part(
				unit,
				"NeonGlow",
				Vector3.new(bar.sx, GLOW_HEIGHT, bar.sz),
				centre + Vector3.new(bar.x, 0, bar.z),
				tint,
				Enum.Material.Neon
			)
			p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, math.rad(bar.turn), 0)
			if i == 1 then
				local light = Instance.new("PointLight")
				light.Range = 10
				light.Brightness = 1
				light.Shadows = false
				light.Color = tint
				light.Parent = p
			end
			table.insert(bars, p)
		end
	end
	for _, bar in bars do
		if bar.Color ~= tint then
			bar.Color = tint
			local light = bar:FindFirstChildOfClass("PointLight")
			if light ~= nil then
				light.Color = tint
			end
		end
	end
end

-- Neon Plants: every unit and column of the plot glows in `neon`; nil removes the glow.
function PlotStyle.neon(origin: Vector3, copies: { { Instance } }, columns: { [number]: BasePart }, neon: string?)
	local tint = if neon ~= nil then colour(Cosmetics.neonRgb(neon)) else nil
	for plantId, units in copies do
		for _, unit in units do
			if unit.Name ~= "Rails" then
				if tint ~= nil then
					glow(unit, origin, tint, plantId)
				else
					for _, child in unit:GetChildren() do
						if child.Name == "NeonGlow" then
							child:Destroy()
						end
					end
				end
			end
		end
	end
	for _, column in columns do
		column.Material = if tint ~= nil then Enum.Material.Neon else Enum.Material.Plastic
		if tint ~= nil then
			column.Color = tint
		end
	end
end

-- Grid VIP: the ground cables of the plot glow neon, with one soft light over the grid box at `at` (Core/Cable.look); the
-- cables of other players keep their dark look. The cables folder is rebuilt by PlotService when its cables change.
function PlotStyle.cables(folder: Folder?, vip: boolean, at: Vector3)
	if folder == nil then
		return
	end
	local look = Cable.look(vip)
	local tint = colour(look.rgb)
	for _, piece in folder:GetChildren() do
		if piece.Name == "Cable" and piece:IsA("BasePart") then
			piece.Material = if look.neon then Enum.Material.Neon else Enum.Material.Plastic
			piece.Color = tint
		end
	end
	local cableGlow = folder:FindFirstChild("CableGlow")
	if look.range == 0 then
		if cableGlow ~= nil then
			cableGlow:Destroy()
		end
		return
	end
	if cableGlow == nil then
		local anchor = part(folder, "CableGlow", Vector3.one, at, tint, Enum.Material.Neon)
		anchor.Transparency = 1
		local light = Instance.new("PointLight")
		light.Shadows = false
		light.Brightness = 0.6
		light.Parent = anchor
		cableGlow = anchor
	end
	local light = cableGlow:FindFirstChildOfClass("PointLight")
	if light ~= nil then
		light.Color = tint
		light.Range = look.range
	end
end

-- The sign board with the owner's name on both sides.
local function sign(folder: Folder, owner: string, at: Vector3, look: any)
	local board =
		part(folder, "Sign", Vector3.new(14, 5, 0.6), at + Vector3.new(0, 6, 0), colour(look.sign), Enum.Material.Wood)
	-- The post ends at the lower edge of the board (y 3.5), so it never stands in front of the name.
	part(
		folder,
		"SignPost",
		Vector3.new(1, 3.5, 1),
		at + Vector3.new(0, 1.75, 0),
		colour(look.fence),
		Enum.Material.Wood
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = owner
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
end

-- Where the owner name sign stands, at the road side of the plot (the founder sign stands beside it).
function PlotStyle.signPoint(origin: Vector3, facing: number): Vector3
	return origin + Vector3.new(24, 0, facing * (Assets.PLOT_SIZE / 2 - STRIP - 2))
end

-- Plot Themes: builds the theme folder of the plot (nothing when `theme` is nil): colours, fence, sign and the decoration of
-- the theme (ThemeProps, laid out for the plot slot `seed`). Returns it.
function PlotStyle.theme(model: Model, origin: Vector3, facing: number, theme: string?, seed: number): Folder?
	local old = model:FindFirstChild("Theme")
	if old ~= nil then
		old:Destroy()
	end
	if theme == nil then
		return nil
	end
	local look = Cosmetics.themeLook(theme)
	local folder = Instance.new("Folder")
	folder.Name = "Theme"
	local half = Assets.PLOT_SIZE / 2
	local y = origin.Y
	-- Ground: a flat strip along every edge.
	local ground = colour(look.ground)
	local material = Enum.Material[look.material]
	part(
		folder,
		"GroundN",
		Vector3.new(2 * half, 0.2, STRIP),
		origin + Vector3.new(0, 0.1, -half + STRIP / 2),
		ground,
		material
	)
	part(
		folder,
		"GroundS",
		Vector3.new(2 * half, 0.2, STRIP),
		origin + Vector3.new(0, 0.1, half - STRIP / 2),
		ground,
		material
	)
	part(
		folder,
		"GroundW",
		Vector3.new(STRIP, 0.2, 2 * half - 2 * STRIP),
		origin + Vector3.new(-half + STRIP / 2, 0.1, 0),
		ground,
		material
	)
	part(
		folder,
		"GroundE",
		Vector3.new(STRIP, 0.2, 2 * half - 2 * STRIP),
		origin + Vector3.new(half - STRIP / 2, 0.1, 0),
		ground,
		material
	)
	-- Fence: posts every POST_EVERY studs on the inner side of the strip and one rail per edge.
	local fence = colour(look.fence)
	local inner = half - STRIP
	for step = 0, (2 * inner) // POST_EVERY do
		local at = -inner + step * POST_EVERY
		for _, point in
			{
				Vector3.new(at, 1.5, -inner),
				Vector3.new(at, 1.5, inner),
				Vector3.new(-inner, 1.5, at),
				Vector3.new(inner, 1.5, at),
			}
		do
			part(
				folder,
				"Post",
				Vector3.new(0.8, 3, 0.8),
				Vector3.new(origin.X + point.X, y + point.Y, origin.Z + point.Z),
				fence,
				Enum.Material.Wood
			)
		end
	end
	part(
		folder,
		"RailN",
		Vector3.new(2 * inner, 0.4, 0.4),
		origin + Vector3.new(0, 2.4, -inner),
		fence,
		Enum.Material.Wood
	)
	part(
		folder,
		"RailS",
		Vector3.new(2 * inner, 0.4, 0.4),
		origin + Vector3.new(0, 2.4, inner),
		fence,
		Enum.Material.Wood
	)
	part(
		folder,
		"RailW",
		Vector3.new(0.4, 0.4, 2 * inner),
		origin + Vector3.new(-inner, 2.4, 0),
		fence,
		Enum.Material.Wood
	)
	part(
		folder,
		"RailE",
		Vector3.new(0.4, 0.4, 2 * inner),
		origin + Vector3.new(inner, 2.4, 0),
		fence,
		Enum.Material.Wood
	)
	-- Sign: at the road side of the plot, beside the spawn platform.
	sign(folder, model.Name, PlotStyle.signPoint(origin, facing), look)
	ThemeProps.add(folder, theme, origin, facing, seed)
	folder.Parent = model
	return folder
end

-- Upgrade Fireworks: a burst of coloured sparks above the plot, gone after a few seconds.
function PlotStyle.fireworks(origin: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Fireworks"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = origin + Vector3.new(0, 40, 0)
	anchor.Parent = workspace
	for _, rgb in { { 255, 80, 80 }, { 255, 220, 60 }, { 80, 200, 255 }, { 120, 255, 120 } } do
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(colour(rgb))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(1.6, 0)
		sparks.Lifetime = NumberRange.new(1.5, 2.5)
		sparks.Speed = NumberRange.new(30, 55)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, -20, 0)
		sparks.Rate = 0
		sparks.Parent = anchor
		sparks:Emit(60)
	end
	Debris:AddItem(anchor, 5)
end

return PlotStyle
