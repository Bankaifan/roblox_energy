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
export type Plant = { id: number, name: string, kind: string, baseCost: number, nominalPower: number }
export type Prestige = { level: number, requiredRevenue: number, multiplier: number, sparks: number }
export type Rule = { th: number, on: boolean }
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
	rules: { [string]: Rule }, -- by rule id ("charge", "sell"); a missing rule is off at its default threshold
	land: any?,
	paint: number?, -- S5 Sign Paint: the chosen colour 1 to 6, 0 or nil = none
}
export type Config = {
	land: any?,
	plants: { Plant },
	upgrades: { run: { any }, permanent: { any }, spark: { any }? },
	prestige: { Prestige },
	phases: { Phase },
	weathers: { Weather },
	effects: any,
}
-- boost: the Sunshine Hour / Turbo Feed-in factor of this player this second (Core/Boost); nil or 1 = none.
export type Env = {
	phase: Phase,
	weather: Weather,
	longMeter: boolean,
	config: Config,
	formulas: any,
	boost: number?,
	income: number?, -- the bought sale multiplier (Premium Tariff, Turbo Feed-in, Core/Shop); nil or 1 = none
	ruleSlots: number?, -- rule slots open (Config/Effects.ruleSlots without the Smart Hub, 3 with it)
	autoBuild: boolean?, -- the Smart Hub auto-build is owned
	covered: { [string]: string }?, -- permanent node id -> the pass that gives it (Shop.coveredNodes): not buyable
	storageFactor: number?, -- the Mega Battery: the storage capacity times this (Core/Shop.storageFactor); nil = 1
	permanent: { number }?, -- permanent plants per plant id (Robux): every run starts with them
	nextWeather: Weather?, -- the weather of the next period; the view shows it only with U15
}

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

-- The panels (plant 1) that stand on aligned cells: cell i (in the order the cells were mown) holds
-- clamp(owned - perCell x (i - 1), 0, perCell) of them. 0 without land config or without aligned cells.
local function alignedPanels(state: State, env: Env): number
	local config = if env.config.land ~= nil then env.config.land.align else nil
	local land = state.land
	if config == nil or land == nil or land.aligned == nil or land.cells == nil then
		return 0
	end
	local cells = land.cells[1] or {}
	local sites = land.sites[1] or 0
	local total = 0
	for _, cell in land.aligned do
		local index = table.find(cells, cell)
		if index ~= nil and index <= sites then
			total += math.max(0, math.min(state.plants[1] - config.perCell * (index - 1), config.perCell))
		end
	end
	return total
end

-- The count a plant produces with: its real units, plus an aligned panel counting `factor` times (milestones and prices
-- use the real count).
local function effectiveCount(state: State, env: Env, plant: Plant): number
	local count = state.plants[plant.id]
	if plant.id == 1 then
		local config = if env.config.land ~= nil then env.config.land.align else nil
		if config ~= nil then
			local factor = if state.pnodes.S4 then env.config.effects.alignFactorS4 else config.factor
			count += alignedPanels(state, env) * (factor - 1)
		end
	end
	return count
end

-- Erzeugung/s of all plants under the given phase and weather.
local function production(state: State, env: Env, phase: Phase, weather: Weather): number
	local total = 0
	for _, plant in env.config.plants do
		local factor = env.formulas.factor(plant.kind, phase, weather)
		local multiplier = plantMultiplier(state, env, plant)
		total += env.formulas.production(plant.nominalPower, effectiveCount(state, env, plant), multiplier, factor)
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
		total += env.formulas.production(plant.nominalPower, effectiveCount(state, env, plant), multiplier, expected)
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

-- Land (Config/Land): nil without config.land. The gates apply only with config.land.required.
local function landRequired(env: Env): boolean
	return env.config.land ~= nil and env.config.land.required == true
end

-- The land of a state; a state without land gets the template of the config.
local function landOf(state: State, env: Env): any
	if state.land == nil then
		state.land = copy(env.config.land.start)
	end
	return state.land
end

-- The Regelzentrale (U21) unlocks the two rules "charge" and "sell"; each exists once and is addressed by its id.
-- With required land the rules also need the wired site.
local function rulesUnlocked(state: State, env: Env): boolean
	if not state.nodes.U21 then
		return false
	end
	return not landRequired(env) or (state.land ~= nil and state.land.wired == true)
end

