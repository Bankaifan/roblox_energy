--!strict
-- Market popup contents (design 0018, R1): for one tab, the list of cards the popup draws. Pure Luau, no Roblox APIs.
-- A card is plain data: icon id, title, info, price, status, state and at most one button. The popup only paints it and
-- sends the button's message; the server checks every message again. Texts come from the `t` function the caller gives.
local ShopView = {}

export type Button = { text: string, enabled: boolean, remote: string?, payload: any?, tab: string? }
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
}
export type Input = {
	view: any,
	coins: number,
	plants: any,
	upgrades: any,
	land: any,
	t: (key: string, args: { [string]: any }?) -> string,
}

-- The tabs in order, each with its Locale keys for the tab button and the one-line explanation under the tab row.
ShopView.tabs = {
	{ id = "plants", key = "tab.plants", hint = "market.hint.plants" },
	{ id = "upgrades", key = "tab.upgrades", hint = "market.hint.upgrades" },
	{ id = "storage", key = "tab.storage", hint = "market.hint.storage" },
	{ id = "tools", key = "tab.tools", hint = "market.hint.tools" },
}
ShopView.STORAGE_MODES = { "charge", "sell", "auto" }
-- Placeholder rule thresholds: charge while the price factor is at most 0.8, sell while it is at least 1.2.
ShopView.CHARGE_BELOW = 0.8
ShopView.SELL_ABOVE = 1.2

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

local function buy(input: Input, enabled: boolean, remote: string, payload: any): Button
	return { text = input.t("action.buy"), enabled = enabled, remote = remote, payload = payload }
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
		if item.needsSite == true then
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
			card.button = buy(input, affordable, "Prepare", { target = "container" })
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
		elseif stored.mode == mode then
			card.state = "active"
			card.status = t("market.active")
		else
			card.button =
				{ text = t("market.select"), enabled = true, remote = "SetStorageMode", payload = { mode = mode } }
		end
		table.insert(cards, card)
	end
	if stored.ruleSlots < 1 then
		table.insert(
			cards,
			{ id = "rules", icon = "rule", title = t("rules.title"), info = t("rules.locked"), state = "locked" }
		)
		return cards
	end
	-- Per owned rule slot: what it holds (with its on/off switch), then the two rules it can be set to.
	for slot = 1, stored.ruleSlots do
		local rule = stored.rules[slot]
		local status: Card = {
			id = `rule.{slot}`,
			icon = "rule",
			title = t("rules.title"),
			info = t("rule.empty", { slot = slot }),
			state = "idle",
		}
		if rule ~= nil then
			status.info = t("rule.status", {
				slot = slot,
				rule = t("rule." .. rule.id),
				threshold = rule.th,
				state = t(if rule.on then "state.on" else "state.off"),
			})
			status.state = if rule.on then "active" else "idle"
			status.button = {
				text = t("market.toggle"),
				enabled = true,
				remote = "SetRule",
				payload = { slot = slot, rule = rule.id, th = rule.th, on = not rule.on },
			}
		end
		table.insert(cards, status)
		local options = {
			{ id = "charge", key = "rule.slotCharge", th = ShopView.CHARGE_BELOW },
			{ id = "sell", key = "rule.slotSell", th = ShopView.SELL_ABOVE },
		}
		for _, option in options do
			table.insert(cards, {
				id = `rule.{slot}.{option.id}`,
				icon = `mode.{option.id}`,
				title = t("rule." .. option.id),
				info = t(option.key, { slot = slot, threshold = option.th }),
				state = "idle",
				button = {
					text = t("market.set"),
					enabled = true,
					remote = "SetRule",
					payload = { slot = slot, rule = option.id, th = option.th, on = true },
				},
			})
		end
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

local BUILDERS: { [string]: (Input) -> { Card } } = {
	plants = plantCards,
	upgrades = upgradeCards,
	storage = storageCards,
	tools = toolCards,
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
