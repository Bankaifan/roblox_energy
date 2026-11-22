--!strict
-- Purchases on the server (Bauplan.md, sections 4 and 5): one ProcessReceipt callback for all products, and pass
-- ownership checked on join and after PromptGamePassPurchaseFinished. The rules live in Core/Shop; this service finds
-- the profile (DataService), writes the result and waits for the save before a receipt is granted.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared:WaitForChild("Core"):WaitForChild("Shop") :: ModuleScript) :: any
local Catalogue = require(Shared:WaitForChild("Config"):WaitForChild("Shop") :: ModuleScript) :: any
local Upgrades = require(Shared:WaitForChild("Config"):WaitForChild("Upgrades") :: ModuleScript) :: any
local DataService = require(script.Parent.DataService) :: any
local PolicyService = require(script.Parent.PolicyService) :: any
local BoostService = require(script.Parent.BoostService) :: any

-- Roblox hands ProcessReceipt a table with PurchaseId (a string, unique per purchase), PlayerId and ProductId; there is no ReceiptId field.
local PurchaseGranted = Enum.ProductPurchaseDecision.PurchaseGranted
local NotProcessedYet = Enum.ProductPurchaseDecision.NotProcessedYet
local SAVE_WAIT_SECONDS = 15 -- a receipt waits for its save; Roblox lets the callback take a while

local PurchaseService = {}

-- The day for the daily limits: whole days since the epoch, from the server clock.
local function today(): number
	return math.floor(os.time() / 86400)
end

-- Receipts of one player are handled one after the other (a lock per UserId), so each one reads the data the previous
-- one saved or undid. Without it, two receipts at once would build on each other's unsaved data.
local receiving: { [number]: boolean } = {}

local function lockReceipts(userId: number)
	while receiving[userId] do
		task.wait()
	end
	receiving[userId] = true
end

local function unlockReceipts(userId: number)
	receiving[userId] = nil
end

-- True when the saved data holds this receipt ID, i.e. the save that just finished includes the credit.
local function holdsReceipt(saved: any, receiptId: string): boolean
	if type(saved) ~= "table" or type(saved.purchases) ~= "table" then
		return false
	end
	for _, known in saved.purchases do
		if known == receiptId then
			return true
		end
	end
	return false
end

-- Saves the profile and waits until a save holding the receipt is written (OnAfterSave). An older save that was already
-- in flight fires OnAfterSave too, but its data lacks the credit, so it does not count. False on timeout or when the
-- profile became inactive.
local function saveNow(profile: any, receiptId: string): boolean
	local saved = false
	local connection: any
	connection = profile.OnAfterSave:Connect(function(lastSaved: any)
		if holdsReceipt(lastSaved, receiptId) then
			saved = true
			connection:Disconnect()
		end
	end)
	profile:Save()
	local deadline = os.clock() + SAVE_WAIT_SECONDS
	while not saved and profile:IsActive() and os.clock() < deadline do
		task.wait()
	end
	if not saved then
		connection:Disconnect()
	end
	return saved
end

-- Takes back the credit of one receipt only: the fields a receipt writes (purchases, boosters, daily) go back to their
-- values before it. Whatever else was written meanwhile (run sync, a pass) is kept.
local function undoCredit(profile: any, before: any)
	local restored = table.clone(profile.Data)
	restored.purchases = before.purchases
	restored.boosters = before.boosters
	restored.daily = before.daily
	restored.sparksBought = before.sparksBought
	restored.permanent = before.permanent
	profile.Data = restored
end

-- The payout of cut yield (Time Skip, Founder Pack) goes into the live run, which Session owns. Session registers two
-- functions: quote(player, seconds) -> coins of that many seconds of full-rate yield (nil without a run yet) and
-- apply(player, coins) -> adds the coins to the run as revenue and copies it into the profile (a negative amount takes
-- a payout back). Without them nothing is paid.
local payout: { quote: (Player, number) -> number?, apply: (Player, number) -> () }? = nil

function PurchaseService.setPayout(quote: (Player, number) -> number?, apply: (Player, number) -> ())
	payout = { quote = quote, apply = apply }
end

-- Spark packs: the sparks go into the live run too (Session owns it), or DataService.sync would write the old count back.
-- Session registers addSparks(player, n) -> false without a run yet; a negative n takes a grant back.
local addSparks: ((Player, number) -> boolean)? = nil

function PurchaseService.setSparks(add: (Player, number) -> boolean)
	addSparks = add