-- A rule as the player sees it: the stored one, or off at the default threshold (rules start off).
local function ruleOf(state: State, env: Env, id: string): Rule
	local stored = state.rules[id]
	if stored ~= nil then
		return stored
	end
	return { th = env.config.effects.rules[id].default, on = false }
end

-- Auto does something only with the Regelzentrale and at least one rule switched on.
local function autoReady(state: State, env: Env): boolean
	if not rulesUnlocked(state, env) then
		return false
	end
	for _, rule in state.rules do
		if rule.on then
			return true
		end
	end
	return false
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
	local chargeRule, sellRule = state.rules.charge, state.rules.sell
	local charging = chargeRule ~= nil and chargeRule.on and priceFactor <= chargeRule.th
	local selling = sellRule ~= nil and sellRule.on and priceFactor >= sellRule.th
	if selling then
		return "sell"
	end
	if charging then
		return "charge"
	end
	return "idle"
end

-- Rule slots open for this run: env.ruleSlots, else the base of Config/Effects.
local function ruleSlots(env: Env): number
	return env.ruleSlots or env.config.effects.ruleSlots
end

local function credit(state: State, amount: number)
	state.coins += amount
	state.runEarned += amount
	state.lifetimeEarned += amount
end

-- What the storage does over `dt` seconds with `generated` energy: the energy taken in, the energy sold out of it,
-- the charge after it, the capacity and the action ("charge", "sell" or "idle"). Charging and selling are limited
-- to capacity / storageRateSeconds per second, so on a small storage part of the output is still sold.
local function storageStep(
	state: State,
	env: Env,
	generated: number,
	dt: number
): (number, number, number, number, string)
	local capacity = env.formulas.storageCapacity(storageStage(state, env), middayOutput(state, env), env.storageFactor)
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
		local reserve = state.rules.reserve
		if reserve ~= nil and reserve.on and state.storage.mode == "auto" and ruleSlots(env) >= 3 then
			output = math.max(0, math.min(output, charge - reserve.th * capacity))
		end
		charge -= output
	end
	return input, output, charge, capacity, action
end

-- One second-scale step of the run: plants produce, the storage charges or sells, the rest is sold at the price.
function GameCore.tick(state: State, env: Env, dt: number): State
	local result = copy(state)
	if not isFinite(dt) or dt <= 0 then
		return result
	end
	local phase, weather = env.phase, env.weather
	local generated = production(state, env, phase, weather) * dt * (env.boost or 1)
	local price = env.formulas.price(phase, weather, market(state, env, phase))
	local input, output, charge = storageStep(state, env, generated, dt)
	local revenue = (generated - input + output) * price * (env.income or 1)
	if not isFinite(revenue) or not isFinite(result.lifetimeEarned + revenue) then
		return result
	end
	credit(result, revenue)
	result.storage.charge = charge
	return result
end

-- Energy per crank click: 1 (with U12: 3), plus 2 % of the production per second with U13.
local function crankEnergy(state: State, env: Env): number
	local effects = env.config.effects
	local energy = effects.crankBase
	if state.nodes.U12 then
		energy = effects.crankGear
	end
	if state.nodes.U13 then
		energy += effects.crankShare * production(state, env, env.phase, env.weather)
	end
	return energy
end

-- Coins one crank turn pays: the energy per click sold at the price factor of this second (the crank does not take
-- the income multiplier, it sells at the market price only).
local function crankCoins(state: State, env: Env): number
	return crankEnergy(state, env) * env.formulas.price(env.phase, env.weather, market(state, env, env.phase))
end

local function crank(state: State, env: Env): boolean
	local energy = crankEnergy(state, env)
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
	-- A plant needs a mown cell of its field for every unit: owned + bought must not pass the mown cells.
	local room = math.huge
	if landRequired(env) then
		local sites = if state.land ~= nil then state.land.sites[index] or 0 else 0
		if sites < 1 then
			return false
		end
		local perSite = env.config.land.unitsPerSite
		if perSite ~= nil then
			room = sites * perSite - state.plants[index]
			if room < 1 then
				return false
			end
		end
	end
	local qty = action.qty
	if qty ~= 1 and qty ~= 10 and qty ~= "max" then
		return false
	end
	local wanted = room
	if qty ~= "max" then
		wanted = math.min(qty, room)
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

