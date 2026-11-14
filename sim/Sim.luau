--!strict
-- Balance bots (Bauplan.md, section 2) on GameCore. One step is one second; the server time (start + elapsed)
-- gives phase and weather through Core/Env. The bot choices are assumptions, listed in docs/balance/report.md.
local GameCore = require("../src/shared/Core/GameCore")
local Formulas = require("../src/shared/Core/Formulas")
local Env = require("../src/shared/Core/Env")

local Config = {
	plants = require("../src/shared/Config/Plants"),
	upgrades = require("../src/shared/Config/Upgrades"),
	prestige = require("../src/shared/Config/Prestige"),
	phases = require("../src/shared/Config/Phases"),
	weathers = require("../src/shared/Config/Weather"),
	effects = require("../src/shared/Config/Effects"),
}

local Sim = {}

Sim.LIMIT = 6 * 3600 -- seconds of play per run; a run stops at stage 8
-- clicks: cranks per second until `crankUntil` seconds of play; every: seconds between purchases;
-- rank: buy the shortest payback (true) or the cheapest affordable offer (false).
Sim.BOTS = {
	optimal = { clicks = 8, crankUntil = math.huge, every = 1, rank = true },
	occasional = { clicks = 8, crankUntil = 60, every = 20, rank = true },
	child = { clicks = 8, crankUntil = math.huge, every = 1, rank = false },
}
local STORAGE_NODES = { U17 = true, U18 = true, U19 = true, U20 = true, U21 = true, U22 = true }
local STORAGE_PLAN = { "U17", "U21", "U18", "U19", "U20", "U22" }
local STORAGE_CHAIN = { "U17", "U18", "U19", "U20" }
local PERMANENT = { "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8" }

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
	}
end

function Sim.envAt(seed: number, time: number): any
	return {
		phase = Env.phaseAt(time, Config.phases),
		weather = Env.weatherAt(time, seed, Config.weathers, 120),
		longMeter = false,
		config = Config,
		formulas = Formulas,
	}
end

function Sim.record(): any
	return { clock = 0, stageAt = {}, snapshots = {}, pause = 0, pauseLongest = 0 }
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

-- Offers the bot can take: plants and run nodes whose prerequisites are met. Storage nodes only for the child bot.
local function offers(state: any, withStorage: boolean): { { cost: number, action: any } }
	local list = {}
	for index, plant in Config.plants do
		if index == 1 or state.plants[index - 1] >= 1 then
			local cost = Formulas.cost(plant.baseCost, state.plants[index])
			table.insert(list, { cost = cost, action = { type = "BuyPlant", plant = index, qty = 1 } })
		end
	end
	for _, node in Config.upgrades.run do
		local id = node.id
		local open = not state.nodes[id] and (withStorage or not STORAGE_NODES[id])
		local plantOk = node.requiresPlant == nil or state.plants[node.requiresPlant] >= 1
		local nodeOk = node.requiresNode == nil or state.nodes[node.requiresNode]
		if open and plantOk and nodeOk then
			table.insert(list, { cost = node.cost, action = { type = "BuyNode", node = id } })
		end
	end
	return list
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
-- Stops at the first item that is not affordable yet.
local function storagePlan(state: any, env: any): any
	if state.nodes.U21 and state.rules[1] == nil then
		local charge = { type = "SetRule", slot = 1, rule = "charge", th = 0.7, on = true }
		state = apply(state, charge, env)
		state = apply(state, { type = "SetRule", slot = 2, rule = "sell", th = 1.2, on = true }, env)
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
		state = permanent(state, env)
		local pick = if bot.rank then bestOffer(state, env, bot.clicks) else cheapestOffer(state)
		if pick ~= nil and pick.cost <= state.coins then
			state = apply(state, pick.action, env)
		end
		if bot.rank then
			state = storagePlan(state, env)
		end
	end
	return state
end

-- Plays up to `seconds` steps from server time `from`; stops early at stage 8.
-- Returns the state and the server time.
function Sim.play(bot: any, state: any, seed: number, from: number, seconds: number, record: any): (any, number)
	local time = from
	for _ = 1, seconds do
		local env = Sim.envAt(seed, time)
		state = decide(bot, state, env, record)
		state = GameCore.tick(state, env, 1)
		record.clock += 1
		time += 1
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

-- Run revenue of one day (480 s from Morgen) with an empty storage.
function Sim.dayRevenue(state: any, seed: number): number
	local current = clone(state)
	current.storage.charge = 0
	local start = current.runEarned
	for time = 0, 479 do
		current = GameCore.tick(current, Sim.envAt(seed, time), 1)
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
		result.nodes.U21 = true
		result.rules = { { id = "charge", th = 0.7, on = true }, { id = "sell", th = 1.2, on = true } }
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
