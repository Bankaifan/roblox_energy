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

return Steps
