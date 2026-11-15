--!strict
-- Pure decisions for third-party plant models (no Roblox instances, so Lune can test them).
local ModelPolicy = {}

-- Non-part classes kept as visuals. Everything else (scripts, remotes, values, sounds, emitters ...) is destroyed.
local KEEP: { [string]: boolean } = {
	Model = true,
	Folder = true,
	SpecialMesh = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
}

-- Whether an instance of this class stays in the model. isBasePart: the instance is a BasePart (Part, MeshPart, ...).
function ModelPolicy.keeps(className: string, isBasePart: boolean): boolean
	return isBasePart or KEEP[className] == true
end

-- The asset id for a plant, or nil to build from primitives.
function ModelPolicy.assetFor(models: { [number]: number }, plantId: number): number?
	local id = models[plantId]
	if type(id) == "number" and id > 0 then
		return id
	end
	return nil
end

-- Fallback decision: use the model only when a sanitised template exists and holds at least one part.
function ModelPolicy.useModel(loaded: boolean, partCount: number): boolean
	return loaded and partCount > 0
end

return ModelPolicy
