--!strict
-- Net (Bauplan.md, section 5): the 13 messages, the field checks of incoming messages and their limits.
return function(t, load)
	local Net = load("Net")

	local count = 0
	for _ in Net.messages do
		count += 1
	end
	t.equal(count, 13, "13 messages")

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

	local crankOk = Net.check("Crank", nil)
	t.truthy(crankOk, "Crank takes no fields")
	t.equal(Net.check("Snapshot", {}), false, "server messages are not accepted from clients")
	t.equal(Net.check("Unknown", {}), false, "unknown message names are rejected")

	local rulesOk, rule = Net.check("SetRule", { slot = 1, rule = "sell", th = 1.2, on = true })
	t.truthy(rulesOk, "a valid SetRule is accepted")
	t.equal(rule.th, 1.2, "threshold is kept")
	t.equal(Net.check("SetRule", { slot = 1, rule = "sell", th = 1.2, on = "yes" }), false, "on must be a boolean")

	local limit = Net.messages.BuyPlant.limit
	t.equal(limit.max, 8, "BuyPlant allows 8 per second")
	t.equal(Net.messages.Prestige.limit.per, 5, "Prestige allows one per 5 seconds")
end
