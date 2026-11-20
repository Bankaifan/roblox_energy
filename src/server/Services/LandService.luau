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
local Effects = require(Config:WaitForChild("Effects") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any
local GameCore = require(Shared:WaitForChild("Core"):WaitForChild("GameCore") :: ModuleScript) :: any
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
	hold: number, -- seconds the server expects, with Quick Hands (S3) applied
	base: number, -- the hold of the fixed steps before S3
	factor: number?, -- the S3 factor the prompt shows now
	cell: number?, -- field cell under the owner's feet now (fields only)
	held: number?, -- the cell the hold began on (fields only)
	possible: boolean, -- the step may be worked now, apart from where the player stands and the tool in the hand
	stage: number?, -- stage of the cell under the owner's feet (fields only), to retitle the prompt on a change
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

-- The mown F1 cell under the player's feet that may be aligned now (holds its panels, not aligned yet), or nil.
local function alignCellUnder(player: Player, plot: Plot): number?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or plot.state == nil then
		return nil
	end
	local at = (root :: BasePart).Position - plot.frame.origin
	local cell = PlotLayout.cellAt(Assets.fields[1], at.X, at.Z * plot.frame.facing, Assets.TILE, Assets.PLOT_TILES)
	local land = plot.state.land or Land.start
	local cells = if land.cells ~= nil then land.cells[1] or {} else {}
	local index = if cell ~= nil then table.find(cells, cell) else nil
	if
		index == nil
		or index > (land.sites[1] or 0)
		or (plot.state.plants[1] or 0) < Land.align.perCell * index
		or table.find(land.aligned or {}, cell) ~= nil
	then
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
	local tool = Toolbelt.toolFor(target, Land, Land.start, nil)
	prompt.ActionText = Locale.t(key, lang)
	prompt.ObjectText = if tool ~= nil then Locale.t(TOOL_KEYS[tool], lang) else ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = if type(target) == "number" or target == "align" then 8 else 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- refresh() switches it on once the step is possible
	prompt.Parent = anchor
	local entry: Entry =
		{ target = target, prompt = prompt, anchor = anchor, hold = hold, base = hold, possible = false }
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
		local under = if type(target) == "number"
			then freeCellUnder(player, plot, target)
			elseif target == "align" then alignCellUnder(player, plot)
			else nil
		local inHand = Toolbelt.inHand(land, target, ToolService.equipped(player), Land, under)
		if target == "align" then
			if held and inHand and under ~= nil and entry.held ~= nil then
				sender(player, "Align", { cell = entry.held })
			end
		elseif type(target) == "number" then
			-- A field is worked on the cell the hold began on; the player must still stand on an unworked cell of the field
			-- (a step over the tile edge while holding does not cancel the work).
			local cell = entry.held
			if held and inHand and under ~= nil and cell ~= nil then
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
		local hold = Land.chains[field][1].hold
		makeEntry(player, plot, field, FIELD_KEYS[field], hold, frame.origin) -- the anchor then follows the owner
	end
	makeEntry(player, plot, "align", "prompt.align", Land.align.hold, frame.origin) -- follows the owner like a field prompt
	local battery = Assets.furniture.battery
	makeEntry(player, plot, "container", "tool.container", 0, worldPoint(frame, battery.x, battery.z))
	local control = Assets.furniture.control
	makeEntry(player, plot, "wired", "prompt.wire", toolHold(WIRE_HOLD_TOOL), worldPoint(frame, control.x, control.z))
end

-- S3 Quick Hands halves every hold of the owner (Effects.holdFactor); 1 without it. The rule is GameCore.holdFactor.
function LandService.holdFactor(state: any?): number
	if state == nil then
		return 1
	end
	return GameCore.holdFactor(state, Effects)
end

-- Once per second from Session: moves each field prompt to the next site and enables only the steps that are possible
-- (tool owned and in the hand, plant revealed, field not full, container missing, wiring ready).
function LandService.refresh(player: Player, state: any)
	local plot = plots[player]
	if plot == nil then
		return
	end
	plot.state = state
	local factor = LandService.holdFactor(state)
	local land = state.land or Land.start
	local hand = ToolService.equipped(player)
	for _, entry in plot.entries do
		local target = entry.target
		local enabled = false
		-- Quick Hands (S3): the fixed steps (align, container, wiring) take the factor of the owner at once.
		if type(target) ~= "number" and entry.factor ~= factor then
			entry.factor = factor
			entry.hold = entry.base * factor
			entry.prompt.HoldDuration = entry.hold
		end
		if type(target) == "number" then
			local done = land.sites[target] or 0
			-- The tool is decided per cell (follow), so a cell that waits for a tool never blocks the mowing of the next one.
			enabled = (target == 1 or (state.plants[target - 1] or 0) >= 1) and done < Land.fields[target]
		elseif target == "align" then
			enabled = land.tools.rails == true and (state.plants[1] or 0) >= 1
		elseif target == "container" then
			enabled = not land.container
		else
			enabled = land.container == true
				and land.wired ~= true
				and state.nodes.U21 == true
				and land.tools[WIRE_HOLD_TOOL] == true
		end
		-- The tool of a field depends on the cell under the player's feet (follow), so only the other steps check it here.
		entry.possible = enabled
			and (type(target) == "number" or target == "align" or Toolbelt.inHand(land, target, hand, Land, nil))
		if type(target) == "number" or target == "align" then
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
	local cell = nil
	if entry.possible then
		cell = if entry.target == "align"
			then alignCellUnder(player, plot)
			else freeCellUnder(player, plot, entry.target)
	end
	entry.cell = cell
	local land = if plot.state ~= nil then plot.state.land or Land.start else Land.start
	local stage, tool, hold = Toolbelt.stage(land, entry.target, cell, Land)
	local factor = LandService.holdFactor(plot.state)
	if cell ~= nil and root ~= nil and root:IsA("BasePart") then
		entry.anchor.Position = (root :: BasePart).Position
	end
	-- The prompt shows the tool and hold of the stage under his feet and only while that tool is in his hand.
	if stage ~= nil and tool ~= nil and (entry.stage ~= stage or entry.factor ~= factor) then
		entry.stage = stage
		entry.factor = factor
		entry.hold = (hold or 0) * factor
		entry.prompt.HoldDuration = entry.hold
		entry.prompt.ObjectText = Locale.t(TOOL_KEYS[tool], Locale.resolve(player.LocaleId))
		local action = if type(entry.target) == "number" then Toolbelt.actionKey(entry.target, tool) else nil
		if action ~= nil then
			entry.prompt.ActionText = Locale.t(action, Locale.resolve(player.LocaleId))
		end
	end
	entry.prompt.Enabled = cell ~= nil and Toolbelt.inHand(land, entry.target, ToolService.equipped(player), Land, cell)
end

task.spawn(function()
	while true do
		task.wait(0.15)
		for player, plot in plots do
			for _, entry in plot.entries do
				if (type(entry.target) == "number" or entry.target == "align") and entry.possible then
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
