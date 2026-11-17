--!strict
-- Align (Mounting Rails): a held action on a mown panel cell; an aligned panel counts twice in the production, the real
-- count (milestones, prices) does not change.
return function(t, load)
	local GameCore = load("Core/GameCore")
	local Formulas = load("Core/Formulas")
	local Land = load("Config/Land")
	local Config: { [string]: any } = {}
	Config.plants = load("Config/Plants")
	Config.upgrades = load("Config/Upgrades")
	Config.prestige = load("Config/Prestige")
	Config.phases = load("Config/Phases")
	Config.weathers = load("Config/Weather")
	Config.effects = load("Config/Effects")
	Config.land = table.clone(Land)
	local env = {
		phase = Config.phases[2],
		weather = Config.weathers[1],
		longMeter = false,
		config = Config,
		formulas = Formulas,
	}

	local function state(panels: number, rails: boolean): { [string]: any }
		local land = table.clone(Land.start)
		land.tools = { scythe = true, rails = rails }
		land.sites = { 3, 0, 0, 0, 0, 0 }
		land.cells = { { 5, 2, 9 }, {}, {}, {}, {}, {} }
		land.steps = { { 1, 1, 1 }, {}, {}, {}, {}, {} }
		land.aligned = {}
		return {
			v = 1,
			coins = 0,
			runEarned = 0,
			lifetimeEarned = 0,
			sparks = 0,
			sparksSpent = 0,
			level = 0,
			plants = { panels, 0, 0, 0, 0, 0 },
			nodes = {},
			pnodes = {},
			storage = { charge = 0, mode = "auto" },
			rules = {},
			land = land,
		}
	end
	local function income(s: { [string]: any }): number
		return GameCore.tick(s, env, 1).coins
	end

	local _, noRails = GameCore.apply(state(3, false), { type = "Align", cell = 5 }, env)
	t.truthy(not noRails, "Align needs the Mounting Rails")
	local _, unmown = GameCore.apply(state(3, true), { type = "Align", cell = 7 }, env)
	t.truthy(not unmown, "Align needs a mown cell")
	local _, noPanel = GameCore.apply(state(1, true), { type = "Align", cell = 2 }, env)
	t.truthy(not noPanel, "a cell whose panel is not bought yet cannot be aligned")

	local base = income(state(3, true))
	local aligned, ok = GameCore.apply(state(3, true), { type = "Align", cell = 5 }, env)
	t.truthy(ok and aligned.land.aligned[1] == 5, "the named cell is aligned")
	local _, twice = GameCore.apply(aligned, { type = "Align", cell = 5 }, env)
	t.truthy(not twice, "a cell aligns once")
	t.truthy(math.abs(income(aligned) - base * 4 / 3) < 1e-6, "one aligned panel of three counts twice")
	t.equal(aligned.plants[1], 3, "the real count does not change")

	local first = GameCore.apply(state(3, true), { type = "Align" }, env)
	t.equal(first.land.aligned[1], 5, "without a cell the first mown cell is aligned")
end
