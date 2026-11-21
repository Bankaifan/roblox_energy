--!strict
-- Water wheel spin (no Roblox APIs): the unit flow direction of the river at a point and the turning direction of a wheel.
local Spin = {}

-- Unit direction (x, z) of the centre line `points` ({ x, z } pairs, in flow order) at the point nearest to (x, z).
function Spin.flowAt(points: { { number } }, x: number, z: number): (number, number)
	local best, bx, bz = math.huge, 1, 0
	for i = 1, #points - 1 do
		local ax, az, cx, cz = points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]
		local dx, dz = cx - ax, cz - az
		local length2 = dx * dx + dz * dz
		if length2 > 0 then
			local u = math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / length2))
			local px, pz = ax + u * dx, az + u * dz
			local d = (x - px) ^ 2 + (z - pz) ^ 2
			if d < best then
				local length = math.sqrt(length2)
				best, bx, bz = d, dx / length, dz / length
			end
		end
	end
	return bx, bz
end

-- +1 or -1: the sense of turning about the axle `axis` (x, y, z) that moves the bottom of the wheel with the flow
-- (fx, fz). With a vertical or flow-parallel axle the sense is +1.
function Spin.sense(ax: number, az: number, fx: number, fz: number): number
	local along = az * fx - ax * fz
	return if along < 0 then -1 else 1
end

-- The point a wheel or rotor turns about: its hub when it has one, else the mean of its big parts. Points are { x, y, z }.
function Spin.centre(hub: { number }?, mean: { number }): { number }
	return hub or mean
end

return Spin
