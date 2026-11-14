--!strict
-- Milestone 0: runs the tests in Studio only, to prove the same files work there. Remove or gate before release.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
-- Server tests need server modules, so they live next to them (src/server) and are added here.
local serverTest = script.Parent:WaitForChild("Services"):WaitForChild("DataService.test") :: ModuleScript
table.insert(cases, { name = "DataService", fn = require(serverTest) })

local _, failed = Harness.run(cases, load)
print(`[TestRunner] {if failed == 0 then "PASS" else "FAIL"}`)
