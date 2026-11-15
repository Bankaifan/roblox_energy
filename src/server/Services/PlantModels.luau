--!strict
-- Third-party plant models (Config/Assets). LoadAsset runs once per asset id and server, in a pcall, off the caller's thread:
-- plot building never waits for it. Until a model is ready (or when the load failed) the plant is built from primitives.
-- The loaded model is sanitised: only visuals stay, every part is anchored and non-colliding.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelPolicy = require(Shared:WaitForChild("Core"):WaitForChild("ModelPolicy") :: ModuleScript) :: any
local Assets = require(Shared:WaitForChild("Config"):WaitForChild("Assets") :: ModuleScript) :: any

local PlantModels = {}

local LOAD_TIMEOUT = 20 -- seconds; after that the plant stays primitive
local FOOTPRINT = 4 -- studs, the width of a primitive plant column

type Entry = { state: string, template: Model? } -- state: "loading", "ready" or "failed"
local entries: { [number]: Entry } = {}

-- Removes everything that is not a visual from `root` (see ModelPolicy.keeps), makes the parts inert, and logs the number
-- of removed instances. Returns that number.
function PlantModels.sanitize(root: Instance): number
	local removed = 0
	for _, inst in root:GetDescendants() do
		if inst:IsDescendantOf(root) then
			if ModelPolicy.keeps(inst.ClassName, inst:IsA("BasePart")) then
				if inst:IsA("BasePart") then
					inst.Anchored = true
					inst.CanCollide = false
					inst.CanQuery = false
					inst.CanTouch = false
				end
			else
				removed += 1
				inst:Destroy()
			end
		end
	end
	warn(`[PlantModels] removed {removed} instances from a loaded model`)
	return removed
end

local function countParts(root: Instance): number
	local count = 0
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function load(assetId: number, entry: Entry)
	local done = false
	task.delay(LOAD_TIMEOUT, function()
		if not done and entry.state == "loading" then
			entry.state = "failed"
			warn(`[PlantModels] asset {assetId}: load timed out, using primitives`)
		end
	end)
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	done = true
	if entry.state ~= "loading" then
		if ok and result ~= nil then
			result:Destroy()
		end
		return
	end
	if not ok or result == nil then
		entry.state = "failed"
		warn(`[PlantModels] asset {assetId}: load failed, using primitives`)
		return
	end
	local container = result :: Model
	PlantModels.sanitize(container)
	if ModelPolicy.useModel(true, countParts(container)) then
		entry.template = container
		entry.state = "ready"
	else
		container:Destroy()
		entry.state = "failed"
		warn(`[PlantModels] asset {assetId}: no visual parts left, using primitives`)
	end
end

-- Starts the load of every configured model; returns at once.
function PlantModels.preload()
	for plantId in Assets.models do
		local assetId = ModelPolicy.assetFor(Assets.models, plantId)
		if assetId ~= nil and entries[assetId] == nil then
			local entry: Entry = { state = "loading", template = nil }
			entries[assetId] = entry
			task.spawn(load, assetId, entry)
		end
	end
end

-- Scales `model` to the primitive plant footprint (bounding box) and returns it.
function PlantModels.fit(model: Model): Model
	local size = model:GetExtentsSize()
	local widest = math.max(size.X, size.Z)
	if widest > 0 then
		model:ScaleTo(model:GetScale() * FOOTPRINT / widest)
	end
	return model
end

-- A fitted clone for the plant, parented to `parent`, or nil when the plant has no model, it is not ready or it failed.
function PlantModels.clone(plantId: number, parent: Instance): Model?
	local assetId = ModelPolicy.assetFor(Assets.models, plantId)
	if assetId == nil then
		return nil
	end
	local entry = entries[assetId]
	if entry == nil or entry.state ~= "ready" or entry.template == nil then
		return nil
	end
	local copy = (entry.template :: Model):Clone()
	copy.Name = "Plant" .. plantId
	PlantModels.fit(copy)
	copy.Parent = parent
	return copy
end

return PlantModels
