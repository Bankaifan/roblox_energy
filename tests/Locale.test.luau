--!strict
-- Locale tables (Bauplan.md, section 3): both languages have the same keys, no text is empty, placeholders match,
-- every plant, node, weather, phase and rule has a text in both languages, the German names are the Bauplan names,
-- and Locale.t fills, falls back and resolve picks the language.
return function(t, load)
	local Locale = load("Config/Locale")
	local Plants = load("Config/Plants")
	local Phases = load("Config/Phases")
	local Weather = load("Config/Weather")
	local Upgrades = load("Config/Upgrades")

	local en = Locale.tables.en
	local de = Locale.tables.de

	local function keysOf(dictionary: { [string]: string }): { string }
		local keys = {}
		for key in dictionary do
			table.insert(keys, key)
		end
		table.sort(keys)
		return keys
	end

	local function placeholdersOf(text: string): string
		local names = {}
		for name in string.gmatch(text, "{(%w+)}") do
			table.insert(names, name)
		end
		table.sort(names)
		return table.concat(names, ",")
	end

	local function hasBoth(key: string)
		t.truthy(en[key] ~= nil and de[key] ~= nil, `{key}: text in both languages`)
	end

	-- Identical key sets
	local enKeys = keysOf(en)
	for _, key in enKeys do
		t.truthy(de[key] ~= nil, `{key}: missing in German`)
	end
	for _, key in keysOf(de) do
		t.truthy(en[key] ~= nil, `{key}: missing in English`)
	end

	-- No empty strings
	for _, dictionary in { en, de } do
		for key, text in dictionary do
			t.truthy(type(text) == "string" and text ~= "", `{key}: empty text`)
		end
	end

	-- Placeholders in both languages are the same
	for _, key in enKeys do
		t.equal(placeholdersOf(de[key]), placeholdersOf(en[key]), `{key}: placeholders differ`)
	end

	-- Every Config entry the HUD shows has a text in both languages
	for _, plant in Plants do
		hasBoth(`plant.{plant.id}`)
	end
	for _, phase in Phases do
		hasBoth(`phase.{phase.id}`)
	end
	for _, weather in Weather do
		hasBoth(`weather.{weather.id}`)
	end
	for _, node in Upgrades.run do
		hasBoth(`node.{node.id}.name`)
		hasBoth(`node.{node.id}.info`)
	end
	for _, list in { Upgrades.permanent, Upgrades.spark } do
		for _, node in list do
			hasBoth(`perm.{node.id}.name`)
			hasBoth(`perm.{node.id}.info`)
			t.equal(en[`perm.{node.id}.info`], node.info, `{node.id}: English info matches the config`)
		end
	end
	for _, key in { "tab.sparks", "market.hint.sparks", "market.sparkPrice" } do
		hasBoth(key)
	end
	for _, key in { "mode.charge", "mode.sell", "mode.auto", "rule.charge", "rule.sell" } do
		hasBoth(key)
	end

	-- German names exactly as in the Bauplan tables: plants (section 3), upgrade nodes (section 2), weather (section 2)
	local germanPlants = { "Balkonmodul", "Wasserrad", "Dach-PV", "Kleinwindrad", "Solarpark", "Windrad" }
	for index, name in germanPlants do
		t.equal(de[`plant.{index}`], name, `plant {index} German name`)
	end
	local germanNodes = {
		"Saubere Module",
		"Kugellager",
		"Nachführung",
		"Leichtbau-Flügel",
		"Putzroboter",
		"Getriebelos",
		"Doppelglas-Module",
		"Höhere Türme",
		"Netzverstärkung I",
		"Netzverstärkung II",
		"Netzverstärkung III",
		"Kurbel-Übersetzung",
		"Schwungrad",
		"Direktvermarktung",
		"Börsenzugang",
		"Spitzenlast-Vertrag",
		"Heimspeicher",
		"Speicher-Erweiterung",
		"Quartierspeicher",
		"Großspeicher",
		"Regelzentrale",
		"Neue Zellchemie",
	}
	for index, node in Upgrades.run do
		t.equal(de[`node.{node.id}.name`], germanNodes[index], `{node.id} German name`)
	end
	local germanWeather = {
		Sonnig = "Sonnig",
		Bewoelkt = "Bewölkt",
		Windig = "Windig",
		Gewitter = "Gewitter",
		Flaute = "Flaute",
	}
	for _, weather in Weather do
		t.equal(de[`weather.{weather.id}`], germanWeather[weather.id], `weather {weather.id} German name`)
	end

	-- Land, tools and popups (Bauplan 0018, section 4): every prompt, tab, tool name, tool line and hint has a text in both
	-- languages, and each text fits on one line of at most 60 characters
	local landKeys = {
		"tab.plants",
		"tab.upgrades",
		"tab.storage",
		"tab.tools",
		"prompt.market",
		"prompt.control",
		"prompt.mow",
		"prompt.dig",
		"prompt.house",
		"prompt.anchor",
		"prompt.fence",
		"prompt.cable",
		"prompt.compact",
		"prompt.wire",
		"tool.hand",
		"tool.scythe",
		"tool.rails",
		"tool.shovel",
		"tool.hammer",
		"tool.wrench",
		"tool.cableDrum",
		"tool.tamper",
		"tool.container",
		"tool.pliers",
		"tool.hand.info",
		"tool.scythe.info",
		"tool.rails.info",
		"tool.shovel.info",
		"tool.hammer.info",
		"tool.wrench.info",
		"tool.cableDrum.info",
		"tool.tamper.info",
		"tool.container.info",
		"tool.pliers.info",
		"hint.noSite",
	}
	for _, key in landKeys do
		hasBoth(key)
		for _, dictionary in { en, de } do
			local text = dictionary[key] or ""
			t.truthy(text ~= "" and (utf8.len(text) or 99) <= 60, `{key}: one line of at most 60 characters`)
		end
	end

	-- Locale.t fills placeholders, keeps unknown ones visible, and falls back to English and to the key
	t.equal(Locale.t("hud.coins", "de", { value = "5" }), "Coins 5", "fills a placeholder")
	t.equal(
		Locale.t("rule.chargeStatus", "en", { threshold = 0.8, state = "on" }),
		"Charges below price 0.8, on",
		"fills several placeholders, numbers included"
	)
	t.equal(Locale.t("mode.autoNeedsRule", "en"), "Auto needs a rule", "the Auto hint")
	t.equal(Locale.t("rules.title", "de"), "Regelautomatik", "the rules section is Regelautomatik")
	t.equal(Locale.t("rule.slotCharge", "en"), "rule.slotCharge", "the slot labels are gone")
	t.equal(Locale.t("hud.coins", "en"), "Coins {value}", "a missing argument stays visible")
	t.equal(Locale.t("plant.1", "fr"), "Balcony Panel", "an unknown language falls back to English")
	t.equal(Locale.t("no.such.key", "de"), "no.such.key", "an unknown key is returned as it is")

	-- The language for a player's locale
	t.equal(Locale.resolve("de-de"), "de", "German locale")
	t.equal(Locale.resolve("de"), "de", "plain German")
	t.equal(Locale.resolve("en-us"), "en", "English locale")
	t.equal(Locale.resolve("fr-fr"), "en", "other locale falls back to English")
	t.equal(Locale.resolve(nil), "en", "no locale falls back to English")

	-- Tutorial v2: every key the presentation can return, plus the closing and skip texts, in both languages.
	local TutorialView = load("Core/TutorialView")
	local tutorialKeys = table.clone(TutorialView.KEYS)
	for _, key in { "tutorial.done", "tutorial.skip", "tutorial.skipConfirm" } do
		table.insert(tutorialKeys, key)
	end
	for _, key in tutorialKeys do
		t.truthy(en[key] ~= nil and de[key] ~= nil, `tutorial text {key} in both languages`)
	end
end
