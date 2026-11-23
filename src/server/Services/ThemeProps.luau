--!strict
-- Theme decoration (docs/themes-design.md, sections 4.2 and 4.5): the pieces of a theme's set stand on the plot as plain parts
-- in the plot's Theme folder. The sites come from Core/ThemeDecor (laid out per plot slot from Core/ThemeMap), the parts of a
-- kind from Core/ThemeParts. PlotStyle.theme calls it when the theme changes; nothing runs per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Core = Shared:WaitForChild("Core")
local Themes = require(Config:WaitForChild("Themes") :: ModuleScript) :: any
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Cosmetics = require(Core:WaitForChild("Cosmetics") :: ModuleScript) :: any
local PlotLayout = require(Core:WaitForChild("PlotLayout") :: ModuleScript) :: any
local River = require(Core:WaitForChild("River") :: ModuleScript) :: any
local Cable = require(Core:WaitForChild("Cable") :: ModuleScript) :: any
local ThemeDecor = require(Core:WaitForChild("ThemeDecor") :: ModuleScript) :: any
local ThemeMap = require(Core:WaitForChild("ThemeMap") :: ModuleScript) :: any
local ThemeParts = require(Core:WaitForChild("ThemeParts") :: ModuleScript) :: any

local ThemeProps = {}

local SHAPES = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Wedge = Enum.PartType.Wedge,
	CornerWedge = Enum.PartType.CornerWedge,
	Sphere = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
}

-- One part of a site. The piece turns by its yaw and is mirrored in z by the plot facing (a plot with facing -1), as every
-- other site of the plot. A Cylinder is built along x and laid upright; a Sphere is a block with a sphere mesh.
local function build(folder: Folder, origin: Vector3, facing: number, site: any, parts: { any })
	for _, p in parts do
		local size = Vector3.new(p.size[1], p.size[2], p.size[3])
		if p.shape == "Cylinder" then
			size = Vector3.new(p.size[2], p.size[1], p.size[3])
		end
		local frame = CFrame.Angles(0, math.rad(facing * (site.yaw + p.yaw)), 0)
		local offset = frame * (Vector3.new(p.at[1], p.at[2], facing * p.at[3]) * site.scale)
		local at = origin + Vector3.new(site.x, 0, facing * site.z) + offset
		local part = Instance.new("Part")
		part.Name = p.shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Shape = SHAPES[p.shape]
		part.Size = size * site.scale
		part.CFrame = CFrame.new(at) * frame
		if p.shape == "Cylinder" then
			part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
		part.Color = Color3.fromRGB(p.rgb[1], p.rgb[2], p.rgb[3])
		part.Material = Enum.Material[p.material]
		part.Parent = folder
		if p.shape == "Sphere" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
	end
end

-- Snow on the four rails of the fence (the fixed piece `railsnow`): a thin white block on top of each rail.
local RAILS: { { any } } = { { 0, -1, true }, { 0, 1, true }, { -1, 0, false }, { 1, 0, false } }
local SNOW = { 248, 250, 255 }

local function rails(folder: Folder, origin: Vector3, facing: number, fence: number)
	for _, rail in RAILS do
		local size = if rail[3] then { 2 * fence, 0.1, 0.5 } else { 0.5, 0.1, 2 * fence }
		local site = { x = rail[1] * fence, z = rail[2] * fence, yaw = 0, scale = 1 }
		local snow = { shape = "Block", size = size, at = { 0, 2.65, 0 }, yaw = 0, rgb = SNOW, material = "Snow" }
		build(folder, origin, facing, site, { snow })
	end
end

-- The decoration of `theme` on the plot: the sites of the set for this plot slot, each piece built from its kind's parts.
-- Kinds without parts yet place nothing; the sites are still kept free for them.
function ThemeProps.decorate(folder: Folder, origin: Vector3, facing: number, theme: string, slot: number)
	local set = Themes.sets[theme]
	if set == nil or #set.pieces == 0 then
		return
	end
	local libs = {
		Assets = Assets,
		Themes = Themes,
		Cosmetics = Cosmetics,
		PlotLayout = PlotLayout,
		River = River,
		Cable = Cable,
		ThemeDecor = ThemeDecor,
	}
	local scene = ThemeMap.scene(libs, slot)
	local sites = ThemeDecor.sites(set, scene.keep, scene.lines, slot, Themes.FENCE)
	local counts: { [number]: number } = {}
	for _, site in sites do
		local index = site.piece
		counts[index] = (counts[index] or 0) + 1
		local parts = ThemeParts.kind(set.pieces[index].kind, counts[index])
		if parts ~= nil then
			build(folder, origin, facing, site, parts)
		end
	end
	for _, piece in set.pieces do
		if piece.zone == "fixed" and piece.kind == "railsnow" then
			rails(folder, origin, facing, Themes.FENCE)
		end
	end
end

return ThemeProps
