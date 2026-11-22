--!strict
-- Market popup contents (design 0018, R1): for one tab, the list of cards the popup draws. Pure Luau, no Roblox APIs.
-- A card is plain data: icon id, title, info, price, status, state and at most one button. The popup only paints it and
-- sends the button's message; the server checks every message again. Texts come from the `t` function the caller gives.
local ShopView = {}

-- `offer`: opens the Roblox purchase prompt of this offer (Extras tab); the client checks that its price was fetched.
export type Button = { text: string, enabled: boolean, remote: string?, payload: any?, tab: string?, offer: string? }
export type Card = {
	id: string,
	icon: string,
	title: string,
	info: string,
	price: string?,
	status: string?,
	-- affordable: can be bought now. short: coins are missing. owned: bought or delivered. locked: not reachable yet.
	-- hint: leads to another tab. active: the chosen setting. idle: a setting that can be chosen.
	state: string,
	button: Button?,
	-- Two small buttons for a value the player sets in steps (the rule thresholds): lower and higher.
	steps: { down: Button, up: Button }?,
	extra: boolean?, -- a Robux offer: the card has the cyan outline
	-- Permanent plants (Robux): up to two small cyan lines under a plant card, each a tap that opens the offer's purchase prompt.
	permanent: { Button }?,
}
export type Input = {
	view: any,
	coins: number,
	plants: any,
	upgrades: any,
	land: any,
	ruleStep: number?, -- the threshold step of the rule steppers (Config/Effects.ruleStep); 0.1 when missing
	t: (key: string, args: { [string]: any }?) -> string,
	-- Extras tab: the Robux offers with a fetched price (Core/Offers.visible), the facts of Shop.extrasView, the coins a
	-- Time Skip gives now and the catalogue (Config/Shop).
	offers: { any }?,
	extras: any?,
	skipCoins: number?,
	shop: any?,
}

-- The tabs in order, each with its Locale keys for the tab button and the one-line explanation under the tab row.
ShopView.tabs = {
	{ id = "plants", icon = "plant.1", key = "tab.plants", hint = "market.hint.plants" },
	{ id = "upgrades", icon = "upgrade", key = "tab.upgrades", hint = "market.hint.upgrades" },
	{ id = "storage", icon = "container", key = "tab.storage", hint = "market.hint.storage" },
	{ id = "tools", icon = "tool.scythe", key = "tab.tools", hint = "market.hint.tools" },
	{ id = "sparks", icon = "tab.sparks", key = "tab.sparks", hint = "market.hint.sparks" },
	{
		id = "production",
		icon = "tab.production",
		key = "tab.production",
		hint = "market.hint.production",
		board = true,
	},
	{ id = "extras", icon = "tab.extras", key = "tab.extras", hint = "market.hint.extras", extras = true },
} :: { { id: string, icon: string, key: string, hint: string, board: boolean?, extras: boolean? } }

-- The tabs shown when the popup was opened at the control board (`atBoard`) or at the market. The production tab belongs to
-- the control board only; the Extras tab shows only with `withExtras` (the server allows it and an offer has a price).
function ShopView.tabsFor(atBoard: boolean, withExtras: boolean?): { any }
	local shown = {}
	for _, tab in ShopView.tabs do
		if (atBoard or not tab.board) and (withExtras == true or not tab.extras) then
			table.insert(shown, tab)
		end
	end
	return shown
end
ShopView.STORAGE_MODES = { "charge", "sell", "auto" }

local SUFFIXES = { "", "K", "M", "B", "T" }

-- 10000000 is "10M", 1100 is "1.1K": at most one decimal and one suffix.
function ShopView.short(value: number): string
	local scaled = value
	local index = 1
	while scaled >= 1000 and index < #SUFFIXES do
		scaled /= 1000
		index += 1
	end
	local text = string.gsub(string.format("%.1f", scaled), "%.0$", "")
	return text .. SUFFIXES[index]
end

local function price(input: Input, cost: number): string
	if cost <= 0 then
		return input.t("market.free")
	end
	return input.t("market.price", { cost = ShopView.short(cost) })
end

local function findOffer(shop: any, id: string): any?
	for _, offer in if shop ~= nil then shop.offers else {} do
		if offer.id == id then
			return offer
		end
	end
	return nil
end

local function buy(input: Input, enabled: boolean, remote: string, payload: any): Button
	return { text = input.t("action.buy"), enabled = enabled, remote = remote, payload = payload }
end

