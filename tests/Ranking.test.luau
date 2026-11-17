--!strict
-- Leaderboards (Bauplan.md, section 3): the world score, the order of the server list, the write throttle and the read cache.
return function(t, load)
	local Ranking = load("Core/Ranking")

	-- World score: level × 1.000.000 + 1.000 × log10(earnings), as a whole number.
	t.equal(Ranking.score(0, 0), 0, "no level and no earnings score 0")
	t.equal(Ranking.score(3, 1e7), 3 * 1000000 + 7000, "10 million earned add seven tenfolds")
	t.equal(Ranking.score(3, 0.5), 3000000, "earnings below 1 count as 1")
	t.truthy(Ranking.score(4, 1) > Ranking.score(3, 1e300), "a higher level beats any amount of earnings")
	t.truthy(Ranking.score(3, 2e7) > Ranking.score(3, 1e7), "more earnings score higher")
	local score = Ranking.score(3, 2.5e7)
	t.equal(score, math.floor(score), "the score is a whole number")

	-- The level and the tenfold come back out of the score for the list.
	local stored = Ranking.score(5, 1e8)
	t.equal(Ranking.level(stored), 5, "the level comes back out of the score")
	t.equal(Ranking.exponent(stored), 8, "the tenfold comes back out of the score")

	-- Server list: level first, then earnings, then name.
	local entries = {
		{ name = "Cara", level = 2, earned = 9e9 },
		{ name = "Ben", level = 3, earned = 10 },
		{ name = "Dan", level = 3, earned = 1000 },
		{ name = "Anna", level = 3, earned = 1000 },
	}
	local sorted = Ranking.sortServer(entries)
	local names = {}
	for _, entry in sorted do
		table.insert(names, entry.name)
	end
	t.equal(table.concat(names, ","), "Anna,Dan,Ben,Cara", "level first, then earnings, then name")
	t.equal(entries[1].name, "Cara", "the list passed in keeps its order")

	-- Lists are cut to the rows asked for; a short list stays whole.
	t.equal(#Ranking.top(sorted, 2), 2, "the list is cut to two rows")
	t.equal(#Ranking.top(sorted, Ranking.WORLD_SIZE), 4, "a short list stays whole")

	-- Write throttle: a first score is written, an unchanged one is not, a change waits a minute.
	t.truthy(Ranking.writeDue(nil, nil, 0, 5), "the first score is written")
	t.truthy(not Ranking.writeDue(100, 5, 130, 5), "an unchanged score is not written")
	t.truthy(not Ranking.writeDue(100, 5, 159, 6), "a changed score waits 60 seconds")
	t.truthy(Ranking.writeDue(100, 5, 160, 6), "after 60 seconds a changed score is written")

	-- Read cache: a world list is reused for a minute, then read again.
	t.truthy(not Ranking.cacheFresh(nil, 0), "nothing read yet")
	t.truthy(Ranking.cacheFresh(100, 159), "a world list is reused for a minute")
	t.truthy(not Ranking.cacheFresh(100, 160), "after a minute it is read again")
end
