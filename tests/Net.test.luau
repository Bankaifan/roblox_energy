--!strict
-- Net (Bauplan.md, section 5): the 14 messages, the field checks of incoming messages and their limits.
return function(t, load)
	local Net = load("Net")

	local count = 0
	for _ in Net.messages do
		count += 1
	end
	t.equal(count, 19, "19 messages")
	t.equal(Net.messages.RankList.direction, "server", "RankList comes from the server")
	t.truthy(Net.check("RankRequest", nil), "the leaderboard asks without fields")
	t.equal(Net.messages.RankRequest.limit.per, 4, "RankRequest allows one request per 4 seconds")
	t.equal(Net.messages.Welcome.direction, "server", "Welcome comes from the server")

	local ok, clean = Net.check("BuyPlant", { plant = 3, qty = "max", extra = "ignored" })
	t.truthy(ok, "a valid BuyPlant is accepted")
	t.equal(clean.plant, 3, "plant is kept")
	t.equal(clean.qty, "max", "qty max is kept")
	t.equal(clean.extra, nil, "unknown fields are dropped")
	t.equal(clean.type, "BuyPlant", "the clean payload names its message")

	t.equal(Net.check("BuyPlant", { plant = 1, qty = 5 }), false, "qty 5 is not allowed")
	t.equal(Net.check("BuyPlant", { plant = 1.5, qty = 1 }), false, "plant must be a whole number")
	t.equal(Net.check("BuyPlant", { plant = 0 / 0, qty = 1 }), false, "NaN is rejected")
	t.equal(Net.check("BuyPlant", nil), false, "a missing field is rejected")
	t.equal(Net.check("BuyPlant", "1"), false, "a non-table payload is rejected")

	local cellOk, cellMsg = Net.check("Prepare", { target = 1, cell = 7 })
	t.truthy(cellOk and cellMsg.cell == 7, "Prepare may name a cell")
	t.truthy(Net.check("Prepare", { target = "market" }), "the cell is optional")
	t.equal(Net.check("Prepare", { target = 1, cell = 1.5 }), false, "a named cell must be a whole number")
	local crankOk = Net.check("Crank", nil)
	t.truthy(crankOk, "Crank takes no fields")
	t.equal(Net.check("Snapshot", {}), false, "server messages are not accepted from clients")
	t.equal(Net.check("Unknown", {}), false, "unknown message names are rejected")

	local rulesOk, rule = Net.check("SetRule", { rule = "sell", th = 1.2, on = true })
	t.truthy(rulesOk, "a valid SetRule is accepted")
	t.equal(rule.th, 1.2, "threshold is kept")
	t.equal(Net.check("SetRule", { rule = "sell", th = 1.2, on = "yes" }), false, "on must be a boolean")
	t.equal(Net.check("SetRule", { rule = 1, th = 1.2, on = true }), false, "a rule is an id, not a slot")

	local toolOk, tool = Net.check("BuyTool", { tool = "shovel" })
	t.truthy(toolOk, "a valid BuyTool is accepted")
	t.equal(tool.tool, "shovel", "tool is kept")
	t.equal(Net.check("BuyTool", { tool = 5 }), false, "tool must be a string")
	t.equal(Net.check("BuyTool", {}), false, "tool is required")
	t.equal(Net.messages.BuyTool.direction, "client", "BuyTool is a client message")
	t.equal(Net.messages.BuyTool.limit.max, 4, "BuyTool allows 4 per second")

	t.equal(Net.messages.Prepare.direction, "internal", "Prepare never crosses the network")
	t.equal(Net.messages.Prepare.limit.max, 2, "Prepare allows 2 per second")
	local prepOk, prep = Net.check("Prepare", { target = 3 })
	t.truthy(prepOk, "the server path accepts a field target")
	t.equal(prep.type, "Prepare", "the clean payload names Prepare")
	t.truthy(Net.check("Prepare", { target = "container" }), "container is a target")
	t.equal(Net.check("Prepare", { target = 7 }), false, "field 7 does not exist")
	t.truthy(Net.check("BuyContainer", {}), "the container can be bought from the client")
	t.equal(Net.check("Prepare", { target = "x" }), false, "an unknown target is rejected")

	local limit = Net.messages.BuyPlant.limit
	t.equal(limit.max, 8, "BuyPlant allows 8 per second")
	t.equal(Net.messages.Prestige.limit.per, 5, "Prestige allows one per 5 seconds")
end