-- Smart Hub auto-build: buys one unit of the dearest plant the coins cover (the same checks as BuyPlant).
local function autoBuild(state: State, env: Env): boolean
	if env.autoBuild ~= true then
		return false
	end
	for index = #env.config.plants, 1, -1 do
		if buyPlant(state, env, { plant = index, qty = 1 }) then
			return true
		end
	end
	return false
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
		if landRequired(env) and id == "U17" and not (state.land ~= nil and state.land.container == true) then
			return false
		end
		if run.cost > state.coins then
			return false
		end
		state.coins -= run.cost
		state.nodes[id] = true
		return true
	end
	local permanent = findById(env.config.upgrades.permanent, id) or findById(env.config.upgrades.spark or {}, id)
	if permanent == nil or (env.covered ~= nil and env.covered[id] ~= nil) then
		return false
	end
	if permanent.sparks > state.sparks - state.sparksSpent then
		return false
	end
	state.sparksSpent += permanent.sparks
	state.pnodes[id] = true
	return true
end

local function setRule(state: State, env: Env, action: { [string]: any }): boolean
	local effects = env.config.effects
	local id, th, on = action.rule, action.th, action.on
	if type(id) ~= "string" or effects.rules[id] == nil or not rulesUnlocked(state, env) then
		return false
	end
	if not isFinite(th) or type(on) ~= "boolean" or effects.rules[id].slot > ruleSlots(env) then
		return false
	end
	-- The client sends the value it chose; the server rounds it to a tenth and clamps it into the range of the rule.
	local range = effects.rules[id]
	local tenths = math.floor(th * 10 + 0.5) / 10
	state.rules[id] = { th = math.max(range.min, math.min(range.max, tenths)), on = on }
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
	-- Auto with no rule switched on would do nothing: it is not selectable then.
	if mode == "auto" and not autoReady(state, env) then
		return false
	end
	state.storage.mode = mode
	return true
end

-- A tool is offered when its plant is revealed (the plant before owned once, as for buying) or its node is bought.
local function toolRevealed(state: State, tool: any): boolean
	if tool.node ~= nil then
		return state.nodes[tool.node] == true
	end
	return tool.plant == 1 or state.plants[tool.plant - 1] >= 1
end

-- The price of a tool the player does not own yet: half with S2 Tool Rebate (rounded up to a whole coin).
local function toolPrice(state: State, env: Env, tool: any): number
	if state.pnodes.S2 then
		return math.ceil(tool.price * env.config.effects.toolRebate)
	end
	return tool.price
end

-- BuyTool { tool }: revealed, not owned, coins cover the price. Tools are kept on prestige.
local function buyTool(state: State, env: Env, action: { [string]: any }): boolean
	if env.config.land == nil or type(action.tool) ~= "string" then
		return false
	end
	local tool = findById(env.config.land.tools, action.tool)
	if tool == nil then
		return false
	end
	local land = landOf(state, env)
	local price = toolPrice(state, env, tool)
	if land.tools[tool.id] or not toolRevealed(state, tool) or price > state.coins then
		return false
	end
	state.coins -= price
	land.tools[tool.id] = true
	return true
end

