--!strict
-- DataService on ProfileStore.Mock (Bauplan, "Speichern"). Studio only: TestRunner runs it, Lune does not (it needs server
-- services). Players are plain tables: DataService reads only UserId, Name and Parent. Covers load, sync, release, a second
-- load with the same run, a profile of a newer version (nil), and a run with slot 3 set and slot 2 empty.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Core"):WaitForChild("Data") :: ModuleScript) :: any
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any
local DataService = require(script.Parent.DataService) :: any

local STORE_NAME = "PowerGrid_Profiles" -- the store of DataService; its Mock shares the data by name

local function same(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, item in a do
		if not same(item, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Parent is not nil, so the load is not cancelled.
local function fakePlayer(userId: number): any
	return { UserId = userId, Name = `test{userId}`, Parent = true }
end

return function(t)
	-- Load, sync, release; a second load gives the run that was synced.
	local player = fakePlayer(9001)
	local run = Data.toState(Data.template())
	run.coins = 42
	run.plants = { 5, 2, 0, 1, 0, 0 }
	run.rules = { [1] = { id = "charge", th = 0.7, on = true }, [3] = { id = "sell", th = 1.5, on = false } }
	t.truthy(DataService.load(player) ~= nil, "a new profile loads")
	DataService.sync(player, run)
	DataService.release(player, nil)
	DataService.flush(10)
	local again, away = DataService.load(player)
	t.truthy(again ~= nil, "the profile loads a second time")
	t.truthy(same(again, run), "the second load gives the synced run exactly")
	t.truthy(away >= 0, "the time away is never negative")
	DataService.release(player, nil)
	DataService.flush(10)

	-- A profile of a newer version cannot be loaded: nil, no time away, and no session is left behind.
	local newerId = 9002
	local writer = ProfileStore.New(STORE_NAME, Data.template()).Mock
	local newer = writer:StartSessionAsync(`player-{newerId}`, {})
	t.truthy(newer ~= nil, "the newer-version profile starts")
	newer.Data.v = 2
	local saved = false
	local connection = newer.OnAfterSave:Connect(function()
		saved = true
	end)
	newer:EndSession()
	for _ = 1, 200 do
		if saved then
			break
		end
		task.wait()
	end
	connection:Disconnect()
	t.truthy(saved, "the newer-version profile is saved")
	local rejected, rejectedAway = DataService.load(fakePlayer(newerId))
	t.equal(rejected, nil, "a profile of a newer version does not load")
	t.equal(rejectedAway, 0, "and gives no time away")

	-- Slot 3 set before slot 2: the save works (no gap in the stored table) and slot 3 comes back.
	local gapPlayer = fakePlayer(9003)
	local gapRun = Data.toState(Data.template())
	gapRun.rules = { [3] = { id = "sell", th = 1, on = true } }
	t.truthy(DataService.load(gapPlayer) ~= nil, "a profile loads for the slot 3 test")
	DataService.release(gapPlayer, gapRun)
	DataService.flush(10)
	local gapBack = DataService.load(gapPlayer)
	t.truthy(gapBack ~= nil, "the slot 3 profile loads again")
	t.equal(gapBack.rules[3].id, "sell", "slot 3 is kept")
	t.equal(gapBack.rules[2], nil, "slot 2 stays empty")
	DataService.release(gapPlayer, nil)
	DataService.flush(10)
end