-- The permanent plant lines of one plant card: the single unit and the pack of 10, each only while the offer is for sale
-- (a fetched price, Shop.permanentOffers) and the shop tab is allowed (minute 12, policy). Nil when there is none.
local function permanentLines(input: Input, index: number): { Button }?
	local facts = input.extras
	if facts == nil or facts.shown ~= true or facts.permanent == nil then
		return nil
	end
	local lines: { Button } = {}
	for _, entry in input.offers or {} do
		local offer = findOffer(input.shop, entry.id)
		if offer ~= nil and offer.plant == index and facts.permanent[entry.id] == true then
			local key = if offer.count > 1 then "market.permanentPack" else "market.permanent"
			local text = input.t(key, { count = offer.count, price = math.floor(entry.price + 0.5) })
			table.insert(lines, { text = text, enabled = true, offer = entry.id })
		end
	end
	return if #lines > 0 then lines else nil
end

local function plantCards(input: Input): { Card }
	local cards: { Card } = {}
	for index, plant in input.plants do
		local item = input.view.plants[index]
		local card: Card = {
			id = `plant.{plant.id}`,
			icon = `plant.{plant.id}`,
			title = input.t(`plant.{plant.id}`),
			info = input.t(`plantKind.{plant.kind}`),
			state = "short",
		}
		if item.needsSite == true and (item.sites or 0) > 0 then
			-- Every mown cell already carries a unit: the card says why and offers no purchase.
			card.state = "hint"
			card.info = input.t("hint.mowMore")
		elseif item.needsSite == true then
			-- No site yet: the card names the tool that prepares the ground and leads to the Tools tab.
			local toolKey = "tool." .. tostring(input.land.fieldTools[index])
			for _, tool in input.land.tools do
				if tool.id == input.land.fieldTools[index] then
					toolKey = tool.textKey
				end
			end
			card.state = "hint"
			card.info = input.t("hint.needTool", { tool = input.t(toolKey) })
			card.button = { text = input.t("market.toTools"), enabled = true, tab = "tools" }
		else
			card.state = if item.affordable then "affordable" else "short"
			card.price = price(input, item.cost)
			card.button = buy(input, item.affordable, "BuyPlant", { plant = index, qty = 1 })
		end
		card.permanent = permanentLines(input, index)
		table.insert(cards, card)
	end
	return cards
end

-- Why a locked upgrade is locked: the plant or the upgrade it needs.
local function requirementOf(input: Input, node: any): string
	if node.requiresPlant ~= nil then
		return input.t(`plant.{node.requiresPlant}`)
	end
	if node.requiresNode ~= nil then
		return `{node.requiresNode} {input.t(`node.{node.requiresNode}.name`)}`
	end
	return input.t("reason.prerequisite")
end

local function upgradeCards(input: Input): { Card }
	local cards: { Card } = {}
	for index, node in input.upgrades.run do
		local item = input.view.nodes[index]
		local card: Card = {
			id = node.id,
			icon = "upgrade",
			title = `{node.id} {input.t(`node.{node.id}.name`)}`,
			info = input.t(`node.{node.id}.info`),
			state = "short",
		}
		if item.state == "bought" then
			card.state = "owned"
			card.status = input.t("reason.bought")
		elseif item.state == "locked" then
			card.state = "locked"
			card.status = input.t("reason.locked", { requirement = requirementOf(input, node) })
		else
			local affordable = item.state == "affordable"
			card.state = if affordable then "affordable" else "short"
			card.price = price(input, item.cost)
			card.button = buy(input, affordable, "BuyNode", { node = node.id })
		end
		table.insert(cards, card)
	end
	return cards
end

-- The Robux cards, defined below: all offers with a price, or only the spark packs.
local robuxCards: (Input, boolean) -> { Card }

-- The Storage tab: the container, the modes and the rules; from the second battery (U18) on also the Mega Battery offer.
local function storageCards(input: Input): { Card }
	local cards: { Card } = {}
	local t = input.t
	local land = input.view.land
	if land ~= nil then
		-- The tab starts with the container; U17 needs it once the land rules are on.
		local card: Card = {
			id = "container",
			icon = "container",
			title = t("tool.container"),
			info = t("tool.container.info"),
			state = "owned",
		}
		if land.container then
			card.status = t("container.owned")
		else
			local affordable = input.coins >= input.land.containerCost
			card.state = if affordable then "affordable" else "short"
			card.price = price(input, input.land.containerCost)
			card.button = buy(input, affordable, "BuyContainer", {})
		end
		table.insert(cards, card)
	end
	local stored = input.view.storage
	for _, mode in ShopView.STORAGE_MODES do
		local card: Card = {
			id = `mode.{mode}`,
			icon = `mode.{mode}`,
			title = t(`mode.{mode}`),
			info = t(`mode.hint.{mode}`),
			state = "idle",
		}
		if stored.stage < 1 then
			card.state = "locked"
			card.status = t("storage.locked")
		elseif mode == "auto" and not stored.autoReady then
			-- Auto does nothing without a rule that is switched on: it cannot be selected until then.
			card.state = "short"
			card.status = t("mode.autoNeedsRule")
		elseif stored.mode == mode then
			card.state = "active"
			card.status = t("market.active")
		else
			card.button =
				{ text = t("market.select"), enabled = true, remote = "SetStorageMode", payload = { mode = mode } }
		end
		table.insert(cards, card)
	end
	for _, card in ShopView.ruleCards(input) do
		table.insert(cards, card)
	end
	if stored.stage >= 2 then
		for _, card in robuxCards(input, false) do
			if card.id == "offer.mega_battery" then
				table.insert(cards, card)
			end
		end
	end
	return cards