-- Prepare { target, cell? }: a field (plant id 1 to 6): one more stage of the named cell (or the first one in work, or the lowest
-- free one); the tool of that stage is owned, a river cell only after the one upstream. "market" (once), "container"
-- (costs coins, once) or "wired" (needs U21, the container and the pliers, once). Hold time is checked by the server.
local function prepare(state: State, env: Env, action: { [string]: any }): boolean
	local config = env.config.land
	local target = action.target
	if config == nil then
		return false
	end
	local land = landOf(state, env)
	if target == "market" then
		if land.market then
			return false
		end
		land.market = true
		return true
	elseif target == "container" then
		if land.container or config.containerCost > state.coins then
			return false
		end
		state.coins -= config.containerCost
		land.container = true
		return true
	elseif target == "wired" then
		if land.wired or not land.container or not state.nodes.U21 or not land.tools.pliers then
			return false
		end
		land.wired = true
		return true
	end
	if not isCount(target) or config.fields[target] == nil then
		return false
	end
	if not toolRevealed(state, { plant = target }) then
		return false
	end
	local chain = config.chains[target]
	local total = config.fields[target]
	-- The started cells: the prepared ones first (in the order they were finished), then those still in work, with the
	-- stages done of each. A state that only knows the count is padded with the lowest free cells, all stages done.
	land.cells = land.cells or {}
	land.steps = land.steps or {}
	local cells = land.cells[target] or {}
	local steps = land.steps[target] or {}
	local sites = land.sites[target] or 0
	local used: { [number]: boolean } = {}
	for _, cell in cells do
		used[cell] = true
	end
	local free = 1
	while #cells < sites do
		if not used[free] then
			used[free] = true
			table.insert(cells, free)
		end
		free += 1
	end
	for index = 1, #cells do
		steps[index] = steps[index] or (if index <= sites then #chain else 1)
	end
	-- A cell is named by the caller (the tile under the player's feet) or, without one, the first cell in work or the
	-- lowest free cell.
	local cell = action.cell
	if cell == nil then
		if cells[sites + 1] ~= nil then
			cell = cells[sites + 1]
		else
			cell = 1
			while used[cell] do
				cell += 1
			end
		end
	end
	if not isCount(cell) or cell > total then
		return false
	end
	local index = table.find(cells, cell)
	if index ~= nil and index <= sites then
		return false -- prepared already
	end
	-- Downstream fields (the river) are worked from the first cell on: the cell before must be prepared.
	if config.downstream ~= nil and config.downstream[target] and cell > 1 then
		local before = table.find(cells, cell - 1)
		if before == nil or before > sites then
			return false
		end
	end
	local stage = if index ~= nil then steps[index] + 1 else 1
	if not land.tools[chain[stage].tool] then
		return false
	end
	if index == nil then
		table.insert(cells, cell)
		index = #cells
	end
	steps[index] = stage
	if stage == #chain then
		-- Done: the cell moves behind the prepared ones.
		table.remove(cells, index)
		table.remove(steps, index)
		table.insert(cells, sites + 1, cell)
		table.insert(steps, sites + 1, stage)
		land.sites[target] = sites + 1
	end
	land.cells[target] = cells
	land.steps[target] = steps
	return true
end

-- Align { cell? }: Mounting Rails are owned; the named mown cell of F1 (or the first one that qualifies) holds all its panels
-- and is not aligned yet. Its panels then count `align.factor` times. Hold time and the tool in the hand: the server checks.
local function align(state: State, env: Env, action: { [string]: any }): boolean
	local config = if env.config.land ~= nil then env.config.land.align else nil
	if config == nil then
		return false
	end
	local land = landOf(state, env)
	if not land.tools.rails then
		return false
	end
	land.aligned = land.aligned or {}
	local cells = if land.cells ~= nil then land.cells[1] or {} else {}
	local sites = land.sites[1] or 0
	local function qualifies(cell: number): boolean
		local index = table.find(cells, cell)
		return index ~= nil
			and index <= sites
			and state.plants[1] >= config.perCell * index
			and table.find(land.aligned, cell) == nil
	end
	local cell = action.cell
	if cell == nil then
		for index = 1, math.min(sites, #cells) do
			if qualifies(cells[index]) then
				cell = cells[index]
				break
			end
		end
	end
	if not isCount(cell) or not qualifies(cell) then
		return false
	end
	table.insert(land.aligned, cell)
	return true
end

-- SetPaint { color }: S5 Sign Paint must be owned; the colour is a whole number from 1 to paintColors.
local function setPaint(state: State, env: Env, action: { [string]: any }): boolean
	local color = action.color
	if not state.pnodes.S5 or not isCount(color) or color < 1 or color > env.config.effects.paintColors then
		return false
	end
	state.paint = color
	return true
end

-- The units of one plant the prepared ground carries: nothing without a site, sites x unitsPerSite, unlimited without
-- the land rules.
local function groundRoom(state: State, env: Env, id: number): number
	if not landRequired(env) then
		return math.huge
	end
	local sites = if state.land ~= nil then state.land.sites[id] or 0 else 0
	local perSite = env.config.land.unitsPerSite
	if sites < 1 then
		return 0
	end
	return if perSite ~= nil then sites * perSite else math.huge
end

-- S1 Starter Kit: a new run starts with units of the first plants, where the ground of that plant is prepared.
local function starterKit(state: State, env: Env)
	for id, count in env.config.effects.starterKit do
		state.plants[id] = math.min(count, groundRoom(state, env, id))
	end
end

-- Permanent plants (bought with Robux, env.permanent per plant id): every run starts with them on top of the Starter Kit,
-- on the same ground, so the price of the next unit counts them as owned.
local function permanentKit(state: State, env: Env)
	for id, count in env.permanent or {} do
		if env.config.plants[id] ~= nil and isCount(count) then
			state.plants[id] =
				math.min(state.plants[id] + count, math.max(groundRoom(state, env, id), state.plants[id]))
		end
	end
end

-- A permanent plant bought during a run: `count` more units of plant `id` at once, as far as the ground carries them
-- (a negative count takes units back, never below 0). Returns the new state; the input is never changed.
function GameCore.grantPlants(state: State, env: Env, id: number, count: number): State
	local result = copy(state)
	if env.config.plants[id] == nil or not isFinite(count) or count ~= math.floor(count) then
		return result
	end
	local owned = result.plants[id]
	local room = math.max(0, groundRoom(result, env, id) - owned)
	result.plants[id] = math.max(0, owned + math.min(count, room))
	return result
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
	if state.pnodes.S1 then
		starterKit(state, env)
	end
	permanentKit(state, env)
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
	elseif action.type == "AutoBuild" then
		ok = autoBuild(result, env)
	elseif action.type == "BuyNode" then
		ok = buyNode(result, env, action)
	elseif action.type == "SetRule" then
		ok = setRule(result, env, action)
	elseif action.type == "SetStorageMode" then
		ok = setStorageMode(result, env, action)
	elseif action.type == "BuyTool" then
		ok = buyTool(result, env, action)
	elseif action.type == "SetPaint" then
		ok = setPaint(result, env, action)
	elseif action.type == "Prepare" then
		ok = prepare(result, env, action)
	elseif action.type == "Align" then
		ok = align(result, env, action)
	elseif action.type == "BuyContainer" then
		ok = prepare(result, env, { type = "Prepare", target = "container" })
	elseif action.type == "Prestige" then
		ok = prestige(result, env)
	end
	if ok then
		return result, true
	end
	return state, false
end

-- The average yield per second: every plant at its expected income, the market and the income multiplier. Storage,
-- rules and the crank do not count.
local function averageRate(state: State, env: Env): number
	local rate = 0
	for _, plant in env.config.plants do
		local expected = env.formulas.expectedIncome(plant.kind, env.config.phases, env.config.weathers)
		local multiplier = plantMultiplier(state, env, plant)
		rate += env.formulas.production(plant.nominalPower, effectiveCount(state, env, plant), multiplier, expected)
	end
	return rate * market(state, env, nil) * (env.income or 1)
end

-- The offline cap (Deckel) in seconds: the longest time away that still pays.
function GameCore.offlineCap(state: State, env: Env): number
	local effects = env.config.effects
	local hours = effects.offlineHours
	if state.pnodes.P6 then
		hours = effects.offlineHoursP6
	elseif state.pnodes.P2 then
		hours = effects.offlineHoursP2
	end
	if env.longMeter then
		hours += effects.longMeterHours
	end
	return hours * 3600
end

-- Offline income: Schnittrate × min(Abwesenheit, Deckel) × Wirkungsgrad. Storage, rules and the crank do not count.
function GameCore.offline(state: State, seconds: number, env: Env): State
	local result = copy(state)
	local effects = env.config.effects
	if not isFinite(seconds) or seconds < effects.offlineMinimumSeconds then
		return result
	end
	local efficiency = effects.offlineEfficiency
	if state.pnodes.P4 then
		efficiency = effects.offlineEfficiencyP4
	end
	local away = math.min(seconds, GameCore.offlineCap(state, env))
	credit(result, averageRate(state, env) * away * efficiency)
	return result
end

-- Coins of `seconds` of average yield at the full rate: no offline efficiency and no offline cap (Time Skip, Founder
-- Pack). 0 for a seconds value that is not a positive finite number.
function GameCore.yield(state: State, seconds: number, env: Env): number
	if not isFinite(seconds) or seconds <= 0 then
		return 0
	end
	return averageRate(state, env) * seconds
end

-- Pays out `amount` coins as run revenue (coins, runEarned and lifetimeEarned). A negative amount takes a payout back;
-- nothing goes below 0. Returns a new state.
function GameCore.payout(state: State, amount: number): State
	local result = copy(state)
	if not isFinite(amount) then
		return result
	end
	result.coins = math.max(0, result.coins + amount)
	result.runEarned = math.max(0, result.runEarned + amount)
	result.lifetimeEarned = math.max(0, result.lifetimeEarned + amount)
	return result
end

-- Run node states for the HUD, in the order of Config.upgrades.run: "bought"; "locked" (a prerequisite is missing);
-- "open" (prerequisites met, the coins do not cover the cost); "affordable".
local function nodeStates(state: State, env: Env): { any }
	local nodes = {}
	for index, node in env.config.upgrades.run do
		local planted = node.requiresPlant == nil or state.plants[node.requiresPlant] >= 1
		local chained = node.requiresNode == nil or state.nodes[node.requiresNode] == true
		local status = "affordable"
		if state.nodes[node.id] then
			status = "bought"
		elseif not (planted and chained) then
			status = "locked"
		elseif node.cost > state.coins then
			status = "open"
		end
		nodes[index] = { id = node.id, cost = node.cost, state = status }
	end
	return nodes
end

-- What the storage does right now, for the HUD line under the modes (same numbers as tick, for one second):
-- { kind = "none" | "idle" | "charging" | "full" | "selling", share = fraction of the output taken in, income = coins/s }.
local function storageFlow(state: State, env: Env, price: number): { [string]: any }
	if storageStage(state, env) < 1 then
		return { kind = "none", share = 0, income = 0 }
	end
	local generated = production(state, env, env.phase, env.weather) * (env.boost or 1)
	local input, output, charge, capacity, action = storageStep(state, env, generated, 1)
	if action == "charge" then
		if charge >= capacity - 1e-9 then
			return { kind = "full", share = 0, income = 0 }
		end
		local share = if generated > 0 then math.min(1, input / generated) else 0
		return { kind = "charging", share = share, income = 0 }
	elseif action == "sell" and output > 0 then
		return { kind = "selling", share = 0, income = output * price }
	end
	return { kind = "idle", share = 0, income = 0 }
end

-- Storage for the HUD: the stage (0 until U17), the mode, whether Auto can do anything, the two rules (U21: charge
-- and sell, each with its threshold, switch and range) and the live flow line.
local function storageView(state: State, env: Env, price: number): { [string]: any }
	local unlocked = rulesUnlocked(state, env)
	local rules = {}
	if unlocked then
		for id, range in env.config.effects.rules do
			if range.slot > ruleSlots(env) then
				continue
			end
			local rule = ruleOf(state, env, id)
			rules[id] = { th = rule.th, on = rule.on, min = range.min, max = range.max }
		end
	end
	local stage = storageStage(state, env)
	local capacity = env.formulas.storageCapacity(stage, middayOutput(state, env), env.storageFactor)
	return {
		stage = stage,
		mode = state.storage.mode,
		rulesUnlocked = unlocked,
		controlOwned = state.nodes.U21 == true, -- U21 bought; the rules still need the wiring (Cable Pliers) when it is false above
		autoReady = autoReady(state, env),
		rules = rules,
		fill = env.formulas.storageFill(state.storage.charge, capacity),
		flow = storageFlow(state, env, price),
	}
end

-- S3 Quick Hands: the factor on every hold time (1 without it). The server times a hold with tool.hold x this.
-- effects = Config/Effects; the server (LandService) uses this same function, so the prompt, the view and the check agree.
function GameCore.holdFactor(state: State, effects: { holdFactor: number }): number
	if state.pnodes.S3 then
		return effects.holdFactor
	end
	return 1
end

-- The grid multiplier shown to the player: the one of the level reached (1 at level 0).
local function gridMultiplier(env: Env, level: number): number
	local step = env.config.prestige[level]
	return if step ~= nil then step.multiplier else 1
end

-- The spark shop for the HUD: the sparks left, every permanent node and spark item with its price, owned flag and
-- whether the sparks cover it, the colour chosen with S5, and the grid multiplier now and after the next expansion.
local function sparkView(state: State, env: Env): { [string]: any }
	local available = state.sparks - state.sparksSpent
	local items = {}
	for _, list in { env.config.upgrades.permanent, env.config.upgrades.spark or {} } do
		for _, node in list do
			local owned = state.pnodes[node.id] == true
			local covered = if env.covered ~= nil then env.covered[node.id] else nil
			table.insert(items, {
				id = node.id,
				sparks = node.sparks,
				owned = owned,
				covered = if owned then nil else covered, -- the pass that already gives it
				buyable = not owned and covered == nil and node.sparks <= available,
			})
		end
	end
	local nextStep = env.config.prestige[state.level + 1]
	return {
		available = available,
		items = items,
		paint = state.paint or 0,
		gridLevel = state.level,
		gridNow = gridMultiplier(env, state.level),
		gridNext = if nextStep ~= nil then nextStep.multiplier else nil,
		sparksNext = if nextStep ~= nil then nextStep.sparks else nil,
	}
end

-- What each plant produces this second and how: count, effective count, base power, multiplier M and the type factor of
-- the phase and weather now. The sum of `output` is the rate before storage.
local function productionView(state: State, env: Env): { [string]: any }
	local rows = {}
	local total = 0
	for _, plant in env.config.plants do
		local factor = env.formulas.factor(plant.kind, env.phase, env.weather)
		local multiplier = plantMultiplier(state, env, plant)
		local effective = effectiveCount(state, env, plant)
		local output = env.formulas.production(plant.nominalPower, effective, multiplier, factor)
		total += output
		table.insert(rows, {
			id = plant.id,
			kind = plant.kind,
			count = state.plants[plant.id],
			effective = effective,
			nominal = plant.nominalPower,
			multiplier = multiplier,
			factor = factor,
			output = output,
		})
	end
	return { rows = rows, total = total, grid = globalMultiplier(state, env) }
end

-- What the crank pays now: coins per turn and per second at `turnsPerSecond` turns (Shop.crankSpeed).
function GameCore.crankOutput(state: State, env: Env, turnsPerSecond: number): { [string]: number }
	local turn = crankCoins(state, env)
	return { turn = turn, second = turn * turnsPerSecond, speed = turnsPerSecond }
end

-- What the HUD shows, so the client does no game logic: each plant's next price and whether the coins cover it,
-- the run nodes, the storage, the crank energy per click, and the next grid expansion with the run earnings,
-- its sparks and whether it is allowed now (nil after the last level).
function GameCore.view(state: State, env: Env): { [string]: any }
	local plants = {}
	for _, plant in env.config.plants do
		local cost = env.formulas.cost(plant.baseCost, state.plants[plant.id])
		plants[plant.id] = { cost = cost, affordable = cost <= state.coins }
	end
	local goal: { [string]: any }? = nil
	local step = env.config.prestige[state.level + 1]
	if step ~= nil then
		goal = {
			level = step.level,
			required = step.requiredRevenue,
			earned = state.runEarned,
			sparks = step.sparks,
			allowed = state.runEarned >= step.requiredRevenue,
		}
	end
	-- The price factor of this second: the same value tick sells at. The next weather shows only with U15.
	local price = env.formulas.price(env.phase, env.weather, market(state, env, env.phase))
	local nextWeather: string? = nil
	if state.nodes.U15 and env.nextWeather ~= nil then
		nextWeather = env.nextWeather.id
	end
	local view: { [string]: any } = {
		plants = plants,
		nodes = nodeStates(state, env),
		storage = storageView(state, env, price),
		price = { factor = price, phase = env.phase.id, weather = env.weather.id, nextWeather = nextWeather },
		crank = crankEnergy(state, env),
		production = productionView(state, env),
		goal = goal,
	}
	if env.config.land ~= nil then
		local land = state.land or env.config.land.start
		local required = landRequired(env)
		for _, plant in env.config.plants do
			plants[plant.id].sites = land.sites[plant.id] or 0
			local sites = land.sites[plant.id] or 0
			local perSite = env.config.land.unitsPerSite
			plants[plant.id].needsSite = required
				and (sites < 1 or (perSite ~= nil and sites * perSite <= state.plants[plant.id]))
		end
		local tools = {}
		for _, tool in env.config.land.tools do
			local owned = land.tools[tool.id] == true
			local revealed = toolRevealed(state, tool)
			local cost = if owned then tool.price else toolPrice(state, env, tool)
			table.insert(tools, {
				id = tool.id,
				price = cost,
				hold = tool.hold * GameCore.holdFactor(state, env.config.effects),
				owned = owned,
				revealed = revealed,
				buyable = revealed and not owned and cost <= state.coins,
				textKey = tool.textKey,
				place = "market",
			})
		end
		view.land = copy(land)
		view.tools = tools
	end
	view.holdFactor = GameCore.holdFactor(state, env.config.effects)
	view.sparks = sparkView(state, env)
	return view
end

return GameCore
