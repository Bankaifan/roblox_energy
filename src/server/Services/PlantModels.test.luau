--!strict
-- PlantModels on fake models (Studio only: TestRunner runs it). sanitise: no script-like or effect instance may survive,
-- and every part ends up anchored without collision or queries. place: a flat plant lies on the ground, glass side up,
-- with the same size for every unit.
local PlantModels = require(script.Parent.PlantModels) :: any

-- An upright panel like plant1_panel: 8 wide, 5 high, thin along z, the glass on the -z side, and a turned pivot.
local function uprightPanel(): (Model, Part)
	local model = Instance.new("Model")
	local back = Instance.new("Part")
	back.Size = Vector3.new(8, 5, 0.2)
	back.Position = Vector3.new(50, 30, -70)
	back.Parent = model
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = Vector3.new(7, 4, 0.1)
	glass.Position = Vector3.new(50, 30, -70.15)
	glass.Parent = model
	model.WorldPivot = CFrame.new(50, 30, -70) * CFrame.Angles(math.rad(90), 0, math.rad(90))
	return model, glass
end

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

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 0.01
	end
	local sizes = {}
	for index, yaw in { 0, 180, 12 } do
		local panel, glass = uprightPanel()
		PlantModels.place(panel, 1, 8, Vector3.new(10, 2, 20), yaw)
		local back = panel:FindFirstChild("Part") :: Part
		t.truthy(near(math.abs(back.CFrame.LookVector.Y), 1), `panel {index} lies flat`)
		t.truthy(glass.Position.Y > back.Position.Y, `panel {index} has the glass on top`)
		t.truthy(near(back.Position.Y - back.Size.Z / 2, 2), `panel {index} lies on the ground`)
		t.truthy(near(back.Position.X, 10) and near(back.Position.Z, 20), `panel {index} lies on its site`)
		sizes[index] = back.Size
	end
	t.truthy(near(sizes[1].X, 8), "the long side fills the site")
	t.truthy(sizes[1] == sizes[2] and sizes[1] == sizes[3], "every panel has the same size")

	-- A standing plant keeps its up side and stands on the ground.
	local tower = Instance.new("Model")
	local mast = Instance.new("Part")
	mast.Size = Vector3.new(2, 10, 4)
	mast.Parent = tower
	PlantModels.place(tower, 2, 8, Vector3.new(0, 2, 0), 180)
	t.truthy(near(mast.CFrame.UpVector.Y, 1), "a standing plant stays upright")
	t.truthy(
		near(mast.Position.Y - mast.Size.Y / 2, 2) and near(mast.Size.Z, 8),
		"it stands on the ground, fitted to the site"
	)
end
