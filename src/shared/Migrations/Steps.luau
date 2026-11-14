--!strict
-- Migrations (Bauplan.md, "Datenmodell, Version 1"): Steps[n] lifts a profile from version n to n+1 and returns it.
-- Core/Data.migrate runs the missing steps in order, then fills new fields from the template.
-- Version 1 is the first version, so there are no steps yet. When the version goes up, add Steps[1] here.
local Steps: { [number]: (any) -> any } = {}

return Steps
