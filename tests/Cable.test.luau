--!strict
-- Cable: the tree of links and the dry pieces around the river.
return function(t, load)
	local Cable = load("Core/Cable")
	local board = { x = 0, z = 0 }
	local links = Cable.links({ { x = 10, z = 0 }, { x = 20, z = 0 }, { x = 30, z = 0 } }, board)
	t.equal(#links, 3, "every site gets one link")
	t.equal(links[2].a.x, 10, "a site joins its nearest linked point, not the board")
	t.equal(links[3].a.x, 20, "the chain runs on")
	t.equal(#Cable.links({}, board), 0, "no sites, no links")

	local river = { { -50, 0 }, { 50, 0 } }
	t.equal(Cable.distanceToLine(river, 0, 7), 7, "distance to the river line")
	local pieces = Cable.dryPieces({ a = { x = 0, z = -20 }, b = { x = 0, z = 20 } }, river, 7, 1)
	t.equal(#pieces, 2, "a cable across the river is cut into two dry pieces")
	t.truthy(pieces[1].b.z <= -7 and pieces[2].a.z >= 7, "the cable goes under the water")
	t.equal(
		#Cable.dryPieces({ a = { x = 0, z = 10 }, b = { x = 30, z = 10 } }, river, 7, 1),
		1,
		"a dry cable stays whole"
	)
end
