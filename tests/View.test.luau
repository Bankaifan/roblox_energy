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
end
