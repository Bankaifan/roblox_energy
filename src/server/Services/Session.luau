--!strict
-- Run state per player, in memory while the player is in the game. Session.tick runs GameCore.tick once per second for
-- every player and sends the owner a Delta. Snapshot goes on Ready and after Netz-Ausbau. The rules themselves live in
-- GameCore. A run starts only with a loaded profile (DataService); every change is copied into the profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameCore = require(Shared:WaitForChild("Core"):WaitForChild("GameCore") :: ModuleScript) :: any
local Shop = require(Shared:WaitForChild("Core"):WaitForChild("Shop") :: ModuleScript) :: any
local Catalogue = require(Shared:WaitForChild("Config"):WaitForChild("Shop") :: ModuleScript) :: any
local Cosmetics = require(Shared:WaitForChild("Core"):WaitForChild("Cosmetics") :: ModuleScript) :: any
local Hints = require(Shared:WaitForChild("Core"):WaitForChild("Hints") :: ModuleScript) :: any
local HintView = require(Shared:WaitForChild("Core"):WaitForChild("HintView") :: ModuleScript) :: any
local Formulas = require(Shared:WaitForChild("Core"):WaitForChild("Formulas") :: ModuleScript) :: any
local Env = require(script.Parent.Env)
local PlotService = require(script.Parent.PlotService)
local LandService = require(script.Parent.LandService)
local ToolService = require(script.Parent.ToolService)
local DataService = require(script.Parent.DataService)
local BoostService = require(script.Parent.BoostService)
local PurchaseService = require(script.Parent.PurchaseService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlotPublicService = require(script.Parent.PlotPublicService)
local TutorialService = require(script.Parent.TutorialService)

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
	land = load("Land"), -- BuyTool and Prepare; the gates stay off until Land.required is true
}

local states: { [Player]: any } = {}
-- Players whose profile is still loading; `remotes` is set when their Ready arrives before the load ends.
local loading: { [Player]: { remotes: { [string]: RemoteEvent }? } } = {}
-- The time away and the offline coins credited at the join. Sent once, with the first Ready after the join.
local welcomes: { [Player]: { away: number, coins: number, hint: boolean } } = {}
-- When each run started (os.clock): the time played in this session, for the Extras tab (minute 12).
local started: { [Player]: number } = {}
-- Auto Crank: the hand cranks since the last tick (they use their share of the limit first) and the carried fraction.
local handCranks: { [Player]: number } = {}
local crankCarry: { [Player]: number } = {}
local Session = {}

-- The bought effects of the player (Core/Shop.envValues): sale multiplier, Sunshine boost, Long Meter, Smart Hub.
-- Without a player (no profile) there are none.
local function envFor(phase: any, weather: any, player: Player?): any
	local profile = if player ~= nil then DataService.profileOf(player) else nil
	local sunshine = BoostService.sunshineStatus().active
	local turbo = player ~= nil and BoostService.turboRemaining(player) > 0
	local bought = if profile ~= nil
		then Shop.envValues(profile.Data, Catalogue, sunshine, turbo)
		else { longMeter = false }
	return {
		phase = phase,
		weather = weather,
		longMeter = bought.longMeter,
		config = config,
		formulas = Formulas,
		boost = bought.boost,
		income = bought.income,
		ruleSlots = bought.ruleSlots,
		autoBuild = bought.autoBuild,
		nextWeather = Env.nextWeather(),
	}
end

-- Seconds of yield a Time Skip gives (Config/Shop); 0 if the catalogue has none.
local function skipSeconds(): number
	for _, offer in Catalogue.offers do
		if offer.id == "timeskip" then
			return offer.seconds
		end
	end
	return 0
end
local SKIP_SECONDS = skipSeconds()
local PASS_WAIT_SECONDS = 8 -- the join waits at most this long for the pass check before the offline credit

-- Time Skip and Founder Pack payouts (PurchaseService): the coins of `seconds` of full-rate yield for the live run, and
-- paying them into it. Both work on the run in memory; DataService.sync copies it into the profile.
PurchaseService.setPayout(function(player: Player, seconds: number): number?
	local state = states[player]
	if state == nil then
		return nil
	end
	local phase, weather = Env.current()
	return GameCore.yield(state, seconds, envFor(phase, weather, player))
end, function(player: Player, coins: number)
	local state = states[player]
	if state == nil then
		return
	end
	local nextState = GameCore.payout(state, coins)
	states[player] = nextState
	DataService.sync(player, nextState)
end)

