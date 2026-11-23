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

	-- The mini turbine (plant 4) spins about its hub cap, the highest part outside the rotor ("NeonGlow" does not count);
	-- a part named Mid inside the rotor wins; without any hub the middle of the rotor is used.
	local function mini(withCap: boolean, withMid: boolean): Model
		local copy = Instance.new("Model")
		local rotor = Instance.new("Model")
		rotor.Name = "Model"
		rotor.Parent = copy
		local blades = Instance.new("Part")
		blades.Size = Vector3.new(1, 12, 12)
		blades.Position = Vector3.new(10, 0, 0)
		blades.Parent = rotor
		if withMid then
			local mid = Instance.new("Part")
			mid.Name = "Mid"
			mid.Size = Vector3.one
			mid.Position = Vector3.new(0, 7, 0)
			mid.Parent = rotor
		end
		if withCap then
			local cap = Instance.new("Part")
			cap.Name = "Cap"
			cap.Position = Vector3.new(0, 5, 0)
			cap.Parent = copy
		end
		local glow = Instance.new("Part")
		glow.Name = "NeonGlow"
		glow.Position = Vector3.new(0, 20, 0)
		glow.Parent = copy
		PlantModels.tagRotor(copy, 4)
		return copy
	end
	local function centreOf(copy: Model): Vector3
		return (copy:FindFirstChild("Model") :: Model):GetAttribute("SpinCentre") :: Vector3
	end
	t.equal(centreOf(mini(true, false)), Vector3.new(0, 5, 0), "the mini rotor turns about the hub cap, not the glow")
	t.equal(centreOf(mini(true, true)), Vector3.new(0, 7, 0), "a Mid part wins over the cap")
	t.equal(centreOf(mini(false, false)), Vector3.new(10, 0, 0), "without a cap the middle of the rotor is the centre")
end
