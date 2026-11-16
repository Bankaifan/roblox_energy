--!strict
-- Which popups are open. While any is, the Roblox hotbar (Backpack) must stay hidden so it cannot cover the popup.
-- Pure: the client only applies `hidden` to the CoreGui; opening twice or closing something shut is harmless.
local PopupGate = {}

export type Gate = { [string]: boolean }

function PopupGate.new(): Gate
	return {}
end

function PopupGate.open(gate: Gate, name: string)
	gate[name] = true
end

function PopupGate.close(gate: Gate, name: string)
	gate[name] = nil
end

-- True while at least one popup is open.
function PopupGate.hidden(gate: Gate): boolean
	return next(gate) ~= nil
end

return PopupGate
