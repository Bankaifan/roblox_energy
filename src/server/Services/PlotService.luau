--!strict
-- Assigns one plot per player, at most MAX_PLOTS on a server, built from basic parts (Bauplan, section 5: no assets).
-- One column per plant; the height of a column follows the number of that plant. A plot is freed when its player leaves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local PlantModels = require(script.Parent.PlantModels)

local PlotService = {}

-- One server holds 8 players (Bauplan, section 4), so 8 plots.
local MAX_PLOTS = 8

local COLORS: { [string]: Color3 } = {
	Solar = Color3.fromRGB(255, 200, 60),
	Wind = Color3.fromRGB(170, 220, 255),
	Grundlast = Color3.fromRGB(140, 140, 140),
}

type Record = {
	slot: number,
	origin: Vector3,
	model: Model,
	columns: { BasePart },
	modelPlants: { boolean }, -- index -> built from a model (else the primitive column)
	copies: { { Model } }, -- index -> the model copies shown now
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

-- Shows min(owned, cap) model copies of a plant in its slot, rebuilt only when that number changes.
local function updateCopies(record: Record, index: number, owned: number, centre: Vector3)
	local entry = Assets.entry(index)
	local wanted = Assets.visibleCopies(owned, if entry ~= nil then entry.cap else 0)
	local shown = record.copies[index]
	if #shown == wanted then
		return
	end
	for _, copy in shown do
		copy:Destroy()
	end
	table.clear(shown)
	local cell, offsets = Assets.layout(wanted, Assets.SLOT)
	for _, offset in offsets do
		local copy = PlantModels.clone(index)
		if copy == nil then
			break
		end
		PlantModels.place(copy, index, cell, centre + Vector3.new(offset.x, 0, offset.z), 1.2)
		copy.Parent = record.model
		table.insert(shown, copy)
	end
end

-- Places one furniture model on the plot (nothing when its file is missing: the plot keeps the current look).
local function addFurniture(record: Record, name: string, turn: number?): Model?
	local copy = PlantModels.furniture(name, record.origin, 1, turn)
	if copy == nil then
		return nil
	end
	if name == "market" then
		PlantModels.cleanMarket(copy)
		PlantModels.mountPanels(copy)
	end
	copy.Parent = record.model
	return copy
end

-- Control center from U21, one battery unit per storage stage; both are rebuilt only when the number changes.
local function updateFurniture(record: Record, extras: { stage: number, control: boolean })
	if extras.control and record.control == nil then
		record.control = addFurniture(record, "control", nil)
	end
	local wanted = Assets.batteryUnits(extras.stage)
	if #record.batteries == wanted then
		return
	end
	for _, unit in record.batteries do
		unit:Destroy()
	end
	table.clear(record.batteries)
	for level = 0, wanted - 1 do
		local unit = PlantModels.battery(record.origin, 1, level)
		if unit == nil then
			break
		end
		unit.Parent = record.model
		table.insert(record.batteries, unit)
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
	local origin = Vector3.new(slot * 60, 0, 0)
	local model = Instance.new("Model")
	model.Name = player.Name
	block(model, "Ground", Vector3.new(40, 1, 40), Color3.fromRGB(90, 140, 80), origin + Vector3.new(0, 0.5, 0))
	local columns: { BasePart } = {}
	local modelPlants: { boolean } = {}
	local copies: { { Model } } = {}
	for index, plant in plants do
		modelPlants[index] = PlantModels.has(index)
		copies[index] = {}
		columns[index] =
			block(model, "Plant" .. index, Vector3.new(4, 0.2, 4), COLORS[plant.kind] or COLORS.Grundlast, origin)
	end
	model.Parent = plotsFolder()
	local record: Record = {
		slot = slot,
		origin = origin,
		model = model,
		columns = columns,
		modelPlants = modelPlants,
		copies = copies,
		control = nil,
		batteries = {},
	}
	plots[player] = record
	-- The crank and the market are built once per plot.
	addFurniture(record, "crank", nil)
	addFurniture(record, "market", nil)
	PlotService.update(player, {})
	return true
end

-- Column heights from the plant counts (index = plant id). Capped at 100 plants per column.
function PlotService.update(player: Player, counts: { number }, extras: { stage: number, control: boolean }?)
	local record = plots[player]
	if record == nil then
		return
	end
	updateFurniture(record, extras or { stage = 0, control = false })
	for index, column in record.columns do
		local owned = math.min(counts[index] or 0, 100)
		local centre = record.origin + Vector3.new((index - 3.5) * 5, 0, 0)
		if record.modelPlants[index] then
			column.Size = Vector3.new(4, 0.2, 4)
			column.Position = centre + Vector3.new(0, 1.1, 0)
			updateCopies(record, index, owned, centre)
		else
			local height = 0.2 + owned * 0.2
			column.Size = Vector3.new(4, height, 4)
			column.Position = centre + Vector3.new(0, 1 + height / 2, 0)
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
