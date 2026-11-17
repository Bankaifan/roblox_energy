--!strict
-- Migrations (Bauplan.md, "Datenmodell"): Steps[n] lifts a profile from version n to n+1 and returns it.
-- Core/Data.migrate runs the missing steps in order, then fills new fields from the template.
local Steps: { [number]: (any) -> any } = {}

-- Version 1 to 2 (Bauplan section 4, the shop): the granted founder pass becomes an owned pass, the daily Time Skip
-- counter moves to `daily`. No version 1 code wrote a booster, so the booster queue starts empty. `grants` is dropped
-- by Core/Data.reconcile, because it is no longer in the template.
Steps[1] = function(profile: any): any
	local grants = if type(profile.grants) == "table" then profile.grants else {}
	profile.passes = { founder = grants.founder == true }
	profile.daily = { day = grants.skipDay, skips = grants.skipCount }
	profile.boosters = {}
	return profile
end

-- Version 2 to 3 (docs/land-development-design.md, section 5): a profile that has earned coins gets the land of the
-- old game: the first row of every field, every tool except the rails, market, container, and the wiring if U21 is
-- owned. A fresh profile (nothing earned) gets the template from Core/Data.reconcile. The numbers are literal on
-- purpose, so the step never changes when the land config does.
Steps[2] = function(profile: any): any
	if type(profile.lifetimeEarned) == "number" and profile.lifetimeEarned > 0 then
		local nodes = if type(profile.nodes) == "table" then profile.nodes else {}
		profile.land = {
			sites = { 4, 4, 4, 4, 4, 4 },
			tools = {
				scythe = true,
				shovel = true,
				hammer = true,
				wrench = true,
				drum = true,
				tamper = true,
				pliers = true,
			},
			container = true,
			wired = nodes.U21 == true,
			market = true,
		}
	end
	return profile
end

-- Threshold ranges of version 4 (a migration stays as it was written, so these are not read from Config).
local RANGES = { charge = { min = 0.3, max = 1 }, sell = { min = 1, max = 2 } }

-- Version 3 -> 4: the rules were kept in slots ("1", "2", "3" -> { id, th, on }); now each rule exists once, keyed by
-- its id ("charge", "sell" -> { th, on }). When two slots held the same rule, a switched-on one wins, else the lower slot.
-- The threshold is rounded to a tenth and clamped into the range of its rule; a slot with an unknown id is dropped.
Steps[3] = function(profile: any): any
	local rules: { [string]: any } = {}
	local slots: { number } = {}
	if type(profile.rules) == "table" then
		for key in profile.rules do
			local slot = tonumber(key)
			if slot ~= nil then
				table.insert(slots, slot)
			end
		end
	end
	table.sort(slots)
	for _, slot in slots do
		local old = profile.rules[tostring(slot)]
		if old == nil then
			old = profile.rules[slot]
		end
		local range = if type(old) == "table" then RANGES[old.id] else nil
		if range ~= nil and type(old.th) == "number" and old.th == old.th and type(old.on) == "boolean" then
			local kept = rules[old.id]
			if kept == nil or (old.on and not kept.on) then
				local tenths = math.floor(old.th * 10 + 0.5) / 10
				rules[old.id] = { th = math.max(range.min, math.min(range.max, tenths)), on = old.on }
			end
		end
	end
	profile.rules = rules
	return profile
end

-- Version 4 -> 5 (docs/land-development-design-v2.md, section 10): cells get stages (`land.steps`) and every field holds
-- units per cell. Per field n = min(max(old sites, ceil(owned / capacity)), cell count); cells 1..n are prepared with every
-- stage done (the river: its first n segments), so no old profile owns more units than its ground carries. The numbers
-- are literal on purpose, so the step never changes when the land config does.
local CAPACITY = { 4, 16, 16, 16, 25, 25 }
local CELLS = { 25, 7, 7, 7, 4, 4 }
local STAGES = { 1, 2, 2, 2, 3, 3 }
Steps[4] = function(profile: any): any
	local land = profile.land
	if type(land) ~= "table" then
		return profile
	end
	local sites, cells, steps = {}, {}, {}
	for field = 1, 6 do
		local owned = if type(profile.plants) == "table" and type(profile.plants[field]) == "number"
			then profile.plants[field]
			else 0
		local old = if type(land.sites) == "table" and type(land.sites[field]) == "number" then land.sites[field] else 0
		local n = math.min(math.max(math.floor(old), math.ceil(owned / CAPACITY[field])), CELLS[field])
		local list, done, used = {}, {}, {}
		local saved = if type(land.cells) == "table" and type(land.cells[field]) == "table"
			then land.cells[field]
			else {}
		if field ~= 2 then
			for _, cell in saved do
				if
					#list < n
					and type(cell) == "number"
					and cell % 1 == 0
					and cell >= 1
					and cell <= CELLS[field]
					and not used[cell]
				then
					used[cell] = true
					table.insert(list, cell)
				end
			end
		end
		local free = 1
		while #list < n do
			if not used[free] then
				used[free] = true
				table.insert(list, free)
			end
			free += 1
		end
		for _ = 1, n do
			table.insert(done, STAGES[field])
		end
		sites[field], cells[field], steps[field] = n, list, done
	end
	land.sites, land.cells, land.steps = sites, cells, steps
	return profile
end

-- Version 5 -> 6 (issue #71): the tutorial starts at its first step. A profile that has earned coins has played past it,
-- so the tutorial is marked done and never shown again; a new profile still gets it.
Steps[5] = function(profile: any): any
	profile.tutorial = 1
	profile.tutorialDone = type(profile.lifetimeEarned) == "number" and profile.lifetimeEarned > 0
	return profile
end

-- Version 6 -> 7: the profile gets `paint` (the colour of S5 Sign Paint, 0 = none) and spark items may appear in
-- `pnodes`. Nothing to convert: Core/Data.reconcile fills `paint` from the template.
Steps[6] = function(profile: any): any
	return profile
end

return Steps
