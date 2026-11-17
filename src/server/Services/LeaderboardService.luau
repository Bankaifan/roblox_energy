--!strict
-- LeaderboardService on the server (Bauplan.md, section 3, Bestenliste). Only the server writes. The server list lives in
-- memory and is sent live. The world list is an ordered DataStore with one score per player: a player's score is written
-- at most once a minute and only when it changed, and the list is read at most once a minute. The rules are in
-- Core/Ranking; Studio tests replace the store with useStore.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ranking = require(Shared:WaitForChild("Core"):WaitForChild("Ranking") :: ModuleScript) :: any

local STORE_NAME = "WorldLeaderboard"

type Seen = {
	name: string,
	userId: number,
	level: number,
	earned: number,
	score: number,
	savedAt: number?, -- server time of the last write, nil before the first one
	saved: number?, -- the score that was written last
}
type WorldRow = { name: string, score: number }

local LeaderboardService = {}
local seen: { [Player]: Seen } = {}
local store: any = nil
local worldRows: { WorldRow } = {}
local worldAt: number? = nil
local fetching = false
local names: { [number]: string } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The ordered DataStore, or nil when it cannot be reached (Studio without API access): then nothing is written.
local function getStore(): any
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			warn(`Leaderboard store unavailable: {result}`)
		end
	end
	return store
end

-- For Studio tests: any object with SetAsync and GetSortedAsync takes the place of the DataStore.
function LeaderboardService.useStore(fake: any)
	store = fake
end

-- Writes one score in the background. The write is recorded first, so a failed write is not retried every second; it
-- goes out again when the score changes or the next minute begins.
local function write(entry: Seen)
	entry.savedAt = now()
	entry.saved = entry.score
	local target = getStore()
	if target == nil then
		return
	end
	local key = tostring(entry.userId)
	local score = entry.score
	task.spawn(function()
		local ok, err = pcall(function()
			target:SetAsync(key, score)
		end)
		if not ok then
			warn(`Leaderboard write failed: {err}`)
		end
	end)
end

-- Called every second for each run with its grid level and run earnings. Only memory changes here; a write goes out
-- when Ranking.writeDue allows it.
function LeaderboardService.observe(player: Player, level: number, earned: number)
	local entry = seen[player]
	if entry == nil then
		entry = {
			name = player.Name,
			userId = player.UserId,
			level = level,
			earned = earned,
			score = 0,
			savedAt = nil,
			saved = nil,
		}
		seen[player] = entry
	end
	entry.level = level
	entry.earned = earned
	entry.score = Ranking.score(level, earned)
	if Ranking.writeDue(entry.savedAt, entry.saved, now(), entry.score) then
		write(entry)
	end
end

-- The player left: a changed score is written once now (this is the last chance), then the player is forgotten.
function LeaderboardService.forget(player: Player)
	local entry = seen[player]
	seen[player] = nil
	if entry ~= nil and entry.saved ~= entry.score then
		write(entry)
	end
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok then result :: string else "?"
	names[userId] = name
	return name
end

-- The world list: the top rows of the ordered DataStore, read at most once a minute. While a read is running, or when
-- it fails, the rows already there are sent.
local function worldList(): { WorldRow }
	if fetching or Ranking.cacheFresh(worldAt, now()) then
		return worldRows
	end
	fetching = true
	worldAt = now()
	local target = getStore()
	if target ~= nil then
		local ok, rows = pcall(function()
			local page = target:GetSortedAsync(false, Ranking.WORLD_SIZE):GetCurrentPage()
			local result: { WorldRow } = {}
			for _, item in page do
				table.insert(result, { name = nameOf(tonumber(item.key) or 0), score = item.value })
			end
			return result
		end)
		if ok then
			worldRows = rows
		else
			warn(`Leaderboard read failed: {rows}`)
		end
	end
	fetching = false
	return worldRows
end

-- The server list: every player on this server, in Ranking order.
local function serverList(): { any }
	local list = {}
	for _, entry in seen do
		table.insert(list, { name = entry.name, level = entry.level, earned = entry.earned })
	end
	return Ranking.top(Ranking.sortServer(list), Ranking.WORLD_SIZE)
end

-- Answers a RankRequest with both lists.
function LeaderboardService.send(remotes: { [string]: RemoteEvent }, player: Player)
	local server = serverList()
	local world = worldList()
	if player.Parent == nil then
		return
	end
	remotes.RankList:FireClient(player, { server = server, world = world })
end

return LeaderboardService
