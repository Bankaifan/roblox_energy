--!strict
-- Purchase hints (Bauplan.md, section 4, 'Platz im Spielverlauf'): when each hint may show. Pure rules in Core/Hints,
-- the first hint minute from Config/Shop.
return function(t, load)
	local Hints = load("Core/Hints")
	local first = load("Config/Shop").firstHintSeconds

	local HINTS: { string } = { "founder", "smartHub", "premium", "vip", "longMeter" }
	local PLACE: { [string]: string } = {
		founder = "shop",
		smartHub = "rules",
		premium = "market",
		vip = "shop",
		longMeter = "welcome",
	}
	local PLACES: { string } = { "shop", "rules", "market", "welcome" }

	-- A state where every hint's fact holds, at the first hint minute. Each test changes only what it names.
	local BASE = {
		place = "shop",
		playSeconds = first,
		storageBought = true,
		controlBought = true,
		gridLevel = 2,
		offlineCapped = true,
		owned = {},
	}

	-- Whether `hint` may show in BASE with `changes` applied.
	local function shows(hint: string, changes: { [string]: any }): boolean
		local state: any = table.clone(BASE)
		for key, value in changes do
			state[key] = value
		end
		return Hints.allowed(hint, state, first)
	end

	-- Minute 12: the first hint minute is 720 seconds, and nothing shows before it for any hint.
	t.equal(first, 720, "the first hint minute is minute 12")
	for _, name in HINTS do
		local place = PLACE[name]
		t.truthy(shows(name, { place = place, playSeconds = first }), `{name} shows at minute 12`)
		t.truthy(not shows(name, { place = place, playSeconds = first - 1 }), `{name} waits one second more`)
		t.truthy(not shows(name, { place = place, playSeconds = 0 }), `{name} is blocked at the start`)
	end

	-- Owned passes never show their hint.
	for _, name in HINTS do
		t.truthy(not shows(name, { place = PLACE[name], owned = { [name] = true } }), `{name} is off once owned`)
	end

	-- Every hint shows in its own place and in no other.
	for _, name in HINTS do
		local place = PLACE[name]
		t.truthy(shows(name, { place = place }), `{name} shows in {place}`)
		for _, other in PLACES do
			if other ~= place then
				t.truthy(not shows(name, { place = other }), `{name} does not show in {other}`)
			end
		end
	end

	-- Founder Pack: after the storage is bought.
	t.truthy(not shows("founder", { storageBought = false }), "Founder Pack waits for the storage")
	t.truthy(shows("founder", { storageBought = true }), "Founder Pack shows after the storage")

	-- Smart Hub: in the rules menu, once U21 is bought.
	t.truthy(not shows("smartHub", { place = "rules", controlBought = false }), "Smart Hub waits for U21")
	t.truthy(shows("smartHub", { place = "rules", controlBought = true }), "Smart Hub shows in the rules menu")

	-- Premium: at the market terminal, after the first grid expansion (level 1).
	t.truthy(not shows("premium", { place = "market", gridLevel = 0 }), "Premium waits for the first expansion")
	t.truthy(shows("premium", { place = "market", gridLevel = 1 }), "Premium shows after the first expansion")

	-- VIP: in the shop from grid level 2.
	t.truthy(not shows("vip", { place = "shop", gridLevel = 1 }), "VIP waits for level 2")
	t.truthy(shows("vip", { place = "shop", gridLevel = 2 }), "VIP shows from level 2")

	-- Long Meter: a line on the welcome screen, only when the offline cap was reached.
	t.truthy(not shows("longMeter", { place = "welcome", offlineCapped = false }), "Long Meter waits for the cap")
	t.truthy(shows("longMeter", { place = "welcome", offlineCapped = true }), "Long Meter shows at the cap")
end
