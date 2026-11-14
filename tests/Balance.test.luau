--!strict
-- Balance bots (sim/Sim) on GameCore: the same seed gives the same economy, and the bots keep the rules.
return function(t)
	local Sim = require("../sim/Sim")

	local first, _ = Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 600, Sim.record())
	local again, _ = Sim.play(Sim.BOTS.optimal, Sim.fresh(), 1, 0, 600, Sim.record())
	t.equal(first.coins, again.coins, "same seed gives the same ten minutes")
	t.truthy(first.plants[1] >= 1, "the optimal bot owns a balcony module within ten minutes")
	t.truthy(first.coins >= 0, "coins never go negative")

	local stage4 = Sim.withStorage(first, 4)
	t.truthy(stage4.nodes.U20 == true and stage4.nodes.U22 == nil, "stage 4 is U17 to U20 without U22")
	t.truthy(stage4.rules[1].id == "charge" and stage4.rules[2].th == 1.2, "stage 1 and up come with the two rules")
	t.truthy(Sim.withStorage(first, 0).nodes.U17 == nil, "stage 0 has no storage")
end
