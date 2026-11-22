--!strict
-- Solar farm (plant 5) fit, issue #294. The sample is the model file as measured in Studio: modelled on a 15 degree
-- slope (legs normal to the slope, rails along it, cross rails stepping down the slope) with a level top (beams, glass,
-- cells). Without the lean the frame hangs in the air on one side; with it the legs stand upright and the panel tilts
-- with the frame.
return function(t, load)
	local Flat = load("Core/Flat")
	local Assets = load("Config/Assets")
	local function vec(x: number, y: number, z: number)
		return { x = x, y = y, z = z }
	end
	-- A part turned `deg` about Z, as the model stores its legs and rails.
	local function part(px: number, py: number, pz: number, sx: number, sy: number, sz: number, deg: number)
		local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
		return {
			pos = vec(px, py, pz),
			size = vec(sx, sy, sz),
			right = vec(c, s, 0),
			up = vec(-s, c, 0),
			back = vec(0, 0, 1),
		}
	end
	local legs = {
		part(-268.24, 4.66, -34.51, 3.68, 0.3, 0.3, 75),
		part(-262.68, 3.92, -34.51, 5.13, 0.3, 0.3, 75),
		part(-257.27, 3.13, -34.51, 6.4, 0.3, 0.3, 75),
		part(-268.24, 4.66, -45.86, 3.68, 0.3, 0.3, 75),
		part(-262.69, 3.89, -45.86, 5.06, 0.3, 0.3, 75),
		part(-257.27, 3.13, -45.86, 6.4, 0.3, 0.3, 75),
	}
	local slope = {
		part(-263.31, 1.8, -34.51, 11, 0.3, 0.3, -15),
		part(-263.31, 1.8, -45.86, 11, 0.3, 0.3, -15),
	}
	-- Cross rails along Z at the foot of each leg row: they give the ground line.
	local cross = {
		{
			pos = vec(-258.02, 0.38, -40.2),
			size = vec(11.25, 0.3, 0.3),
			right = vec(0, 0, 1),
			up = vec(0, 1, 0),
			back = vec(-1, 0, 0),
		},
		{
			pos = vec(-263.25, 1.78, -40.2),
			size = vec(11.25, 0.3, 0.3),
			right = vec(0, 0, 1),
			up = vec(0, 1, 0),
			back = vec(-1, 0, 0),
		},
		{
			pos = vec(-268.57, 3.21, -40.2),
			size = vec(11.25, 0.3, 0.3),
			right = vec(0, 0, 1),
			up = vec(0, 1, 0),
			back = vec(-1, 0, 0),
		},
	}
	local beams = {
		part(-262.07, 6.3, -34.51, 11.27, 0.3, 0.3, 0),
		part(-262.07, 6.3, -40.34, 11.27, 0.3, 0.3, 0),
		part(-262.07, 6.3, -45.82, 11.27, 0.3, 0.3, 0),
	}
	local panel = { part(-262.05, 6.51, -40.18, 11.9, 0.12, 11.78, 0) }
	for z = -45.62, -34.89, 0.65 do
		table.insert(panel, part(-262.05, 6.55, z, 11.9, 0.12, 0.04, 0))
	end

	local function frame(deg: number)
		local all = {}
		for _, group in { legs, slope, cross, beams } do
			for _, item in Flat.leanZ(group, deg) do
				table.insert(all, item)
			end
		end
		return all
	end
	local function spread(parts): number
		local low, high = math.huge, -math.huge
		for _, item in parts do
			low, high = math.min(low, item.pos.y), math.max(high, item.pos.y)
		end
		return high - low
	end

	local entry = Assets.entry(5)
	t.truthy(entry ~= nil and entry.lean == 15, "plant 5 leans by the 15 degrees of its slope")
	local lean = if entry ~= nil and entry.lean ~= nil then entry.lean else 0

	t.truthy(spread(cross) > 2.5, "as modelled the ground rails step down 2.8 studs")
	t.truthy(spread(Flat.leanZ(cross, lean)) < 0.05, "leaned they lie on one level")
	for _, item in Flat.leanZ(legs, lean) do
		t.truthy(math.abs(item.right.y) > 0.999, "a leg stands upright")
	end
	for _, item in Flat.leanZ(slope, lean) do
		t.truthy(math.abs(item.right.y) < 1e-3, "a slope rail lies level")
	end

	-- The glass rests on the top beams (no gap along the panel's normal) and stays inside the frame in plan.
	local top, glass = Flat.leanZ(beams, lean), Flat.leanZ({ panel[1] }, lean)
	local normal = glass[1].up
	local function along(item): number
		return item.pos.x * normal.x + item.pos.y * normal.y + item.pos.z * normal.z
	end
	local gap = (along(glass[1]) - glass[1].size.y / 2) - (along(top[1]) + top[1].size.y / 2)
	t.truthy(math.abs(gap) < 0.1, "the glass rests on the beams")
	t.truthy(math.abs(normal.x) > 0.25 and normal.y > 0.96, "and tilts with the frame")
	local inner = Flat.box(frame(lean))
	local outer = Flat.box(Flat.leanZ(panel, lean))
	t.truthy(outer.minX >= inner.minX - 0.5 and outer.maxX <= inner.maxX + 0.5, "the panel is within the frame in x")
	t.truthy(outer.minZ >= inner.minZ - 0.5 and outer.maxZ <= inner.maxZ + 0.5, "and in z")
end
