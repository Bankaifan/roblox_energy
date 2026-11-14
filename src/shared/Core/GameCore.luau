--!strict
-- GameCore (Bauplan.md, sections 2 and 5): the rules of one run. Pure: no Roblox APIs, no network, no clock.
-- tick, apply and offline return a new state and never change their input. The server checks of section 5
-- (ownership, prerequisite, recomputed price) live in apply: a rejected action returns the input state and false.
-- env = { phase, weather, longMeter, config, formulas }:
--   phase, weather: the current values from Core/Env; longMeter: the Langzeit-Zähler pass is owned;
--   config: { plants, upgrades, prestige, phases, weathers, effects } from the Config tables;
--   formulas: Core/Formulas. Passed in, because core modules do not require each other.
export type Phase = { id: string, duration: number, solar: number, price: number }
export type Weather = { id: string, share: number, solar: number, wind: number, price: number }
export type Plant = { id: number, kind: string, baseCost: number, nominalPower: number }
export type Prestige = { level: number, requiredRevenue: number, multiplier: number, sparks: number }
export type Rule = { id: string, th: number, on: boolean }
export type State = {
	coins: number,
	runEarned: number,
	lifetimeEarned: number,
	level: number,
	sparks: number,
	sparksSpent: number,
	plants: { number },
	nodes: { [string]: boolean },
	pnodes: { [string]: boolean },
	storage: { charge: number, mode: string },
	rules: { [number]: Rule },
}
export type Config = {
	plants: { Plant },
	upgrades: { run: { any }, permanent: { any } },
	prestige: { Prestige },
	phases: { Phase },
	weathers: { Weather },
	effects: any,
}
export type Env = { phase: Phase, weather: Weather, longMeter: boolean, config: Config, formulas: any }

local GameCore = {}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isCount(value: any): boolean
	return isFinite(value) and value >= 0 and value == math.floor(value)
end

local function findById(list: { any }, id: any): any
	for _, item in list do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- Plant part of M_i: the node doubling of that plant (U01 to U06) and the type node (U07 solar, U08 wind).
local function nodeFactor(state: State, env: Env, plant: Plant): number
	local effects = env.config.effects
	local factor = 1
	if state.nodes[string.format("U%02d", plant.id)] then
		factor *= effects.plantNodeFactor
	end
	if plant.kind == "Solar" and state.nodes.U07 then
		factor *= effects.typeNodeFactor
	end
	if plant.kind == "Wind" and state.nodes.U08 then
		factor *= effects.typeNodeFactor
	end
	return factor
end

local function milestoneFactor(state: State, env: Env): number
	if state.pnodes.P7 then
		return env.config.effects.milestoneFactorP7
	end
	return env.config.effects.milestoneFactor
end

-- Global part of M_i: 1,6^Netzstufe × Netzverstärkung (U09, U10, U11).
local function globalMultiplier(state: State, env: Env): number
	local reinforcement = 1
	for id, factor in env.config.effects.grid do
		if state.nodes[id] then
			reinforcement *= factor
		end
	end
	return env.formulas.globalMultiplier(state.level, reinforcement)
end

-- M_i = plant part × global part.
local function plantMultiplier(state: State, env: Env, plant: Plant): number
	local count = state.plants[plant.id]
	local milestones = milestoneFactor(state, env)
	local plantPart = env.formulas.plantMultiplier(count, milestones, nodeFactor(state, env, plant))
	return plantPart * globalMultiplier(state, env)
end

-- Erzeugung/s of all plants under the given phase and weather.
local function production(state: State, env: Env, phase: Phase, weather: Weather): number
	local total = 0
	for _, plant in env.config.plants do
		local factor = env.formulas.factor(plant.kind, phase, weather)
		local multiplier = plantMultiplier(state, env, plant)
		total += env.formulas.production(plant.nominalPower, state.plants[plant.id], multiplier, factor)
	end
	return total
end

-- Mittagserzeugung: output at noon, averaged over the weather (Bauplan: Solar 0,725, Wind 1,02, Grundlast 1,0).
local function middayOutput(state: State, env: Env): number
	local noon = findById(env.config.phases, "Mittag")
	local total = 0
	for _, plant in env.config.plants do
		local expected = 0
		for _, weather in env.config.weathers do
			expected += weather.share / 100 * env.formulas.factor(plant.kind, noon, weather)
		end
		local multiplier = plantMultiplier(state, env, plant)
		total += env.formulas.production(plant.nominalPower, state.plants[plant.id], multiplier, expected)
	end
	return total
end

-- Markt: U14 and U15 add 10 % each, U16 multiplies the evening price (Bauplan, section 2).
local function market(state: State, env: Env, phase: Phase?): number
	local effects = env.config.effects
	local factor = 1
	if state.nodes.U14 then
		factor += effects.marketStep
	end
	if state.nodes.U15 then
		factor += effects.marketStep
	end
	if phase ~= nil and phase.id == "Abend" and state.nodes.U16 then
		factor *= effects.eveningFactor
	end
	return factor
