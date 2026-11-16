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
	t.truthy(not Toolbelt.inHand(land, 7, "scythe", Land), "an unknown field is never worked")
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