end

-- The price line, for the HUD and the rule section: the price factor of this second, the phase and, with U15, the
-- next weather. `quote` is view.price.
function ShopView.priceText(quote: any, t: (string, { [string]: any }?) -> string): string
	local args = { factor = string.format("%.2f", quote.factor), phase = t(`phase.{quote.phase}`) }
	if quote.nextWeather ~= nil then
		args.weather = t(`weather.{quote.nextWeather}`)
		return t("hud.priceNext", args)
	end
	return t("hud.price", args)
end

-- The live storage line of the view: what the storage does this second; "" without a storage.
function ShopView.flowText(flow: any, t: (string, { [string]: any }?) -> string): string
	if flow.kind == "charging" then
		return t("flow.charging", { percent = math.floor(flow.share * 100 + 0.5) })
	elseif flow.kind == "full" then
		return t("flow.full")
	elseif flow.kind == "selling" then
		return t("flow.selling", { value = ShopView.short(flow.income) })
	elseif flow.kind == "idle" then
		return t("flow.idle")
	end
	return ""
end

local function tenths(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- The "Regelautomatik" section of the Storage tab: a head card with the price now and what the storage does, then one
-- card per rule (buy below, sell above) with its switch and two steppers. Locked as one card before U21 (and wiring).
function ShopView.ruleCards(input: Input): { Card }
	local t = input.t
	local stored = input.view.storage
	if not stored.rulesUnlocked then
		return {
			{
				id = "rules",
				icon = "rule",
				title = t("rules.title"),
				info = t(if stored.controlOwned then "rules.unwired" else "rules.locked"),
				state = "locked",
			},
		}
	end
	local step = input.ruleStep or 0.1
	local cards: { Card } = {
		{
			id = "rules",
			icon = "rule",
			title = t("rules.title"),
			info = ShopView.priceText(input.view.price, t),
			status = ShopView.flowText(stored.flow, t),
			state = "idle",
		},
	}
	for _, id in { "charge", "sell", "reserve" } do
		local rule = stored.rules[id]
		if rule == nil then
			continue -- the reserve rule is the third slot: only with the Smart Hub
		end
		local function message(th: number, on: boolean): Button
			return {
				text = "",
				enabled = true,
				remote = "SetRule",
				payload = { rule = id, th = tenths(th), on = on },
			}
		end
		local toggle = message(rule.th, not rule.on)
		toggle.text = t(if rule.on then "rule.switchOff" else "rule.switchOn")
		local down = message(rule.th - step, rule.on)
		down.text = t("rule.down", { step = if id == "reserve" then `{math.floor(step * 100 + 0.5)} %` else step })
		down.enabled = rule.th > rule.min + 1e-9
		local up = message(rule.th + step, rule.on)
		up.text = t("rule.up", { step = if id == "reserve" then `{math.floor(step * 100 + 0.5)} %` else step })
		up.enabled = rule.th < rule.max - 1e-9
		table.insert(cards, {
			id = `rule.{id}`,
			icon = `mode.{id}`,
			title = t(`rule.{id}`),
			info = t(`rule.{id}Status`, {
				threshold = string.format("%.1f", rule.th),
				percent = math.floor(rule.th * 100 + 0.5),
				state = t(if rule.on then "state.on" else "state.off"),
			}),
			state = if rule.on then "active" else "idle",
			button = toggle,
			steps = { down = down, up = up },
		})
	end
	return cards
end

-- One card per tool: the info line says what the tool unlocks, also while the tool is not for sale yet. A view without
-- tools (the server has no land rules yet) still lists every tool of the config, as not available yet.
local function toolCards(input: Input): { Card }
	local cards: { Card } = {}
	for _, item in input.view.tools or input.land.tools do
		local card: Card = {
			id = `tool.{item.id}`,
			icon = `tool.{item.id}`,
			title = input.t(item.textKey),
			info = input.t(item.textKey .. ".info"),
			state = "locked",
		}
		if item.owned then
			card.state = "owned"
			card.status = input.t("market.owned")
		elseif not item.revealed then
			card.status = input.t("market.notYet")
		else
			card.state = if item.buyable then "affordable" else "short"
			card.price = price(input, item.price)
			card.button = buy(input, item.buyable, "BuyTool", { tool = item.id })
		end
		table.insert(cards, card)
	end
	return cards
end

-- One card per permanent node and spark item (view.sparks.items): name, price in sparks, the effect line, owned or Buy.
-- The spark packs for Robux follow at the bottom.
local function sparkCards(input: Input): { Card }
	local cards: { Card } = {}
	local sparks = input.view.sparks
	if sparks == nil then
		return cards
	end
	for _, item in sparks.items do
		local card: Card = {
			id = item.id,
			icon = "spark",
			title = `{item.id} {input.t(`perm.{item.id}.name`)}`,
			info = input.t(`perm.{item.id}.info`),
			state = "short",
		}
		if item.owned then
			card.state = "owned"
			card.status = input.t("reason.bought")
		else
			card.state = if item.buyable then "affordable" else "short"
			card.price = input.t("market.sparkPrice", { cost = item.sparks })
			card.button = buy(input, item.buyable, "BuyNode", { node = item.id })
		end
		table.insert(cards, card)
	end
	for _, card in robuxCards(input, true) do
		table.insert(cards, card)
	end
	return cards
end

-- Production tab: what the plants make now and how the number comes about (info only, no buttons).
local function productionCards(input: Input): { Card }
	local cards: { Card } = {}
	local production = input.view.production
	if production == nil then
		return cards
	end
	table.insert(cards, {
		id = "production.total",
		icon = "spark",
		title = input.t("production.total", { rate = ShopView.short(production.total) }),
		info = input.t("production.grid", { grid = string.format("%.2f", production.grid) }),
		state = "idle",
	})
	for _, row in production.rows do
		if row.count > 0 then
			table.insert(cards, {
				id = `production.{row.id}`,
				icon = `plant.{row.id}`,
				title = input.t(`plant.{row.id}`),
				info = input.t("production.row", {
					count = string.format("%.4g", row.effective),
					power = string.format("%.4g", row.nominal),
					mult = string.format("%.4g", row.multiplier),
					factor = string.format("%.2f", row.factor),
				}),
				status = input.t("production.output", { rate = ShopView.short(row.output) }),
				state = "idle",
			})
		end
	end
	return cards
end

-- Extras tab: one card per Robux offer with a fetched price (`input.offers`; the others are not listed). A pass already
-- owned says so in green; a booster that does not fit the queue and a Time Skip over the daily limit have no button.
-- A spark pack is offered from grid stage 1 on, and only while the sparks still missing cover it.
function robuxCards(input: Input, packsOnly: boolean): { Card }
	local cards: { Card } = {}
	local facts = input.extras
	if facts == nil or facts.shown ~= true then
		return cards
	end
	local t = input.t
	for _, entry in input.offers or {} do
		local offer = findOffer(input.shop, entry.id)
		if offer ~= nil and offer.plant ~= nil then
			continue -- a permanent plant is sold on its plant card
		end
		local pack = offer ~= nil and offer.sparks ~= nil
		if pack and not ((facts.level or 0) >= 1 and (facts.sparksMissing or 0) >= offer.sparks) then
			continue
		end
		if packsOnly and not pack then
			continue
		end
		local card: Card = {
			id = `offer.{entry.id}`,
			icon = `offer.{entry.type}`,
			title = entry.name,
			info = t(`offer.{entry.id}.info`, { coins = ShopView.short(math.floor(input.skipCoins or 0)) }),
			state = "extra",
			extra = true,
		}
		local view = { text = t("extras.view"), enabled = true, offer = entry.id } :: Button
		if entry.type == "pass" and facts.owned[entry.id] == true then
			card.state = "owned"
			card.status = t("extras.owned")
		elseif offer ~= nil and offer.queued and facts.stock + offer.seconds > input.shop.boosterStockSeconds then
			card.status = t("extras.stockFull")
		elseif offer ~= nil and offer.daily and facts.skipsLeft ~= nil and facts.skipsLeft < 1 then
			card.status = t("extras.limit")
		else
			card.price = t("extras.price", { price = math.floor(entry.price + 0.5) })
			card.button = view
		end
		table.insert(cards, card)
	end
	return cards
end

local function extrasCards(input: Input): { Card }
	return robuxCards(input, false)
end

local BUILDERS: { [string]: (Input) -> { Card } } = {
	plants = plantCards,
	upgrades = upgradeCards,
	storage = storageCards,
	tools = toolCards,
	sparks = sparkCards,
	production = productionCards,
	extras = extrasCards,
}

-- The cards of `tab` for the server's view; an unknown tab or a missing view has no cards.
function ShopView.cards(tab: string, input: Input): { Card }
	local builder = BUILDERS[tab]
	if builder == nil or input.view == nil then
		return {}
	end
	return builder(input)
end

return ShopView
