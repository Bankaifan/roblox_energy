--!strict
-- Purchase hint lines (Bauplan.md, section 4): each line shows only when Core/Hints allows it and leads to its Extras card.
return function(t, load)
	local HintView = load("Core/HintView")
	local Hints = load("Core/Hints")
	local first = load("Config/Shop").firstHintSeconds

	-- Facts where every hint holds: the Extras tab shown, nothing owned, every offer listed.
	local function facts(changes: { [string]: any }?): any
		local base: any = {
			extras = { shown = true, owned = {} },
			allowed = Hints.allowed,
			firstSeconds = first,
			storageBought = true,
			controlBought = true,
			gridLevel = 1,
			offlineCapped = true,
			listed = { founder = true, smart_hub = true, premium = true, long_meter = true },
		}
		for key, value in changes or {} do
			base[key] = value
		end
		return base
	end
	local function key(text: string): string
		return text
	end
	local function names(place: string, changes: { [string]: any }?): string
		local out = {}
		for _, line in HintView.lines(place, facts(changes)) do
			table.insert(out, line.hint)
		end
		return table.concat(out, ",")
	end

	t.equal(names("shop"), "founder", "the Founder Pack line in the Extras tab")
	t.equal(names("rules"), "smartHub", "the Smart Hub line under the rules")
	t.equal(names("market"), "premium", "the Premium Tariff line after the first grid expansion")
	t.equal(names("welcome"), "longMeter", "the Long Meter line on the welcome screen")
	t.equal(HintView.lines("welcome", facts())[1].offer, "long_meter", "a line leads to its offer")

	-- No hint during the tutorial or before minute 12: the server's `shown` is false.
	t.equal(names("shop", { extras = { shown = false, owned = {} } }), "", "no hint while the Extras facts are hidden")
	-- Hints.allowed decides: a missing fact or an owned pass hides the line.
	t.equal(names("shop", { storageBought = false }), "", "no Founder hint before the storage")
	t.equal(names("market", { gridLevel = 0 }), "", "no Premium hint before the first grid expansion")
	t.equal(names("welcome", { offlineCapped = false }), "", "no Long Meter hint when the cap was not reached")
	t.equal(
		names("rules", { extras = { shown = true, owned = { smart_hub = true } } }),
		"",
		"no hint for an owned pass"
	)
	-- The line leads to an Extras card: an offer without a live price has no line.
	t.equal(names("shop", { listed = {} }), "", "no hint without its Extras card")
	local unchecked = facts()
	unchecked.listed = nil
	t.equal(#HintView.lines("welcome", unchecked), 1, "the welcome screen does not check the card list")

	-- Cards: the Extras tab line has no button, the others lead to the Extras tab; other tabs have none.
	local extrasCards = HintView.cards("extras", facts(), key)
	t.equal(#extrasCards, 1, "one hint card in the Extras tab")
	t.equal(extrasCards[1].state, "hint", "the hint card is a quiet line")
	t.equal(extrasCards[1].button, nil, "the Extras tab line has no button")
	t.equal(HintView.cards("storage", facts(), key)[1].button.tab, "extras", "the rules hint leads to the Extras tab")
	t.equal(HintView.cards("plants", facts(), key)[1].button.tab, "extras", "the market hint leads to the Extras tab")
	t.equal(#HintView.cards("tools", facts(), key), 0, "a tab without a place has no hint")
end
