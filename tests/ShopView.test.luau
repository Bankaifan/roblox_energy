--!strict
-- ShopView.cards (market popup): the cards per tab, their states and the one message each button sends.
return function(t, load)
	local ShopView = load("Core/ShopView")
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Locale = load("Config/Locale")
	local Land = load("Config/Land")
	local config: { [string]: any } = {
		plants = load("Config/Plants"),
		upgrades = load("Config/Upgrades"),
		prestige = load("Config/Prestige"),
		phases = load("Config/Phases"),
		weathers = load("Config/Weather"),
		effects = load("Config/Effects"),
	}
	local land: { [string]: any } = table.clone(Land)
	land.required = true
	land.unitsPerSite = 1
	config.land = land
	local env = {
		phase = config.phases[2],
		weather = config.weathers[1],
		longMeter = false,
		config = config,
		formulas = Formulas,
	}

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
	local function cards(tab: string, state: any, lang: string?): { any }
		return ShopView.cards(tab, {
			view = GameCore.view(state, env),
			coins = state.coins,
			plants = config.plants,
			upgrades = config.upgrades,
			land = land,
			ruleStep = config.effects.ruleStep,
			t = function(key: string, args: any): string
				return Locale.t(key, lang or "en", args)
			end,
		})
	end
	local function byId(list: { any }): { [string]: any }
		local found = {}
		for _, card in list do
			found[card.id] = card
		end
		return found
	end

	t.equal(ShopView.short(1100), "1.1K", "prices are shortened")
	t.equal(#ShopView.cards("plants", { view = nil } :: any), 0, "no cards before the first view")
	t.equal(#ShopView.cards("nope", { view = {} } :: any), 0, "an unknown tab has no cards")

	-- Plants: without a site the card leads to the Tools tab; with one it has a price and a Buy button.
	local state = fresh()
	state.coins = 20
	local plants = cards("plants", state)
	t.equal(#plants, 6, "one card per plant")
	t.equal(plants[1].state, "hint", "a plant without a site is a hint")
	t.equal(plants[1].button.tab, "tools", "its button opens the Tools tab")
	t.equal(plants[2].info, "Prepare the ground first: Shovel in hand", "the water wheel names the shovel")
	state.land = table.clone(Land.start)
	state.land.tools = { scythe = true }
	state.land.sites = { 1, 0, 0, 0, 0, 0 }
	plants = cards("plants", state)
	t.equal(plants[1].state, "affordable", "20 coins cover the first panel")
	t.equal(plants[1].price, "15 Coins", "the price is on the card")
	t.equal(plants[1].button.remote, "BuyPlant", "Buy sends BuyPlant")
	t.equal(plants[1].button.payload.plant, 1, "for plant 1")
	state.plants[1] = 1
	plants = cards("plants", state)
	t.equal(plants[1].state, "hint", "every mown cell carries a unit")
	t.equal(plants[1].info, "Mow more ground first", "the card names the reason")
	t.equal(plants[1].button, nil, "and offers no purchase")
	state.plants[1] = 0
	state.coins = 5
	plants = cards("plants", state)
	t.equal(plants[1].state, "short", "5 coins are short")
	t.equal(plants[1].button.enabled, false, "the Buy button is off")
	t.equal(cards("plants", state, "de")[1].title, "Balkonmodul", "German titles")

	-- Upgrades: locked names the requirement, bought has no button, affordable buys the node.
	state.coins = 100
	state.plants[1] = 1
	state.nodes.U12 = true
	local upgrades = byId(cards("upgrades", state))
	t.equal(upgrades.U12.state, "owned", "U12 is bought")
	t.equal(upgrades.U12.button, nil, "a bought upgrade has no button")
	t.equal(upgrades.U02.status, "Locked: needs Water Wheel", "U02 names its plant")
	t.equal(upgrades.U10.status, "Locked: needs U09 Grid Boost I", "U10 names its node")
	t.equal(upgrades.U01.state, "short", "150 coins are not there for U01")
	state.coins = 200
	upgrades = byId(cards("upgrades", state))
	t.equal(upgrades.U01.state, "affordable", "200 coins cover U01")
	t.equal(upgrades.U01.button.payload.node, "U01", "Buy sends the node id")

	-- Storage: the container first, modes locked before U17, the rules one locked card before U21.
	local storage = cards("storage", state)
	t.equal(storage[1].id, "container", "the tab starts with the container")
	t.equal(storage[1].state, "short", "200 coins do not cover the container")
	t.equal(storage[2].state, "locked", "modes are locked before U17")
	t.equal(storage[#storage].id, "rules", "rules are one locked card before U21")
	t.equal(storage[#storage].info, Locale.t("rules.locked", "en"), "before U21 the card asks for U21")
	state.nodes.U21 = true
	local unwired = cards("storage", state)
	t.equal(
		unwired[#unwired].info,
		Locale.t("rules.unwired", "en"),
		"with U21 but no wiring the card asks for the wiring"
	)
	state.nodes.U21 = nil
	state.coins = 500
	state.nodes.U17 = true
	state.nodes.U21 = true
	state.land.wired = true
	state.storage.mode = "charge"
	local stored = byId(cards("storage", state))
	t.equal(stored.container.button.remote, "BuyContainer", "the container has its own client message")
	t.equal(stored["mode.charge"].state, "active", "the current mode is active")
	t.equal(stored["mode.auto"].button, nil, "Auto cannot be selected without a rule")
	t.equal(stored["mode.auto"].status, "Auto needs a rule", "and says why")
	t.truthy(stored.rules.info:find("Price x0.70", 1, true) ~= nil, "the rule section shows the price now")
	t.equal(stored["rule.charge"].info, "Charges below price 0.7, off", "an unset rule is off at its default")
	t.equal(stored["rule.charge"].button.payload.on, true, "the switch turns it on")
	t.equal(stored["rule.charge"].steps.up.payload.th, 0.8, "the stepper raises by a tenth")
	t.equal(stored["rule.sell"].steps.down.payload.th, 1.1, "the stepper lowers by a tenth")
	t.equal(stored["rule.sell"].steps.down.enabled, true, "the sell rule can go down from 1.2")
	state.rules.charge = { th = 0.3, on = true }
	stored = byId(cards("storage", state))
	t.equal(stored["rule.charge"].steps.down.enabled, false, "the charge rule stops at 0.3")
	t.equal(stored["rule.charge"].button.payload.on, false, "the switch turns a running rule off")
	t.equal(stored["mode.auto"].button.payload.mode, "auto", "a rule on makes Auto selectable")

	-- Tools: owned, not yet available, buyable; every card explains what the tool unlocks.
	state.coins = 40
	local tools = byId(cards("tools", state))
	t.equal(tools["tool.scythe"].state, "owned", "the scythe is owned")
	t.equal(tools["tool.shovel"].state, "affordable", "with a panel and 40 coins the shovel is buyable")
	t.equal(tools["tool.shovel"].button.payload.tool, "shovel", "Buy sends the tool id")
	t.equal(tools["tool.shovel"].info, "Digs the stream for water wheels", "the card says what the tool unlocks")
	t.equal(tools["tool.rails"].state, "short", "300 coins are not there for the rails")
	t.equal(tools["tool.wrench"].state, "locked", "the wrench is not available yet")
	t.truthy(tools["tool.wrench"].info ~= "", "a locked tool still explains itself")

	local noLand = ShopView.cards("tools", { view = {}, coins = 0, land = land, t = Locale.t } :: any)
	t.equal(#noLand, #Land.tools, "without land rules every tool is still listed")
	t.equal(noLand[1].state, "locked", "as not available yet")

	-- Sparks: a card per permanent node and spark item; the Buy button sends BuyNode with the sparks as price.
	local sparkState = fresh()
	sparkState.sparks, sparkState.sparksSpent = 7, 3
	sparkState.pnodes.P1 = true
	local sparkCards = cards("sparks", sparkState)
	t.equal(#sparkCards, 14, "eight permanent nodes and six spark items")
	local sparks = byId(sparkCards)
	t.equal(sparks.P1.state, "owned", "an owned node says so")
	t.equal(sparks.P1.title, "P1 Starting Capital", "the title has id and name")
	t.equal(sparks.S2.state, "affordable", "S2 costs 2 of the 4 sparks left")
	t.equal(sparks.S2.price, "2 sparks", "the price is in sparks")
	t.equal(sparks.S2.button.remote, "BuyNode", "Buy sends BuyNode")
	t.equal(sparks.S2.button.payload.node, "S2", "with the item id")
	t.equal(sparks.S3.state, "short", "S3 costs 6 sparks, 4 are left")
	t.truthy(not sparks.S3.button.enabled, "its button is off")
	t.equal(sparks.S4.state, "short", "S4 costs 10 sparks, 4 are left")
	t.equal(sparks.S4.title, "S4 Fine Tuning", "S4 is listed with its name")
	t.truthy(not sparks.S4.button.enabled, "its button is off")
	t.equal(byId(cards("sparks", sparkState, "de")).S2.title, "S2 Werkzeug-Rabatt", "German item name")

	for _, tab in ShopView.tabs do
		t.truthy(Locale.tables.de[tab.key] ~= nil and Locale.tables.de[tab.hint] ~= nil, `texts for tab {tab.id}`)
	end
end
