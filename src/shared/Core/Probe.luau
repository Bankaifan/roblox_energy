--!strict
-- Milestone 0 probe: pure Luau without Roblox APIs. Proves that the same file loads in Lune and in Studio.
local Probe = {}

function Probe.add(a: number, b: number): number
	return a + b
end

return Probe
