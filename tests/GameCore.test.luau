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
	local function env(phase: number, weather: number, longMeter: boolean?, boost: number?)
		return {
			phase = Config.phases[phase],
			weather = Config.weathers[weather],
			longMeter = longMeter == true,
			config = Config,
			formulas = Formulas,
			boost = boost,
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

	-- SetRule: the control center (U21) unlocks the two rules, addressed by id; the server rounds the threshold to a
	-- tenth and clamps it into the range of the rule (charge 0,3 to 1,0, sell 1,0 to 2,0).
	local function setRule(state: { [string]: any }, rule: any, th: any, on: any?): (any, boolean)
		local action = { type = "SetRule", rule = rule, th = th, on = if on == nil then true else on }
		return GameCore.apply(state, action, env(2, 1))
	end
	local rules = fresh()
	local _, ruleLockedOk = setRule(rules, "charge", 0.7)
	t.truthy(not ruleLockedOk, "a rule needs the control center")
	rules.nodes.U21 = true
	local ruled, ruleOk = setRule(rules, "charge", 0.7)
	t.truthy(ruleOk and ruled.rules.charge.th == 0.7 and ruled.rules.charge.on, "charge rule accepted at 0,7")
	local rounded = setRule(rules, "sell", 1.24)
	t.equal(rounded.rules.sell.th, 1.2, "a threshold is rounded to a tenth")
	t.equal(setRule(rules, "charge", 5).rules.charge.th, 1, "a charge threshold above 1,0 is clamped to 1,0")
	t.equal(setRule(rules, "charge", 0).rules.charge.th, 0.3, "a charge threshold below 0,3 is clamped to 0,3")
	t.equal(setRule(rules, "sell", 0.5).rules.sell.th, 1, "a sell threshold below 1,0 is clamped to 1,0")
	t.equal(setRule(rules, "sell", 9).rules.sell.th, 2, "a sell threshold above 2,0 is clamped to 2,0")
	local off = setRule(rules, "sell", 1.5, false)
	t.truthy(off.rules.sell.on == false and off.rules.sell.th == 1.5, "a rule is switched off with its threshold kept")
	local _, nanOk = setRule(rules, "sell", 0 / 0)
	t.truthy(not nanOk, "a NaN threshold is rejected")
	local _, infOk = setRule(rules, "sell", math.huge)
	t.truthy(not infOk, "an infinite threshold is rejected")
	local _, unknownRuleOk = setRule(rules, "expand", 1)
	t.truthy(not unknownRuleOk, "an unknown rule id is rejected")
	local _, slotOk = setRule(rules, 1, 1)
	t.truthy(not slotOk, "a slot number is no rule id")
	local _, onOk = setRule(rules, "sell", 1.2, "yes")
	t.truthy(not onOk, "the switch must be a boolean")

	-- SetStorageMode: needs the first storage node; Auto needs U21 and at least one rule switched on.
	local storageless = fresh()
	local _, modeLockedOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "charge" }, env(2, 1))
	t.truthy(not modeLockedOk, "storage mode needs a storage")
	storageless.nodes.U17 = true
	local moded, modeOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "charge" }, env(2, 1))
	t.truthy(modeOk and moded.storage.mode == "charge", "storage mode is set")
	local _, autoBeforeOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "auto" }, env(2, 1))
	t.truthy(not autoBeforeOk, "Auto is not selectable before U21")
	storageless.nodes.U21 = true
	local _, autoNoRuleOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "auto" }, env(2, 1))
	t.truthy(not autoNoRuleOk, "Auto is not selectable without a rule switched on")
	storageless.rules.sell = { th = 1.2, on = false }
	local _, autoOffOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "auto" }, env(2, 1))
	t.truthy(not autoOffOk, "Auto is not selectable with every rule off")
	storageless.rules.sell.on = true
	local autoSet, autoOk = GameCore.apply(storageless, { type = "SetStorageMode", mode = "auto" }, env(2, 1))
	t.truthy(autoOk and autoSet.storage.mode == "auto", "Auto is selectable with a rule on")

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
	auto.rules.charge = { th = 0.7, on = true }
	local autoNoon = GameCore.tick(auto, env(2, 1), 1)
	t.truthy(autoNoon.storage.charge > 0, "auto charges at the noon price")
	local autoMorning = GameCore.tick(auto, env(1, 1), 1)
	t.equal(autoMorning.storage.charge, 0, "auto does not charge at 1,2")

	-- Boost (Core/Boost factor, passed in as env.boost): a factor of 2 doubles the generation, so the coins sold
	-- in the same second double too. No storage here, so everything generated is sold. nil and 1 change nothing.
	local boosted = fresh()
	boosted.plants[3] = 10
	local plain = GameCore.tick(boosted, env(2, 1), 1)
	t.truthy(plain.coins > 0, "the plants sell something at noon")
	near(GameCore.tick(boosted, env(2, 1, false, 2), 1).coins, 2 * plain.coins, "a boost of 2 doubles the coins")
	t.equal(GameCore.tick(boosted, env(2, 1, false, 1), 1).coins, plain.coins, "a boost of 1 changes nothing")
	t.equal(GameCore.tick(boosted, env(2, 1, false, nil), 1).coins, plain.coins, "no boost changes nothing")

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

	-- Land (design 0018): without config.land nothing changes; with required the gates apply.
	local noLand, noLandOk = GameCore.apply(rich, { type = "BuyTool", tool = "shovel" }, env(2, 1))
	t.truthy(not noLandOk and noLand == rich, "BuyTool needs config.land")
	local _, noPrepareOk = GameCore.apply(rich, { type = "Prepare", target = 1 }, env(2, 1))
	t.truthy(not noPrepareOk, "Prepare needs config.land")
	local noLandView = GameCore.view(rich, env(2, 1))
	t.truthy(noLandView.tools == nil and noLandView.plants[1].needsSite == nil, "view has no land without config.land")

	local Land = load("Config/Land")
	local function landEnv(required: boolean)
		local config: { [string]: any } = table.clone(Config)
		local land: { [string]: any } = table.clone(Land)
		land.required = required
		config.land = land
		local result = env(2, 1)
		result.config = config
		return result
	end
	local open, gated = landEnv(false), landEnv(true)
	local _, openBuyOk = GameCore.apply(rich, { type = "BuyPlant", plant = 1, qty = 1 }, open)
	t.truthy(openBuyOk, "without required, buying needs no site")
	local _, gatedBuyOk = GameCore.apply(rich, { type = "BuyPlant", plant = 1, qty = 1 }, gated)
	t.truthy(not gatedBuyOk, "with required, buying needs a site")
	local mowed, mowedOk = GameCore.apply(rich, { type = "Prepare", target = 1 }, gated)
	t.truthy(mowedOk and mowed.land.sites[1] == 1, "the free scythe mows the first site")
	t.equal(rich.land, nil, "Prepare never changes its input")
	local _, siteBuyOk = GameCore.apply(mowed, { type = "BuyPlant", plant = 1, qty = 1 }, gated)
	t.truthy(siteBuyOk, "a prepared site unlocks the plant")
	local _, noToolOk = GameCore.apply(mowed, { type = "Prepare", target = 2 }, gated)
	t.truthy(not noToolOk, "Prepare needs the tool")
	local _, pastOk = GameCore.apply(
		{ land = { sites = { 24 }, tools = { scythe = true } } },
		{ type = "Prepare", target = 1 },
		gated
	)
	t.truthy(not pastOk, "Prepare stops at the sites of the field")

	local owner = fresh()
	owner.plants[1] = 1
	owner.coins = 29
	local _, poorToolOk = GameCore.apply(owner, { type = "BuyTool", tool = "shovel" }, gated)
	t.truthy(not poorToolOk, "BuyTool needs the coins")
	owner.coins = 1000
	local shovel, shovelOk = GameCore.apply(owner, { type = "BuyTool", tool = "shovel" }, gated)
	t.truthy(shovelOk and shovel.coins == 970 and shovel.land.tools.shovel == true, "the shovel costs 30")
	local _, twiceOk = GameCore.apply(shovel, { type = "BuyTool", tool = "shovel" }, gated)
	t.truthy(not twiceOk, "a tool is bought once")
	local _, hiddenOk = GameCore.apply(owner, { type = "BuyTool", tool = "hammer" }, gated)
	t.truthy(not hiddenOk, "an unrevealed tool cannot be bought")
	local _, unknownOk = GameCore.apply(owner, { type = "BuyTool", tool = "axe" }, gated)
	t.truthy(not unknownOk, "an unknown tool is rejected")
	local viewed = GameCore.view(owner, gated)
	t.truthy(viewed.plants[2].needsSite and viewed.tools[3].buyable, "view shows needsSite and the buyable shovel")

	-- The container gates U17, wiring gates the rule slots, prestige keeps the land.
	local storage = fresh()
	storage.coins = 100000
	storage.plants[1] = 1
	storage.nodes.U16 = true
	local _, noContainerOk = GameCore.apply(storage, { type = "BuyNode", node = "U17" }, gated)
	t.truthy(not noContainerOk, "U17 needs the container with required land")
	local boxed, boxedOk = GameCore.apply(storage, { type = "Prepare", target = "container" }, gated)
	t.truthy(boxedOk and boxed.coins == 99500, "the container costs 500")
	local stored, storedOk = GameCore.apply(boxed, { type = "BuyNode", node = "U17" }, gated)
	t.truthy(storedOk, "U17 with the container")
	stored.nodes.U21 = true
	t.equal(GameCore.view(stored, gated).storage.rulesUnlocked, false, "the rules need the wiring")
	stored.coins = 1000
	local _, unwiredOk = GameCore.apply(stored, { type = "Prepare", target = "wired" }, gated)
	t.truthy(not unwiredOk, "wiring needs the pliers")
	local pliers = GameCore.apply(stored, { type = "BuyTool", tool = "pliers" }, gated)
	local wired, wiredOk = GameCore.apply(pliers, { type = "Prepare", target = "wired" }, gated)
	t.truthy(wiredOk, "wiring with the pliers")
	t.equal(GameCore.view(wired, gated).storage.rulesUnlocked, true, "a wired board unlocks the rules")
	t.equal(GameCore.view(stored, open).storage.rulesUnlocked, true, "without required the rules need no wiring")
	wired.runEarned = 10000000
	local after, afterOk = GameCore.apply(wired, { type = "Prestige" }, gated)
	t.truthy(
		afterOk and after.land.container and after.land.wired and after.land.tools.pliers,
		"prestige keeps the land"
	)

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
	local TYPES =
		{ "Crank", "BuyPlant", "BuyNode", "SetRule", "SetStorageMode", "Prestige", "BuyTool", "Prepare", "Nonsense" }
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

	local TOOL_IDS = { "scythe", "rails", "shovel", "hammer", "wrench", "drum", "tamper", "pliers", "axe" }
	local TARGETS = { 1, 2, 3, 4, 5, 6, 7, 0, "market", "container", "wired", "x" }
	for run = 1, 100 do
		local state = fresh()
		state.coins = 500
		local landEnvironment = landEnv(run % 2 == 0)
		for step = 1, 60 do
			local current = env(math.random(4), math.random(5), math.random(2) == 1)
			current.config = landEnvironment.config
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
				tool = pick(TOOL_IDS),
				target = pick(TARGETS),
			}
			state = GameCore.apply(state, action, current)
			for field, fieldSize in Land.fields do
				local sites = if state.land ~= nil then state.land.sites[field] else 0
				t.truthy(sites >= 0 and sites <= fieldSize, `run {run} step {step}: sites of field {field}`)
			end
			if math.random(10) == 1 then
				state = GameCore.offline(state, pick(SECONDS), current)
			end
			local label = `run {run} step {step}`
			t.truthy(finiteNonNegative(state.coins), `{label}: coins {state.coins}`)
			t.truthy(finiteNonNegative(state.storage.charge), `{label}: charge {state.storage.charge}`)
		end
	end
end
