--!strict
-- Config tables (Bauplan section 6, level 1): unique IDs, prerequisites exist, costs rise,
-- weather shares sum to 100. Also the Bauplan totals: 720 s per day, 215 sparks.
return function(t, load)
	local Plants = load("Config/Plants")
	local Phases = load("Config/Phases")
	local Weather = load("Config/Weather")
	local Prestige = load("Config/Prestige")
	local Upgrades = load("Config/Upgrades")

	local function idsOf(list: { any }): { string }
		local ids = {}
		for _, entry in list do
			table.insert(ids, tostring(entry.id))
		end
		return ids
	end

	local function assertUnique(ids: { string }, label: string)
		local seen: { [string]: boolean } = {}
		for _, id in ids do
			t.truthy(not seen[id], `{label}: duplicate ID {id}`)
			seen[id] = true
		end
	end

	local function assertRising(list: { any }, field: string, label: string)
		for i = 2, #list do
			t.truthy(list[i][field] > list[i - 1][field], `{label}: {field} does not rise at entry {i}`)
		end
	end

	local function sumOf(list: { any }, field: string): number
		local sum = 0
		for _, entry in list do
			sum += entry[field]
		end
		return sum
	end

	-- Counts and unique IDs
	t.equal(#Upgrades.run, 22, "run nodes")
	t.equal(#Upgrades.permanent, 8, "permanent nodes")
	assertUnique(idsOf(Plants), "plants")
	assertUnique(idsOf(Phases), "phases")
	assertUnique(idsOf(Weather), "weather")
	assertUnique(idsOf(Upgrades.run), "run nodes")
	assertUnique(idsOf(Upgrades.permanent), "permanent nodes")
	t.equal(#Upgrades.spark, 6, "spark items S1 to S6")
	assertUnique(idsOf(Upgrades.spark), "spark items")

	-- Prerequisites must exist; a node costs more than the node it requires
	local plantIds: { [number]: boolean } = {}
	for _, plant in Plants do
		plantIds[plant.id] = true
	end
	local costOf: { [string]: number } = {}
	for _, node in Upgrades.run do
		costOf[node.id] = node.cost
	end
	for _, node in Upgrades.run do
		if node.requiresPlant then
			t.truthy(plantIds[node.requiresPlant], `{node.id}: plant {node.requiresPlant} missing`)
		end
		if node.requiresNode then
			local prerequisite = costOf[node.requiresNode]
			t.truthy(prerequisite ~= nil, `{node.id}: node {node.requiresNode} missing`)
			t.truthy(node.cost > prerequisite, `{node.id}: cost not above {node.requiresNode}`)
		end
	end

	-- The HUD shows English names and labels from Config
	for _, plant in Plants do
		t.truthy(type(plant.name) == "string" and plant.name ~= "", `plant {plant.id}: name`)
	end
	for _, node in Upgrades.run do
		t.truthy(type(node.name) == "string" and node.name ~= "", `{node.id}: name`)
	end
	for _, list in { Phases, Weather } do
		for _, entry in list do
			t.truthy(type(entry.label) == "string" and entry.label ~= "", `{entry.id}: label`)
		end
	end

	-- Every upgrade node has a short English effect text for the HUD detail area
	for _, list in { Upgrades.run, Upgrades.permanent, Upgrades.spark } do
		for _, node in list do
			t.truthy(type(node.info) == "string" and node.info ~= "", `{node.id}: info`)
			t.truthy(#node.info <= 60, `{node.id}: info longer than 60 characters`)
		end
	end

	-- Land: tools serve a plant or a node that exists, every field has a tool, the scythe is free
	local Land = load("Config/Land")
	t.equal(Land.required, true, "the land gates are on: a site before the first plant")
	local Data = load("Core/Data")
	for field, chain in Land.chains do
		t.equal(#chain, Data.CHAIN_LENGTH[field], `field {field}: the migration knows the chain length`)
	end
	t.equal(#Land.fields, #Plants, "one field per plant")
	t.equal(#Land.fieldTools, #Plants, "one field tool per plant")
	local toolIds: { [string]: any } = {}
	for _, tool in Land.tools do
		t.truthy(toolIds[tool.id] == nil, `land: duplicate tool {tool.id}`)
		toolIds[tool.id] = tool
		t.truthy(tool.plant == nil or plantIds[tool.plant], `tool {tool.id}: plant missing`)
		t.truthy(tool.node == nil or costOf[tool.node] ~= nil, `tool {tool.id}: node missing`)
		t.truthy(tool.price >= 0 and tool.hold >= 0, `tool {tool.id}: price and hold`)
		t.truthy(type(tool.textKey) == "string", `tool {tool.id}: text key`)
	end
	for plantId, toolId in Land.fieldTools do
		t.truthy(toolIds[toolId] ~= nil and toolIds[toolId].plant == plantId, `field {plantId}: tool`)
		t.truthy(Land.fields[plantId] >= 1, `field {plantId}: sites`)
	end
	t.equal(toolIds.scythe.price, 0, "the scythe is free")
	t.truthy(Land.start.tools.scythe == true, "the scythe is owned at the start")

	-- Rising values
	assertRising(Plants, "baseCost", "plants")
	assertRising(Prestige, "requiredRevenue", "grid expansion")
	assertRising(Prestige, "multiplier", "grid expansion")
	assertRising(Prestige, "sparks", "grid expansion")
	for i, level in Prestige do
		t.equal(level.level, i, "grid expansion: levels count from 1")
	end

	-- Totals from the Bauplan
	t.equal(sumOf(Weather, "share"), 100, "weather shares in percent")
	t.equal(sumOf(Phases, "duration"), 720, "day length in seconds")
	t.equal(sumOf(Upgrades.permanent, "sparks"), 185, "sparks of all permanent nodes")
	t.equal(sumOf(Upgrades.spark, "sparks"), 30, "sparks of the spark items S1 to S6")
	t.equal(sumOf(Prestige, "sparks"), 215, "sparks of grid expansion levels 1 to 10")
	t.equal(
		sumOf(Prestige, "sparks"),
		sumOf(Upgrades.permanent, "sparks") + sumOf(Upgrades.spark, "sparks"),
		"stages 1 to 10 pay for every permanent node and spark item"
	)
end