end

-- Permanent plants: the units bought go into the live run too (Session owns it), as far as the ground carries them; the
-- profile keeps the count for every later run. Session registers addPlants(player, plant, n) -> false without a run yet;
-- a negative n takes a grant back.
local addPlants: ((Player, number, number) -> boolean)? = nil

function PurchaseService.setPlants(add: (Player, number, number) -> boolean)
	addPlants = add
end

local function quoteCoins(player: Player, seconds: number): number?
	if payout == nil or seconds <= 0 then
		return 0
	end
	return payout.quote(player, seconds)
end

-- The credit of one receipt, under the receipt lock. Nothing is written unless the save is confirmed.
local function credit(player: Player, receipt: any): Enum.ProductPurchaseDecision
	local profile = DataService.profileOf(player)
	if profile == nil then
		warn(`[PurchaseService] receipt {receipt.PurchaseId}: no loaded profile for {player.Name}`)
		return NotProcessedYet
	end
	local offerId = Shop.offerForProduct(Catalogue, receipt.ProductId)
	if offerId == nil then
		warn(`[PurchaseService] unknown product {receipt.ProductId}`)
		return NotProcessedYet
	end
	local before = profile.Data
	local data, status, seconds = Shop.receipt(before, receipt.PurchaseId, offerId, today(), Catalogue, Upgrades)
	if status == "duplicate" then
		return PurchaseGranted
	end
	if status ~= "granted" then
		warn(`[PurchaseService] receipt {receipt.PurchaseId} for {offerId} refused: {status}`)
		return NotProcessedYet
	end
	local sparks = Shop.packSparks(Catalogue, offerId)
	if sparks > 0 and (addSparks == nil or not addSparks(player, sparks)) then
		warn(`[PurchaseService] receipt {receipt.PurchaseId} for {offerId}: no run yet, asked again later`)
		return NotProcessedYet
	end
	local plant = Shop.permanentPlant(Catalogue, offerId)
	if plant ~= nil and (addPlants == nil or not addPlants(player, plant.id, plant.count)) then
		if sparks > 0 and addSparks ~= nil then
			addSparks(player, -sparks)
		end
		warn(`[PurchaseService] receipt {receipt.PurchaseId} for {offerId}: no run yet, asked again later`)
		return NotProcessedYet
	end
	-- The coins of the yield are written with the receipt ID, in the same step (no yield between), so one save holds both.
	local coins = quoteCoins(player, seconds)
	if coins == nil then
		if sparks > 0 and addSparks ~= nil then
			addSparks(player, -sparks)
		end
		if plant ~= nil and addPlants ~= nil then
			addPlants(player, plant.id, -plant.count)
		end
		warn(`[PurchaseService] receipt {receipt.PurchaseId} for {offerId}: no run yet, asked again later`)
		return NotProcessedYet
	end
	profile.Data = data
	if coins > 0 and payout ~= nil then
		payout.apply(player, coins)
	end
	if saveNow(profile, receipt.PurchaseId) then
		return PurchaseGranted
	end
	warn(
		`[PurchaseService] receipt {receipt.PurchaseId} for {offerId}: the save was not confirmed in time, credit undone`
	)
	undoCredit(profile, before) -- not saved: this credit is undone, the receipt is asked for again
	if plant ~= nil and addPlants ~= nil then
		addPlants(player, plant.id, -plant.count)
	end
	if sparks > 0 and addSparks ~= nil then
		addSparks(player, -sparks)
	end
	if coins > 0 and payout ~= nil then
		payout.apply(player, -coins)
	end
	return NotProcessedYet
end

-- One receipt for the player. A receipt already in the profile is granted again without a credit. No loaded profile
-- or an unknown product: NotProcessedYet, Roblox asks again later.
function PurchaseService.receive(player: Player, receipt: any): Enum.ProductPurchaseDecision
	lockReceipts(player.UserId)
	local ok, result = pcall(credit, player, receipt)
	unlockReceipts(player.UserId)
	if not ok then
		error(result, 0)
	end
	return result
end

-- The one ProcessReceipt callback. An error counts as not processed: nothing is granted then.
local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	print(`[PurchaseService] receipt {receipt.PurchaseId} arrived, product {receipt.ProductId}`)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return NotProcessedYet
	end
	local ok, result = pcall(PurchaseService.receive, player, receipt)
	if ok then
		return result
	end
	warn(`[PurchaseService] receipt {receipt.PurchaseId} not processed: {result}`)
	return NotProcessedYet
