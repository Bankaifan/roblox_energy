--!strict
-- PurchaseService on the server (Bauplan.md, sections 4 and 5), on ProfileStore.Mock. Studio only: TestRunner runs it,
-- Lune does not (it needs server services). The Sunshine Hour gets a test Roblox ID for the run only, and it is put back
-- at the end. Players are plain tables: the services read only UserId, Name and Parent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogue = require(Shared:WaitForChild("Config"):WaitForChild("Shop") :: ModuleScript) :: any
local DataService = require(script.Parent.DataService) :: any
local PurchaseService = require(script.Parent.PurchaseService) :: any
local PolicyService = require(script.Parent.PolicyService) :: any

local PRODUCT_ID = 880001 -- stands in for the Sunshine Hour's Roblox ID, during this test only
local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet

return function(t)
	local sunshine: any
	for _, offer in Catalogue.offers do
		if offer.id == "sunshine" then
			sunshine = offer
		end
	end
	local placeholder = sunshine.robloxId
	sunshine.robloxId = PRODUCT_ID

	-- A fresh player (random ID, so the Mock store holds nothing for them yet).
	local userId = math.random(100000, 999999)
	local player: any = { UserId = userId, Name = `test{userId}`, Parent = true }
	local receipt = { PlayerId = userId, PurchaseId = `pt-{userId}-1`, ProductId = PRODUCT_ID }

	-- No loaded profile: nothing is credited, Roblox asks again on the next join.
	t.equal(PurchaseService.receive(player, receipt), NotYet, "without a loaded profile the receipt waits")
	t.equal(DataService.profileOf(player), nil, "and no profile is held")

	-- Loaded: the receipt is granted once and credited once, the same receipt again changes nothing.
	t.truthy(DataService.load(player) ~= nil, "the profile loads")
	t.equal(PurchaseService.receive(player, receipt), Granted, "the receipt is granted")
	local data = DataService.profileOf(player).Data
	t.equal(#data.boosters, 1, "one Sunshine Hour in the queue")
	t.equal(data.boosters[1].kind, "sunshine", "the queue holds the Sunshine Hour")
	t.equal(data.boosters[1].left, sunshine.seconds, "for its full length")
	t.equal(data.purchases[1], receipt.PurchaseId, "the receipt ID is kept with the credit")
	t.equal(PurchaseService.receive(player, receipt), Granted, "the same receipt again is granted")
	t.equal(#DataService.profileOf(player).Data.boosters, 1, "but credited only once")

	-- An unknown product is refused, nothing is credited.
	local unknown = { PlayerId = userId, PurchaseId = `pt-{userId}-2`, ProductId = 1 }
	t.equal(PurchaseService.receive(player, unknown), NotYet, "an unknown product is refused")
	t.equal(#DataService.profileOf(player).Data.boosters, 1, "and nothing is credited")

	-- The credit is saved: after a release and a load, the queue and the receipt are still there.
	DataService.release(player, nil)
	DataService.flush(10)
	t.truthy(DataService.load(player) ~= nil, "the profile loads again")
	local saved = DataService.profileOf(player).Data
	t.equal(#saved.boosters, 1, "the Sunshine Hour survives the save")
	t.equal(saved.purchases[1], receipt.PurchaseId, "and so does the receipt ID")
	t.equal(PurchaseService.receive(player, receipt), Granted, "after the rejoin the old receipt is still a duplicate")
	t.equal(#DataService.profileOf(player).Data.boosters, 1, "and is not credited again")
	DataService.release(player, nil)
	DataService.flush(10)

	-- Two receipts at once (Sunshine Hour and another bought together): each waits for its own save, both are granted,
	-- both are credited and both IDs survive a save and a reload. Neither credit may undo the other.
	t.truthy(DataService.load(player) ~= nil, "the profile loads for the overlapping receipts")
	local first = { PlayerId = userId, PurchaseId = `pt-{userId}-3`, ProductId = PRODUCT_ID }
	local second = { PlayerId = userId, PurchaseId = `pt-{userId}-4`, ProductId = PRODUCT_ID }
	local results: { first: any?, second: any? } = {}
	task.spawn(function()
		results.first = PurchaseService.receive(player, first)
	end)
	task.spawn(function()
		results.second = PurchaseService.receive(player, second)
	end)
	local deadline = os.clock() + 40
	while (results.first == nil or results.second == nil) and os.clock() < deadline do
		task.wait()
	end
	t.equal(results.first, Granted, "the first overlapping receipt is granted")
	t.equal(results.second, Granted, "the second overlapping receipt is granted")
	local both = DataService.profileOf(player).Data
	t.equal(#both.boosters, 3, "both overlapping receipts are credited (one before, two now)")
	t.truthy(table.find(both.purchases, first.PurchaseId) ~= nil, "the first receipt ID is kept")
	t.truthy(table.find(both.purchases, second.PurchaseId) ~= nil, "the second receipt ID is kept")
	DataService.release(player, nil)
	DataService.flush(10)
	t.truthy(DataService.load(player) ~= nil, "the profile loads after the overlapping receipts")
	local reloaded = DataService.profileOf(player).Data
	t.equal(#reloaded.boosters, 3, "the saved queue holds all three Sunshine Hours")
	t.truthy(table.find(reloaded.purchases, second.PurchaseId) ~= nil, "and the second receipt ID is saved")
	DataService.release(player, nil)
	DataService.flush(10)

	-- Passes (issue #243): ownership is what Roblox confirms now. confirmPass is stubbed for this run only.
	local meter: any
	for _, offer in Catalogue.offers do
		if offer.id == "long_meter" then
			meter = offer
		end
	end
	local meterPlaceholder, realConfirm = meter.robloxId, PurchaseService.confirmPass
	meter.robloxId = 880002
	t.truthy(DataService.load(player) ~= nil, "the profile loads for the pass checks")
	local profile = DataService.profileOf(player)
	profile.Data = table.clone(profile.Data)
	profile.Data.passes = { long_meter = true, premium = true }
	PurchaseService.confirmPass = function(): boolean
		return false
	end
	PurchaseService.join(player)
	t.equal(next(DataService.profileOf(player).Data.passes), nil, "join clears the saved pass flags")
	PurchaseService.checkPasses(player)
	t.equal(DataService.profileOf(player).Data.passes.long_meter, nil, "a failed or trial check grants nothing")
	PurchaseService.confirmPass = function(): boolean
		return true
	end
	PurchaseService.checkPasses(player)
	t.equal(DataService.profileOf(player).Data.passes.long_meter, true, "a confirmed pass is granted")
	PurchaseService.confirmPass = function(): boolean
		return false
	end
	local cleared = table.clone(DataService.profileOf(player).Data)
	cleared.passes = {}
	DataService.profileOf(player).Data = cleared
	PurchaseService.passFinished(player, 880002, true)
	PurchaseService.passFinished(player, 880002, false)
	t.equal(DataService.profileOf(player).Data.passes.long_meter, nil, "an unconfirmed purchase event grants nothing")
	PurchaseService.confirmPass = realConfirm
	meter.robloxId = meterPlaceholder
	DataService.release(player, nil)
	DataService.flush(10)

	-- Policy: a player the Roblox policy call cannot answer for (this fake player) gets no paid items: the shop is hidden.
	t.equal(PolicyService.paidItemsAllowed(player), false, "a failed policy call hides the shop")
	t.equal(PurchaseService.shopVisible(player), false, "the shop is hidden for that player")

	sunshine.robloxId = placeholder
end
