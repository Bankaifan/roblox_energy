--!strict
-- DataService on ProfileStore.Mock (Bauplan, "Speichern"). Studio only: TestRunner runs it, Lune does not (it needs server
-- services). Players are plain tables: DataService reads only UserId, Name and Parent. Covers load, sync, release, a second
-- load with the same run, a profile of a newer version (nil), and a run with only the sell rule set.
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
	run.rules = { charge = { th = 0.7, on = true }, sell = { th = 1.5, on = false } }
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
	newer.Data.v = Data.VERSION + 1
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

	-- Only the sell rule set: the save works and the sell rule comes back, the charge rule stays unset.
	local sellPlayer = fakePlayer(9003)
	local sellRun = Data.toState(Data.template())
	sellRun.rules = { sell = { th = 1, on = true } }
	t.truthy(DataService.load(sellPlayer) ~= nil, "a profile loads for the sell rule test")
	DataService.release(sellPlayer, sellRun)
	DataService.flush(10)
	local sellBack = DataService.load(sellPlayer)
	t.truthy(sellBack ~= nil, "the sell rule profile loads again")
	t.equal(sellBack.rules.sell.on, true, "the sell rule is kept")
	t.equal(sellBack.rules.charge, nil, "the charge rule stays unset")
	DataService.release(sellPlayer, nil)
	DataService.flush(10)
end
