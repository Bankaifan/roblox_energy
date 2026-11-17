--!strict
-- Leaderboard rules (Bauplan.md, section 3, Bestenliste): the world score, the order of the server list, the write
-- throttle and the read cache. Pure functions with no Roblox APIs, so Lune runs them unchanged. LeaderboardService
-- keeps the state and makes the DataStore calls.
export type Entry = { name: string, level: number, earned: number }

local Ranking = {}

Ranking.LEVEL_STEP = 1000000 -- one grid level in the world score
Ranking.LOG_STEP = 1000 -- one tenfold of run earnings in the world score
Ranking.WORLD_SIZE = 50 -- rows in each list
Ranking.WRITE_INTERVAL = 60 -- seconds between two world writes of the same player
Ranking.READ_TTL = 60 -- seconds a world list is reused before it is read again

-- Netz-Stufe × 1.000.000 + 1.000 × Zehnerlogarithmus der Einnahmen im Lauf, as a whole number. Earnings below 1 count
-- as 1. The small addition keeps an exact power of ten (1e7 gives 7000) from rounding down to 6999.
function Ranking.score(level: number, earned: number): number
	local revenue = math.max(earned, 1)
	return math.floor(level * Ranking.LEVEL_STEP + Ranking.LOG_STEP * math.log(revenue, 10) + 1e-6)
end

-- The grid level a world score stands for.
function Ranking.level(score: number): number
	return math.floor(score / Ranking.LEVEL_STEP)
end

-- The tenfold of the earnings in a world score, e.g. 7.0 for 10 million; the list shows it as "about 10^7".
function Ranking.exponent(score: number): number
	return (score % Ranking.LEVEL_STEP) / Ranking.LOG_STEP
end

-- The server list: higher Netz-Stufe first, then more earnings in the run, then the name (equal runs keep a fixed order).
-- Returns a new list; the one passed in is not changed.
function Ranking.sortServer(entries: { Entry }): { Entry }
	local sorted = table.clone(entries)
	table.sort(sorted, function(a: Entry, b: Entry): boolean
		if a.level ~= b.level then
			return a.level > b.level
		end
		if a.earned ~= b.earned then
			return a.earned > b.earned
		end
		return a.name < b.name
	end)
	return sorted
end

-- The first `count` rows of a list (a shorter list stays whole). Returns a new list.
function Ranking.top(entries: { any }, count: number): { any }
	local result = {}
	for index = 1, math.min(count, #entries) do
		result[index] = entries[index]
	end
	return result
end

-- A score goes to the world list when it changed since its last write and the last write is at least WRITE_INTERVAL
-- seconds back. `savedAt` and `saved` are nil before the first write.
function Ranking.writeDue(savedAt: number?, saved: number?, now: number, score: number): boolean
	if saved == score then
		return false
	end
	return savedAt == nil or now - savedAt >= Ranking.WRITE_INTERVAL
end

-- A world list read at `fetchedAt` is reused for READ_TTL seconds.
function Ranking.cacheFresh(fetchedAt: number?, now: number): boolean
	return fetchedAt ~= nil and now - fetchedAt < Ranking.READ_TTL
end

return Ranking
