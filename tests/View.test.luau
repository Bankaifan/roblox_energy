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

	-- Crank output: coins per turn (energy x price factor) and per second at the given speed.
	local output = GameCore.crankOutput(flywheel, env(2, 1), 6)
	local factor = GameCore.view(flywheel, env(2, 1)).price.factor
	t.truthy(math.abs(output.turn - 12.2 * factor) < 1e-6, "a turn pays the energy at the price factor")
	t.truthy(math.abs(output.second - output.turn * 6) < 1e-6, "per second is the turn times the speed")
	local cranked = GameCore.apply(flywheel, { type = "Crank" }, env(2, 1))
	t.truthy(math.abs(cranked.coins - flywheel.coins - output.turn) < 1e-6, "a real turn pays exactly the shown amount")

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
	t.equal(goal.sparks, 8, "grid level 1 gives 8 sparks")
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

	-- Price: the factor tick sells at (Mittag 0,7 x Sonnig 1,0); the next weather only with U15.
	t.truthy(math.abs(view.price.factor - 0.7) < 1e-9, "the price factor at noon in sunshine is 0,7")
	t.equal(view.price.phase, "Mittag", "the view names the phase")
	t.equal(view.price.nextWeather, nil, "no next weather without U15")
	local seer = fresh()
	local seerEnv = env(2, 1)
	seerEnv.nextWeather = Config.weathers[4]
	t.equal(GameCore.view(seer, seerEnv).price.nextWeather, nil, "the next weather stays hidden without U15")
	seer.nodes.U15 = true
	local seen = GameCore.view(seer, seerEnv).price
	t.equal(seen.nextWeather, Config.weathers[4].id, "U15 shows the next weather")
	t.truthy(math.abs(seen.factor - 0.77) < 1e-9, "U15 raises the price factor by 10 %")

	-- Storage: stage 0 until U17; the two rules need U21 and show their threshold, switch and range.
	t.equal(view.storage.stage, 0, "no storage stage before U17")
	t.equal(view.storage.rulesUnlocked, false, "no rules without U21")
	t.equal(view.storage.autoReady, false, "Auto does nothing without U21")
	t.equal(view.storage.flow.kind, "none", "no flow line without a storage")
	local stored = fresh()
	stored.nodes.U17 = true
	stored.nodes.U21 = true
	stored.rules.sell = { th = 1.5, on = true }
	local storage = GameCore.view(stored, env(2, 1)).storage
	t.equal(storage.stage, 1, "U17 is storage stage 1")
	t.equal(storage.rulesUnlocked, true, "U21 unlocks the rules")
	t.equal(storage.autoReady, true, "a rule on makes Auto selectable")
	t.equal(storage.rules.sell.th, 1.5, "the sell rule shows its threshold")
	t.equal(storage.rules.sell.on, true, "the sell rule shows it is on")
	t.equal(storage.rules.charge.th, 0.7, "an unset charge rule shows the default 0,7")
	t.equal(storage.rules.charge.on, false, "an unset rule is off")
	t.equal(storage.rules.charge.min, 0.3, "the charge range starts at 0,3")
	t.equal(storage.rules.sell.max, 2, "the sell range ends at 2,0")
	stored.rules.sell.on = false
	t.equal(GameCore.view(stored, env(2, 1)).storage.autoReady, false, "all rules off: Auto is not ready")

	-- Flow line: 10 rooftop solar at noon make 560/s; capacity 18270, rate 304.5/s, so 304.5 of 560 is taken in.
	local flowing = fresh()
	flowing.plants[3] = 10
	flowing.nodes.U17 = true
	flowing.storage.mode = "charge"
	local charging = GameCore.view(flowing, env(2, 1)).storage.flow
	t.equal(charging.kind, "charging", "charge mode shows charging")
	t.truthy(math.abs(charging.share - 304.5 / 560) < 1e-6, "the share is input / generated")
	flowing.storage.charge = 18270
	t.equal(GameCore.view(flowing, env(2, 1)).storage.flow.kind, "full", "a full storage shows full")
	flowing.storage.mode = "sell"
	local selling = GameCore.view(flowing, env(3, 1)).storage.flow
	t.equal(selling.kind, "selling", "sell mode with stored energy shows selling")
	t.truthy(math.abs(selling.income - 304.5 * 1.8) < 1e-6, "selling income is the energy sold per second at the price")
	flowing.storage.charge = 0
	t.equal(GameCore.view(flowing, env(3, 1)).storage.flow.kind, "idle", "selling with an empty storage is idle")
	local sold = GameCore.tick(flowing, env(2, 1), 1)
	t.truthy(sold.coins > 0, "the rate shown in the HUD (coins earned) counts the sale")
	t.equal(storage.fill, 0, "an empty storage has fill 0")
	t.equal(view.storage.fill, 0, "no storage has fill 0")
	t.equal(Formulas.storageFill(30, 60), 0.5, "half the capacity is fill 0.5")
	t.equal(Formulas.storageFill(90, 60), 1, "fill is capped at 1")
	t.equal(Formulas.unitFill(0.5, 0, 2), 1, "with two units at half fill, the bottom unit is full")
	t.equal(Formulas.unitFill(0.5, 1, 2), 0, "and the top unit is empty")
	t.equal(Formulas.unitFill(0.25, 0, 1), 0.3, "one unit at a quarter shows in tenths")

	-- Market popup data (Tools tab, site states, container): what the HUD draws comes from view.land and view.tools.
	local Land = load("Config/Land")
	local Locale = load("Config/Locale")
	local landConfig: { [string]: any } = table.clone(Config)
	local landTemplate: { [string]: any } = table.clone(Land)
	landTemplate.required = true
	landConfig.land = landTemplate
	local landEnv = env(2, 1)
	landEnv.config = landConfig
	local landState = fresh()
	landState.coins = 40
	local landView = GameCore.view(landState, landEnv)
	t.truthy(landView.plants[1].needsSite, "a plant without a site names its tool instead of Buy")
	t.equal(Land.fieldTools[2], "shovel", "the water wheel row names the shovel")
	t.equal(landView.land.container, false, "the Storage tab starts with the container still to buy")
	local byId = {}
	for _, tool in landView.tools do
		byId[tool.id] = tool
	end
	t.truthy(byId.scythe.owned, "the scythe is owned at the start")
	t.equal(byId.shovel.revealed, false, "the shovel waits for the first panel")
	landState.plants[1] = 1
	byId = {}
	for _, tool in GameCore.view(landState, landEnv).tools do
		byId[tool.id] = tool
	end
	t.truthy(byId.shovel.revealed and byId.shovel.buyable, "with a panel and 40 coins the shovel is buyable")
	t.equal(byId.shovel.place, "market", "tools are sold at the market")
	for _, tool in Land.tools do
		local en = Locale.tables.en
		t.truthy(en[tool.textKey] ~= nil and en[tool.textKey .. ".info"] ~= nil, `texts for {tool.id}`)
	end
	t.truthy(
		Locale.tables.en["tool.line"] ~= nil and Locale.tables.de["hint.needTool"] ~= nil,
		"popup texts in both languages"
	)
end
