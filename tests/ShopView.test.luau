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

	-- Production tab: a total card and one card per owned plant with the formula.
	local made = fresh()
	made.plants[1] = 3
	local output = cards("production", made)
	t.equal(#output, 2, "a total card and one plant card")
	t.truthy(output[2].info:find("3 x 1 x M", 1, true) ~= nil, "the plant card shows its count and base power")
	t.truthy(output[2].status ~= nil, "and its output")
	-- The numbers: the total is the sum of the rows, the grid part follows the level, aligned panels count more than owned.
	made.level = 2
	made.plants[3] = 2
	made.nodes.U03 = true
	local production = GameCore.view(made, env).production
	local sum = 0
	for _, row in production.rows do
		sum += row.output
	end
	t.truthy(math.abs(sum - production.total) < 1e-9, "the total is the sum of the plant outputs")
	t.equal(production.grid, Formulas.globalMultiplier(2, 1), "the grid multiplier follows the level")
	local house = production.rows[3]
	t.equal(
		house.output,
		house.nominal * house.effective * house.multiplier * house.factor,
		"output = base x count x M x factor"
	)
	t.truthy(house.multiplier > 1 and house.count == 2, "a node and the level lift the multiplier above 1")
	t.equal(production.rows[1].effective, 3, "panels without aligned cells count as owned")

	-- Extras tab: only offers with a fetched price, owned passes, booster stock, the daily limit, the Time Skip coins.
	local Catalogue = load("Config/Shop")
	local Offers = load("Core/Offers")
	local function extras(facts: any, prices: { [number]: number }, lang: string?, skipCoins: number?): { any }
		local shop: any = table.clone(Catalogue)
		shop.offers = {}
		for index, offer in Catalogue.offers do
			local copy: any = table.clone(offer)
			copy.robloxId = 1000 + index
			table.insert(shop.offers, copy)
		end
		return ShopView.cards("extras", {
			view = {},
			coins = 0,
			plants = config.plants,
			upgrades = config.upgrades,
			land = land,
			offers = Offers.visible(shop, prices, lang or "en"),
			extras = facts,
			skipCoins = skipCoins,
			shop = shop,
			t = function(key: string, args: any): string
				return Locale.t(key, lang or "en", args)
			end,
		})
	end
	local allPrices: { [number]: number } = {}
	for index = 1, #Catalogue.offers do
		allPrices[1000 + index] = 50 + index
	end
	local open = { shown = true, owned = {}, stock = 0, skipsLeft = 3 }
	local listed = byId(extras(open, allPrices))
	t.equal(#extras(open, allPrices), 12, "one card per offer with a price, the spark packs aside")
	t.equal(#extras(open, {}), 0, "offers without a fetched price are hidden")
	t.equal(#extras({ shown = false, owned = {}, stock = 0 }, allPrices), 0, "a hidden tab has no cards")
	t.equal(listed["offer.founder"].price, "51 Robux", "the live price and the word Robux")
	t.equal(listed["offer.founder"].button.offer, "founder", "View opens the prompt of the offer")
	t.equal(listed["offer.founder"].button.text, "View", "the button says View")
	t.equal(listed["offer.founder"].extra, true, "a Robux card has the cyan outline")
	t.equal(byId(extras(open, allPrices, "de"))["offer.founder"].button.text, "Ansehen", "German button")
	local partial = extras(open, { [1002] = 199 })
	t.equal(#partial, 1, "only the offer with a price is listed")
	t.equal(partial[1].id, "offer.smart_hub", "it is the Smart Hub")

	local owned = byId(extras({ shown = true, owned = { neon = true }, stock = 0, skipsLeft = 3 }, allPrices))
	t.equal(owned["offer.neon"].state, "owned", "an owned pass is owned")
	t.equal(owned["offer.neon"].status, "Owned", "and says Owned")
	t.equal(owned["offer.neon"].button, nil, "with no button")
	t.equal(owned["offer.themes"].state, "extra", "another pass is still for sale")

	local stocked = byId(extras({ shown = true, owned = {}, stock = 2800, skipsLeft = 3 }, allPrices))
	t.equal(stocked["offer.turbo"].button, nil, "a booster that does not fit the queue has no button")
	t.equal(stocked["offer.turbo"].status, "Queue full", "it says why")
	t.truthy(stocked["offer.sunshine"].button ~= nil, "a booster that still fits can be viewed")

	local limited = byId(extras({ shown = true, owned = {}, stock = 0, skipsLeft = 0 }, allPrices, "de"))
	t.equal(limited["offer.timeskip"].button, nil, "a Time Skip over the daily limit has no button")
	t.equal(limited["offer.timeskip"].status, "Heute aufgebraucht", "it says why")
	local unlimited = byId(extras({ shown = true, owned = {}, stock = 0 }, allPrices))
	t.truthy(unlimited["offer.timeskip"].button ~= nil, "no daily limit: the Time Skip can be viewed")

	local skip = byId(extras(open, allPrices, "en", 12500))["offer.timeskip"]
	t.truthy(string.find(skip.info, "12.5K coins", 1, true) ~= nil, "the Time Skip card shows the coins it gives now")
	-- Spark packs: from grid stage 1 on and only while the missing sparks cover them; also at the bottom of the Sparks tab.
	local function packFacts(level: number, missing: number): any
		return { shown = true, owned = {}, stock = 0, skipsLeft = 3, level = level, sparksMissing = missing }
	end
	t.equal(#extras(packFacts(0, 215), allPrices), 12, "no spark pack before grid stage 1")
	local stage1 = byId(extras(packFacts(1, 215), allPrices))
	t.truthy(stage1["offer.sparks5"] ~= nil and stage1["offer.sparks40"] ~= nil, "all three packs from grid stage 1")
	t.equal(#extras(packFacts(1, 215), allPrices), 15, "the Extras tab lists the packs")
	local needs = byId(extras(packFacts(1, 15), allPrices))
	t.truthy(needs["offer.sparks15"] ~= nil and needs["offer.sparks5"] ~= nil, "packs up to the missing sparks stay")
	t.equal(needs["offer.sparks40"], nil, "a pack larger than the missing sparks is hidden")
	t.equal(#extras(packFacts(1, 0), allPrices), 12, "nothing missing: no pack")
	t.equal(stage1["offer.sparks15"].price, "63 Robux", "a pack shows the live price")
	t.equal(stage1["offer.sparks15"].button.offer, "sparks15", "and opens the prompt of its offer")
	t.truthy(string.find(stage1["offer.sparks5"].info, "5 sparks", 1, true) ~= nil, "English card text")
	t.truthy(
		string.find(byId(extras(packFacts(1, 215), allPrices, "de"))["offer.sparks5"].info, "Funken", 1, true) ~= nil,
		"German card text"
	)
	local sparksTab = ShopView.cards("sparks", {
		view = { sparks = { items = {}, available = 0 } },
		coins = 0,
		plants = config.plants,
		upgrades = config.upgrades,
		land = land,
		offers = Offers.visible(
			(function()
				local shop: any = table.clone(Catalogue)
				shop.offers = {}
				for index, offer in Catalogue.offers do
					local copy: any = table.clone(offer)
					copy.robloxId = 1000 + index
					table.insert(shop.offers, copy)
				end
				return shop
			end)(),
			allPrices,
			"en"
		),
		extras = packFacts(1, 20),
		shop = Catalogue,
		t = function(key: string, args: any): string
			return Locale.t(key, "en", args)
		end,
	})
	t.equal(#sparksTab, 2, "the Sparks tab ends with the packs that still fit")
	t.equal(sparksTab[1].id, "offer.sparks5", "the 5 pack comes first")
	t.equal(ShopView.tabsFor(false, true)[6].id, "extras", "Extras is the last tab")
	t.equal(#ShopView.tabsFor(true, true), 7, "the control board has seven tabs with Extras")
	for _, offer in Catalogue.offers do
		t.truthy(Locale.tables.de[`offer.{offer.id}.info`] ~= nil, `German text for {offer.id}`)
	end

	local function ids(list: { any }): string
		local names = {}
		for _, tab in list do
			table.insert(names, tab.id)
		end
		return table.concat(names, ",")
	end
	t.equal(ids(ShopView.tabsFor(false)), "plants,upgrades,storage,tools,sparks", "the market has no production tab")
	t.equal(
		ids(ShopView.tabsFor(true)),
		"plants,upgrades,storage,tools,sparks,production",
		"the control board has all tabs"
	)

	for _, tab in ShopView.tabs do
		t.truthy(Locale.tables.de[tab.key] ~= nil and Locale.tables.de[tab.hint] ~= nil, `texts for tab {tab.id}`)
	end
end