end

-- Records one owned pass in the profile for this session. Passes are not kept across sessions (migration 8 to 9, and
-- join clears them): ownership is what Roblox reports now. Shop.purchase keeps the ownership once.
-- The yield of a pass (Founder Pack) is paid by claimYield, once per profile.
function PurchaseService.grantPass(player: Player, offerId: string)
	local profile = DataService.profileOf(player)
	if profile == nil then
		return
	end
	local data, _, reason = Shop.purchase(profile.Data, offerId, today(), Catalogue)
	if reason == nil then
		profile.Data = data
	end
	PurchaseService.claimYield(player)
end

-- Pays the yield of every owned pass that has one and was not paid before (Core/Shop.claimPassYield: the flag is saved
-- in the profile, so a pass seen again on a later join pays nothing). Without a run (Session.start has not finished)
-- nothing is paid and the flag stays open; Session.start calls this again once the run exists.
function PurchaseService.claimYield(player: Player)
	local profile = DataService.profileOf(player)
	if profile == nil or payout == nil then
		return
	end
	for _, offer in Catalogue.offers do
		if offer.type == "pass" and offer.seconds ~= nil then
			local data, seconds = Shop.claimPassYield(profile.Data, offer.id, Catalogue)
			local coins = if seconds > 0 then payout.quote(player, seconds) else nil
			if coins ~= nil then
				profile.Data = data
				payout.apply(player, coins)
			end
		end
	end
end

-- Asks Roblox whether the player owns this pass. A failed call counts as not owned, so it grants nothing.
-- UserOwnsGamePassAsync is the engine method (MarketplaceService reference); a started free trial is no confirmation.
function PurchaseService.confirmPass(player: Player, offer: any): boolean
	local ok, owned = pcall(function(): boolean
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, offer.robloxId)
	end)
	return ok and owned == true
end

-- Asks Roblox for every pass with an ID; only a confirmed pass is granted.
function PurchaseService.checkPasses(player: Player)
	for _, offer in Catalogue.offers do
		if offer.type == "pass" and offer.robloxId > 0 and PurchaseService.confirmPass(player, offer) then
			PurchaseService.grantPass(player, offer.id)
		end
	end
end

-- Join, after the profile loaded (Session.start): saved pass flags are cleared (a lost pass must not stay), the
-- paid-item policy is asked once, then the passes are checked.
function PurchaseService.join(player: Player)
	local profile = DataService.profileOf(player)
	if profile ~= nil then
		local data = table.clone(profile.Data)
		data.passes = {}
		profile.Data = data
	end
	PolicyService.paidItemsAllowed(player)
	PurchaseService.checkPasses(player)
end

-- The shop is shown only when the player may buy paid items (the policy answer of this session).
function PurchaseService.shopVisible(player: Player): boolean
	return PolicyService.paidItemsAllowed(player)
end

-- The Extras tab facts of this player (Core/Shop.extrasView); `playSeconds` is the time played in this session.
function PurchaseService.extras(player: Player, playSeconds: number): any
	local profile = DataService.profileOf(player)
	if profile == nil then
		return { shown = false, owned = {}, stock = 0 }
	end
	return Shop.extrasView(profile.Data, today(), Catalogue, PurchaseService.shopVisible(player), playSeconds, Upgrades)
end

-- Grid VIP: today's free Turbo Feed-in. The day is written only when the same Turbo the shop sells starts (the stock
-- is not full). False without a profile, without the pass, when it was taken today or when the stock is full.
function PurchaseService.claimFreeTurbo(player: Player): boolean
	local profile = DataService.profileOf(player)
	if profile == nil then
		return false
	end
	local data, reason = Shop.claimFreeTurbo(profile.Data, today())
	if reason ~= nil or not BoostService.buyTurbo(player) then
		return false
	end
	profile.Data = data
	return true
end

-- PromptGamePassPurchaseFinished: the event also fires when a free trial starts, so only a pass Roblox confirms is granted.
function PurchaseService.passFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	for _, offer in Catalogue.offers do
		if offer.type == "pass" and offer.robloxId > 0 and offer.robloxId == gamePassId then
			if PurchaseService.confirmPass(player, offer) then
				PurchaseService.grantPass(player, offer.id)
			end
		end
	end
end

-- Connects the callbacks. Called once from Main.server.
function PurchaseService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(PurchaseService.passFinished)
end

return PurchaseService
