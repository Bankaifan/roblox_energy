--!strict
-- Save data (Bauplan.md, "Datenmodell, Version 1"). Pure: no DataStore, no Roblox APIs. A profile is what is saved;
-- fromState and toState map the fields of a run between the profile and the GameCore state (sections 2 and 5).
-- migrate takes the migration steps as an argument, because core modules do not require each other (see GameCore).
export type Profile = { [string]: any }
export type Steps = { [number]: (Profile) -> Profile }

local VERSION = 1
local MAX_PURCHASES = 100 -- the last 100 receipt IDs

-- The GameCore state fields a profile stores; the rest of the profile (lastSeen, grants, ...) belongs to the player.
local STATE_FIELDS = {
	"coins",
	"runEarned",
	"lifetimeEarned",
	"level",
	"sparks",
	"sparksSpent",
	"plants",
	"nodes",
	"pnodes",
	"storage",
	"rules",
}

local Data = {}
Data.VERSION = VERSION

-- The default profile, version 1. Every call returns a new table.
local function template(): Profile
	return {
		v = VERSION,
		coins = 0,
		runEarned = 0,
		lifetimeEarned = 0,
		level = 0,
		sparks = 0,
		sparksSpent = 0,
		plants = { 0, 0, 0, 0, 0, 0 },
		nodes = {},
		pnodes = {},
		storage = { charge = 0, mode = "auto" },
		rules = {},
		lastSeen = 0,
		playSeconds = 0,
		sessions = 0,
		firstJoin = 0,
		purchases = {},
		grants = { founder = false, boostSeconds = 0, skipDay = 0, skipCount = 0 },
		cosmetics = {},
		settings = { lang = "auto", sfx = true, music = true },
		tutorial = 0,
	}
end
Data.template = template

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = deepCopy(item)
	end
	return result
end

local function isRule(item: any): boolean
	return type(item) == "table"
		and (item.id == "charge" or item.id == "sell")
		and type(item.on) == "boolean"
		and type(item.th) == "number"
		and item.th >= 0.5
		and item.th <= 2
end

-- A scalar keeps its type; a number must also be finite and not negative. Anything else gives the default.
local function scalar(default: any, value: any): any
	local kind = type(default)
	if kind == "number" then
		if type(value) == "number" and value == value and value >= 0 and value < math.huge then
			return value
		end
	elseif type(value) == kind then
		return value
	end
	return default
end

-- A table with fixed keys: each known key is cleaned as a scalar, unknown keys are dropped.
local function fields(value: any, default: { [string]: any }): { [string]: any }
	local result = {}
	for key, item in default do
		result[key] = scalar(item, if type(value) == "table" then value[key] else nil)
	end
	return result
end

-- The plant counts: one per plant, missing ones are 0.
local function counts(value: any, default: { any }): { any }
	local result = {}
	for index, item in default do
		result[index] = scalar(item, if type(value) == "table" then value[index] else nil)
	end
	return result
end

-- A map (nodes, rules, ...): keeps the entries that pass the check, drops the rest.
local function entries(value: any, check: (any) -> boolean): { [any]: any }
	local result = {}
	if type(value) == "table" then
		for key, item in value do
			if check(item) then
				result[key] = item
			end
		end
	end
	return result
end

-- A list of strings (receipt IDs), at most the last MAX_PURCHASES.
local function strings(value: any): { string }
	local result = {}
	if type(value) == "table" then
		for _, item in value do
			if type(item) == "string" then
				table.insert(result, item)
			end
		end
	end
	while #result > MAX_PURCHASES do
		table.remove(result, 1)
	end
	return result
end

local function isTrue(item: any): boolean
	return item == true
end

local function isText(item: any): boolean
	return type(item) == "string"
end

-- How each field of the template is cleaned on load. Fields without an entry are scalars.
local CLEANERS: { [string]: (any, any) -> any } = {
	plants = counts,
	nodes = function(value: any): any
		return entries(value, isTrue)
	end,
	pnodes = function(value: any): any
		return entries(value, isTrue)
	end,
	rules = function(value: any): any
		return entries(value, isRule)
	end,
	cosmetics = function(value: any): any
		return entries(value, isText)
	end,
	purchases = function(value: any): any
		return strings(value)
	end,
	storage = fields,
	grants = fields,
	settings = fields,
}

-- Fills the template from a loaded profile: missing and wrongly typed fields get the default, unknown fields are dropped.
local function reconcile(profile: any): Profile
	local defaults = template()
	local result: Profile = {}
	for key, default in defaults do
		local value = if type(profile) == "table" then profile[key] else nil
		local clean = CLEANERS[key]
		if clean ~= nil then
			result[key] = clean(value, default)
		else
			result[key] = scalar(default, value)
		end
	end
	result.v = VERSION
	return result
end

-- Brings a saved profile to the current version: runs steps[n] for each missing version n, then reconciles.
-- Returns the new profile, or nil and a reason (no valid version, a newer version, or a missing step).
-- The input is never changed.
function Data.migrate(profile: any, steps: Steps): (Profile?, string?)
	if
		type(profile) ~= "table"
		or type(profile.v) ~= "number"
		or profile.v < 0
		or profile.v ~= math.floor(profile.v)
	then
		return nil, "invalid version"
	end
	if profile.v > VERSION then
		return nil, "newer version"
	end
	local current = deepCopy(profile)
	for version = profile.v, VERSION - 1 do
		local step = steps[version]
		if step == nil then
			return nil, `no migration from version {version}`
		end
		current = step(current)
	end
	return reconcile(current), nil
end

-- The GameCore state of a profile: the fields a run stores, copied. The rules keys become slot numbers again.
function Data.toState(profile: Profile): Profile
	local state = {}
	for _, key in STATE_FIELDS do
		state[key] = deepCopy(profile[key])
	end
	local rules: { [number]: any } = {}
	for key, rule in profile.rules do
		local slot = tonumber(key)
		if slot ~= nil then
			rules[slot] = deepCopy(rule)
		end
	end
	state.rules = rules
	return state
end

-- A profile from a GameCore state. The other fields come from `base` (a profile), or from the template.
-- The rules are stored with string keys ("1", "2", ...): ProfileStore refuses numeric tables with gaps, and a
-- player may set slot 3 before slot 2.
function Data.fromState(state: Profile, base: Profile?): Profile
	local profile = deepCopy(base or template())
	for _, key in STATE_FIELDS do
		profile[key] = deepCopy(state[key])
	end
	local rules: { [string]: any } = {}
	for slot, rule in state.rules do
		rules[tostring(slot)] = deepCopy(rule)
	end
	profile.rules = rules
	profile.v = VERSION
	return profile
end

-- Seconds since the last save, from the server clock; never negative. A profile never saved (lastSeen 0) is away for 0.
-- The cap on offline income is applied by GameCore.offline.
function Data.awaySeconds(lastSeen: number, now: number): number
	if lastSeen <= 0 then
		return 0
	end
	return math.max(0, now - lastSeen)
end

return Data
