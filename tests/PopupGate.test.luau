--!strict
-- Popup gate: the hotbar is hidden exactly while a popup is open.
return function(t, load)
	local PopupGate = load("Core/PopupGate")
	local gate = PopupGate.new()
	t.truthy(not PopupGate.hidden(gate), "no popup, hotbar shown")
	PopupGate.open(gate, "market")
	PopupGate.open(gate, "market")
	t.truthy(PopupGate.hidden(gate), "an open popup hides the hotbar")
	PopupGate.open(gate, "other")
	PopupGate.close(gate, "market")
	t.truthy(PopupGate.hidden(gate), "another popup still hides it")
	PopupGate.close(gate, "other")
	PopupGate.close(gate, "other")
	t.truthy(not PopupGate.hidden(gate), "all closed, hotbar back")
end
