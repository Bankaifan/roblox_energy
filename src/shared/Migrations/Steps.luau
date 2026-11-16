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

return Steps
