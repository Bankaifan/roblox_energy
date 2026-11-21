--!strict
-- Balance bots (sim/Sim) on GameCore: the same seed gives the same economy, and the bots keep the rules.
return function(t)
	local Sim = require("../sim/Sim")

	local first, _ = Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 600, Sim.record())
	local again, _ = Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 600, Sim.record())
	t.equal(first.coins, again.coins, "same seed gives the same ten minutes")
	t.truthy(first.plants[1] >= 1, "the optimal bot owns a balcony module within ten minutes")
	t.truthy(first.coins >= 0, "coins never go negative")
	-- Land rules are on: the bot mows before the first panel and digs before the first water wheel.
	local early, _ = Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 120, Sim.record())
	t.truthy(early.plants[1] >= 1 and early.land.sites[1] >= 4, "a mown row and a panel within two minutes")
	t.truthy(early.plants[2] >= 1 and early.land.tools.shovel, "the shovel and a water wheel within two minutes")
	for index, owned in first.plants do
		t.truthy(owned == 0 or first.land.sites[index] >= 1, `plant {index} is only owned with a prepared site`)
	end

	-- Buyers: the shop factors reach the env, the cap holds, and the Time Skips pay out three times on day one.
	t.equal(Sim.BOTS.premium.buy.income, 1.5, "Premium Tariff: income x1.5")
	t.equal(Sim.BOTS.turbo.buy.income, 3, "Premium plus Turbo: income x3")
	t.truthy(Sim.FULL_STACK.income * Sim.FULL_STACK.boost <= 3, "all boosters together stay within x3")
	local record = Sim.record()
	Sim.play(Sim.BOTS.skips, Sim.fresh(), 1, 0, 2000, record)
	t.equal(record.skipped, 3, "three Time Skips on day one")
	local plain = Sim.record()
	Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 2000, plain)
	t.equal(plain.skipped, 0, "the optimal bot buys nothing")

	local stage4 = Sim.withStorage(first, 4)
	t.truthy(stage4.nodes.U20 == true and stage4.nodes.U22 == nil, "stage 4 is U17 to U20 without U22")
	t.truthy(stage4.rules.charge.on and stage4.rules.sell.th == 1.2, "stage 1 and up come with the two rules")
	t.truthy(Sim.withStorage(first, 0).nodes.U17 == nil, "stage 0 has no storage")
end
