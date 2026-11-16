--!strict
-- Assigns one plot per player, at most MAX_PLOTS on a server, built from basic parts (Bauplan, section 5: no assets).
-- One column per plant; the height of a column follows the number of that plant. A plot is freed when its player leaves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Core = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core")
local PlotLayout = require(Core:WaitForChild("PlotLayout") :: ModuleScript) :: any
local Formulas = require(Core:WaitForChild("Formulas") :: ModuleScript) :: any
local Meadow = require(Core:WaitForChild("Meadow") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local PlantModels = require(script.Parent.PlantModels)
local PlotGround = require(script.Parent.PlotGround)
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
	copies: { { Model } }, -- index -> the model units shown now
	keys: { string }, -- index -> "<units><w|t>" of the units shown now (w wild, t tidy)
	control: Model?, -- the control center, built once U21 is owned
	batteries: { Model }, -- one unit per storage stage
	groundKey: string, -- what the cleared patches show now
	fenceKey: string, -- what the fences show now
	fences: Folder?, -- stakes and ropes around the fields that wait for their tool
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
-- so a unit only ever stands on prepared ground. Panels (plant 1) lie wild until Mounting Rails are owned (`tidy`),
-- then in rows of four. Returns the sites and whether wild.
local function unitSites(
	record: Record,
	index: number,
	owned: number,
	prepared: number,
	tidy: boolean
): ({ any }, boolean)
	local field = Assets.fields[index]
	local count = math.min(math.floor(owned), prepared, Assets.siteCount(index))
	if index == 1 and not tidy then
		count = math.min(count, PlotLayout.wildFit(field, prepared, Assets.TILE))
		return PlotLayout.wild(field, count, record.slot, Assets.TILE, Assets.PLOT_TILES), true
	end
	return PlotLayout.sites(field, count, Assets.TILE, Assets.PLOT_TILES), false
end

-- The world position of a plot-relative site: the plot is mirrored in z when it faces the other way.
local function sitePoint(record: Record, site: { x: number, z: number }): Vector3
	return record.origin + Vector3.new(site.x, 0, site.z * record.facing)
end

-- Shows min(owned, prepared sites) model units of a plant, rebuilt only when the count or the layout changes.
local function updateUnits(record: Record, index: number, owned: number, prepared: number, tidy: boolean)
	local sites, wild = unitSites(record, index, owned, prepared, tidy)
	local key = #sites .. if wild then "w" else "t"
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
		PlantModels.place(copy, index, cell, sitePoint(record, site), record.origin.Y, angle)
		copy.Parent = record.model
		table.insert(shown, copy)
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
local function addPrompt(owner: Player, model: Model, name: string, key: string, onTriggered: ((Player) -> ())?)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor == nil then
		return
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

local function updateFurniture(record: Record, extras: { stage: number, control: boolean, fill: number? })
	if extras.control and record.control == nil then
		record.control = addFurniture(record, "control", nil)
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
local function updateLand(record: Record, counts: { number }, land: any)
	local ground, fence = {}, {}
	for index in Assets.fields do
		local total = Assets.siteCount(index)
		local prepared = math.min(land.sites[index] or 0, total)
		local open = prepared < total
			and land.tools[Land.fieldTools[index]] == true
			and (index == 1 or (counts[index - 1] or 0) >= 1)
		table.insert(ground, tostring(prepared))
		table.insert(fence, if open then tostring(prepared) else "-")
	end
	local container = land.container == true or #record.batteries > 0
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
			local tiles = math.min(land.sites[index] or 0, Assets.siteCount(index))
			for _, site in PlotLayout.sites(field, tiles, Assets.TILE, Assets.PLOT_TILES) do
				table.insert(patches, Meadow.sitePatch(site.x, site.z, side))
			end
		end
		PlotGround.clear(record.slot, record.facing, groundKey, patches)
	end
	local fenceKey = table.concat(fence, " ")
	if record.fenceKey ~= fenceKey then
		record.fenceKey = fenceKey
		if record.fences ~= nil then
			record.fences:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Fences"
		for index, field in Assets.fields do
			if fence[index] ~= "-" then
				local prepared = land.sites[index] or 0
				local stakes, ropes = Meadow.fence(field, prepared, record.slot, Assets.TILE, Assets.PLOT_TILES)
				PlotGround.fence(folder, record.origin, record.facing, stakes, ropes)
			end
		end
		folder.Parent = record.model
		record.fences = folder
	end
end

-- Gives the player a plot. Returns false when every slot is taken; the caller then turns the player away.
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
	model.Parent = plotsFolder()
	local record: Record = {
		slot = slot,
		facing = place.facing,
		origin = origin,
		model = model,
		columns = columns,
		modelPlants = modelPlants,
		copies = copies,
		keys = {},
		control = nil,
		batteries = {},
		groundKey = "",
		fenceKey = "",
		fences = nil,
	}
	plots[player] = record
	LandService.build(player, { origin = origin, facing = place.facing, model = model })
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
	PlotService.update(player, {})
	return true
end

-- Units from the plant counts (index = plant id): min(owned, prepared sites) of constant size, and the ground from
-- `land` (the state field; a fresh land when missing). Once the player owns Mounting Rails the panels sit in rows of
-- four instead of the wild layout.
function PlotService.update(
	player: Player,
	counts: { number },
	extras: { stage: number, control: boolean, fill: number? }?,
	land: any?
)
	local record = plots[player]
	if record == nil then
		return
	end
	local ownLand = land or Land.start
	local tidy = ownLand.tools.rails == true
	updateFurniture(record, extras or { stage = 0, control = false })
	updateLand(record, counts, ownLand)
	for index in record.modelPlants do
		if record.modelPlants[index] then
			updateUnits(record, index, math.min(counts[index] or 0, 100), ownLand.sites[index] or 0, tidy)
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
