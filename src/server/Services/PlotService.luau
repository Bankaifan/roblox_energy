--!strict
-- Assigns one plot per player, at most MAX_PLOTS on a server, built from basic parts (Bauplan, section 5: no assets).
-- One column per plant; the height of a column follows the number of that plant. A plot is freed when its player leaves.
local PlotService = {}

-- One server holds 8 players (Bauplan, section 4), so 8 plots.
local MAX_PLOTS = 8

local COLORS: { [string]: Color3 } = {
	Solar = Color3.fromRGB(255, 200, 60),
	Wind = Color3.fromRGB(170, 220, 255),
	Grundlast = Color3.fromRGB(140, 140, 140),
}

type Record = { slot: number, origin: Vector3, model: Model, columns: { BasePart } }
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
	for index, plant in plants do
		columns[index] =
			block(model, "Plant" .. index, Vector3.new(4, 0.2, 4), COLORS[plant.kind] or COLORS.Grundlast, origin)
	end
	model.Parent = plotsFolder()
	plots[player] = { slot = slot, origin = origin, model = model, columns = columns }
	PlotService.update(player, {})
	return true
end

-- Column heights from the plant counts (index = plant id). Capped at 100 plants per column.
function PlotService.update(player: Player, counts: { number })
	local record = plots[player]
	if record == nil then
		return
	end
	for index, column in record.columns do
		local height = 0.2 + math.min(counts[index] or 0, 100) * 0.2
		column.Size = Vector3.new(4, height, 4)
		column.Position = record.origin + Vector3.new((index - 3.5) * 5, 1 + height / 2, 0)
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
