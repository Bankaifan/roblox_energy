--!strict
-- Lune entry point: `lune run scripts/run-tests`. Runs every tests/*.test.luau against src/shared.
local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("../tests/Harness")

local function load(path: string): any
	return require(`../src/shared/{path}`)
end

local cases: { Harness.Case } = {}
for _, file in fs.readDir("tests") do
	local name = string.match(file, "^(.+)%.test%.luau$")
	if name then
		table.insert(cases, { name = name, fn = require(`../tests/{name}.test`) })
	end
end

local _, failed = Harness.run(cases, load)
process.exit(if failed > 0 or #cases == 0 then 1 else 0)
