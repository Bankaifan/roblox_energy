--!strict
-- Studio only (TestRunner): the sanitiser leaves no script-like instance in a fake third-party model.
local PlantModels = require(script.Parent.PlantModels) :: any

return function(t: any, _load: any)
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = true
	part.Parent = model
	Instance.new("SpecialMesh").Parent = part

	local junk = {
		"Script",
		"LocalScript",
		"ModuleScript",
		"BindableEvent",
		"RemoteEvent",
		"ObjectValue",
		"StringValue",
		"Sound",
		"ParticleEmitter",
	}
	for _, className in junk do
		Instance.new(className).Parent = part
	end
	-- Nested: a script inside a removed folder-like container and inside a nested model.
	local nested = Instance.new("Model")
	nested.Parent = model
	Instance.new("Script").Parent = nested
	local deepPart = Instance.new("Part")
	deepPart.Parent = nested
	Instance.new("RemoteEvent").Parent = deepPart

	local removed = PlantModels.sanitize(model)
	t.equal(removed, #junk + 2, "removed instance count")
	for _, inst in model:GetDescendants() do
		t.truthy(
			not (
					inst:IsA("LuaSourceContainer")
					or inst:IsA("BindableEvent")
					or inst:IsA("RemoteEvent")
					or inst:IsA("ValueBase")
					or inst:IsA("Sound")
					or inst:IsA("ParticleEmitter")
				),
			`{inst.ClassName} left in the model`
		)
		if inst:IsA("BasePart") then
			t.truthy(inst.Anchored and not inst.CanCollide and not inst.CanQuery, `{inst.Name} is inert`)
		end
	end
	t.truthy(part:FindFirstChildOfClass("SpecialMesh") ~= nil, "mesh stays")
	model:Destroy()
end
