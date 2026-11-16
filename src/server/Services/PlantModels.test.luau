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
		"NoCollisionConstraint",
	}
	for _, class in removed do
		Instance.new(class).Parent = if class == "Weld"
				or class == "WeldConstraint"
				or class == "NoCollisionConstraint"
			then second
			else part
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

	-- place: the scale depends on the cell only, a turned copy keeps the size of a straight one.
	local function placed(angle: number?): number
		local copy = Instance.new("Model")
		local body = Instance.new("Part")
		body.Size = Vector3.new(4, 2, 2)
		body.Parent = copy
		copy.PrimaryPart = body
		PlantModels.place(copy, 1, 8, Vector3.new(0, 0, 0), 0, angle)
		local scale = copy:GetScale()
		copy:Destroy()
		return scale
	end
	t.equal(placed(12), placed(nil), "a turned copy keeps its size")
end
