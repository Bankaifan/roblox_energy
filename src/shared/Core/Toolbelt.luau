--!strict
-- Tool belt rules (no Roblox APIs): which tools a player carries and which one a land step needs in the hand.
-- `land` is the state field, `config` is Config/Land. The server builds one Roblox Tool per carried id (ToolService)
-- and lets a hold count only while the needed tool is the one in the character's hand (LandService).
local Toolbelt = {}

-- The ids of the tools the player owns, in the order of the config (the order on the belt).
function Toolbelt.owned(land: any, config: any): { string }
	local ids: { string } = {}
	for _, tool in config.tools do
		if land.tools[tool.id] == true then
			table.insert(ids, tool.id)
		end
	end
	return ids
end

-- The tool a step needs in the hand: a field (plant id) needs its field tool, "wired" the pliers. Nil means bare
-- hands (the market shutter, the container) or an unknown target.
function Toolbelt.toolFor(target: any, config: any): string?
	if target == "wired" then
		return "pliers"
	elseif type(target) == "number" then
		return config.fieldTools[target]
	end
	return nil
end

-- True when the step may be worked now: it needs no tool, or the needed tool is owned and is the one equipped.
function Toolbelt.inHand(land: any, target: any, equipped: string?, config: any): boolean
	local tool = Toolbelt.toolFor(target, config)
	if tool == nil then
		return type(target) ~= "number"
	end
	return land.tools[tool] == true and equipped == tool
end

return Toolbelt
