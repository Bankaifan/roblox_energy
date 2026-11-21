--!strict
-- Balance bots (Bauplan.md, section 2) on GameCore. One step is one second; the server time (start + elapsed)
-- gives phase and weather through Core/Env. The bot choices are assumptions, listed in docs/balance/report.md.
local GameCore = require("../src/shared/Core/GameCore")
local Formulas = require("../src/shared/Core/Formulas")
local Env = require("../src/shared/Core/Env")
local ShopCore = require("../src/shared/Core/Shop")

local Config = {
	plants = require("../src/shared/Config/Plants"),
	upgrades = require("../src/shared/Config/Upgrades"),
	prestige = require("../src/shared/Config/Prestige"),
	phases = require("../src/shared/Config/Phases"),
	weathers = require("../src/shared/Config/Weather"),
	effects = require("../src/shared/Config/Effects"),
	land = require("../src/shared/Config/Land"),
	shop = require("../src/shared/Config/Shop"),
}

local Sim = {}

Sim.LIMIT = 6 * 3600 -- seconds of play per run; a run stops at stage 8
-- What a buyer owns from the start (Bauplan section 4): the income and generation factors the server would pass into the
-- env (Core/Shop.envValues, capped at multiplierCap) and the Time Skips bought on day one (one every 10 minutes of play).
local SKIP_EVERY = 600
local SKIP_SECONDS = 0
for _, offer in Config.shop.offers do
	if offer.id == "timeskip" then
		SKIP_SECONDS = offer.seconds
	end
end
local function buyer(passes: { [string]: boolean }, turbo: boolean, skips: number, sunshine: boolean?): any
	local values = ShopCore.envValues({ passes = passes, boosters = {} }, Config.shop, sunshine == true, turbo)
	return { income = values.income, boost = values.boost, skips = skips, storageFactor = values.storageFactor }
end

-- clicks: cranks per second until `crankUntil` seconds of play; every: seconds between purchases;
-- rank: buy the shortest payback (true) or the cheapest affordable offer (false).
Sim.BOTS = {
	optimal = { clicks = 8, crankUntil = math.huge, every = 1, rank = true },
	occasional = { clicks = 8, crankUntil = 60, every = 20, rank = true },
	child = { clicks = 8, crankUntil = math.huge, every = 1, rank = false },
	-- The optimal bot with purchases: Premium Tariff, Premium plus a permanent Turbo Feed-in, three Time Skips.
	premium = { clicks = 8, crankUntil = math.huge, every = 1, rank = true, buy = buyer({ premium = true }, false, 0) },
	turbo = { clicks = 8, crankUntil = math.huge, every = 1, rank = true, buy = buyer({ premium = true }, true, 0) },
	skips = {
		clicks = 8,
		crankUntil = math.huge,
		every = 1,
		rank = true,
		buy = buyer({}, false, Config.shop.skipsPerDay),
	},
}
-- A buyer of the Mega Battery only: the storage capacity factor of the catalogue.
Sim.MEGA_BATTERY = buyer({ mega_battery = true }, false, 0)
-- Everything that multiplies at once (Premium, Turbo, Sunshine Hour): Z11 checks that the cap holds.
Sim.FULL_STACK = buyer({ premium = true }, true, 0, true)
local STORAGE_NODES = { U17 = true, U18 = true, U19 = true, U20 = true, U21 = true, U22 = true }
local STORAGE_PLAN = { "U17", "U21", "U18", "U19", "U20", "U22" }
local STORAGE_CHAIN = { "U17", "U18", "U19", "U20" }
local PERMANENT = { "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8" }
-- Land work (design 0018): a bot prepares the first row of a field in one go. It walks WALK seconds and holds the
-- tool for each site; in that time it neither cranks nor buys.
local WALK = 3
local PER = Config.land.unitsPerSite
local ROW = 4
local HOLD: { [string]: number } = {}
for _, tool in Config.land.tools do
	HOLD[tool.id] = tool.hold
end

local STORAGE_COST = 0 -- the price of the first battery (U17)
for _, node in Config.upgrades.run do
	if node.id == "U17" then
		STORAGE_COST = node.cost
	end
