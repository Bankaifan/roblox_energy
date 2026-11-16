--!strict
-- Prompts for preparing the land (design 0018, section 4): one ProximityPrompt per field on an invisible anchor at the next
-- site, plus the container and the wiring. A prompt only starts the hold; the server times it (Core/Work), checks the owner
-- and the distance, then sends an internal "Prepare" through the same path as a client message (Action: limit, Net, Session).
-- There is no client message for preparing, so a client can skip the animation but never the server-side hold time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Assets = require(Config:WaitForChild("Assets") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local PlotLayout = require(Shared:WaitForChild("Core"):WaitForChild("PlotLayout") :: ModuleScript) :: any
local Work = require(Shared:WaitForChild("Core"):WaitForChild("Work") :: ModuleScript) :: any

local LandService = {}

-- The root part must be within this many studs of the site when the hold ends.
LandService.MAX_DISTANCE = 18

local FIELD_KEYS = { "prompt.mow", "prompt.dig", "prompt.house", "prompt.anchor", "prompt.fence", "prompt.compact" }
local WIRE_HOLD_TOOL = "pliers"

export type Frame = { origin: Vector3, facing: number, model: Model }
type Entry = {
	target: any, -- plant id (1 to 6), "container" or "wired"
	prompt: ProximityPrompt,
	anchor: Part,
	hold: number,
	shown: number, -- sites the anchor is placed for (fields only)
}
type Plot = { frame: Frame, work: any, entries: { Entry } }
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

-- The next site of a field (the one after the `done` prepared), or the last one when the field is full.
local function nextSite(field: number, done: number): { x: number, z: number }
	local count = math.min(done + 1, Land.fields[field])
	local sites = PlotLayout.sites(Assets.fields[field], count, Assets.TILE, Assets.PLOT_TILES)
	return sites[#sites]
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
	prompt.ActionText = Locale.t(key, Locale.resolve(player.LocaleId))
	prompt.ObjectText = ""
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- refresh() switches it on once the step is possible
	prompt.Parent = anchor
	local entry: Entry = { target = target, prompt = prompt, anchor = anchor, hold = hold, shown = 0 }
	table.insert(plot.entries, entry)
	local name = tostring(target)
	prompt.PromptButtonHoldBegan:Connect(function(who: Player)
		if who == player then
			Work.begin(plot.work, name, os.clock())
		end
	end)
	prompt.Triggered:Connect(function(who: Player)
		if who ~= player or sender == nil then
			return
		end
		-- A hold of 0 needs no timer; every other hold must have run at least 0.9 x its duration on the server clock.
		local held = if entry.hold > 0 then Work.finish(plot.work, name, os.clock(), entry.hold) else true
		if held and nearby(player, anchor.Position) then
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
		local site = nextSite(field, 0)
		local hold = toolHold(Land.fieldTools[field])
		makeEntry(player, plot, field, FIELD_KEYS[field], hold, worldPoint(frame, site.x, site.z))
	end
	local battery = Assets.furniture.battery
	makeEntry(player, plot, "container", "tool.container", 0, worldPoint(frame, battery.x, battery.z))
	local control = Assets.furniture.control
	makeEntry(player, plot, "wired", "prompt.wire", toolHold(WIRE_HOLD_TOOL), worldPoint(frame, control.x, control.z))
end

-- Once per second from Session: moves each field prompt to the next site and enables only the steps that are possible
-- (tool owned, plant revealed, field not full, container missing, wiring ready).
function LandService.refresh(player: Player, state: any)
	local plot = plots[player]
	if plot == nil then
		return
	end
	local land = state.land or Land.start
	for _, entry in plot.entries do
		local target = entry.target
		local enabled = false
		if type(target) == "number" then
			local done = land.sites[target] or 0
			enabled = land.tools[Land.fieldTools[target]] == true
				and (target == 1 or (state.plants[target - 1] or 0) >= 1)
				and done < Land.fields[target]
			if enabled and entry.shown ~= done + 1 then
				entry.shown = done + 1
				local site = nextSite(target, done)
				entry.anchor.Position = worldPoint(plot.frame, site.x, site.z) + Vector3.new(0, 2, 0)
			end
		elseif target == "container" then
			enabled = not land.container
		else
			enabled = land.container == true
				and land.wired ~= true
				and state.nodes.U21 == true
				and land.tools[WIRE_HOLD_TOOL] == true
		end
		entry.prompt.Enabled = enabled
	end
end

-- Drops the player's prompts and hold (the plot model is destroyed by PlotService).
function LandService.forget(player: Player)
	plots[player] = nil
end

return LandService
