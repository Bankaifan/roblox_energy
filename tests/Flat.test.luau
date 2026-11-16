--!strict
-- Laying a panel flat: the sample is the plant 1 model as measured in Studio (it stands upright in its file, its
-- pivot is rotated, the cells sit on the -Z side of the body).
return function(t, load)
	local Flat = load("Core/Flat")
	local function vec(x: number, y: number, z: number)
		return { x = x, y = y, z = z }
	end
	local function near(a, b): boolean
		return math.abs(a.x - b.x) < 1e-6 and math.abs(a.y - b.y) < 1e-6 and math.abs(a.z - b.z) < 1e-6
	end
	-- Rodrigues: `v` rotated about the unit `axis` by `angle`.
	local function rotate(v, axis, angle: number)
		local c, s = math.cos(angle), math.sin(angle)
		local d = (axis.x * v.x + axis.y * v.y + axis.z * v.z) * (1 - c)
		return vec(
			v.x * c + (axis.y * v.z - axis.z * v.y) * s + axis.x * d,
			v.y * c + (axis.z * v.x - axis.x * v.z) * s + axis.y * d,
			v.z * c + (axis.x * v.y - axis.y * v.x) * s + axis.z * d
		)
	end

	local body = {
		pos = vec(89.1, 2.6, -150.06),
		size = vec(5.2, 0.12, 8.2),
		right = vec(0, 1, 0),
		up = vec(0, 0, -1),
		back = vec(-1, 0, 0),
	}
	local cells = {
		pos = vec(88.6, 2.599, -150.101),
		size = vec(0.0025, 0.975, 4.977),
		right = vec(0, 0, -1),
		up = vec(-1, 0, 0),
		back = vec(0, 1, 0),
	}
	local up = vec(0, 1, 0)

	local box = Flat.box({ body, cells })
	t.truthy(math.abs((box.maxX - box.minX) - 8.2) < 1e-6, "the file's panel is 8.2 wide in world x")
	t.truthy(math.abs((box.maxY - box.minY) - 5.2) < 1e-6, "and stands 5.2 tall")
	t.truthy(math.abs((box.maxZ - box.minZ) - 0.12) < 1e-6, "its thickness lies along world z")
	t.equal(Flat.box({}), nil, "no parts, no box")

	local normal = Flat.normal({ cells, body }, up)
	t.truthy(near(normal, vec(0, 0, -1)), "the glass side is where the cells sit")
	t.truthy(near(Flat.normal({ body }, vec(0, 0, 1)), vec(0, 0, 1)), "a body alone takes the side nearer the target")
	t.equal(Flat.normal({}, up), nil, "no parts, no normal")

	local axis, angle = Flat.turn(normal, up)
	t.truthy(near(rotate(normal, axis, angle), up), "the turn puts the glass side up")
	t.truthy(math.abs(angle - math.pi / 2) < 1e-6, "by a quarter turn")
	local _, none = Flat.turn(up, up)
	t.equal(none, 0, "a flat panel is not turned")
	for _, from in { vec(0, -1, 0), vec(-1, 0, 0), vec(0.6, -0.48, 0.64) } do
		local a, w = Flat.turn(from, up)
		t.truthy(near(rotate(from, a, w), up), `any side turns up ({from.x}, {from.y}, {from.z})`)
	end
end