end

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = clone(item)
	end
	return result
end
Sim.clone = clone

-- The state after one action, or the input state when the action is refused.
local function apply(state: any, action: any, env: any): any
	return (GameCore.apply(state, action, env))
end

function Sim.fresh(): any
	local plants = {}
	for index = 1, #Config.plants do
		plants[index] = 0
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
		land = clone(Config.land.start),
	}
end

function Sim.envAt(seed: number, time: number, buy: any?): any
	local env = {
		phase = Env.phaseAt(time, Config.phases),
		weather = Env.weatherAt(time, seed, Config.weathers, 120),
		longMeter = false,
		config = Config,
		formulas = Formulas,
	}
	if buy ~= nil then
		env.income = buy.income
		env.boost = buy.boost
		env.storageFactor = buy.storageFactor
	end
	return env
end

function Sim.record(): any
	return { clock = 0, stageAt = {}, snapshots = {}, pause = 0, pauseLongest = 0, busy = 0, skipped = 0 }
end

-- Coins per second now: one tick, plus the crank income of `clicks` clicks (the crank is not part of the tick).
local function rate(state: any, env: any, clicks: number): number
	local ticked = GameCore.tick(state, env, 1)
	local click = apply(state, { type = "Crank" }, env).coins - state.coins
	return ticked.runEarned - state.runEarned + clicks * click
end

-- `clicks` cranks in one step: one apply, and its revenue counted `clicks` times.
local function crankBurst(state: any, env: any, clicks: number): any
	local cranked = apply(state, { type = "Crank" }, env)
	local extra = (cranked.coins - state.coins) * (clicks - 1)
	cranked.coins += extra
	cranked.runEarned += extra
	cranked.lifetimeEarned += extra
	return cranked
end

-- Offers the bot can take: plants (with a prepared site) and run nodes whose prerequisites are met. Storage nodes
-- only for the child bot, which buys the container like any offer.
local function offers(state: any, withStorage: boolean): { { cost: number, action: any } }
	local list = {}
	for index, plant in Config.plants do
		if
			(index == 1 or state.plants[index - 1] >= 1)
			and state.land.sites[index] >= 1
			and (PER == nil or state.plants[index] < state.land.sites[index] * PER)
		then
			local cost = Formulas.cost(plant.baseCost, state.plants[index])
			table.insert(list, { cost = cost, action = { type = "BuyPlant", plant = index, qty = 1 } })
		end
	end
	for _, node in Config.upgrades.run do
		local id = node.id
		local open = not state.nodes[id] and (withStorage or not STORAGE_NODES[id])
		local plantOk = node.requiresPlant == nil or state.plants[node.requiresPlant] >= 1
		local nodeOk = node.requiresNode == nil or state.nodes[node.requiresNode]
		if open and plantOk and nodeOk and (id ~= "U17" or state.land.container) then
			table.insert(list, { cost = node.cost, action = { type = "BuyNode", node = id } })
		end
	end
	if withStorage and not state.land.container then
		table.insert(list, { cost = Config.land.containerCost, action = { type = "Prepare", target = "container" } })
	end
	return list
end

-- Land work: for the first revealed field without a prepared row the bot buys the tool as soon as the coins cover
-- it, then prepares ROW sites. Returns the state and the seconds the work takes (0 when there is none).
local function landWork(state: any, env: any): (any, number)
	for index in Config.plants do
		local revealed = index == 1 or state.plants[index - 1] >= 1
		-- Without Config.land.unitsPerSite one row is enough; with it the bot mows another row whenever every mown
		-- cell carries a unit.
		local wanted = math.min(ROW, Config.land.fields[index])
		local more = state.land.sites[index] < wanted
		if PER ~= nil then
			wanted = math.min(state.land.sites[index] + ROW, Config.land.fields[index])
			more = state.land.sites[index] * PER <= state.plants[index] and state.land.sites[index] < wanted
		end
		if revealed and more then
			-- Cell by cell, stage by stage: each stage needs its tool, bought as soon as the coins cover it. A stage
			-- the bot cannot pay yet ends the work; the cell stays in work and the next visit continues it.
			local chain = Config.land.chains[index]
			local seconds = 0
			local stalled = false
			while not stalled and state.land.sites[index] < wanted do
				local done = state.land.steps[index][state.land.sites[index] + 1] or 0
				for stage = done + 1, #chain do
					local tool = chain[stage].tool
					if not state.land.tools[tool] then
						state = apply(state, { type = "BuyTool", tool = tool }, env)
					end
					local after, ok = GameCore.apply(state, { type = "Prepare", target = index }, env)
					if not ok then
						stalled = true
						break
					end
					state = after
					seconds += chain[stage].hold
				end
			end
			return state, if seconds > 0 then WALK + seconds else 0
		end
	end
	return state, 0
