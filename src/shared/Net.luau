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
		fields = { slot = "int", rule = { "charge", "sell" }, th = "number", on = "boolean" },
		limit = { max = 2, per = 1 },
	},
	SetStorageMode = {
		direction = "client",
		fields = { mode = { "charge", "sell", "auto" } },
		limit = { max = 2, per = 1 },
	},
	Prestige = { direction = "client", fields = {}, limit = { max = 1, per = 5 } },
	SetCosmetic = { direction = "client", fields = { slot = "int", item = "string" }, limit = { max = 1, per = 1 } },
	Ready = { direction = "client", fields = {}, limit = { max = 1, per = 5 } },
	Snapshot = { direction = "server", fields = {} }, -- the whole run state of the player
	Delta = { direction = "server", fields = { coins = "number", rate = "number", charge = "number" } },
	Env = { direction = "server", fields = { phase = "string", weather = "string" } },
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
	if message == nil or message.direction ~= "client" then
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
