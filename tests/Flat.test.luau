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

	-- Issue #192: the whole plant 1 file as measured in Studio (the body plus the eight cell rows of size 0 x 0.98 x 4.98, two
	-- of the rows are 1 stud apart on x). The body is the largest part, so it gives the normal; after the turn the panel lies
	-- flat (0.12 high, 8.2 x 5.2 on the ground) and the cell rows sit above the body's middle.
	local rows = {}
	for x = 85.6, 92.6, 1 do
		table.insert(rows, {
			pos = vec(x, 2.6, -150.1),
			size = vec(0, 0.98, 4.98),
			right = vec(0, 0, -1),
			up = vec(-1, 0, 0),
			back = vec(0, 1, 0),
		})
	end
	local file = { body }
	for _, row in rows do
		table.insert(file, row)
	end
	t.equal(#rows, 8, "the file has eight cell rows")
	for _, toward in { up, vec(0, 0, 1), vec(0, -1, 0) } do
		t.truthy(near(Flat.normal(file, toward), vec(0, 0, -1)), "the cell side wins over the side asked for")
	end
	local lay, spin = Flat.turn(Flat.normal(file, up), up)
	local function laid(part)
		local function turn(v)
			return rotate(v, lay, spin)
		end
		return {
			pos = turn(part.pos),
			size = part.size,
			right = turn(part.right),
			up = turn(part.up),
			back = turn(part.back),
		}
	end
	local flat = {}
	for _, part in file do
		table.insert(flat, laid(part))
	end
	local lying = Flat.box(flat)
	t.truthy(math.abs((lying.maxY - lying.minY) - 0.12) < 1e-6, "laid down the panel is 0.12 high")
	t.truthy(math.abs((lying.maxX - lying.minX) - 8.2) < 1e-6, "8.2 long")
	t.truthy(math.abs((lying.maxZ - lying.minZ) - 5.2) < 1e-6, "and 5.2 wide")
	t.truthy(near(laid(body).up, vec(0, 0, -1)) == false, "the body's thin axis no longer lies along z")
	t.truthy(math.abs(math.abs(laid(body).up.y) - 1) < 1e-6, "it stands vertical")
	for _, row in rows do
		t.truthy(laid(row).pos.y > laid(body).pos.y, "a cell row lies above the body: the glass side is up")
	end
end