end

-- The offer with the shortest payback (cost over coins per second gained). The probe has a full purse,
-- so offers that are not affordable yet are priced too.
local function bestOffer(state: any, env: any, clicks: number): any?
	local now = rate(state, env, clicks)
	local probe = clone(state)
	probe.coins = 1e12
	local best, bestPayback = nil, math.huge
	for _, offer in offers(state, false) do
		local after, ok = GameCore.apply(probe, offer.action, env)
		if ok then
			local gain = rate(after, env, clicks) - now
			if gain > 0 and offer.cost / gain < bestPayback then
				best, bestPayback = offer, offer.cost / gain
			end
		end
	end
	return best
end

local function cheapestOffer(state: any): any?
	local pick = nil
	for _, offer in offers(state, true) do
		if offer.cost <= state.coins and (pick == nil or offer.cost < pick.cost) then
			pick = offer
		end
	end
	return pick
end

local function affordable(state: any): boolean
	for _, offer in offers(state, true) do
		if offer.cost <= state.coins then
			return true
		end
	end
	return false
end

-- Permanent nodes in order, as soon as their sparks are there.
local function permanent(state: any, env: any): any
	for _, id in PERMANENT do
		if not state.pnodes[id] then
			return apply(state, { type = "BuyNode", node = id }, env)
		end
	end
	return state
end

-- Rules first (Günstig laden 0,7 and Teuer verkaufen 1,2), then the storage chain in plan order.
-- Stops at the first item that is not affordable yet. The container comes with the first battery (when the coins
-- cover both), the pliers and the wiring right after the control center; both cost a walk.
local function storagePlan(state: any, env: any, record: any): any
	if not state.land.container then
		if state.coins < Config.land.containerCost + STORAGE_COST then
			return state
		end
		record.busy = WALK
		state = apply(state, { type = "Prepare", target = "container" }, env)
	end
	if state.nodes.U21 and not state.land.wired then
		state = apply(state, { type = "BuyTool", tool = "pliers" }, env)
		local wired, ok = GameCore.apply(state, { type = "Prepare", target = "wired" }, env)
		if not ok then
			return state
		end
		record.busy = WALK + HOLD.pliers
		state = wired
	end
	if state.nodes.U21 and state.rules.charge == nil then
		local charge = { type = "SetRule", rule = "charge", th = 0.7, on = true }
		state = apply(state, charge, env)
		state = apply(state, { type = "SetRule", rule = "sell", th = 1.2, on = true }, env)
	end
	for _, id in STORAGE_PLAN do
		if not state.nodes[id] then
			return apply(state, { type = "BuyNode", node = id }, env)
		end
	end
	return state
end