-- Spark packs (PurchaseService): the sparks bought go into the live run, which DataService.sync copies into the profile.
-- False without a run yet; a negative count takes a grant back.
PurchaseService.setSparks(function(player: Player, count: number): boolean
	local state = states[player]
	if state == nil then
		return false
	end
	local nextState = table.clone(state)
	nextState.sparks = state.sparks + count
	states[player] = nextState
	DataService.sync(player, nextState)
	return true
end)

-- Join: the profile loads first, so nobody plays without a saved profile. Then the offline income of the time away
-- is credited, and the plot is given out.
function Session.start(player: Player)
	if states[player] ~= nil or loading[player] ~= nil then
		return
	end
	loading[player] = {}
	local state, away = DataService.load(player)
	local job = loading[player]
	if state == nil then
		loading[player] = nil
		if player.Parent ~= nil then
			player:Kick("Your save could not be loaded. Please rejoin.")
		end
		return
	end
	if player.Parent == nil then
		loading[player] = nil
		DataService.release(player)
		return
	end
	-- No free plot means the server is full; the player is turned away before a run starts.
	if not PlotService.create(player, config.plants) then
		loading[player] = nil
		DataService.release(player)
		player:Kick("The server is full. Try another server.")
		return
	end
	-- Owned passes and the paid-item policy come first: the offline credit needs the passes (Long Meter raises the cap).
	-- Asked in a task and waited for at most PASS_WAIT_SECONDS, so a slow Roblox answer does not hold the join; a pass
	-- that confirms later is granted then (the credit of this join has used the cap without it).
	local checked = false
	task.spawn(function()
		local ok, err = pcall(PurchaseService.join, player)
		if not ok then
			warn(`[Session] pass check of {player.Name} failed: {err}`)
		end
		checked = true
	end)
	local deadline = os.clock() + PASS_WAIT_SECONDS
	while not checked and player.Parent ~= nil and os.clock() < deadline do
		task.wait()
	end
	if player.Parent == nil then
		loading[player] = nil
		DataService.release(player)
		PlotService.remove(player)
		return
	end
	loading[player] = nil
	local phase, weather = Env.current()
	local env = envFor(phase, weather, player)
	local credited = GameCore.offline(state, away, env)
	-- The Long Meter hint of the welcome screen: the cap was reached and Core/HintView allows the line.
	local capped = away >= GameCore.offlineCap(state, env)
	local hint = #HintView.lines("welcome", {
		extras = PurchaseService.extras(player, math.huge),
		allowed = Hints.allowed,
		firstSeconds = Catalogue.firstHintSeconds,
		storageBought = false,
		controlBought = false,
		gridLevel = 0,
		offlineCapped = capped,
	}) > 0
	welcomes[player] = { away = away, coins = credited.coins - state.coins, hint = hint }
	states[player] = credited
	started[player] = os.clock()
	DataService.sync(player, credited)
	ToolService.refresh(player, credited.land or config.land.start)
	PurchaseService.claimYield(player) -- the Founder Pack yield, if the pass was confirmed and is still unpaid
	if job.remotes ~= nil then
		Session.ready(job.remotes, player)
	end
end

function Session.stop(player: Player)
	local state = states[player]
	states[player] = nil
	welcomes[player] = nil
	started[player] = nil
	handCranks[player] = nil
	crankCarry[player] = nil
	BoostService.forget(player)
	LeaderboardService.forget(player)
	PlotPublicService.forget(player)
	TutorialService.forget(player)
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

-- Ready: the client gets the current phase and weather, then the whole run. After the first Ready of a join it also gets
-- the Welcome (time away and offline coins), when the time away reached the minimum that pays offline income.
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
	remotes.Env:FireClient(player, Env.payload(phase, weather))
	remotes.Snapshot:FireClient(player, state)
	TutorialService.send(remotes, player)
	local welcome = welcomes[player]
	welcomes[player] = nil
	if welcome ~= nil and welcome.away >= config.effects.offlineMinimumSeconds then
		remotes.Welcome:FireClient(player, welcome)
	end
end

