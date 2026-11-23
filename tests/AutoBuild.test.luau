--!strict
-- Smart Hub auto-build (Bauplan.md, section on rules and passes): the switch and coin reserve (rule "autobuild"),
-- the shortest payback among the plants the coins cover, and the reserve that must stay.
return function(t, load)
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Config = {
		plants = load("Config/Plants"),
		upgrades = load("Config/Upgrades"),
		prestige = load("Config/Prestige"),
		phases = load("Config/Phases"),
		weathers = load("Config/Weather"),
		effects = load("Config/Effects"),
	}
	local function env(owner: boolean)
		return {
			phase = Config.phases[2],
			weather = Config.weathers[1],
			longMeter = false,
			config = Config,
			formulas = Formulas,
			autoBuild = owner,
		}
	end
	local function fresh(coins: number, plants: { number }, rule: { [string]: any }?): { [string]: any }
		local state: { [string]: any } = { v = 1, coins = coins, runEarned = 0, lifetimeEarned = 0, sparks = 0 }
		state.level = 0
		state.sparksSpent = 0
		state.plants = plants
		state.nodes = {}
		state.pnodes = {}
		state.storage = { charge = 0, mode = "auto" }
		state.rules = { autobuild = rule }
		return state
	end
	local on = { th = 0, on = true }

	-- The setting: owners only, no Regelzentrale needed, in tenths up to 90 %.
	local blank = fresh(0, { 0, 0, 0, 0, 0, 0 })
	local _, deniedOk = GameCore.apply(blank, { type = "SetRule", rule = "autobuild", th = 0.5, on = true }, env(false))
	t.equal(deniedOk, false, "without the Smart Hub the setting is refused")
	local set, setOk = GameCore.apply(blank, { type = "SetRule", rule = "autobuild", th = 0.97, on = true }, env(true))
	t.truthy(setOk, "an owner sets it without U21")
	t.equal(set.rules.autobuild.th, 0.9, "the reserve stops at 90 %")
	t.equal(GameCore.view(blank, env(true)).storage.autoBuild.th, 0.2, "the reserve starts at 20 %")
	t.equal(GameCore.view(blank, env(true)).storage.autoBuild.on, false, "the switch starts off")
	t.equal(GameCore.view(blank, env(false)).storage.autoBuild, nil, "non-owners see no auto-build setting")

	-- Off or not owned: nothing is bought.
	local _, offOk =
		GameCore.apply(fresh(1000, { 1, 0, 0, 0, 0, 0 }, { th = 0, on = false }), { type = "AutoBuild" }, env(true))
	t.equal(offOk, false, "switched off it buys nothing")
	local _, freeOk = GameCore.apply(fresh(1000, { 1, 0, 0, 0, 0, 0 }, on), { type = "AutoBuild" }, env(false))
	t.equal(freeOk, false, "without the pass it buys nothing")

	-- The shortest payback wins, not the dearest plant: panels are cheap per energy at first, the wheel when they are many.
	local early, earlyOk = GameCore.apply(fresh(1000, { 1, 0, 0, 0, 0, 0 }, on), { type = "AutoBuild" }, env(true))
	t.truthy(earlyOk, "it buys")
	t.equal(early.plants[1], 2, "with few panels the next panel pays back first")
	t.equal(early.plants[2], 0, "and the dearer wheel is skipped")
	local late = fresh(1000, { 30, 0, 0, 0, 0, 0 }, on)
	local lateAfter = GameCore.apply(late, { type = "AutoBuild" }, env(true))
	t.equal(lateAfter.plants[2], 1, "with many panels the wheel pays back first")
	t.equal(lateAfter.plants[1], 30, "and the panel count stays")

	-- The reserve: coins after the purchase stay at or above the share of the coins before.
	local _, keptOk =
		GameCore.apply(fresh(100, { 1, 0, 0, 0, 0, 0 }, { th = 0.9, on = true }), { type = "AutoBuild" }, env(true))
	t.equal(keptOk, false, "100 coins with a 90 % reserve cannot pay 15")
	local _, allowedOk =
		GameCore.apply(fresh(100, { 1, 0, 0, 0, 0, 0 }, { th = 0.8, on = true }), { type = "AutoBuild" }, env(true))
	t.truthy(allowedOk, "a purchase that leaves exactly 80 % of the coins or more is allowed")

	-- A plant the coins do not cover is not a candidate.
	local poor, poorOk = GameCore.apply(fresh(18, { 1, 0, 0, 0, 0, 0 }, on), { type = "AutoBuild" }, env(true))
	t.truthy(poorOk, "18 coins buy a panel")
	t.equal(poor.plants[2], 0, "never a plant that costs more than the coins")

	-- Auto storage mode needs a storage rule: the auto-build switch alone does not count.
	local only = fresh(0, { 0, 0, 0, 0, 0, 0 }, on)
	only.nodes.U17 = true
	only.nodes.U21 = true
	only.storage.mode = "charge"
	local _, onlyOk = GameCore.apply(only, { type = "SetStorageMode", mode = "auto" }, env(true))
	t.equal(onlyOk, false, "auto-build on only: Auto storage is refused")
	only.rules.charge = { th = 0.7, on = true }
	local _, chargeOk = GameCore.apply(only, { type = "SetStorageMode", mode = "auto" }, env(true))
	t.truthy(chargeOk, "with a charge rule on, Auto is allowed")

	-- The server tries at most every 2 seconds.
	t.truthy(GameCore.autoBuildDue(nil, 5, 2), "the first try is due")
	t.equal(GameCore.autoBuildDue(10, 11.9, 2), false, "not before the 2 seconds")
	t.truthy(GameCore.autoBuildDue(10, 12, 2), "due after 2 seconds")

	-- An expansion without P5 drops the rules but keeps the auto-build setting; with P5 everything stays.
	local run = fresh(5000, { 5, 0, 0, 0, 0, 0 }, { th = 0.4, on = true })
	run.rules.charge = { th = 0.7, on = true }
	run.runEarned = 10000000
	run.nodes.U21 = true
	local expanded, expandOk = GameCore.apply(run, { type = "Prestige" }, env(true))
	t.truthy(expandOk, "the expansion works")
	t.equal(expanded.rules.charge, nil, "without P5 the charge rule is gone")
	t.equal(expanded.rules.autobuild.th, 0.4, "the auto-build setting stays")
end
