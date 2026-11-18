--!strict
-- Save data (Bauplan.md, "Datenmodell, Version 3"). Pure: no DataStore, no Roblox APIs. A profile is what is saved;
-- fromState and toState map the fields of a run between the profile and the GameCore state (sections 2 and 5).
-- migrate takes the migration steps as an argument, because core modules do not require each other (see GameCore).
export type Profile = { [string]: any }
export type Steps = { [number]: (Profile) -> Profile }

local VERSION = 8 -- 3: land; 4: rules keyed by id, no slots; 5: land.steps (tool chains); 6: tutorial step; 7: paint, the colour of S5 Sign Paint; 8: tutorial v2, twelve steps (Migrations/Steps)
local MAX_SITES = { 25, 7, 7, 7, 4, 4 } -- prepared sites per field F1..F6 (docs/land-development-design-v2.md, section 2)
local CHAIN_LENGTH = { 1, 2, 2, 2, 3, 3 } -- stages of one cell per field (Config/Land chains)
local TOOLS = { -- the tool IDs of the land design; any other key in `land.tools` is dropped
	scythe = true,
	rails = true,
	shovel = true,
	hammer = true,
	wrench = true,
	drum = true,
	tamper = true,
	pliers = true,
}
local MAX_PURCHASES = 100 -- the last 100 receipt IDs
local MAX_BOOSTER_ENTRIES = 100 -- the booster queue (Core/Shop keeps it at most 60 minutes long)

-- The GameCore state fields a profile stores; the rest of the profile (lastSeen, passes, ...) belongs to the player.
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
	"land",
	"paint",
}

local Data = {}
Data.VERSION = VERSION
Data.CHAIN_LENGTH = CHAIN_LENGTH

-- The default profile, version 3. Every call returns a new table.
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
		paint = 0,
		land = {
			sites = { 0, 0, 0, 0, 0, 0 },
			cells = { {}, {}, {}, {}, {}, {} },
			steps = { {}, {}, {}, {}, {}, {} },
			aligned = {},
			tools = { scythe = true },
			container = false,
			wired = false,
			market = false,
		},
		lastSeen = 0,
		playSeconds = 0,
		sessions = 0,
		firstJoin = 0,
		purchases = {},
		passes = {},
		boosters = {},
		daily = { day = 0, skips = 0 },
		cosmetics = {},
		settings = { lang = "auto", sfx = true, music = true },
		tutorial = 1, -- the current tutorial step (Core/Tutorial): 1 for a new profile
		tutorialDone = false, -- skipped or finished: never shown again
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

-- The saved rules, by rule id ("charge", "sell"). GameCore clamps the threshold into the range of its rule when it is set.
local RULE_IDS = { charge = true, sell = true }

local function rules(value: any): any
	local result = {}
	if type(value) == "table" then
		for id, item in value do
			if
				RULE_IDS[id] == true
				and type(item) == "table"
				and type(item.on) == "boolean"
				and type(item.th) == "number"
				and item.th >= 0.3
				and item.th <= 2
			then
				result[id] = { th = item.th, on = item.on }
			end
		end
	end
	return result
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

-- A booster queue entry: a kind and the seconds left, both valid. Entries with no time left are dropped.
local function isBooster(item: any): boolean
	return type(item) == "table"
		and type(item.kind) == "string"
		and type(item.left) == "number"
		and item.left > 0
		and item.left < math.huge
end

-- The booster queue, in order: the first entry is the active booster.
local function boosters(value: any): any
	local result = {}
	if type(value) == "table" then
		for _, item in value do
			if isBooster(item) and #result < MAX_BOOSTER_ENTRIES then
				table.insert(result, { kind = item.kind, left = item.left })
			end
		end
	end
	return result
end

-- The colour chosen with S5 Sign Paint: a whole number 1 to 6, anything else is 0 (none).
local function paint(value: any, default: any): any
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= 6 then
		return value
	end
	return default
