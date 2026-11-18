--!strict
-- Tool belt: the carried tools follow the land, a step counts only with its own tool in the hand, every tool has a model.
return function(t, load)
	local Land = load("Config/Land")
	local Tools = load("Config/Tools")
	local Locale = load("Config/Locale")
	local Toolbelt = load("Core/Toolbelt")

	local land = { tools = { scythe = true, shovel = true }, sites = {} }
	t.equal(table.concat(Toolbelt.owned(Land.start, Land), ","), "scythe", "a fresh player carries the scythe")
	t.equal(table.concat(Toolbelt.owned(land, Land), ","), "scythe,shovel", "a bought tool joins the belt")

	t.truthy(Toolbelt.inHand(land, 1, "scythe", Land), "mowing works with the scythe in the hand")
	t.truthy(not Toolbelt.inHand(land, 1, nil, Land), "mowing needs a tool in the hand")
	t.truthy(not Toolbelt.inHand(land, 1, "shovel", Land), "the shovel does not mow")
	t.truthy(not Toolbelt.inHand(land, 3, "hammer", Land), "a tool in the hand that is not owned does not count")

	-- A field step needs the tool of its next stage; the hammer never mows.
	local working = {
		tools = { scythe = true, hammer = true, drum = true },
		sites = { 0, 0, 0, 0, 1, 0 },
		cells = { {}, {}, { 4 }, {}, { 2, 7 }, {} },
		steps = { {}, {}, { 1 }, {}, { 3, 1 }, {} },
	}
	t.truthy(
		not Toolbelt.inHand(working, 3, "hammer", Land, 9),
		"a new house lot is mown with the scythe, not the hammer"
	)
	t.truthy(Toolbelt.inHand(working, 3, "scythe", Land, 9), "a new house lot is mown with the scythe")
	t.truthy(Toolbelt.inHand(working, 3, "hammer", Land, 4), "the mown lot takes the hammer")
	t.truthy(not Toolbelt.inHand(working, 3, "scythe", Land, 4), "the mown lot no longer takes the scythe")
	t.truthy(Toolbelt.inHand(working, 5, "hammer", Land, 7), "the farm cell takes the hammer for its fence")
	t.truthy(Toolbelt.inHand(working, 5, "hammer", Land), "without a cell the first cell in work decides")
	t.truthy(not Toolbelt.inHand(working, 5, "drum", Land, 7), "the drum waits for the fence")
	t.truthy(not Toolbelt.inHand(working, 5, "drum", Land, 2), "a prepared cell takes no tool")
	local stage, stageTool, hold = Toolbelt.stage(working, 5, 7, Land)
	t.truthy(stage == 2 and stageTool == "hammer" and hold == 2.5, "stage 2 of the farm is the hammer for 2.5 seconds")
	local _, houseTool, houseHold = Toolbelt.stage(working, 3, 4, Land)
	t.truthy(houseTool == "hammer" and houseHold == Land.chains[3][2].hold, "the mown lot takes the hold of the hammer")
	local _, lotTool, lotHold = Toolbelt.stage(working, 3, 9, Land)
	t.truthy(lotTool == "scythe" and lotHold == Land.chains[3][1].hold, "a new lot takes the hold of the scythe")
	t.equal(Toolbelt.stage(working, 6, nil, Land), 1, "a new wind pad starts at stage 1")
	t.truthy(not Toolbelt.inHand(land, 7, "scythe", Land), "an unknown field is never worked")
	-- The action text of a field step names the tool in the hand; every field tool has one, the drum lays cable
	local expectedKeys = {
		scythe = "prompt.mow",
		shovel = "prompt.dig",
		wrench = "prompt.anchor",
		drum = "prompt.cable",
		tamper = "prompt.compact",
	}
	for _, tool in Land.fieldTools do
		if tool ~= "hammer" then
			t.equal(Toolbelt.actionKey(5, tool), expectedKeys[tool], `{tool}: action text`)
		end
	end
	t.equal(Toolbelt.actionKey(3, "hammer"), "prompt.house", "the hammer builds the house on a lot")
	t.equal(Toolbelt.actionKey(5, "hammer"), "prompt.fence", "the hammer builds the fence on the farm")
	t.truthy(Toolbelt.actionKey(5, "pliers") == nil, "a tool that is no field stage has no action text")
	t.truthy(Toolbelt.inHand(land, "container", nil, Land), "the container needs no tool")
	t.truthy(not Toolbelt.inHand(land, "wired", "scythe", Land), "wiring needs the pliers")

	for _, tool in Land.tools do
		local model = Tools[tool.id]
		t.truthy(model ~= nil and #model.parts >= 2, `{tool.id} has a model of at least two parts`)
		local handle = model.parts[1]
		t.truthy(handle.at[1] == 0 and handle.at[2] == 0 and handle.at[3] == 0, `{tool.id}: the handle is the origin`)
		t.truthy(math.abs(model.grip) <= handle.size[2] / 2, `{tool.id}: the hand holds the handle`)
		for _, lang in { "en", "de" } do
			t.truthy(Locale.t(tool.textKey, lang) ~= tool.textKey, `{tool.id} has a name in {lang}`)
			t.truthy(Locale.t(tool.textKey .. ".info", lang) ~= tool.textKey .. ".info", `{tool.id}: tooltip in {lang}`)
		end
	end
end
