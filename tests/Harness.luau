--!strict
-- Tiny test runner shared by Lune (CI) and Studio. No Roblox APIs, no spec library.
export type T = {
	equal: (actual: any, expected: any, label: string) -> (),
	truthy: (value: any, label: string) -> (),
}
export type Case = { name: string, fn: (t: T, load: (path: string) -> any) -> () }

local Harness = {}

function Harness.run(cases: { Case }, load: (path: string) -> any): (number, number)
	local passed, failed = 0, 0
	for _, case in cases do
		local ok, err = pcall(case.fn, {
			equal = function(actual, expected, label)
				if actual ~= expected then
					error(`{label}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
				end
			end,
			truthy = function(value, label)
				if not value then
					error(`{label}: expected a truthy value`, 2)
				end
			end,
		}, load)
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL {case.name}: {tostring(err)}`)
		end
	end
	print(`{passed} passed, {failed} failed`)
	return passed, failed
end

return Harness
