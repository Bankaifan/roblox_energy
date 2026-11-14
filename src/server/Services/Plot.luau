--!strict
-- One plot per player, built from basic parts (Bauplan, section 5: no assets). One column per plant,
-- the height of a column follows the number of that plant.
local Plot = {}

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

local function freeSlot(): number
	local slot = 1
	while true do
		local taken = false
		for _, record in plots do
			taken = taken or record.slot == slot
		end
		if not taken then
			return slot
		end
		slot += 1
	end
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

function Plot.create(player: Player, plants: { any })
	local slot = freeSlot()
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
	Plot.update(player, {})
end

-- Column heights from the plant counts (index = plant id). Capped at 100 plants per column.
function Plot.update(player: Player, counts: { number })
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

function Plot.remove(player: Player)
	local record = plots[player]
	if record ~= nil then
		record.model:Destroy()
		plots[player] = nil
	end
end

return Plot
