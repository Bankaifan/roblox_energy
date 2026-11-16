--!strict
-- Assigns one plot per player, at most MAX_PLOTS on a server. A plot is a piece of the meadow (no slab of its own)
-- with a thin border, the furniture in front and one field per plant: units of a fixed size stand on the sites of a
-- field (design 0018). Layout coordinates have +z on the road side; a plot on the other side of the road is mirrored
-- in z and its models are turned by 180 degrees. A plot is freed when its player leaves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Core = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core")
local PlotLayout = require(Core:WaitForChild("PlotLayout") :: ModuleScript) :: any
local Formulas = require(Core:WaitForChild("Formulas") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local PlantModels = require(script.Parent.PlantModels)

local PlotService = {}

-- One server holds 8 players (Bauplan, section 4), so 8 plots: two rows of four beside the road.
local MAX_PLOTS = 2 * Assets.PLOT_COLUMNS

local COLORS: { [string]: Color3 } = {
	Solar = Color3.fromRGB(255, 200, 60),
	Wind = Color3.fromRGB(170, 220, 255),
	Grundlast = Color3.fromRGB(140, 140, 140),
}
local BORDER_COLOR = Color3.fromRGB(226, 222, 208)
local BORDER_WIDTH = 1

type Extras = { stage: number, control: boolean, fill: number?, land: any? }
type Record = {
	slot: number,
	origin: Vector3, -- the plot centre on the ground
	facing: number, -- 1 or -1: layout +z in world z
	turn: number, -- degrees about Y that go with the mirror
	model: Model,
	columns: { BasePart }, -- index -> the primitive column, or an unseen marker when the plant has a model
	modelPlants: { boolean }, -- index -> built from a model (else the primitive column)
	copies: { { Model } }, -- index -> the units shown now
	shown: { string }, -- index -> what `copies` holds (count and layout), to rebuild only on a change
	control: Model?, -- the control center, built once U21 is owned
	batteries: { Model }, -- one unit per storage stage
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

-- The ground point of the layout point (x, z) of a plot.
local function at(record: Record, x: number, z: number): Vector3
	return record.origin + Vector3.new(x, 0, record.facing * z)
end

-- Four thin strips around the plot; the ground itself is the meadow.
local function addBorder(record: Record)
	local half = Assets.PLOT_SIZE / 2
	local edge = half - BORDER_WIDTH / 2
	for _, side in { -1, 1 } do
		local alongX = Vector3.new(Assets.PLOT_SIZE, 0.2, BORDER_WIDTH)
		local alongZ = Vector3.new(BORDER_WIDTH, 0.2, Assets.PLOT_SIZE)
		local lift = Vector3.new(0, 0.1, 0)
		block(record.model, "Border", alongX, BORDER_COLOR, at(record, 0, side * edge) + lift).CanCollide = false
		block(record.model, "Border", alongZ, BORDER_COLOR, at(record, side * edge, 0) + lift).CanCollide = false
	end
end

-- Shows the units of a plant on the sites of its field: min(owned, sites) of a fixed size, panels wild or in rows of
-- four. Rebuilt only when the number or the layout changes.
local function updateUnits(record: Record, index: number, owned: number, land: any?)
	local field = Assets.fields[index]
	local entry = Assets.entry(index)
	if field == nil or entry == nil then
		return
	end
	local wanted = PlotLayout.shown(field, owned, if land ~= nil then land.sites[index] or 0 else nil)
	local rails: boolean? = nil
	if land ~= nil then
		rails = land.tools.rails == true
	end
	local wild = entry.flat == true and not PlotLayout.tidy(field, owned, rails)
	local points = if wild
		then PlotLayout.wild(field, wanted, record.slot, Assets.TILE, Assets.PLOT_TILES)
		else PlotLayout.sites(field, wanted, Assets.TILE, Assets.PLOT_TILES)
	local key = `{#points}:{wild}`
	if record.shown[index] == key then
		return
	end
	record.shown[index] = key
	local shown = record.copies[index]
	for _, copy in shown do
		copy:Destroy()
	end
	table.clear(shown)
	for _, point in points do
		local copy = PlantModels.clone(index)
		if copy == nil then
			break
		end
		local yaw = record.turn + (point.angle or 0)
		PlantModels.place(copy, index, field.size * Assets.TILE, at(record, point.x, point.z), yaw)
		copy.Parent = record.model
		table.insert(shown, copy)
	end
end

-- Places one furniture model on the plot (nothing when its file is missing: the plot keeps the current look).
local function addFurniture(record: Record, name: string): Model?
	local entry = Assets.furniture[name]
	local target = at(record, entry.x, entry.z)
	local copy = PlantModels.furniture(name, target)
	if copy == nil then
		return nil
	end
	if name == "market" then
		PlantModels.cleanMarket(copy)
		PlantModels.mountPanels(copy)
		-- The market is built with its facade towards -z; on the plot it looks at the road.
		PlantModels.turn(copy, target, record.turn + 180)
	else
		PlantModels.turn(copy, target, record.turn)
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

local function updateFurniture(record: Record, extras: Extras)
	if extras.control and record.control == nil then
		record.control = addFurniture(record, "control")
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
	local target = at(record, Assets.furniture.battery.x, Assets.furniture.battery.z)
	for level = 0, wanted - 1 do
		local unit = PlantModels.battery(target, level)
		if unit == nil then
			break
		end
		PlantModels.turn(unit, target, record.turn)
		unit.Parent = record.model
		table.insert(record.batteries, unit)
	end
	tintBatteries(record, extras.fill or 0)
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
	local model = Instance.new("Model")
	model.Name = player.Name
	-- With streaming a client gets a plot whole or not at all.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local record: Record = {
		slot = slot,
		origin = Vector3.new(place.x, Assets.GROUND_Y, place.z),
		facing = place.facing,
		turn = if place.facing < 0 then 180 else 0,
		model = model,
		columns = {},
		modelPlants = {},
		copies = {},
		shown = {},
		control = nil,
		batteries = {},
	}
	addBorder(record)
	for index, plant in plants do
		record.modelPlants[index] = PlantModels.has(index)
		record.copies[index] = {}
		-- Named "Plant..." for the night light of World.client; unseen above the field when the plant has a model.
		local first = PlotLayout.sites(Assets.fields[index], 1, Assets.TILE, Assets.PLOT_TILES)[1]
		local spot = at(record, first.x, first.z) + Vector3.new(0, 4, 0)
		local column = block(model, "Plant" .. index, Vector3.one, COLORS[plant.kind] or COLORS.Grundlast, spot)
		column.CanCollide = false
		column.Transparency = if record.modelPlants[index] then 1 else 0
		record.columns[index] = column
	end
	model.Parent = plotsFolder()
	plots[player] = record
	-- The crank and the market are built once per plot.
	local crank = addFurniture(record, "crank")
	if crank ~= nil then
		addPrompt(player, crank, "CrankPrompt", "action.crank", function(who: Player)
			if crankHandler ~= nil then
				crankHandler(who)
			end
		end)
	end
	local market = addFurniture(record, "market")
	if market ~= nil then
		addPrompt(player, market, "ShopPrompt", "action.shop", nil)
	end
	PlotService.update(player, {})
	return true
end

-- Units from the plant counts (index = plant id), furniture from `extras`. `extras.land` is the player's land while
-- the land rules are on: then a field shows at most its prepared sites. A plant without a model file gets a column on
-- its first site whose height follows the count.
function PlotService.update(player: Player, counts: { number }, extras: Extras?)
	local record = plots[player]
	if record == nil then
		return
	end
	local given: Extras = extras or { stage = 0, control = false }
	updateFurniture(record, given)
	for index, column in record.columns do
		local owned = counts[index] or 0
		if record.modelPlants[index] then
			updateUnits(record, index, owned, given.land)
		else
			local side = Assets.fields[index].size * Assets.TILE
			local height = 0.2 + math.min(owned, 30) * 0.2
			column.Size = Vector3.new(side, height, side)
			column.Position = Vector3.new(column.Position.X, record.origin.Y + height / 2, column.Position.Z)
		end
	end
end

-- Destroys the player's plot and frees its slot for the next player.
function PlotService.remove(player: Player)
	local record = plots[player]
	if record ~= nil then
		record.model:Destroy()
		plots[player] = nil
	end
end

return PlotService
