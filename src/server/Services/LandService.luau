--!strict
-- Prompts for preparing the land (design 0018, section 4): one ProximityPrompt per field on an invisible anchor that
-- follows the owner's character (the player works the cell under his feet, in any order), plus the container and the
-- wiring, which stand at their furniture. A prompt only starts the hold; the server times it (Core/Work), checks the owner
-- and the distance, then sends an internal "Prepare" through the same path as a client message (Action: limit, Net, Session).
-- There is no client message for preparing, so a client can skip the animation but never the server-side hold time.
-- A step that needs a tool shows its prompt only while that tool is in the owner's hand (ToolService, Core/Toolbelt), and
-- the server checks the hand again when the hold ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any
local Work = require(Shared:WaitForChild("Core"):WaitForChild("Work") :: ModuleScript) :: any
local Toolbelt = require(Shared:WaitForChild("Core"):WaitForChild("Toolbelt") :: ModuleScript) :: any
local ToolService = require(script.Parent.ToolService)

local LandService = {}

-- The root part must be within this many studs of the site when the hold ends.
LandService.MAX_DISTANCE = 18

local FIELD_KEYS = { "prompt.mow", "prompt.dig", "prompt.house", "prompt.anchor", "prompt.fence", "prompt.compact" }
local WIRE_HOLD_TOOL = "pliers"
local TOOL_KEYS: { [string]: string } = {}
for _, tool in Land.tools do
	TOOL_KEYS[tool.id] = tool.textKey
end

export type Frame = { origin: Vector3, facing: number, model: Model }
type Entry = {
	target: any, -- plant id (1 to 6), "container" or "wired"
	prompt: ProximityPrompt,
	anchor: Part,
	hold: number,
	cell: number?, -- field cell under the owner's feet now (fields only)
	held: number?, -- the cell the hold began on (fields only)
	possible: boolean, -- the step may be worked now, apart from where the player stands
}
type Plot = { frame: Frame, work: any, entries: { Entry }, state: any? } -- state: the run at the last refresh
local plots: { [Player]: Plot } = {}

-- Set once by Action: sends a checked "Prepare" action for the player through the shared limits.
local sender: ((Player, string, { [string]: any }) -> ())? = nil

function LandService.setSender(fn: (Player, string, { [string]: any }) -> ())
	sender = fn
end

local function toolHold(toolId: string): number
	for _, tool in Land.tools do
		if tool.id == toolId then
			return tool.hold
		end
	end
	return 0
end

-- World position of a plot-relative point: the plot is mirrored in z when it faces the other way.
local function worldPoint(frame: Frame, x: number, z: number): Vector3
	return frame.origin + Vector3.new(x, 0, z * frame.facing)
end

-- The plot-relative cell of `field` under the player's feet that is not mown yet, or nil.
local function freeCellUnder(player: Player, plot: Plot, field: number): number?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or plot.state == nil then
		return nil
	end
	local at = (root :: BasePart).Position - plot.frame.origin
	local cell = PlotLayout.cellAt(Assets.fields[field], at.X, at.Z * plot.frame.facing, Assets.TILE, Assets.PLOT_TILES)
	if cell == nil then
		return nil
	end
	local land = plot.state.land or Land.start
	local mown = PlotLayout.mown(land.cells and land.cells[field], land.sites[field] or 0, Land.fields[field])
	if table.find(mown, cell) ~= nil then
		return nil
	end
	return cell
end

-- True when the player's character stands within MAX_DISTANCE studs of `point`.
local function nearby(player: Player, point: Vector3): boolean
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return ((root :: BasePart).Position - point).Magnitude <= LandService.MAX_DISTANCE
end

