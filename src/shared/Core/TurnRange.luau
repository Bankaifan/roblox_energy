--!strict
-- Turning range (no Roblox APIs): a turning model (rotor, water wheel) moves only while its point lies within `range`
-- studs of the camera. Points and the eye are plain x, y, z numbers.
local TurnRange = {}

TurnRange.RANGE = 150

-- True when the point (x, y, z) lies within `range` studs of the eye (ex, ey, ez), the border included.
function TurnRange.within(x: number, y: number, z: number, ex: number, ey: number, ez: number, range: number): boolean
	local dx, dy, dz = x - ex, y - ey, z - ez
	return dx * dx + dy * dy + dz * dz <= range * range
end

return TurnRange