end

-- Speicher stage 0 to 4: the number of storage nodes owned (U17 to U20 come in a chain).
local function storageStage(state: State, env: Env): number
	local stage = 0
	for index, id in env.config.effects.storageNodes do
		if state.nodes[id] then
			stage = index
		end
	end
	return stage
end

local function storageEfficiency(state: State, env: Env): number
	if state.nodes.U22 then
		return env.config.effects.storageEfficiencyU22
	end
	return env.config.effects.storageEfficiency
end

-- Regel-Plätze: two with the Regelzentrale (U21), three with P8.
local function ruleSlots(state: State, env: Env): number
	if not state.nodes.U21 then
		return 0
	end
	if state.pnodes.P8 then
		return env.config.effects.ruleSlotsP8
	end
	return env.config.effects.ruleSlots
end

-- What the storage does this second: "charge", "sell" or "idle". In "auto" the rules decide;
-- if both rules fire, "sell" wins.
local function storageAction(state: State, env: Env): string
	local mode = state.storage.mode
	if mode == "charge" or mode == "sell" then
		return mode
	end
	if mode ~= "auto" then
		return "idle"
	end
	local priceFactor = env.phase.price * env.weather.price
	local charging, selling = false, false
	for _, rule in state.rules do
		if rule.on and rule.id == "charge" and priceFactor <= rule.th then
			charging = true
		end
		if rule.on and rule.id == "sell" and priceFactor >= rule.th then
			selling = true
		end
	end
	if selling then
		return "sell"
	end
	if charging then
		return "charge"
	end
	return "idle"
end

local function credit(state: State, amount: number)
	state.coins += amount
	state.runEarned += amount
	state.lifetimeEarned += amount
end

-- One second-scale step of the run: plants produce, the storage charges or sells, the rest is sold at the price.
function GameCore.tick(state: State, env: Env, dt: number): State
	local result = copy(state)
	if not isFinite(dt) or dt <= 0 then
		return result
	end
	local phase, weather = env.phase, env.weather
	local generated = production(state, env, phase, weather) * dt
	local price = env.formulas.price(phase, weather, market(state, env, phase))
	local capacity = env.formulas.storageCapacity(storageStage(state, env), middayOutput(state, env))
	local efficiency = storageEfficiency(state, env)
	local charge = math.min(state.storage.charge, capacity)
	local rate = capacity / env.config.effects.storageRateSeconds * dt
	local input, output = 0, 0
	local action = storageAction(state, env)
	if action == "charge" then
		input = math.max(0, math.min(rate, generated, (capacity - charge) / efficiency))
		charge = math.min(capacity, charge + input * efficiency)
	elseif action == "sell" then
		output = math.min(rate, charge)
		charge -= output
	end
	local revenue = (generated - input + output) * price
	if not isFinite(revenue) or not isFinite(result.lifetimeEarned + revenue) then
		return result
	end
	credit(result, revenue)
	result.storage.charge = charge
	return result
end

local function crank(state: State, env: Env): boolean
	local effects = env.config.effects
	local energy = effects.crankBase
	if state.nodes.U12 then
		energy = effects.crankGear
	end
	if state.nodes.U13 then
		energy += effects.crankShare * production(state, env, env.phase, env.weather)
	end
	local price = env.formulas.price(env.phase, env.weather, market(state, env, env.phase))
	local revenue = energy * price
	if not isFinite(revenue) then
		return false
	end
	credit(state, revenue)
	return true
end

-- The price is recomputed here: as many plants as asked for (1, 10 or "max"), each at Basis × 1,15^Anzahl.
local function buyPlant(state: State, env: Env, action: { [string]: any }): boolean
	local index = action.plant
	if not isCount(index) or env.config.plants[index] == nil then
		return false
	end
	local plant = env.config.plants[index]
	if index > 1 and state.plants[index - 1] < 1 then
		return false
	end
	local qty = action.qty
	if qty ~= 1 and qty ~= 10 and qty ~= "max" then
		return false
	end
	local wanted = math.huge
	if qty ~= "max" then
		wanted = qty
	end
	local owned = state.plants[index]
	local count, total = 0, 0
	while count < wanted do
		local price = env.formulas.cost(plant.baseCost, owned + count)
		if total + price > state.coins then
			break
		end
		total += price
		count += 1
	end
	if count == 0 or (qty ~= "max" and count < qty) then
		return false
	end
	state.coins -= total
	state.plants[index] += count
	return true
end

