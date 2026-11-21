--!strict
-- Assigns one plot per player, at most MAX_PLOTS on a server, built from basic parts (Bauplan, section 5: no assets).
-- One column per plant; the height of a column follows the number of that plant. A plot is freed when its player leaves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Core = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core")
local PlotLayout = require(Core:WaitForChild("PlotLayout") :: ModuleScript) :: any
local River = require(Core:WaitForChild("River") :: ModuleScript) :: any
local Cosmetics = require(Core:WaitForChild("Cosmetics") :: ModuleScript) :: any
local Cable = require(Core:WaitForChild("Cable") :: ModuleScript) :: any
local Formulas = require(Core:WaitForChild("Formulas") :: ModuleScript) :: any
local ShopView = require(Core:WaitForChild("ShopView") :: ModuleScript) :: any
local Meadow = require(Core:WaitForChild("Meadow") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local PlantModels = require(script.Parent.PlantModels)
local PlotGround = require(script.Parent.PlotGround)
local PlotStyle = require(script.Parent.PlotStyle)
local LandService = require(script.Parent.LandService)

local PlotService = {}

-- One server holds 8 players (Bauplan, section 4), so 8 plots: two rows of four beside the road.
local MAX_PLOTS = 2 * Assets.PLOT_COLUMNS

local COLORS: { [string]: Color3 } = {
	Solar = Color3.fromRGB(255, 200, 60),
	Wind = Color3.fromRGB(170, 220, 255),
	Grundlast = Color3.fromRGB(140, 140, 140),
}

type Record = {
	slot: number,
	facing: number, -- 1 or -1: a plot with -1 is mirrored in z so that it faces the road
	origin: Vector3,
	model: Model,
	columns: { [number]: BasePart }, -- index -> the primitive column (only for plants without a model)
	modelPlants: { boolean }, -- index -> built from a model (else the primitive column)
	shells: { Model },
	shellKey: string,
	copies: { { Model } }, -- index -> the model units shown now
	keys: { string }, -- index -> "<cells>|<aligned cells>" of the units shown now
	control: Model?, -- the control center, built once U21 is owned
	batteries: { Model }, -- one unit per storage stage
	shell: Model?, -- the walk-in container, built once it is bought
	groundKey: string, -- what the cleared patches show now
	fenceKey: string, -- what the fences show now
	fences: Folder?, -- stakes and ropes around the fields that wait for their tool
	foundationKey: string, -- what the foundations show now
	foundations: Folder?, -- concrete steps under the anchored wind plants
	cableKey: string, -- what the ground cables show now
	cables: Folder?, -- cables from the farm cells to the grid box
	buildKey: string, -- what the farm fences and masts show now
	builds: Folder?, -- post fences round the solar farm cells and guyed masts on the mini turbine cells
	themeKey: string, -- the Plot Themes design shown now ("" = none)
	look: string, -- the crank look shown now (Cosmetics.crankLook)
	river: { number }, -- the dig stage of each river segment (River.stages)
	course: any, -- the river course of this plot (River.course)
}
local plots: { [Player]: Record } = {}

local function plotsFolder(): Folder
	local found = workspace:FindFirstChild("Plots")
	if found ~= nil then
		return found :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = workspace
	return folder
end

-- The lowest slot no player holds, or nil when all MAX_PLOTS slots are taken.
local function freeSlot(): number?
	for slot = 1, MAX_PLOTS do
		local taken = false
		for _, record in plots do
			taken = taken or record.slot == slot
		end
		if not taken then
			return slot
		end
	end
	return nil
end

local function block(parent: Instance, name: string, size: Vector3, color: Color3, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Color = color
	part.Position = position
	part.Parent = parent
	return part
end

-- The sites of a plant for `owned` units: min(owned, prepared sites), each with the same footprint whatever the count,
-- so a unit only ever stands on prepared ground. Panels (plant 1) lie wild on their mown cell; a cell in `aligned` (the
-- Align action with the Mounting Rails) holds its panel straight on the cell centre. Returns the sites.
local function unitSites(record: Record, index: number, owned: number, cells: { number }, aligned: { number }): { any }
	local field = Assets.fields[index]
	local count = math.min(math.floor(owned), #cells)
	local chosen = table.move(cells, 1, count, 1, {})
	local points = PlotLayout.cellSites(field, chosen, Assets.TILE, Assets.PLOT_TILES)
	if index ~= 1 then
		table.sort(chosen)
		return PlotLayout.cellSites(field, chosen, Assets.TILE, Assets.PLOT_TILES)
	end
	-- Panels: wild on the mown cells in the order they were mown, a cell with rails straight on its centre.
	local sites: { any } = PlotLayout.wild(points, record.slot)
	for i, cell in chosen do
		if table.find(aligned, cell) ~= nil then
			sites[i] = { x = points[i].x, z = points[i].z, angle = 0, rail = true }
		end
	end
	return sites
end

-- The world position of a plot-relative site: the plot is mirrored in z when it faces the other way.
local function sitePoint(record: Record, site: { x: number, z: number }): Vector3
	return record.origin + Vector3.new(site.x, 0, site.z * record.facing)
end

-- The water wheels stand in the river, two to a pair side by side on one axle across the flow (River.wheelSpots). They are
-- rebuilt only when their number or the flooded part of the river changes.
local WHEEL_SINK = 2.3 -- studs the lowest point of a wheel lies under the meadow: 1.3 under the water surface
local function updateWheels(record: Record, owned: number)
	local spots = River.wheelSpots(record.course, record.river, math.min(owned, 100))
	local key = `{#spots}:{River.flooded(record.river)}`
	if record.keys[2] == key then
		return
	end
	record.keys[2] = key
	local shown = record.copies[2]
	for _, copy in shown do
		copy:Destroy()
	end
	table.clear(shown)
	local entry = Assets.entry(2)
	local scale = if entry ~= nil then entry.scale else 1
	local cap = Assets.WHEEL_MAX
	for index, spot in spots do
		if index > cap then
			break
		end
		local copy = PlantModels.clone(2)
		if copy == nil then
			break
		end
		local point = sitePoint(record, spot)
		PlantModels.placeWheel(
			copy,
			scale,
			point,
			record.origin.Y - WHEEL_SINK,
			spot.nx,
			spot.nz * record.facing,
			spot.side,
			spot.tx,
			spot.tz * record.facing
		)
		copy.Parent = record.model
		table.insert(shown, copy)
	end
end

-- Two dark steel rails under an aligned panel: a Model of two thin bars along the plot's z axis, 3 studs apart.
local function railsFor(record: Record, site: { x: number, z: number }): Model
	local rails = Instance.new("Model")
	rails.Name = "Rails"
	for side = -1, 1, 2 do
		local bar = Instance.new("Part")
		bar.Name = "Rail"
		bar.Anchored = true
		bar.CanCollide = false
		bar.Material = Enum.Material.Metal
		bar.Color = Color3.fromRGB(70, 74, 82)
		bar.Size = Vector3.new(0.5, 0.4, 6.8)
		bar.Position = sitePoint(record, site) + Vector3.new(side * 1.5, 0.2, 0)
		bar.Parent = rails
	end
	return rails
end

-- Shows min(owned, prepared sites) model units of a plant, rebuilt only when the count or the layout changes.
local function updateUnits(record: Record, index: number, owned: number, cells: { number }, aligned: { number })
	local sites = unitSites(record, index, owned, cells, aligned)
	local key = table.concat(cells, ",", 1, #sites) .. "|" .. table.concat(aligned, ",")
	if record.keys[index] == key then
		return
	end
	record.keys[index] = key
	local shown = record.copies[index]
	for _, copy in shown do
		copy:Destroy()
	end
	table.clear(shown)
	local cell = Assets.fields[index].size * Assets.TILE
	for _, site in sites do
		local copy = PlantModels.clone(index)
		if copy == nil then
			break
		end
		local angle = if site.angle ~= nil then site.angle * record.facing else nil
		-- A plant on a foundation stands on top of its two steps.
		local lift = if Assets.foundations[index] ~= nil then 2 * Assets.FOUNDATION_STEP - 0.15 else 0
		PlantModels.place(copy, index, cell, sitePoint(record, site), record.origin.Y + lift, angle)
		PlantModels.tagRotor(copy, index)
		copy.Parent = record.model
		table.insert(shown, copy)
		if site.rail == true then
			table.insert(shown, railsFor(record, site))
		end
	end
end

local function updateShells(record: Record, owned: number, cells: { number })
	local bare = PlotLayout.bare(cells, owned)
	local key = table.concat(bare, ",")
	if record.shellKey == key then
		return
	end
	record.shellKey = key
	for _, copy in record.shells do
		copy:Destroy()
	end
	table.clear(record.shells)
	local field = Assets.fields[3]
	local cell = field.size * Assets.TILE
	for _, site in PlotLayout.cellSites(field, bare, Assets.TILE, Assets.PLOT_TILES) do
		local copy = PlantModels.clone(3)
		if copy == nil then
			break
		end
		PlantModels.place(copy, 3, cell, sitePoint(record, site), record.origin.Y)
		PlantModels.stripPanels(copy)
		copy.Parent = record.model
		table.insert(record.shells, copy)
	end
end

-- Places one furniture model on the plot (nothing when its file is missing: the plot keeps the current look).
local function addFurniture(record: Record, name: string, turn: number?): Model?
	-- A plot that faces the other way turns its furniture around, so the market front still looks at the plot centre.
	local around = if record.facing == -1 then 180 else 0
	local copy = PlantModels.furniture(name, record.origin, record.origin.Y, (turn or 0) + around, record.facing)
	if copy == nil then
		return nil
	end
	if name == "market" then
		PlantModels.cleanMarket(copy)
		PlantModels.mountPanels(copy, record.facing)
	end
	copy.Parent = record.model
	return copy
end

-- Set once by Action: runs the same path as the Net "Crank" message (rate limit, checks, Session).
local crankHandler: ((Player) -> ())? = nil

function PlotService.setCrankHandler(handler: (Player) -> ())
	crankHandler = handler
end

-- A ProximityPrompt on a furniture model, texted in the owner's language. `onTriggered` runs on the server for the
-- owner only; a prompt without it is handled on the client (the shop prompt: Controllers/Hud opens its panel).
local function addPrompt(
	owner: Player,
	model: Model,
	name: string,
	key: string,
	onTriggered: ((Player) -> ())?
): ProximityPrompt?
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor == nil then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = Locale.t(key, Locale.resolve(owner.LocaleId))
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	if onTriggered ~= nil then
		prompt.Triggered:Connect(function(player: Player)
			if player == owner then
				onTriggered(player)
			end
		end)
	end
	return prompt
end

-- The crank prompt's second line shows what the crank pays now (GameCore.crankOutput), so it is there only while the
-- player stands in the prompt range. Written once a second by Session, in the owner's language.
function PlotService.setCrankOutput(player: Player, output: { [string]: number })
	local record = plots[player]
	local crank = if record ~= nil then record.model:FindFirstChild("CrankPrompt", true) else nil
	if crank == nil or not crank:IsA("ProximityPrompt") then
		return
	end
	crank.ObjectText = Locale.t(
		"crank.output",
		Locale.resolve(player.LocaleId),
		{ turn = ShopView.short(output.turn), second = ShopView.short(output.second) }
	)
end

-- Control center from U21, one battery unit per storage stage; both are rebuilt only when the number changes.
local EMPTY_COLOR = Color3.fromRGB(110, 110, 110)
local FULL_COLOR = Color3.fromRGB(60, 190, 80)

-- Tints each battery unit from grey (empty) to green (full) by its share of the charge; repaints only on a change.
local function tintBatteries(record: Record, fill: number)
	local count = #record.batteries
	for level, unit in record.batteries do
		local own = Formulas.unitFill(fill, level - 1, count)
		if unit:GetAttribute("Fill") ~= own then
			unit:SetAttribute("Fill", own)
			local color = EMPTY_COLOR:Lerp(FULL_COLOR, own)
			for _, item in unit:GetDescendants() do
				if item:IsA("BasePart") and item.Material ~= Enum.Material.Neon then
					item.Color = color
				end
			end
		end
	end
end

local function updateFurniture(
	record: Record,
	extras: { stage: number, control: boolean, fill: number? },
	owner: Player
)
	if extras.control and record.control == nil then
		record.control = addFurniture(record, "control", nil)
		-- Opens the rule popup on the client (Controllers/Market, storage tab); the rules themselves need the wiring.
		if record.control ~= nil then
			addPrompt(owner, record.control, "ControlPrompt", "prompt.control", nil)
			-- A second prompt on key F opens the power overview (what each plant makes and how it is calculated).
			local info = addPrompt(owner, record.control, "ControlInfo", "prompt.production", nil)
			if info ~= nil then
				info.KeyboardKeyCode = Enum.KeyCode.F
				info.UIOffset = Vector2.new(0, 70)
			end
		end
	end
	local wanted = Assets.batteryUnits(extras.stage)
	if #record.batteries == wanted then
		tintBatteries(record, extras.fill or 0)
		return
	end
	for _, unit in record.batteries do
		unit:Destroy()
	end
	table.clear(record.batteries)
	for level = 0, wanted - 1 do
		local unit = PlantModels.battery(record.origin, record.origin.Y, level, record.facing)
		if unit == nil then
			break
		end
		unit.Parent = record.model
		table.insert(record.batteries, unit)
	end
	tintBatteries(record, extras.fill or 0)
end

-- Studs of bare earth around a furniture piece.
local FURNITURE_MARGIN = 8

-- The ground follows the land: bare earth with a wobbly outline around the crank and the market and under every prepared
-- site; the rest stays meadow. Buying a unit never clears grass: only the tool does (Prepare). A field whose tool is owned and whose plant is revealed gets a low
-- fence around the sites that are still to prepare. Terrain and fence are rebuilt only when their content changes.
local function updateLand(record: Record, counts: { number }, land: any, paint: number?)
	local ground, fence = {}, {}
	for index in Assets.fields do
		local total = Assets.siteCount(index)
		local mown = PlotLayout.mown(land.cells and land.cells[index], land.sites[index] or 0, total)
		-- Bare earth shows from the first stage on: a cell in work has its grass cut already.
		local started = PlotLayout.started(land.cells and land.cells[index], land.sites[index] or 0, total)
		local open = #mown < total and (index == 1 or (counts[index - 1] or 0) >= 1)
		table.insert(ground, table.concat(started, ","))
		table.insert(fence, if open then "open" else "-")
	end
	local container = land.container == true or #record.batteries > 0
	if container and record.shell == nil then
		record.shell = PlantModels.container(record.origin, record.origin.Y, record.facing)
		record.shell.Parent = record.model
	end
	-- The river (field F2): each started cell is a segment, dug and then flooded; the trench replaces its bare patch.
	local river = River.fromLand(
		land.cells and land.cells[2],
		land.steps and land.steps[2],
		land.sites[2] or 0,
		Assets.river.segments
	)
	PlotGround.river(record.slot, record.facing, river)
	record.river = river
	-- The client draws the foam (PlotFx) from these.
	record.model:SetAttribute("RiverStages", table.concat(river, ""))
	record.model:SetAttribute("Slot", record.slot)
	record.model:SetAttribute("Facing", record.facing)
	record.model:SetAttribute("Origin", record.origin)
	local groundKey = table.concat(ground, " ") .. ` {record.control ~= nil} {container}`
	if record.groundKey ~= groundKey then
		record.groundKey = groundKey
		local patches = {}
		for name, spot in Assets.furniture do
			local stands = name == "crank"
				or name == "market"
				or (name == "control" and record.control ~= nil)
				or (name == "battery" and container)
			if stands then
				table.insert(patches, { x = spot.x, z = spot.z, r = spot.size / 2 + FURNITURE_MARGIN })
			end
		end
		for index, field in Assets.fields do
			local side = field.size * Assets.TILE
			if field.river == true then
				continue
			end
			local started =
				PlotLayout.started(land.cells and land.cells[index], land.sites[index] or 0, Assets.siteCount(index))
			for _, site in PlotLayout.cellSites(field, started, Assets.TILE, Assets.PLOT_TILES) do
				table.insert(patches, Meadow.sitePatch(site.x, site.z, side))
			end
		end
		PlotGround.clear(record.slot, record.facing, groundKey, patches)
	end
	local tint = if paint ~= nil and paint >= 1 then Assets.paintColors[paint] else nil
	local fenceKey = table.concat(fence, " ") .. `|{paint or 0}`
	if record.fenceKey ~= fenceKey then
		record.fenceKey = fenceKey
		if record.fences ~= nil then
			record.fences:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Fences"
		for index, field in Assets.fields do
			if fence[index] ~= "-" then
				-- The rope runs around the whole field while it is open: the player mows where he stands inside it.
				local stakes, ropes = Meadow.fence(field, {}, record.slot, Assets.TILE, Assets.PLOT_TILES)
				PlotGround.fence(
					folder,
					record.origin,
					record.facing,
					stakes,
					ropes,
					if tint ~= nil then Color3.fromRGB(tint[1], tint[2], tint[3]) else nil
				)
			end
		end
		folder.Parent = record.model
		record.fences = folder
	end
end

-- The cells of a field whose stages are done up to `stage` (the prepared ones count as done).
local function anchored(land: any, index: number, stage: number): { number }
	local cells = (land.cells and land.cells[index]) or {}
	local steps = (land.steps and land.steps[index]) or {}
	local sites = land.sites[index] or 0
	local list = {}
	for i, cell in cells do
		if i <= sites or (steps[i] or 0) >= stage then
			table.insert(list, cell)
		end
	end
	return list
end

-- Round concrete foundations of two steps under the anchored cells of the wind fields; the plant stands in the middle.
local function updateFoundations(record: Record, land: any)
	local parts = {}
	local keys = {}
	for index, foundation in Assets.foundations do
		local cells = anchored(land, index, foundation.stage)
		table.insert(keys, `{index}:{table.concat(cells, ",")}`)
		for _, site in PlotLayout.cellSites(Assets.fields[index], cells, Assets.TILE, Assets.PLOT_TILES) do
			table.insert(parts, { site = site, radius = foundation.radius })
		end
	end
	local key = table.concat(keys, " ")
	if record.foundationKey == key then
		return
	end
	record.foundationKey = key
	if record.foundations ~= nil then
		record.foundations:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Foundations"
	local step = Assets.FOUNDATION_STEP
	for _, item in parts do
		local centre = sitePoint(record, item.site)
		for level = 1, 2 do
			local radius = if level == 1 then item.radius else item.radius * 2 / 3
			local disc = Instance.new("Part")
			disc.Name = "Foundation" .. level
			disc.Shape = Enum.PartType.Cylinder
			disc.Material = Enum.Material.Concrete
			disc.Color = Color3.fromRGB(168, 168, 164)
			disc.Anchored = true
			disc.CanCollide = true
			disc.Size = Vector3.new(step, radius * 2, radius * 2)
			-- A cylinder's axis is its X axis: turn it upright; the lower step sinks 0.15 studs into the ground.
			disc.CFrame = CFrame.new(centre.X, record.origin.Y + step * (level - 0.5) - 0.15, centre.Z)
				* CFrame.Angles(0, 0, math.pi / 2)
			disc.Parent = folder
		end
	end
	folder.Parent = record.model
	record.foundations = folder
end

-- Ground cables from every cell of the solar farm and the wind turbine whose cable stage is done to the grid box: a dark strip
-- linked field-wise to each other and to the box (Core/Cable), buried where the river runs.
local function updateCables(record: Record, land: any)
	local box = Assets.furniture.control
	local keys = {}
	local fieldSites: { { any } } = {}
	for index, cable in Assets.cables do
		local cells = anchored(land, index, cable.stage)
		table.insert(keys, `{index}:{table.concat(cells, ",")}`)
		table.insert(fieldSites, PlotLayout.cellSites(Assets.fields[index], cells, Assets.TILE, Assets.PLOT_TILES))
	end
	local key = table.concat(keys, " ")
	if record.cableKey == key then
		return
	end
	record.cableKey = key
	if record.cables ~= nil then
		record.cables:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cables"
	local function strip(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		if length < 0.1 then
			return
		end
		local part = Instance.new("Part")
		part.Name = "Cable"
		part.Material = Enum.Material.Plastic
		part.Color = Color3.fromRGB(30, 30, 34)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Size = Vector3.new(Assets.CABLE_WIDTH, 0.15, length)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Parent = folder
	end
	local y = record.origin.Y + 0.1
	local function lay(from: { x: number, z: number }, to: { x: number, z: number })
		local a, b = sitePoint(record, from), sitePoint(record, to)
		strip(Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z))
	end
	-- The sites of a field are linked to each other and to the control board; no piece lies over the river water.
	for _, sites in fieldSites do
		for _, link in Cable.links(sites, { x = box.x, z = box.z }) do
			for _, piece in Cable.dryPieces(link, Assets.river.points, Assets.river.width / 2 + 1, 2) do
				lay(piece.a, piece.b)
			end
		end
	end
	folder.Parent = record.model
	record.cables = folder
end

-- Post fence round the solar farm cells (hammer) and a guyed mast with a cross arm on the mini turbine cells (wrench).
local function updateBuilds(record: Record, land: any, counts: { number })
	local keys = {}
	local items = {}
	for index, build in Assets.stageBuilds do
		local cells = anchored(land, index, build.stage)
		if build.kind == "mast" then
			-- The mast marks a prepared cell until its turbine stands: the first `owned` mown cells carry a unit.
			local mown =
				PlotLayout.mown(land.cells and land.cells[index], land.sites[index] or 0, Assets.siteCount(index))
			local built: { [number]: boolean } = {}
			for i = 1, math.min(math.floor(counts[index] or 0), #mown) do
				built[mown[i]] = true
			end
			local open = {}
			for _, cell in cells do
				if not built[cell] then
					table.insert(open, cell)
				end
			end
			cells = open
		end
		table.insert(keys, `{index}:{table.concat(cells, ",")}`)
		for _, site in PlotLayout.cellSites(Assets.fields[index], cells, Assets.TILE, Assets.PLOT_TILES) do
			table.insert(
				items,
				{ kind = build.kind, side = Assets.fields[index].size * Assets.TILE, centre = sitePoint(record, site) }
			)
		end
	end
	local key = table.concat(keys, " ")
	if record.buildKey == key then
		return
	end
	record.buildKey = key
	if record.builds ~= nil then
		record.builds:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Builds"
	local ground = record.origin.Y
	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = material
		p.Color = color
		p.Size = size
		p.CFrame = frame
		p.Parent = folder
	end
	local wood, steel = Color3.fromRGB(120, 88, 56), Color3.fromRGB(150, 154, 160)
	for _, item in items do
		local c = item.centre
		if item.kind == "fence" then
			local half = item.side / 2 - 0.5
			local posts = math.max(1, math.floor(item.side / Assets.FENCE_POST))
			local step = 2 * half / posts
			for side = 0, 3 do
				local turn = CFrame.new(c.X, ground, c.Z) * CFrame.Angles(0, side * math.pi / 2, 0)
				for i = 0, posts - 1 do
					part(
						"FencePost",
						Vector3.new(0.4, 2.4, 0.4),
						turn * CFrame.new(-half + i * step, 1.2, half),
						wood,
						Enum.Material.Wood
					)
				end
				part(
					"FenceRail",
					Vector3.new(2 * half, 0.25, 0.2),
					turn * CFrame.new(0, 1.9, half),
					wood,
					Enum.Material.Wood
				)
				part(
					"FenceRail",
					Vector3.new(2 * half, 0.25, 0.2),
					turn * CFrame.new(0, 1.0, half),
					wood,
					Enum.Material.Wood
				)
			end
		else
			local height = Assets.MAST_HEIGHT
			part(
				"MastPole",
				Vector3.new(0.6, height, 0.6),
				CFrame.new(c.X, ground + height / 2, c.Z),
				steel,
				Enum.Material.Metal
			)
			part(
				"MastArm",
				Vector3.new(5, 0.3, 0.3),
				CFrame.new(c.X, ground + height - 1, c.Z),
				steel,
				Enum.Material.Metal
			)
			-- Three guy wires from the top to the ground, 120 degrees apart.
			local top = Vector3.new(c.X, ground + height - 0.5, c.Z)
			for i = 0, 2 do
				local angle = i * 2 * math.pi / 3
				local foot = Vector3.new(c.X + math.cos(angle) * 3.5, ground + 0.1, c.Z + math.sin(angle) * 3.5)
				part(
					"MastGuy",
					Vector3.new(0.08, 0.08, (top - foot).Magnitude),
					CFrame.lookAt((top + foot) / 2, foot),
					steel,
					Enum.Material.Metal
				)
			end
		end
	end
	folder.Parent = record.model
	record.builds = folder
end

-- The stone ring under the crank by look (Cosmetics.crankLook): S6 turns it gold with a faint glow, the Founder Pack
-- copper, else it keeps the yellow disc. The Founder Pack also puts a founder sign beside the crank.
local GOLD = Color3.fromRGB(255, 200, 40)
local COPPER = Color3.fromRGB(184, 115, 51)

local function updateFounderSign(record: Record, pad: BasePart, founder: boolean)
	local sign = record.model:FindFirstChild("FounderSign")
	if not founder then
		if sign ~= nil then
			sign:Destroy()
		end
		return
	end
	if sign ~= nil then
		return
	end
	local at = pad.Position + Vector3.new(9, 5, 0)
	local post = block(record.model, "FounderSign", Vector3.new(0.6, 5, 0.6), COPPER, at - Vector3.new(0, 3, 0))
	post.CanCollide = false
	local board = block(post, "Board", Vector3.new(7, 3, 0.4), COPPER, at)
	board.Material = Enum.Material.Metal
	board.CanCollide = false
	board.Orientation = Vector3.new(0, 90, 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "FOUNDER"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Parent = gui
end

local function updateCrank(record: Record, look: string, founder: boolean)
	local pad = record.model:FindFirstChild("CrankPad")
	if pad == nil or not pad:IsA("BasePart") then
		return
	end
	updateFounderSign(record, pad, founder)
	if record.look == look then
		return
	end
	record.look = look
	local glow = pad:FindFirstChild("GoldenGlow")
	if look == "golden" then
		pad.Color = GOLD
		pad.Material = Enum.Material.Metal
		if glow == nil then
			local light = Instance.new("PointLight")
			light.Name = "GoldenGlow"
			light.Color = GOLD
			light.Range = 14
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = pad
		end
		return
	end
	if glow ~= nil then
		glow:Destroy()
	end
	pad.Color = if look == "copper" then COPPER else COLORS.Solar
	pad.Material = if look == "copper" then Enum.Material.Metal else Enum.Material.Plastic
end

-- Gives the player a plot. Returns false when every slot is taken; the caller then turns the player away.
-- The spawn platform of the plot: the player respawns on it and, when his character stands elsewhere already (it spawned
-- while the profile loaded), is moved to it. The place's own spawn at the origin is switched off.
local SPAWN_PAD = 12
function PlotService.addSpawn(player: Player, record: Record)
	local old = workspace:FindFirstChild("SpawnLocation")
	if old ~= nil and old:IsA("SpawnLocation") then
		old:Destroy()
	end
	local crank = Assets.furniture.crank
	local at = PlotLayout.spawnPoint(Assets.PLOT_SIZE, crank.z, SPAWN_PAD)
	local point = record.origin + Vector3.new(at.x, 0.5, at.z * record.facing)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "Spawn"
	pad.Anchored = true
	pad.Neutral = true
	pad.Size = Vector3.new(SPAWN_PAD, 1, SPAWN_PAD)
	pad.Position = point
	pad.Color = COLORS.Solar
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.Parent = record.model
	player.RespawnLocation = pad
	local character = player.Character
	if character ~= nil then
		character:PivotTo(CFrame.new(point + Vector3.new(0, 4, 0)))
	end
end

function PlotService.create(player: Player, plants: { any }): boolean
	if plots[player] ~= nil then
		return true
	end
	local slot = freeSlot()
	if slot == nil then
		return false
	end
	local place = PlotLayout.slot(slot, Assets.PLOT_SPACING, Assets.PLOT_ROW_Z)
	local origin = Vector3.new(place.x, Assets.GROUND_Y, place.z)
	local model = Instance.new("Model")
	model.Name = player.Name
	-- With streaming a client gets a plot whole or not at all. No grass slab: the ground is terrain (PlotGround).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local columns: { [number]: BasePart } = {}
	local modelPlants: { boolean } = {}
	local copies: { { Model } } = {}
	for index, plant in plants do
		modelPlants[index] = PlantModels.has(index)
		copies[index] = {}
		if not modelPlants[index] then
			columns[index] = block(
				model,
				"Plant" .. index,
				Vector3.new(Assets.COLUMN, 0.2, Assets.COLUMN),
				COLORS[plant.kind] or COLORS.Grundlast,
				origin
			)
		end
	end
	model:SetAttribute("OwnerId", player.UserId) -- the client hides the prompts of other players' plots (PlotFx)
	model.Parent = plotsFolder()
	local record: Record = {
		slot = slot,
		facing = place.facing,
		origin = origin,
		model = model,
		columns = columns,
		modelPlants = modelPlants,
		copies = copies,
		shells = {},
		shellKey = "",
		keys = {},
		river = River.stages(nil, Assets.river.segments),
		course = River.course(Assets.river, slot),
		control = nil,
		batteries = {},
		shell = nil,
		groundKey = "",
		fenceKey = "",
		fences = nil,
		foundationKey = "",
		foundations = nil,
		cableKey = "",
		cables = nil,
		buildKey = "",
		builds = nil,
		themeKey = "",
		look = "plain",
	}
	plots[player] = record
	LandService.build(player, { origin = origin, facing = place.facing, model = model })
	PlotService.addSpawn(player, record)
	-- The crank and the market are built once per plot. A yellow disc under the crank marks it from afar.
	local crank = addFurniture(record, "crank", nil)
	if crank ~= nil then
		local spot = Assets.furniture.crank
		local centre = origin + Vector3.new(spot.x, 0, spot.z * place.facing)
		local pad = block(model, "CrankPad", Vector3.new(0.2, 10, 10), COLORS.Solar, centre)
		pad.Shape = Enum.PartType.Cylinder
		pad.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
		pad.CanCollide = false
		addPrompt(player, crank, "CrankPrompt", "action.crank", function(who: Player)
			if crankHandler ~= nil then
				crankHandler(who)
			end
		end)
	end
	local market = addFurniture(record, "market", nil)
	if market ~= nil then
		addPrompt(player, market, "ShopPrompt", "action.shop", nil)
	end
	-- Invisible marks for the tutorial arrow: the middle of field 1 and the river spring (cell 1 of field 2).
	for number, cell in { [1] = 13, [2] = 1 } do
		local field = Assets.fields[number]
		local site = PlotLayout.cellCentre(field, cell, Assets.TILE, Assets.PLOT_TILES)
		local spot = Instance.new("Part")
		spot.Name = "TutorialSpot" .. number
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.CastShadow = false
		spot.Transparency = 1
		spot.Size = Vector3.one
		spot.Position = sitePoint(record, site) + Vector3.new(0, 1, 0)
		spot.Parent = model
	end
	PlotService.update(player, {})
	return true
end

-- Units from the plant counts (index = plant id): min(owned, prepared sites) of constant size, and the ground from
-- `land` (the state field; a fresh land when missing). Once the player owns Mounting Rails the panels sit in rows of
-- four instead of the wild layout.
function PlotService.update(
	player: Player,
	counts: { number },
	extras: {
		stage: number,
		control: boolean,
		fill: number?,
		paint: number?,
		golden: boolean?,
		founder: boolean?,
	}?,
	land: any?
)
	local record = plots[player]
	if record == nil then
		return
	end
	local ownLand = land or Land.start
	updateFurniture(record, extras or { stage = 0, control = false }, player)
	updateLand(record, counts, ownLand, if extras ~= nil then extras.paint else nil)
	updateFoundations(record, ownLand)
	updateCables(record, ownLand)
	updateBuilds(record, ownLand, counts)
	local founder = extras ~= nil and extras.founder == true
	updateCrank(record, Cosmetics.crankLook(founder, extras ~= nil and extras.golden == true), founder)
	for index in record.modelPlants do
		if record.modelPlants[index] then
			local cells = PlotLayout.mown(
				ownLand.cells and ownLand.cells[index],
				ownLand.sites[index] or 0,
				Assets.siteCount(index)
			)
			if index == 2 then
				updateWheels(record, counts[2] or 0)
			else
				updateUnits(record, index, math.min(counts[index] or 0, 100), cells, ownLand.aligned or {})
				if index == 3 then
					updateShells(record, counts[3] or 0, cells)
				end
			end
		end
	end
	for index, column in record.columns do
		-- Primitive fallback: one column of the field's footprint on its first site, taller with more plants.
		local owned = math.min(counts[index] or 0, 100)
		local field = Assets.fields[index]
		local side = math.min(Assets.COLUMN, field.size * Assets.TILE)
		local height = 0.2 + math.min(owned, 30) * 0.2
		local first = PlotLayout.sites(field, 1, Assets.TILE, Assets.PLOT_TILES)[1]
		column.Size = Vector3.new(side, height, side)
		column.Position = sitePoint(record, first) + Vector3.new(0, height / 2, 0)
	end
end

-- Cosmetics (Core/Cosmetics flags): the glow of Neon Plants on every unit; the design of Plot Themes is rebuilt when it changes.
function PlotService.style(player: Player, flags: any)
	local record = plots[player]
	if record == nil then
		return
	end
	PlotStyle.neon(record.origin, record.copies, record.columns, flags.neon)
	local key = if flags.themed then flags.theme else ""
	if record.themeKey ~= key then
		record.themeKey = key
		PlotStyle.theme(record.model, record.origin, record.facing, if flags.themed then flags.theme else nil)
	end
end

-- Upgrade Fireworks above the player's plot.
function PlotService.fireworks(player: Player)
	local record = plots[player]
	if record ~= nil then
		PlotStyle.fireworks(record.origin)
	end
end

-- Destroys the player's plot, turns its ground back into meadow and frees its slot for the next player.
function PlotService.remove(player: Player)
	LandService.forget(player)
	local record = plots[player]
	if record ~= nil then
		record.model:Destroy()
		PlotGround.restore(record.slot)
		plots[player] = nil
	end
end

return PlotService
