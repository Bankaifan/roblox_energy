--!strict
-- Asset config shape and the model fallback decision (pure; the sanitiser itself needs Roblox instances).
return function(t, load)
	local Assets = load("Config/Assets")
	local Plants = load("Config/Plants")
	local ModelPolicy = load("Core/ModelPolicy")

	local plantIds: { [number]: boolean } = {}
	for _, plant in Plants do
		plantIds[plant.id] = true
	end
	for plantId, assetId in Assets.models do
		t.truthy(plantIds[plantId], `asset for unknown plant {plantId}`)
		t.truthy(type(assetId) == "number" and assetId > 0, `plant {plantId}: asset id`)
	end
	t.equal(Assets.models[1], 138971850808156,"plant 1 uses the supplied solar panel")
	t.equal(Assets.models[2], nil, "plant 2 stays primitive")

	t.equal(ModelPolicy.assetFor(Assets.models, 1), 138971850808156, "asset for plant 1")
	t.equal(ModelPolicy.assetFor(Assets.models, 2), nil, "no asset for plant 2")
	t.equal(ModelPolicy.assetFor({ [1] = 0 }, 1), nil, "zero id is no asset")

	t.truthy(ModelPolicy.useModel(true, 3), "loaded model with parts is used")
	t.truthy(not ModelPolicy.useModel(false, 3), "failed load falls back")
	t.truthy(not ModelPolicy.useModel(true, 0), "model without parts falls back")

	t.truthy(ModelPolicy.keeps("MeshPart", true), "parts stay")
	t.truthy(ModelPolicy.keeps("SpecialMesh", false), "meshes stay")
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
	for _, name in junk do
		t.truthy(not ModelPolicy.keeps(name, false), `{name} is removed`)
	end
end