-- Run nodes cost coins and need their prerequisite; permanent nodes cost sparks and reset nothing.
local function buyNode(state: State, env: Env, action: { [string]: any }): boolean
	local id = action.node
	if type(id) ~= "string" or state.nodes[id] or state.pnodes[id] then
		return false
	end
	local run = findById(env.config.upgrades.run, id)
	if run ~= nil then
		if run.requiresPlant ~= nil and state.plants[run.requiresPlant] < 1 then
			return false
		end
		if run.requiresNode ~= nil and not state.nodes[run.requiresNode] then
			return false
		end
		if run.cost > state.coins then
			return false
		end
		state.coins -= run.cost
		state.nodes[id] = true
		return true
	end
	local permanent = findById(env.config.upgrades.permanent, id)
	if permanent == nil or permanent.sparks > state.sparks - state.sparksSpent then
		return false
	end
	state.sparksSpent += permanent.sparks
	state.pnodes[id] = true
	return true
end

local function setRule(state: State, env: Env, action: { [string]: any }): boolean
	local effects = env.config.effects
	local slot, rule, th, on = action.slot, action.rule, action.th, action.on
	if not isCount(slot) or slot < 1 or slot > ruleSlots(state, env) then
		return false
	end
	if rule ~= "charge" and rule ~= "sell" then
		return false
	end
	if not isFinite(th) or th < effects.ruleMin or th > effects.ruleMax then
		return false
	end
	local tenths = math.floor(th * 10 + 0.5)
	if math.abs(th * 10 - tenths) > 1e-9 or type(on) ~= "boolean" then
		return false
	end
	state.rules[slot] = { id = rule, th = tenths / 10, on = on }
	return true
end

local function setStorageMode(state: State, env: Env, action: { [string]: any }): boolean
	local mode = action.mode
	if mode ~= "charge" and mode ~= "sell" and mode ~= "auto" then
		return false
	end
	if storageStage(state, env) < 1 then
		return false
	end
	state.storage.mode = mode
	return true
end

-- Netz-Ausbau: needs the run revenue of the next level. Plants, run nodes and coins go back to the start;
-- P1 gives start coins, P5 keeps the storage, the control center and the rules.
local function prestige(state: State, env: Env): boolean
	local step = env.config.prestige[state.level + 1]
	if step == nil or state.runEarned < step.requiredRevenue then
		return false
	end
	local effects = env.config.effects
	local nodes = {}
	if state.pnodes.P5 then
		for _, id in effects.keptNodes do
			nodes[id] = state.nodes[id]
		end
	else
		state.rules = {}
	end
	local plants = {}
	for _, plant in env.config.plants do
		plants[plant.id] = 0
	end
	state.level += 1
	state.sparks += step.sparks
	state.nodes = nodes
	state.plants = plants
	state.coins = 0
	if state.pnodes.P1 then
		state.coins = effects.startCoins
	end
	state.runEarned = 0
	state.storage.charge = 0
	return true
end

-- Applies one client action after the server checks. Returns the new state and true, or the input and false.
function GameCore.apply(state: State, action: { [string]: any }, env: Env): (State, boolean)
	if type(action) ~= "table" then
		return state, false
	end
	local result = copy(state)
	local ok = false
	if action.type == "Crank" then
		ok = crank(result, env)
	elseif action.type == "BuyPlant" then
		ok = buyPlant(result, env, action)
	elseif action.type == "BuyNode" then
		ok = buyNode(result, env, action)
	elseif action.type == "SetRule" then
		ok = setRule(result, env, action)
	elseif action.type == "SetStorageMode" then
		ok = setStorageMode(result, env, action)
	elseif action.type == "Prestige" then
		ok = prestige(result, env)
	end
	if ok then
		return result, true
	end
	return state, false
end

-- Offline income: Schnittrate × min(Abwesenheit, Deckel) × Wirkungsgrad. Storage, rules and the crank do not count.
function GameCore.offline(state: State, seconds: number, env: Env): State
	local result = copy(state)
	local effects = env.config.effects
	if not isFinite(seconds) or seconds < effects.offlineMinimumSeconds then
		return result
	end
	local hours = effects.offlineHours
	if state.pnodes.P6 then
		hours = effects.offlineHoursP6
	elseif state.pnodes.P2 then
		hours = effects.offlineHoursP2
	end
	if env.longMeter then
		hours += effects.longMeterHours
	end
	local efficiency = effects.offlineEfficiency
	if state.pnodes.P4 then
		efficiency = effects.offlineEfficiencyP4
	end
	local rate = 0
	for _, plant in env.config.plants do
		local expected = env.formulas.expectedIncome(plant.kind, env.config.phases, env.config.weathers)
		local multiplier = plantMultiplier(state, env, plant)
		rate += env.formulas.production(plant.nominalPower, state.plants[plant.id], multiplier, expected)
	end
	local away = math.min(seconds, hours * 3600)
	credit(result, rate * market(state, env, nil) * away * efficiency)
	return result
end

return GameCore
