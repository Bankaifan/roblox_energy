--!strict
-- GameCore (Bauplan.md, sections 2 and 5): tick, apply, offline, the server checks, random inputs.
return function(t, load)
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Config = {}
	Config.plants = load("Config/Plants")
	Config.upgrades = load("Config/Upgrades")
	Config.prestige = load("Config/Prestige")
	Config.phases = load("Config/Phases")
	Config.weathers = load("Config/Weather")
	Config.effects = load("Config/Effects")

	-- Phases: 1 Morgen, 2 Mittag, 3 Abend, 4 Nacht. Weather: 1 Sonnig, 2 Bewoelkt, 3 Windig, 4 Gewitter, 5 Flaute.
	local function env(phase: number, weather: number, longMeter: boolean?)
		return {
			phase = Config.phases[phase],
			weather = Config.weathers[weather],
			longMeter = longMeter == true,
			config = Config,
			formulas = Formulas,
		}
	end

	-- An empty run in the Bauplan data model, version 1.
	local function fresh(): { [string]: any }
		local state: { [string]: any } = { v = 1, coins = 0, runEarned = 0, lifetimeEarned = 0, sparks = 0 }
		state.level = 0
		state.sparksSpent = 0
		state.plants = { 0, 0, 0, 0, 0, 0 }
		state.nodes = {}
		state.pnodes = {}
		state.storage = { charge = 0, mode = "auto" }
		state.rules = {}
		return state
	end

	local function near(actual: number, expected: number, label: string)
		t.truthy(math.abs(actual - expected) < 1e-3, `{label}: expected {expected}, got {actual}`)
	end

	-- Crank: one click, sold at the current price (Mittag 0,7, Sonnig 1,0).
	local start = fresh()
	local cranked, crankOk = GameCore.apply(start, { type = "Crank" }, env(2, 1))
	t.truthy(crankOk, "crank is accepted")
	near(cranked.coins, 0.7, "one click sells at the noon price")
	t.equal(start.coins, 0, "apply never changes its input")

	-- BuyPlant: the price is recomputed, and the plant before must be owned.
	local rich = fresh()
	rich.coins = 1000
	local bought, boughtOk = GameCore.apply(rich, { type = "BuyPlant", plant = 1, qty = 1 }, env(2, 1))
	t.truthy(boughtOk, "first balcony module is accepted")
	t.equal(bought.coins, 985, "first balcony module costs 15")
	t.equal(bought.plants[1], 1, "one balcony module owned")
	local _, lockedOk = GameCore.apply(rich, { type = "BuyPlant", plant = 3, qty = 1 }, env(2, 1))
	t.truthy(not lockedOk, "rooftop solar needs a balcony module first")
	local poor = fresh()
	poor.coins = 100
	local _, tooMany = GameCore.apply(poor, { type = "BuyPlant", plant = 1, qty = 10 }, env(2, 1))
	t.truthy(not tooMany, "ten at once is all or nothing: 304 needed, 100 there")

	local maxFunds = fresh()
	maxFunds.coins = 10000
	local maxed = GameCore.apply(maxFunds, { type = "BuyPlant", plant = 1, qty = "max" }, env(2, 1))
	local count = maxed.plants[1]
	t.truthy(count >= 1, "max buys at least one")
	t.truthy(maxed.coins >= 0 and maxed.coins < Formulas.cost(15, count), "max stops before the next piece")

	-- BuyNode: run nodes cost coins and need their prerequisite, permanent nodes cost sparks.
	local nodeFunds = fresh()
	nodeFunds.coins = 1000
	local _, nodeLockedOk = GameCore.apply(nodeFunds, { type = "BuyNode", node = "U01" }, env(2, 1))
	t.truthy(not nodeLockedOk, "U01 needs a balcony module")
	nodeFunds.plants[1] = 1
	local withNode, nodeOk = GameCore.apply(nodeFunds, { type = "BuyNode", node = "U01" }, env(2, 1))
	t.truthy(nodeOk, "U01 is accepted with its prerequisite")
	t.equal(withNode.coins, 850, "U01 costs 150")
	local sparkFunds = fresh()
	sparkFunds.sparks = 2
	local _, sparkShortOk = GameCore.apply(sparkFunds, { type = "BuyNode", node = "P1" }, env(2, 1))
	t.truthy(not sparkShortOk, "P1 needs 3 sparks")
	sparkFunds.sparks = 3
	local withPerm, permOk = GameCore.apply(sparkFunds, { type = "BuyNode", node = "P1" }, env(2, 1))
	t.truthy(permOk and withPerm.pnodes.P1 == true, "P1 is bought with sparks")
	t.equal(withPerm.sparksSpent, 3, "P1 spends its 3 sparks")

	-- SetRule: the control center (U21) unlocks the rules; thresholds are 0,5 to 2,0 in tenths.
	local function setRule(state: { [string]: any }, slot: number, rule: string, th: number): (any, boolean)
		local action = { type = "SetRule", slot = slot, rule = rule, th = th, on = true }
		return GameCore.apply(state, action, env(2, 1))
	end
	local rules = fresh()
	local _, ruleLockedOk = setRule(rules, 1, "charge", 0.7)
	t.truthy(not ruleLockedOk, "a rule needs the control center")
	rules.nodes.U21 = true
	local ruled, ruleOk = setRule(rules, 1, "charge", 0.7)
	t.truthy(ruleOk and ruled.rules[1].th == 0.7, "rule accepted at 0,7")
	local _, oddStepOk = setRule(rules, 1, "sell", 0.75)
	t.truthy(not oddStepOk, "threshold must be in tenths")
	local _, thirdSlotOk = setRule(rules, 3, "sell", 1.2)
	t.truthy(not thirdSlotOk, "only two slots without P8")
	rules.pnodes.P8 = true
	local _, thirdOk = setRule(rules, 3, "sell", 1.2)
	t.truthy(thirdOk, "P8 opens the third slot")

	-- SetStorageMode: needs the first storage node.
	local storageless = fresh()
	local _, modeLockedOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "charge" }, env(2, 1))
	t.truthy(not modeLockedOk, "storage mode needs a storage")
	storageless.nodes.U17 = true
	local moded, modeOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "charge" }, env(2, 1))
	t.truthy(modeOk and moded.storage.mode == "charge", "storage mode is set")

	-- Storage at noon and evening: 10 rooftop solar, midday output 406/s, capacity 30 s = 12180.
	local storing = fresh()
	storing.plants[3] = 10
	storing.nodes.U17 = true
	storing.storage.mode = "charge"
	local noon = GameCore.tick(storing, env(2, 1), 1)
	near(noon.storage.charge, 172.55, "noon charge: 203 per second times 0,85")
	near(noon.coins, 249.9, "noon sale: 560 - 203 at 0,7")
	storing = noon
	storing.storage.mode = "sell"
	local evening = GameCore.tick(storing, env(3, 1), 1)
	t.equal(evening.storage.charge, 0, "evening empties the storage")
	near(evening.coins - noon.coins, 612.99, "evening sale: (168 + 172,55) at 1,8")

	-- Auto mode: the charge rule fires at a price factor of 0,7 or less and not at 1,2.
	local auto = fresh()
	auto.plants[3] = 10
	auto.nodes.U17 = true
	auto.nodes.U21 = true
	auto.rules[1] = { id = "charge", th = 0.7, on = true }
	local autoNoon = GameCore.tick(auto, env(2, 1), 1)
	t.truthy(autoNoon.storage.charge > 0, "auto charges at the noon price")
	local autoMorning = GameCore.tick(auto, env(1, 1), 1)
	t.equal(autoMorning.storage.charge, 0, "auto does not charge at 1,2")

	-- Prestige: needs the run revenue, resets the run; P1 gives start coins, P5 keeps storage and rules.
	local expansion = fresh()
	expansion.runEarned = 10000000
	expansion.coins = 5000
	expansion.plants[1] = 5
	expansion.nodes.U09 = true
	expansion.nodes.U17 = true
	local expanded, expandOk = GameCore.apply(expansion, { type = "Prestige" }, env(2, 1))
	t.truthy(expandOk, "expansion at 10 Mio.")
	t.equal(expanded.level, 1, "level 1 after the first expansion")
	t.equal(expanded.sparks, 5, "first expansion gives 5 sparks")
	t.equal(expanded.coins, 0, "coins reset")
	t.equal(expanded.plants[1], 0, "plants reset")
	t.truthy(expanded.nodes.U09 == nil and expanded.nodes.U17 == nil, "run nodes reset")
	expansion.pnodes.P1 = true
	expansion.pnodes.P5 = true
	local kept, keptOk = GameCore.apply(expansion, { type = "Prestige" }, env(2, 1))
	t.truthy(keptOk and kept.coins == 1000 and kept.nodes.U17 == true, "P1 start coins, P5 keeps U17")
	expansion.runEarned = 9999999
	local _, shortOk = GameCore.apply(expansion, { type = "Prestige" }, env(2, 1))
	t.truthy(not shortOk, "expansion needs 10 Mio.")

	-- Offline: nothing under 60 seconds, capped at 2 hours; the Langzeit-Zähler adds 4 hours on top (cap 6 h).
	local away = fresh()
	away.plants[1] = 10
	local short = GameCore.offline(away, 30, env(2, 1))
	t.equal(short.coins, 0, "under a minute pays nothing")
	local capped = GameCore.offline(away, 1000000000, env(2, 1))
	local twoHours = GameCore.offline(away, 7200, env(2, 1))
	t.truthy(capped.coins > 0, "offline income is paid")
	near(capped.coins, twoHours.coins, "offline stops at the 2 hour cap")
	local longMeter = GameCore.offline(away, 1000000000, env(2, 1, true))
	near(longMeter.coins, 3 * twoHours.coins, "Langzeit-Zähler lifts the 2 hour cap to 6 hours")

	-- Random inputs: whatever the client sends, coins and storage stay finite and not negative.
	math.randomseed(20261113)
	local TYPES = { "Crank", "BuyPlant", "BuyNode", "SetRule", "SetStorageMode", "Prestige", "Nonsense" }
	local ITEMS = { 0, 1, 2, 6, 7, 10, 25, -1, 0.5, 0.7, 1.5, 2, 2.5, 99, math.huge, -math.huge }
	table.insert(ITEMS, math.huge - math.huge)
	table.insert(ITEMS, "max")
	table.insert(ITEMS, "charge")
	table.insert(ITEMS, "sell")
	table.insert(ITEMS, "auto")
	table.insert(ITEMS, "x")
	table.insert(ITEMS, true)
	local NODE_IDS = {}
	for index = 1, 22 do
		table.insert(NODE_IDS, string.format("U%02d", index))
	end
	for index = 1, 8 do
		table.insert(NODE_IDS, string.format("P%d", index))
	end
	local DT = { 0, 0.1, 1, 10, 1000, -1, math.huge, math.huge - math.huge }
	local SECONDS = { 0, 59, 60, 3600, 1000000, math.huge, -1 }

	local function pick(list: { any }): any
		return list[math.random(#list)]
	end

	local function finiteNonNegative(value: number): boolean
		return value >= 0 and value < math.huge
	end

	for run = 1, 100 do
		local state = fresh()
		state.coins = 500
		for step = 1, 60 do
			local current = env(math.random(4), math.random(5), math.random(2) == 1)
			state = GameCore.tick(state, current, pick(DT))
			local action = {
				type = pick(TYPES),
				plant = pick(ITEMS),
				qty = pick(ITEMS),
				node = pick(NODE_IDS),
				slot = pick(ITEMS),
				rule = pick(ITEMS),
				th = pick(ITEMS),
				on = pick(ITEMS),
				mode = pick(ITEMS),
			}
			state = GameCore.apply(state, action, current)
			if math.random(10) == 1 then
				state = GameCore.offline(state, pick(SECONDS), current)
			end
			local label = `run {run} step {step}`
			t.truthy(finiteNonNegative(state.coins), `{label}: coins {state.coins}`)
			t.truthy(finiteNonNegative(state.storage.charge), `{label}: charge {state.storage.charge}`)
		end
	end
end
