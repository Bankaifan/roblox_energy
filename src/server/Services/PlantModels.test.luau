--!strict
-- PlantModels.sanitise on a fake model (Studio only: TestRunner runs it). No script-like or effect instance may survive,
-- and every part ends up anchored without collision or queries.
local PlantModels = require(script.Parent.PlantModels) :: any

return function(t)
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = true
	part.Parent = model
	local second = Instance.new("Part")
	second.Parent = part
	local removed = {
		"Script",
		"LocalScript",
		"ModuleScript",
		"Sound",
		"ParticleEmitter",
		"Beam",
		"Trail",
		"WeldConstraint",
		"BindableEvent",
		"RemoteEvent",
		"StringValue",
		"IntValue",
		"Weld",
	}
	for _, class in removed do
		Instance.new(class).Parent = if class == "Weld" or class == "WeldConstraint" then second else part
	end

	PlantModels.sanitise(model)

	for _, item in model:GetDescendants() do
		t.truthy(item:IsA("BasePart"), `only parts are left, found {item.ClassName}`)
		local base = item :: BasePart
		t.equal(base.Anchored, true, "part anchored")
		t.equal(base.CanCollide, false, "part without collision")
		t.equal(base.CanQuery, false, "part without queries")
	end
	t.equal(#model:GetDescendants(), 2, "both parts are kept")
	model:Destroy()
end