-- One checked client action. GameCore.apply rejects anything it does not accept; then nothing changes.
function Session.apply(remotes: { [string]: RemoteEvent }, player: Player, action: { [string]: any })
	local state = states[player]
	if state == nil then
		return
	end
	local phase, weather = Env.update(remotes)
	local nextState, ok = GameCore.apply(state, action, envFor(phase, weather, player))
	if not ok then
		return
	end
	states[player] = nextState
	DataService.sync(player, nextState)
	if action.type == "Crank" then
		handCranks[player] = (handCranks[player] or 0) + 1
		TutorialService.crank(player)
	end
	if action.type == "BuyTool" then
		ToolService.refresh(player, nextState.land or config.land.start)
	elseif action.type == "Prepare" or action.type == "Align" or action.type == "BuyContainer" then
		LandService.refresh(player, nextState) -- the prompt moves to the next site at once
	end
	if action.type == "Prestige" then
		remotes.Snapshot:FireClient(player, nextState)
		Session.fireworks(remotes, player, state.level, nextState.level)
	end
end

-- Upgrade Fireworks: at a grid expansion of an owner of the pass, fireworks over the plot and a message to everyone.
function Session.fireworks(remotes: { [string]: RemoteEvent }, player: Player, before: any, after: any)
	local profile = DataService.profileOf(player)
	if profile == nil or not Cosmetics.fireworksDue(before, after, profile.Data.passes.fireworks == true) then
		return
	end
	PlotService.fireworks(player)
	remotes.Notice:FireAllClients({ text = Cosmetics.expansionNotice(player.Name, after) })
end

-- SetCosmetic: the chosen glow colour or theme goes into the profile when Core/Cosmetics accepts it.
function Session.setCosmetic(player: Player, slot: number, item: string)
	local profile = DataService.profileOf(player)
	if profile == nil then
		return
	end
	local data = profile.Data
	local choice = Cosmetics.choose(data.passes, data.cosmetics or {}, slot, item)
	if choice ~= nil then
		data.cosmetics = choice
	end
end

-- The chosen glow colour and theme go to the owner with the extras, for the style buttons ("" = not owned).
local function styleExtras(extras: any, flags: any): any
	if flags ~= nil then
		extras.style = { neon = flags.neon or "", theme = if flags.themed then flags.theme else "" }
	end
	return extras
end

-- Once per second: every run gets one step of `dt` seconds.
function Session.tick(remotes: { [string]: RemoteEvent }, dt: number)
	local phase, weather = Env.update(remotes)
	for player, state in states do
		-- Each player has their own factor: the Sunshine Hour is for everyone, the Turbo Feed-in is the owner's.
		local env = envFor(phase, weather, player)
		-- Auto Crank (pass): the server cranks for the owner while online; hand cranks count against the same limit.
		local profile = DataService.profileOf(player)
		if profile ~= nil then
			local cranks, carry =
				Shop.autoCranks(profile.Data, Catalogue, dt, handCranks[player] or 0, crankCarry[player] or 0)
			crankCarry[player] = carry
			for _ = 1, cranks do
				state = GameCore.apply(state, { type = "Crank" }, env)
			end
		end
		handCranks[player] = 0
		local nextState = GameCore.tick(state, env, dt)
		states[player] = nextState
		DataService.sync(player, nextState)
		LeaderboardService.observe(player, nextState.level, nextState.runEarned)
		local view = GameCore.view(nextState, env)
		local storage = view.storage
		PlotService.update(player, nextState.plants, {
			stage = storage.stage,
			control = storage.controlOwned, -- the board stands once U21 is owned; wiring it is what unlocks the rules
			fill = storage.fill,
			paint = nextState.paint,
			golden = nextState.pnodes.S6 == true,
		}, nextState.land)
		LandService.refresh(player, nextState)
		ToolService.refresh(player, nextState.land or config.land.start)
		PlotPublicService.tick(remotes, player, nextState)
		local flags = if profile ~= nil then Cosmetics.flags(profile.Data.passes, profile.Data.cosmetics or {}) else nil
		if flags ~= nil then
			PlotService.style(player, flags)
		end
		TutorialService.observe(remotes, player, nextState)
		remotes.Delta:FireClient(player, {
			coins = nextState.coins,
			rate = (nextState.lifetimeEarned - state.lifetimeEarned) / dt,
			charge = nextState.storage.charge,
			turbo = BoostService.turboRemaining(player),
			skip = GameCore.yield(nextState, SKIP_SECONDS, env), -- what a Time Skip would give now (shop card)
			extras = styleExtras(PurchaseService.extras(player, os.clock() - (started[player] or os.clock())), flags),
			view = view,
		})
	end
end

return Session
