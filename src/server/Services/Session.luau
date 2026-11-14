--!strict
-- Run state per player, in memory while the player is in the game. Session.tick runs GameCore.tick once per second for
-- every player and sends the owner a Delta. Snapshot goes on Ready and after Netz-Ausbau. The rules themselves live in
-- GameCore. A run starts only with a loaded profile (DataService); every change is copied into the profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameCore = require(Shared:WaitForChild("Core"):WaitForChild("GameCore") :: ModuleScript) :: any
local Formulas = require(Shared:WaitForChild("Core"):WaitForChild("Formulas") :: ModuleScript) :: any
local Env = require(script.Parent.Env)
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)

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
-- Players whose profile is still loading; `remotes` is set when their Ready arrives before the load ends.
local loading: { [Player]: { remotes: { [string]: RemoteEvent }? } } = {}
local gains: { [Player]: number } = {}
local Session = {}

local function envFor(phase: any, weather: any): any
	return { phase = phase, weather = weather, longMeter = false, config = config, formulas = Formulas }
end

-- Join: the profile loads first, so nobody plays without a saved profile. Then the offline income of the time away
-- is credited, and the plot is given out.
function Session.start(player: Player)
	if states[player] ~= nil or loading[player] ~= nil then
		return
	end
	loading[player] = {}
	local state, away = DataService.load(player)
	local job = loading[player]
	loading[player] = nil
	if state == nil then
		if player.Parent ~= nil then
			player:Kick("Your save could not be loaded. Please rejoin.")
		end
		return
	end
	if player.Parent == nil then
		DataService.release(player)
		return
	end
	-- No free plot means the server is full; the player is turned away before a run starts.
	if not PlotService.create(player, config.plants) then
		DataService.release(player)
		player:Kick("The server is full. Try another server.")
		return
	end
	local phase, weather = Env.current()
	local credited = GameCore.offline(state, away, envFor(phase, weather))
	gains[player] = credited.coins - state.coins
	states[player] = credited
	DataService.sync(player, credited)
	if job.remotes ~= nil then
		Session.ready(job.remotes, player)
	end
end

function Session.stop(player: Player)
	local state = states[player]
	states[player] = nil
	gains[player] = nil
	DataService.release(player, state)
	PlotService.remove(player)
end

-- Shutdown: every run is written and released, then the saves are awaited (BindToClose allows about 30 s).
function Session.close()
	for player, state in states do
		states[player] = nil
		DataService.release(player, state)
	end
	DataService.flush(25)
end

-- The income credited for the time away at the join, for the welcome screen (M2-3). 0 when there was none.
function Session.offlineGain(player: Player): number
	return gains[player] or 0
end

-- Ready: the client gets the current phase and weather, then the whole run.
function Session.ready(remotes: { [string]: RemoteEvent }, player: Player)
	local job = loading[player]
	if job ~= nil then
		job.remotes = remotes
		return
	end
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
	DataService.sync(player, nextState)
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
		DataService.sync(player, nextState)
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
