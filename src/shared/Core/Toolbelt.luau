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

-- The stage a field step would work next: its number (1 = first stage), its tool and its hold seconds. `cell` names the
-- cell under the player; without one it is the first cell still in work, else a new cell (stage 1). Nil when the cell is
-- prepared already or the field is unknown.
function Toolbelt.stage(land: any, field: any, cell: number?, config: any): (number?, string?, number?)
	local chain = if type(field) == "number" then config.chains[field] else nil
	if chain == nil then
		return nil, nil, nil
	end
	local cells = if land.cells ~= nil then land.cells[field] or {} else {}
	local steps = if land.steps ~= nil then land.steps[field] or {} else {}
	local sites = if land.sites ~= nil then land.sites[field] or 0 else 0
	local index = nil
	if cell == nil then
		if cells[sites + 1] ~= nil then
			index = sites + 1
		end
	else
		index = table.find(cells, cell)
	end
	local done = 0
	if index ~= nil then
		done = steps[index] or (if index <= sites then #chain else 1)
	end
	local entry = chain[done + 1]
	if entry == nil then
		return nil, nil, nil
	end
	return done + 1, entry.tool, entry.hold
end

-- The tool a step needs in the hand: a field (plant id) needs the tool of its next stage (of `cell`, see stage), "wired" the
-- pliers, "align" the mounting rails. Nil means bare hands (the market shutter, the container), an unknown target or a cell that is done.
function Toolbelt.toolFor(target: any, config: any, land: any?, cell: number?): string?
	if target == "wired" then
		return "pliers"
	elseif target == "align" then
		return "rails"
	elseif type(target) == "number" then
		local _, tool = Toolbelt.stage(land or {}, target, cell, config)
		return tool
	end
	return nil
end

-- True when the step may be worked now: it needs no tool, or the needed tool is owned and is the one equipped.
function Toolbelt.inHand(land: any, target: any, equipped: string?, config: any, cell: number?): boolean
	local tool = Toolbelt.toolFor(target, config, land, cell)
	if tool == nil then
		return type(target) ~= "number" and target ~= "wired"
	end
	return land.tools[tool] == true and equipped == tool
end

-- The action text of a field step, by the tool of its stage (the prompt names the step in the hand): the scythe mows, the
-- shovel digs, the hammer builds the house on a lot (field 3) or the fence, the wrench mounts the anchor, the drum lays
-- cable, the tamper compacts. Nil for a tool that is no field stage.
function Toolbelt.actionKey(field: any, tool: string): string?
	if tool == "scythe" then
		return "prompt.mow"
	elseif tool == "shovel" then
		return "prompt.dig"
	elseif tool == "hammer" then
		return if field == 3 then "prompt.house" else "prompt.fence"
	elseif tool == "wrench" then
		return "prompt.anchor"
	elseif tool == "drum" then
		return "prompt.cable"
	elseif tool == "tamper" then
		return "prompt.compact"
	end
	return nil
end

return Toolbelt
