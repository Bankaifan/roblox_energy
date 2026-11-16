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
	t.equal(plants[2].info, "Prepare the ground first: Shovel", "the water wheel names the shovel")
	state.land = table.clone(Land.start)
	state.land.tools = { scythe = true }
	state.land.sites = { 1, 0, 0, 0, 0, 0 }
	plants = cards("plants", state)
	t.equal(plants[1].state, "affordable", "20 coins cover the first panel")
	t.equal(plants[1].price, "15 Coins", "the price is on the card")
	t.equal(plants[1].button.remote, "BuyPlant", "Buy sends BuyPlant")
	t.equal(plants[1].button.payload.plant, 1, "for plant 1")
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

	-- Storage: the container first, modes locked before U17, rule cards per owned slot.
	local storage = cards("storage", state)
	t.equal(storage[1].id, "container", "the tab starts with the container")
	t.equal(storage[1].state, "short", "200 coins do not cover the container")
	t.equal(storage[2].state, "locked", "modes are locked before U17")
	t.equal(storage[#storage].id, "rules", "rules are one locked card before U21")
	state.coins = 500
	state.nodes.U17 = true
	state.nodes.U21 = true
	state.rules[1] = { id = "sell", th = 1.2, on = true }
	state.land.wired = true
	local stored = byId(cards("storage", state))
	t.equal(stored.container.button.remote, "Prepare", "the container is prepared")
	t.equal(stored["mode.auto"].state, "active", "the current mode is active")
	t.equal(stored["mode.sell"].button.payload.mode, "sell", "another mode can be selected")
	t.equal(stored["rule.1"].button.payload.on, false, "the switch turns a running rule off")
	t.equal(stored["rule.2"].button, nil, "an empty slot has no switch")
	t.equal(stored["rule.2.charge"].button.payload.th, ShopView.CHARGE_BELOW, "a slot can be set to charge")

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

	for _, tab in ShopView.tabs do
		t.truthy(Locale.tables.de[tab.key] ~= nil and Locale.tables.de[tab.hint] ~= nil, `texts for tab {tab.id}`)
	end
end
