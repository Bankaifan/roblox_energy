--!strict
-- Session on ProfileStore.Mock (Bauplan.md, "Offline-Ertrag" and "Willkommen-Bildschirm"). Studio only: TestRunner runs it,
-- Lune does not (it needs server services). Two players rejoin after 2 hours away: each gets their own run and plot, and a
-- Welcome with the time away and the offline coins, which the Snapshot already includes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Core"):WaitForChild("Data") :: ModuleScript) :: any
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any
local DataService = require(script.Parent.DataService) :: any
local Session = require(script.Parent.Session) :: any

local STORE_NAME = "PowerGrid_Profiles" -- the store of DataService; its Mock shares the data by name
local AWAY = 7200

-- Saves a profile with the run `state`, last saved at `lastSeen`, and waits until the save is written.
local function seed(userId: number, state: any, lastSeen: number)
	local writer = ProfileStore.New(STORE_NAME, Data.template()).Mock
	local profile = writer:StartSessionAsync(`player-{userId}`, {})
	profile.Data = Data.fromState(state, profile.Data)
	profile.Data.lastSeen = lastSeen
	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:EndSession()
	for _ = 1, 200 do
		if saved then
			break
		end
		task.wait()
	end
	connection:Disconnect()
	assert(saved, "the seeded profile is saved")
end

-- Parent is not nil, so the load is not cancelled.
local function fakePlayer(userId: number): any
	return { UserId = userId, Name = `test{userId}`, Parent = true }
end

-- Remotes for one player: the last payload of each message is kept in `sent`.
local function recorder(): ({ [string]: any }, { [string]: any })
	local sent: { [string]: any } = {}
	local function sink(name: string): any
		return {
			FireClient = function(_self: any, _player: any, payload: any)
				sent[name] = payload
			end,
		}
	end
	return sent, { Env = sink("Env"), Snapshot = sink("Snapshot"), Welcome = sink("Welcome") }
end

return function(t)
	local now = os.time()
	local alice = fakePlayer(9101)
	local bob = fakePlayer(9102)
	local aliceRun = Data.toState(Data.template())
	aliceRun.plants = { 5, 0, 0, 0, 0, 0 }
	local bobRun = Data.toState(Data.template())
	bobRun.coins = 500
	bobRun.plants = { 0, 2, 0, 0, 0, 0 }
	seed(alice.UserId, aliceRun, now - AWAY)
	seed(bob.UserId, bobRun, now - AWAY)

	local aliceSent, aliceRemotes = recorder()
	local bobSent, bobRemotes = recorder()
	Session.start(alice)
	Session.start(bob)
	Session.ready(aliceRemotes, alice)
	Session.ready(bobRemotes, bob)

	-- Each player gets their own run back, not the other's.
	t.equal(aliceSent.Snapshot.plants[1], 5, "alice gets her own plants")
	t.equal(aliceSent.Snapshot.plants[2], 0, "alice does not get bob's plants")
	t.equal(bobSent.Snapshot.plants[2], 2, "bob gets his own plants")
	t.equal(bobSent.Snapshot.plants[1], 0, "bob does not get alice's plants")

	-- The rejoin: about 2 hours away, the offline coins are credited and shown, and the Snapshot includes them.
	local aliceWelcome = aliceSent.Welcome
	t.truthy(aliceWelcome ~= nil, "alice gets a Welcome after 2 hours away")
	t.truthy(aliceWelcome.away >= AWAY and aliceWelcome.away <= AWAY + 120, "the time away is about 2 hours")
	t.truthy(aliceWelcome.coins > 0, "the offline coins are paid")
	t.equal(
		aliceSent.Snapshot.coins,
		aliceWelcome.coins,
		"alice's Snapshot holds exactly the offline coins (she had 0)"
	)
	local bobWelcome = bobSent.Welcome
	t.truthy(bobWelcome ~= nil and bobWelcome.coins > 0, "bob gets his own offline coins")
	t.equal(bobSent.Snapshot.coins, 500 + bobWelcome.coins, "bob's Snapshot is his 500 plus his offline coins")

	-- Each has their own plot.
	local plots = workspace:FindFirstChild("Plots")
	local aliceModel = plots and plots:FindFirstChild(alice.Name)
	local bobModel = plots and plots:FindFirstChild(bob.Name)
	t.truthy(aliceModel ~= nil and bobModel ~= nil and aliceModel ~= bobModel, "each player has a plot of their own")

	-- Leaving releases both runs; the Welcome is sent once per join, so a second Ready shows nothing.
	Session.ready(aliceRemotes, alice)
	t.equal(aliceSent.Welcome, aliceWelcome, "a second Ready does not send the Welcome again")
	Session.stop(alice)
	Session.stop(bob)
	DataService.flush(10)
end