local function makeEntry(player: Player, plot: Plot, target: any, key: string, hold: number, point: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Land" .. tostring(target)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = point + Vector3.new(0, 2, 0)
	anchor.Parent = plot.frame.model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LandPrompt" .. tostring(target)
	local lang = Locale.resolve(player.LocaleId)
	local tool = Toolbelt.toolFor(target, Land)
	prompt.ActionText = Locale.t(key, lang)
	prompt.ObjectText = if tool ~= nil then Locale.t(TOOL_KEYS[tool], lang) else ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = if type(target) == "number" then 8 else 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- refresh() switches it on once the step is possible
	prompt.Parent = anchor
	local entry: Entry = { target = target, prompt = prompt, anchor = anchor, hold = hold, possible = false }
	table.insert(plot.entries, entry)
	local name = tostring(target)
	prompt.PromptButtonHoldBegan:Connect(function(who: Player)
		if who == player then
			entry.held = entry.cell
			Work.begin(plot.work, name, os.clock())
		end
	end)
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player or sender == nil then
			return
		end
		-- A hold of 0 needs no timer; every other hold must have run at least 0.9 x its duration on the server clock.
		local held = if entry.hold > 0 then Work.finish(plot.work, name, os.clock(), entry.hold) else true
		local land = if plot.state ~= nil then plot.state.land or Land.start else Land.start
		local inHand = Toolbelt.inHand(land, target, ToolService.equipped(player), Land)
		if type(target) == "number" then
			-- A field is worked where the player stands: the cell must be the one the hold began on, still under his feet.
			local cell = freeCellUnder(player, plot, target)
			if held and inHand and cell ~= nil and cell == entry.held then
				sender(player, "Prepare", { target = target, cell = cell })
			end
		elseif held and inHand and nearby(player, anchor.Position) then
			sender(player, "Prepare", { target = target })
		end
	end)
end

-- Builds the prompts of a new plot (called by PlotService.create); the owner is the only one who can use them.
function LandService.build(player: Player, frame: Frame)
	if plots[player] ~= nil then
		return
	end
	local plot: Plot = { frame = frame, work = Work.new(), entries = {} }
	plots[player] = plot
	for field = 1, #Land.fields do
		local hold = toolHold(Land.fieldTools[field])
		makeEntry(player, plot, field, FIELD_KEYS[field], hold, frame.origin) -- the anchor then follows the owner
	end
	local battery = Assets.furniture.battery
	makeEntry(player, plot, "container", "tool.container", 0, worldPoint(frame, battery.x, battery.z))
	local control = Assets.furniture.control
	makeEntry(player, plot, "wired", "prompt.wire", toolHold(WIRE_HOLD_TOOL), worldPoint(frame, control.x, control.z))
end

-- Once per second from Session: moves each field prompt to the next site and enables only the steps that are possible
-- (tool owned and in the hand, plant revealed, field not full, container missing, wiring ready).
function LandService.refresh(player: Player, state: any)
	local plot = plots[player]
	if plot == nil then
		return
	end
	plot.state = state
	local land = state.land or Land.start
	local hand = ToolService.equipped(player)
	for _, entry in plot.entries do
		local target = entry.target
		local enabled = false
		if type(target) == "number" then
			local done = land.sites[target] or 0
			enabled = land.tools[Land.fieldTools[target]] == true
				and (target == 1 or (state.plants[target - 1] or 0) >= 1)
				and done < Land.fields[target]
		elseif target == "container" then
			enabled = not land.container
		else
			enabled = land.container == true
				and land.wired ~= true
				and state.nodes.U21 == true
				and land.tools[WIRE_HOLD_TOOL] == true
		end
		entry.possible = enabled and Toolbelt.inHand(land, target, hand, Land)
		if type(target) == "number" then
			LandService.follow(player, plot, entry)
		else
			entry.prompt.Enabled = entry.possible
		end
	end
end

-- Field prompt: the anchor sits at the owner's feet and the prompt shows only while the step is possible and the cell
-- under him is still unmown. Called from refresh and several times a second by the loop below.
function LandService.follow(player: Player, plot: Plot, entry: Entry)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local cell = if entry.possible then freeCellUnder(player, plot, entry.target) else nil
	entry.cell = cell
	if cell ~= nil and root ~= nil and root:IsA("BasePart") then
		entry.anchor.Position = (root :: BasePart).Position
	end
	entry.prompt.Enabled = cell ~= nil
end

task.spawn(function()
	while true do
		task.wait(0.15)
		for player, plot in plots do
			for _, entry in plot.entries do
				if type(entry.target) == "number" and entry.possible then
					LandService.follow(player, plot, entry)
				end
			end
		end
	end
end)

-- Taking a tool into the hand or putting it away shows or hides its prompts at once, not at the next second.
ToolService.onEquipChanged(function(player: Player)
	local plot = plots[player]
	if plot ~= nil and plot.state ~= nil then
		LandService.refresh(player, plot.state)
	end
end)

-- Drops the player's prompts and hold (the plot model is destroyed by PlotService).
function LandService.forget(player: Player)
	plots[player] = nil
end

return LandService
