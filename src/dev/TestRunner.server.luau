--!strict
-- Runs the tests in Studio. Only built by test.project.json, never part of the published place (default.project.json).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tests = ReplicatedStorage:WaitForChild("Tests")
local Harness = require(Tests:WaitForChild("Harness") :: ModuleScript) :: any

local function load(path: string): any
	local node: Instance = Shared
	for _, part in string.split(path, "/") do
		node = node:WaitForChild(part)
	end
	return require(node :: ModuleScript)
end

local cases = {}
for _, child in Tests:GetChildren() do
	local name = string.match(child.Name, "^(.+)%.test$")
	if name and child:IsA("ModuleScript") then
		table.insert(cases, { name = name, fn = require(child) })
	end
end
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
-- Server tests need server modules, so they live next to them (src/server) and are added here.
local serverTest = Services:WaitForChild("DataService.test") :: ModuleScript
table.insert(cases, { name = "DataService", fn = require(serverTest) })
local sessionTest = Services:WaitForChild("Session.test") :: ModuleScript
table.insert(cases, { name = "Session", fn = require(sessionTest) })
local boostTest = Services:WaitForChild("BoostService.test") :: ModuleScript
table.insert(cases, { name = "BoostService", fn = require(boostTest) })
local plantModelsTest = Services:WaitForChild("PlantModels.test") :: ModuleScript
table.insert(cases, { name = "PlantModels", fn = require(plantModelsTest) })
local purchaseTest = Services:WaitForChild("PurchaseService.test") :: ModuleScript
table.insert(cases, { name = "PurchaseService", fn = require(purchaseTest) })

local _, failed = Harness.run(cases, load)
print(`[TestRunner] {if failed == 0 then "PASS" else "FAIL"}`)
