--!strict
-- Purchase hint lines (Bauplan.md, section 4): which quiet hint line a screen shows, and the card that carries it. Pure
-- Luau: the caller passes the facts and Core/Hints.allowed (core modules do not require each other). A line is never a
-- pop-up; the Market draws it as a card at the end of its tab and its button leads to the Extras card of the offer.
local HintView = {}

export type Line = { hint: string, offer: string }
export type Facts = {
	-- The Extras facts of the server (Shop.extrasView): `shown` is false during the tutorial and before the first hint
	-- minute, `owned` holds the passes owned by offer id.
	extras: any,
	allowed: (hint: any, state: any, firstSeconds: number) -> boolean, -- Core/Hints.allowed
	firstSeconds: number, -- Config/Shop.firstHintSeconds
	storageBought: boolean,
	controlBought: boolean,
	gridLevel: number,
	offlineCapped: boolean,
	listed: { [string]: boolean }?, -- offers with a live price (Extras tab); nil: not checked (the welcome screen)
}

-- The four hints that have a line, with the offer their line leads to, in the order they show.
local OFFER: { [string]: string } = {
	founder = "founder",
	smartHub = "smart_hub",
	premium = "premium",
	longMeter = "long_meter",
}
local ORDER = { "founder", "smartHub", "premium", "longMeter" }
-- The place of Core/Hints each Market tab stands for: the Extras tab is the shop, the Storage tab holds the rules, the
-- Plants tab is the market terminal.
local PLACE: { [string]: string } = { extras = "shop", storage = "rules", plants = "market" }

-- The hint lines of `place` ("shop", "rules", "market" or "welcome"); none while the Extras facts are not shown.
function HintView.lines(place: string, facts: Facts): { Line }
	local lines: { Line } = {}
	local extras = facts.extras
	if extras == nil or extras.shown ~= true then
		return lines
	end
	local owned: { [string]: boolean } = {}
	for hint, offer in OFFER do
		owned[hint] = extras.owned[offer] == true
	end
	-- `shown` already holds the first hint minute and the end of the tutorial.
	local state = {
		place = place,
		playSeconds = facts.firstSeconds,
		storageBought = facts.storageBought,
		controlBought = facts.controlBought,
		gridLevel = facts.gridLevel,
		offlineCapped = facts.offlineCapped,
		owned = owned,
	}
	for _, hint in ORDER do
		local offer = OFFER[hint]
		if facts.allowed(hint, state, facts.firstSeconds) and (facts.listed == nil or facts.listed[offer] == true) then
			table.insert(lines, { hint = hint, offer = offer })
		end
	end
	return lines
end

-- The cards for `tab` (a ShopView card each, state "hint"): the line's text and, outside the Extras tab, a button to it.
function HintView.cards(tab: string, facts: Facts, t: (string, { [string]: any }?) -> string): { any }
	local cards = {}
	local place = PLACE[tab]
	if place == nil then
		return cards
	end
	for _, line in HintView.lines(place, facts) do
		local card: any =
			{ id = `hint.{line.hint}`, icon = "tab.extras", title = t(`hint.{line.hint}`), info = "", state = "hint" }
		if tab ~= "extras" then
			card.button = { text = t("extras.view"), enabled = true, tab = "extras" }
		end
		table.insert(cards, card)
	end
	return cards
end

return HintView
