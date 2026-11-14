--!strict
-- Run state per player, in memory until M2. Session.tick runs GameCore.tick once per second for every player and
-- sends the owner a Delta. Snapshot goes on Ready and after Netz-Ausbau. The rules themselves live in GameCore.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameCore = require(Shared:WaitForChild("Core"):WaitForChild("GameCore") :: ModuleScript) :: any
local Formulas = require(Shared:WaitForChild("Core"):WaitForChild("Formulas") :: ModuleScript) :: any
local Env = require(script.Parent.Env)
local PlotService = require(script.Parent.PlotService)

local Config = Shared:WaitForChild("Config")
local function load(name: string): any
	return require(Config:WaitForChild(name) :: ModuleScript)
end
local config = {
	plants = load("Plants"),
	upgrades = load("Upgrades"),
	prestige = load("Prestige"),
	phases = load("Phases"),
	weathers = load("Weather"),
	effects = load("Effects"),
}

local states: { [Player]: any } = {}
local Session = {}

local function envFor(phase: any, weather: any): any
	return { phase = phase, weather = weather, longMeter = false, config = config, formulas = Formulas }
end

-- An empty run in the Bauplan data model, version 1.
local function freshRun(): { [string]: any }
	local plants = {}
	for _, plant in config.plants do
		plants[plant.id] = 0
	end
	return {
		v = 1,
		coins = 0,
		runEarned = 0,
		lifetimeEarned = 0,
		level = 0,
		sparks = 0,
		sparksSpent = 0,
		plants = plants,
		nodes = {},
		pnodes = {},
		storage = { charge = 0, mode = "auto" },
		rules = {},
	}
end

function Session.start(player: Player)
	if states[player] ~= nil then
		return
	end
	-- No free plot means the server is full; the player is turned away before a run starts.
	if not PlotService.create(player, config.plants) then
		player:Kick("The server is full. Try another server.")
		return
	end
	states[player] = freshRun()
end

function Session.stop(player: Player)
	states[player] = nil
	PlotService.remove(player)
end

-- Ready: the client gets the current phase and weather, then the whole run.
function Session.ready(remotes: { [string]: RemoteEvent }, player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local phase, weather = Env.current()
	remotes.Env:FireClient(player, { phase = phase.id, weather = weather.id })
	remotes.Snapshot:FireClient(player, state)
end

-- One checked client action. GameCore.apply rejects anything it does not accept; then nothing changes.
function Session.apply(remotes: { [string]: RemoteEvent }, player: Player, action: { [string]: any })
	local state = states[player]
	if state == nil then
		return
	end
	local phase, weather = Env.update(remotes)
	local nextState, ok = GameCore.apply(state, action, envFor(phase, weather))
	if not ok then
		return
	end
	states[player] = nextState
	if action.type == "Prestige" then
		remotes.Snapshot:FireClient(player, nextState)
	end
end

-- Once per second: every run gets one step of `dt` seconds.
function Session.tick(remotes: { [string]: RemoteEvent }, dt: number)
	local phase, weather = Env.update(remotes)
	local env = envFor(phase, weather)
	for player, state in states do
		local nextState = GameCore.tick(state, env, dt)
		states[player] = nextState
		PlotService.update(player, nextState.plants)
		remotes.Delta:FireClient(player, {
			coins = nextState.coins,
			rate = (nextState.lifetimeEarned - state.lifetimeEarned) / dt,
			charge = nextState.storage.charge,
			view = GameCore.view(nextState, env),
		})
	end
end

return Session
