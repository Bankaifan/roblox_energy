--!strict
-- Ground cables (no Roblox APIs): the sites of a field are linked to each other and to the control board as a tree, each new
-- site to its nearest linked point, and a link is cut into dry pieces so that no cable lies over the river water.
local Cable = {}

export type Point = { x: number, z: number }
export type Link = { a: Point, b: Point }

local function distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Links every site to the tree that starts at `board`: the site nearest to the tree joins next, to its nearest point.
function Cable.links(sites: { Point }, board: Point): { Link }
	local linked: { Point } = { board }
	local waiting = table.clone(sites)
	local links: { Link } = {}
	while #waiting > 0 do
		local bestAt, bestFrom, bestDistance = 1, linked[1], math.huge
		for index, site in waiting do
			for _, other in linked do
				local d = distance(site, other)
				if d < bestDistance then
					bestAt, bestFrom, bestDistance = index, other, d
				end
			end
		end
		local site = table.remove(waiting, bestAt) :: Point
		table.insert(links, { a = bestFrom, b = site })
		table.insert(linked, site)
	end
	return links
end

-- Distance from (x, z) to the polyline `points` ({ x, z } pairs).
function Cable.distanceToLine(points: { { number } }, x: number, z: number): number
	local best = math.huge
	for i = 1, #points - 1 do
		local ax, az, cx, cz = points[i][1], points[i][2], points[i + 1][1], points[i + 1][2]
		local dx, dz = cx - ax, cz - az
		local length2 = dx * dx + dz * dz
		local u = if length2 > 0 then math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / length2)) else 0
		best = math.min(best, math.sqrt((x - (ax + u * dx)) ^ 2 + (z - (az + u * dz)) ^ 2))
	end
	return best
end

-- The dry pieces of the link a -> b: sampled every `step` studs, a sample counts as wet when it lies closer than `margin` to the
-- river centre line `river`. Runs of dry samples become one piece each (the cable goes under the water in between).
function Cable.dryPieces(link: Link, river: { { number } }, margin: number, step: number): { Link }
	local length = distance(link.a, link.b)
	local count = math.max(1, math.ceil(length / step))
	local pieces: { Link } = {}
	local start: Point? = nil
	local last: Point? = nil
	for i = 0, count do
		local u = i / count
		local at = { x = link.a.x + (link.b.x - link.a.x) * u, z = link.a.z + (link.b.z - link.a.z) * u }
		local dry = Cable.distanceToLine(river, at.x, at.z) >= margin
		if dry then
			if start == nil then
				start = at
			end
			last = at
		elseif start ~= nil and last ~= nil then
			table.insert(pieces, { a = start, b = last })
			start, last = nil, nil
		end
	end
	if start ~= nil and last ~= nil then
		table.insert(pieces, { a = start, b = last })
	end
	return pieces
end

return Cable
