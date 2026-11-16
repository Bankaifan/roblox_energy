--!strict
-- Network messages (Bauplan.md, section 5): names, direction, field rules and the limit per player.
-- Net.check turns a client payload into a clean table: only the declared fields, each of its declared type.
-- Field rules: "int" (finite whole number), "number" (finite), "string", "boolean", or a list of allowed values.
-- The server checks in Core/GameCore (IDs from Config, prices, ownership) come after this.
export type Limit = { max: number, per: number }
export type Message = { direction: string, fields: { [string]: any }, limit: Limit? }

local Net = {}

Net.messages = {
	BuyPlant = {
		direction = "client",
		fields = { plant = "int", qty = { 1, 10, "max" } },
		limit = { max = 8, per = 1 },
	},
	BuyNode = { direction = "client", fields = { node = "string" }, limit = { max = 4, per = 1 } },
	Crank = { direction = "client", fields = {}, limit = { max = 8, per = 1 } },
	SetRule = {
		direction = "client",
		fields = { rule = { "charge", "sell" }, th = "number", on = "boolean" },
		limit = { max = 2, per = 1 },
	},
	SetStorageMode = {
		direction = "client",
		fields = { mode = { "charge", "sell", "auto" } },
		limit = { max = 2, per = 1 },
	},
	Prestige = { direction = "client", fields = {}, limit = { max = 1, per = 5 } },
	SetCosmetic = { direction = "client", fields = { slot = "int", item = "string" }, limit = { max = 1, per = 1 } },
	BuyTool = { direction = "client", fields = { tool = "string" }, limit = { max = 4, per = 1 } },
	-- Prepare is "internal": the server (LandService, after the hold time and distance checks) sends it to itself.
	-- It has no RemoteEvent, so a client cannot send it. target: a field (plant id 1 to 6) or a furniture step.
	Prepare = {
		direction = "internal",
		fields = { target = { 1, 2, 3, 4, 5, 6, "market", "container", "wired" } },
		limit = { max = 2, per = 1 },
	},
	Ready = { direction = "client", fields = {}, limit = { max = 1, per = 5 } },
	Snapshot = { direction = "server", fields = {} }, -- the whole run state of the player
	-- turbo: seconds of the owner's own Turbo Feed-in left (0 = off).
	Delta = {
		direction = "server",
		fields = { coins = "number", rate = "number", charge = "number", turbo = "number" },
	},
	-- sunshineEnds is the server time the Sunshine Hour ends (0 = off); the client counts down from it.
	Env = {
		direction = "server",
		fields = {
			phase = "string",
			weather = "string",
			sunshineEnds = "number",
			sunshineBuyer = "string",
			sunshineQueued = "number",
		},
	},
	Welcome = { direction = "server", fields = { away = "number", coins = "number" } }, -- once per join, after Ready
	PlotPublic = { direction = "server", fields = {} },
	Notice = { direction = "server", fields = { text = "string" } },
} :: { [string]: Message }

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function accepts(rule: any, value: any): boolean
	if type(rule) == "table" then
		return table.find(rule, value) ~= nil
	elseif rule == "int" then
		return isFinite(value) and value == math.floor(value)
	elseif rule == "number" then
		return isFinite(value)
	elseif rule == "string" then
		return type(value) == "string" and #value <= 64
	elseif rule == "boolean" then
		return type(value) == "boolean"
	end
	return false
end

-- Returns true and the clean payload (with the message name as `type`), or false and an empty table.
function Net.check(name: string, payload: any): (boolean, { [string]: any })
	local message = Net.messages[name]
	if message == nil or (message.direction ~= "client" and message.direction ~= "internal") then
		return false, {}
	end
	local data = if payload == nil then {} else payload
	if type(data) ~= "table" then
		return false, {}
	end
	local clean: { [string]: any } = { type = name }
	for field, rule in message.fields do
		local value = data[field]
		if value == nil or not accepts(rule, value) then
			return false, {}
		end
		clean[field] = value
	end
	return true, clean
end

return Net