end

-- The land: sites are whole numbers 0..MAX_SITES[field] per plant, known tools stay when true, the scythe is always owned,
-- the flags are booleans.
local function land(value: any, default: any): any
	local source = if type(value) == "table" then value else {}
	local sites = {}
	for index in default.sites do
		local count = scalar(0, if type(source.sites) == "table" then source.sites[index] else nil)
		sites[index] = math.min(math.floor(count), MAX_SITES[index])
	end
	-- The started cells: the prepared ones first (as many as `sites`, every stage done), then those still in work with the
	-- stages done of each. A profile without cells gets the first cells of the fill order.
	local cells, steps = {}, {}
	for index in default.sites do
		local saved = if type(source.cells) == "table" then source.cells[index] else nil
		local savedSteps = if type(source.steps) == "table" then source.steps[index] else nil
		local list, done, used = {}, {}, {}
		for i, cell in if type(saved) == "table" then saved else {} do
			if
				type(cell) == "number"
				and cell % 1 == 0
				and cell >= 1
				and cell <= MAX_SITES[index]
				and not used[cell]
			then
				local stage = if type(savedSteps) == "table" then savedSteps[i] else nil
				if #list < sites[index] then
					used[cell] = true
					table.insert(list, cell)
					table.insert(done, CHAIN_LENGTH[index])
				elseif type(stage) == "number" and stage % 1 == 0 and stage >= 1 and stage < CHAIN_LENGTH[index] then
					used[cell] = true
					table.insert(list, cell)
					table.insert(done, stage)
				end
			end
		end
		local free = 1
		local prepared = 0
		for _, stage in done do
			if stage == CHAIN_LENGTH[index] then
				prepared += 1
			end
		end
		-- Short of cells: pad the prepared ones with the lowest free cells, in front of those in work.
		while prepared < sites[index] do
			if not used[free] then
				used[free] = true
				table.insert(list, prepared + 1, free)
				table.insert(done, prepared + 1, CHAIN_LENGTH[index])
				prepared += 1
			end
			free += 1
		end
		cells[index] = list
		steps[index] = done
	end
	-- Aligned panel cells (F1): whole prepared cell numbers, each once, in the order they were aligned.
	local aligned, alignedSeen = {}, {}
	if type(source.aligned) == "table" then
		for _, cell in source.aligned do
			if
				type(cell) == "number"
				and cell % 1 == 0
				and table.find(cells[1], cell) ~= nil
				and (table.find(cells[1], cell) :: number) <= sites[1]
				and not alignedSeen[cell]
			then
				alignedSeen[cell] = true
				table.insert(aligned, cell)
			end
		end
	end
	local tools = { scythe = true }
	if type(source.tools) == "table" then
		for id in TOOLS do
			if source.tools[id] == true then
				tools[id] = true
			end
		end
	end
	return {
		sites = sites,
		cells = cells,
		steps = steps,
		aligned = aligned,
		tools = tools,
		container = source.container == true,
		wired = source.wired == true,
		market = source.market == true,
	}
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
	rules = rules,
	cosmetics = function(value: any): any
		return entries(value, isText)
	end,
	purchases = function(value: any): any
		return strings(value)
	end,
	passes = function(value: any): any
		return entries(value, isTrue)
	end,
	boosters = boosters,
	land = land,
	paint = paint,
	storage = fields,
	daily = fields,
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

-- The GameCore state of a profile: the fields a run stores, copied. The rules are keyed by their id in both.
function Data.toState(profile: Profile): Profile
	local state = {}
	for _, key in STATE_FIELDS do
		state[key] = deepCopy(profile[key])
	end
	return state
end

-- A profile from a GameCore state. The other fields come from `base` (a profile), or from the template.
function Data.fromState(state: Profile, base: Profile?): Profile
	local profile = deepCopy(base or template())
	for _, key in STATE_FIELDS do
		profile[key] = deepCopy(state[key])
	end
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
