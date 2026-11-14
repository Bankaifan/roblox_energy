--!strict
-- GameCore.view (HUD): next prices, affordability, crank energy per click, the next grid expansion.
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
	local function env(phase: number, weather: number)
		return {
			phase = Config.phases[phase],
			weather = Config.weathers[weather],
			longMeter = false,
			config = Config,
			formulas = Formulas,
		}
	end

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

	-- Prices: the next unit of each plant, and whether the coins cover it.
	local state = fresh()
	state.coins = 20
	local view = GameCore.view(state, env(2, 1))
	t.equal(view.plants[1].cost, 15, "the first balcony panel costs 15")
	t.truthy(view.plants[1].affordable, "20 coins cover a balcony panel")
	t.equal(view.plants[2].affordable, false, "120 coins are not there for the water wheel")

	local owned = fresh()
	owned.plants[1] = 2
	owned.coins = 19
	local ownedView = GameCore.view(owned, env(2, 1))
	t.truthy(math.abs(ownedView.plants[1].cost - 15 * 1.15 ^ 2) < 1e-6, "the price rises with 1,15 per unit owned")
	t.equal(ownedView.plants[1].affordable, false, "19 coins do not cover the third panel at 19.84")

	-- Crank: 1 energy per click; with U13 plus 2 % of the production per second (10 rooftop solar at noon: 560/s).
	t.equal(view.crank, 1, "one click is one energy")
	local withNode = fresh()
	withNode.nodes.U12 = true
	t.equal(GameCore.view(withNode, env(2, 1)).crank, 3, "U12 makes a click 3 energy")
	local flywheel = fresh()
	flywheel.nodes.U13 = true
	flywheel.plants[3] = 10
	t.truthy(math.abs(GameCore.view(flywheel, env(2, 1)).crank - 12.2) < 1e-6, "U13 adds 2 % of 560/s")

	-- Goal: the next grid expansion and the run earnings; nothing after the last level.
	local earning = fresh()
	earning.runEarned = 4000000
	local goal = GameCore.view(earning, env(2, 1)).goal
	t.equal(goal.level, 1, "the next expansion is level 1")
	t.equal(goal.required, 10000000, "level 1 needs 10 Mio.")
	t.equal(goal.earned, 4000000, "the run earnings are shown")
	local last = fresh()
	last.level = 10
	t.equal(GameCore.view(last, env(2, 1)).goal, nil, "no goal after the last expansion")
	t.equal(goal.sparks, 5, "grid level 1 gives 5 sparks")
	t.equal(goal.allowed, false, "4 Mio. earned are not enough for level 1")
	earning.runEarned = 10000000
	t.truthy(GameCore.view(earning, env(2, 1)).goal.allowed, "10 Mio. earned allow level 1")

	-- Run nodes: locked without the plant or node before, open when the coins are short, affordable, bought.
	local nodes = view.nodes
	t.equal(nodes[1].state, "locked", "U01 needs a balcony panel")
	t.equal(nodes[12].state, "open", "U12 costs 50: 20 coins are not enough")
	local rich = fresh()
	rich.coins = 100000
	rich.plants[1] = 1
	rich.nodes.U12 = true
	local richNodes = GameCore.view(rich, env(2, 1)).nodes
	t.equal(richNodes[1].state, "affordable", "U01 is affordable with a panel and 100000 coins")
	t.equal(richNodes[1].cost, 150, "U01 costs 150")
	t.equal(richNodes[12].state, "bought", "U12 is bought")
	t.equal(richNodes[13].state, "affordable", "U13 needs U12 and 2000 coins")

	-- Storage: stage 0 until U17; the rule slots need U21 and show the rule in each slot.
	t.equal(view.storage.stage, 0, "no storage stage before U17")
	t.equal(view.storage.ruleSlots, 0, "no rule slots without U21")
	local stored = fresh()
	stored.nodes.U17 = true
	stored.nodes.U21 = true
	stored.rules[2] = { id = "sell", th = 1.2, on = true }
	local storage = GameCore.view(stored, env(2, 1)).storage
	t.equal(storage.stage, 1, "U17 is storage stage 1")
	t.equal(storage.ruleSlots, 2, "U21 gives two rule slots")
	t.equal(storage.rules[2].id, "sell", "the sell rule shows in slot 2")
end