-- One second of decisions: prestige as soon as it is reachable, cranks, then purchases at the bot's rhythm.
local function decide(bot: any, state: any, env: any, record: any): any
	local step = Config.prestige[state.level + 1]
	if step ~= nil and state.runEarned >= step.requiredRevenue then
		record.snapshots[state.level + 1] = state
		state = apply(state, { type = "Prestige" }, env)
	end
	-- Time Skip: 20 minutes of average yield at the full rate, paid out like the shop does.
	if bot.buy ~= nil and record.skipped < bot.buy.skips and record.clock >= (record.skipped + 1) * SKIP_EVERY then
		record.skipped += 1
		state = GameCore.payout(state, GameCore.yield(state, SKIP_SECONDS, env))
	end
	if record.busy > 0 then
		record.busy -= 1
		return state
	end
	if bot.clicks > 0 and record.clock < bot.crankUntil then
		state = crankBurst(state, env, bot.clicks)
	end
	if record.clock < 600 then
		if affordable(state) then
			record.pause = 0
		else
			record.pause += 1
			record.pauseLongest = math.max(record.pauseLongest, record.pause)
		end
	end
	if record.clock % bot.every == 0 then
		state, record.busy = landWork(state, env)
		if record.busy > 0 then
			return state
		end
		state = permanent(state, env)
		local pick = if bot.rank then bestOffer(state, env, bot.clicks) else cheapestOffer(state)
		if pick ~= nil and pick.cost <= state.coins then
			state = apply(state, pick.action, env)
		end
		if bot.rank then
			state = storagePlan(state, env, record)
		end
	end
	return state
end

-- Plays up to `seconds` steps from server time `from`; stops early at stage 8.
-- Returns the state and the server time.
function Sim.play(bot: any, state: any, seed: number, from: number, seconds: number, record: any): (any, number)
	local time = from
	for _ = 1, seconds do
		local env = Sim.envAt(seed, time, bot.buy)
		state = decide(bot, state, env, record)
		state = GameCore.tick(state, env, 1)
		record.clock += 1
		time += 1
		if record.clock == 3600 then
			record.earnedHour = state.lifetimeEarned
		end
		if state.level > 0 and record.stageAt[state.level] == nil then
			record.stageAt[state.level] = record.clock
		end
		if state.level >= 8 then
			break
		end
	end
	return state, time
end

-- One run from server time `start`, until stage 8 or Sim.LIMIT seconds. Returns the record.
function Sim.run(bot: any, seed: number, start: number): any
	local record = Sim.record()
	Sim.play(bot, Sim.fresh(), seed, start, Sim.LIMIT, record)
	return record
end

-- The first day (Bauplan, section 1): sessions of 35, 25 and 25 minutes, offline pauses of 4 and 14 hours.
-- Returns the stage at the end of the day.
function Sim.day(bot: any, seed: number): number
	local record = Sim.record()
	local state, time = Sim.fresh(), 0
	state, time = Sim.play(bot, state, seed, time, 2100, record)
	state = GameCore.offline(state, 4 * 3600, Sim.envAt(seed, time))
	time += 4 * 3600
	state, time = Sim.play(bot, state, seed, time, 1500, record)
	state = GameCore.offline(state, 14 * 3600, Sim.envAt(seed, time))
	time += 14 * 3600
	state = Sim.play(bot, state, seed, time, 1500, record)
	return state.level
end

-- Run revenue of one day (720 s from Morgen) with an empty storage. `buy`: what a buyer owns (Sim.MEGA_BATTERY).
function Sim.dayRevenue(state: any, seed: number, buy: any?): number
	local current = clone(state)
	current.storage.charge = 0
	local start = current.runEarned
	for time = 0, 719 do
		current = GameCore.tick(current, Sim.envAt(seed, time, buy), 1)
	end
	return current.runEarned - start
end

-- The state with the storage chain of `stage` (0 to 4). From stage 1 the rule center is there, with both rules on.
function Sim.withStorage(state: any, stage: number): any
	local result = clone(state)
	for _, id in STORAGE_CHAIN do
		result.nodes[id] = nil
	end
	result.nodes.U21 = nil
	result.nodes.U22 = nil
	result.rules = {}
	result.storage = { charge = 0, mode = "auto" }
	for index = 1, stage do
		result.nodes[STORAGE_CHAIN[index]] = true
	end
	if stage >= 1 then
		result.land.container = true
		result.land.wired = true
		result.nodes.U21 = true
		result.rules = { charge = { th = 0.7, on = true }, sell = { th = 1.2, on = true } }
	end
	return result
end

-- The state with only the plants whose id is true in `keep`.
function Sim.onlyPark(state: any, keep: { [number]: boolean }): any
	local result = clone(state)
	for index in Config.plants do
		if not keep[index] then
			result.plants[index] = 0
		end
	end
	return result
end

return Sim
