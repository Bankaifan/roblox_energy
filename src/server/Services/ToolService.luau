--!strict
-- The tool belt: one Roblox Tool in the Backpack (hotbar) for every tool the player owns (Core/Toolbelt), built from the
-- parts of Config/Tools, named and tooltipped in the player's language. Tools are only ever added. Equipping decides
-- nothing by itself: LandService asks `equipped` on the server when a hold ends, and GameCore checks the owned tool.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Tools = require(Config:WaitForChild("Tools") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local Toolbelt = require(Shared:WaitForChild("Core"):WaitForChild("Toolbelt") :: ModuleScript) :: any

local ToolService = {}

local ID = "ToolId" -- attribute on each Tool: the id in Config/Land
local byId: { [string]: any } = {}
for _, tool in Land.tools do
	byId[tool.id] = tool
end

-- Set once by LandService: runs when a player takes a tool into the hand or puts it away.
local equipHandler: ((Player) -> ())? = nil

function ToolService.onEquipChanged(handler: (Player) -> ())
	equipHandler = handler
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function build(tool: any, lang: string): Tool
	local spec = Tools[tool.id]
	local item = Instance.new("Tool")
	item.Name = Locale.t(tool.textKey, lang)
	item.ToolTip = Locale.t(tool.textKey .. ".info", lang)
	item.CanBeDropped = false
	item.RequiresHandle = true
	item.GripPos = Vector3.new(0, spec.grip, 0)
	item:SetAttribute(ID, tool.id)
	local handle: Part? = nil
	for index, shape in spec.parts do
		local part = Instance.new("Part")
		part.Name = if index == 1 then "Handle" else shape.name
		part.Size = vector(shape.size)
		part.Color = Color3.fromRGB(shape.color[1], shape.color[2], shape.color[3])
		part.Material = (Enum.Material :: any)[shape.material]
		if shape.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if handle == nil then
			handle = part
		else
			local turn = shape.turn or { 0, 0, 0 }
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = part
			weld.C0 = CFrame.new(vector(shape.at))
				* CFrame.Angles(math.rad(turn[1]), math.rad(turn[2]), math.rad(turn[3]))
			weld.Parent = part
		end
		part.Parent = item
	end
	return item
end

-- The player's Tool for `id`, in the hand or in the Backpack.
local function find(player: Player, backpack: Instance, id: string): Tool?
	for _, holder in { backpack, player.Character :: Instance? } do
		if holder ~= nil then
			for _, child in holder:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(ID) == id then
					return child
				end
			end
		end
	end
	return nil
end

-- Gives the player every owned tool that is missing (after the profile loads, after BuyTool, after a respawn). Called
-- once per second from Session; removes nothing.
function ToolService.refresh(player: Player, land: any)
	if typeof(player) ~= "Instance" then
		return -- Session.test runs with plain tables as players
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	local lang = Locale.resolve(player.LocaleId)
	for _, id in Toolbelt.owned(land, Land) do
		if Tools[id] ~= nil and find(player, backpack, id) == nil then
			local item = build(byId[id], lang)
			-- Deferred: the handler reads the hand after the Tool has moved between Backpack and character.
			local function changed()
				task.defer(function()
					if equipHandler ~= nil then
						equipHandler(player)
					end
				end)
			end
			item.Equipped:Connect(changed)
			item.Unequipped:Connect(changed)
			item.Parent = backpack
		end
	end
end

-- The id of the tool the player's character holds now, or nil. Read on the server, so a client cannot claim a tool.
function ToolService.equipped(player: Player): string?
	if typeof(player) ~= "Instance" then
		return nil
	end
	local character = player.Character
	local held = if character ~= nil then character:FindFirstChildOfClass("Tool") else nil
	local id = if held ~= nil then held:GetAttribute(ID) else nil
	return if type(id) == "string" then id else nil
end

return ToolService
