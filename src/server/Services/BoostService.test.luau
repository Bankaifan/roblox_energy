--!strict
-- BoostService on the server (Bauplan.md, section 3): one Sunshine Hour for everyone, queue and 60-minute cap, the
-- owner's Turbo Feed-in, and the Env payload every client gets. Studio only: TestRunner runs it, because it needs the
-- server services. The boosters are cleared before and after, so no test booster reaches a real player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Boost") :: ModuleScript) :: any
local BoostService = require(script.Parent.BoostService) :: any
local Env = require(script.Parent.Env) :: any

return function(t)
	BoostService.reset()

	t.truthy(BoostService.buySunshine("Anna"), "the Sunshine Hour is bought")
	local status = BoostService.sunshineStatus()
	t.truthy(status.active, "the Sunshine Hour runs at once")
	t.equal(status.buyer, "Anna", "the banner names the buyer")
	t.truthy(BoostService.buySunshine("Ben"), "a second purchase is accepted")
	t.equal(BoostService.sunshineStatus().queued, Config.sunshineSeconds, "the second one waits in the queue")

	-- Env: every client gets the same booster state as the server holds.
	local payload = Env.payload({ id = "Mittag" }, { id = "Sonnig" })
	t.equal(payload.sunshineBuyer, "Anna", "Env carries the buyer of the running block")
	t.equal(payload.sunshineEnds, status.ends, "Env carries the end time")
	t.equal(payload.sunshineQueued, Config.sunshineSeconds, "Env carries the queued seconds")

	-- Cap: four more fit into 60 minutes, the next one is refused.
	for _ = 1, 4 do
		t.truthy(BoostService.buySunshine("Cara"), "purchases up to 60 minutes are accepted")
	end
	t.truthy(not BoostService.buySunshine("Cara"), "a purchase beyond 60 minutes is refused")

	-- Turbo Feed-in on its own (the Sunshine Hour is cleared): the owner gets the factor, nobody else does.
	BoostService.reset()
	local owner = { Name = "owner" } :: any
	local other = { Name = "other" } :: any
	t.equal(BoostService.turboRemaining(owner), 0, "no Turbo before the purchase")
	t.truthy(BoostService.buyTurbo(owner), "the Turbo Feed-in is bought")
	t.truthy(BoostService.turboRemaining(owner) > 0, "the owner has Turbo time")
	t.equal(BoostService.multiplierFor(owner), Config.factor, "the owner gets the factor")
	t.equal(BoostService.multiplierFor(other), 1, "the Turbo Feed-in does not help other players")
	BoostService.forget(owner)
	t.equal(BoostService.turboRemaining(owner), 0, "forgetting a player clears their Turbo")

	-- The Sunshine Hour gives the factor to everyone, the owner or not.
	BoostService.reset()
	t.truthy(BoostService.buySunshine("Anna"), "the Sunshine Hour is bought for the test")
	t.equal(BoostService.multiplierFor(other), Config.factor, "the Sunshine Hour gives the factor to others too")

	BoostService.reset()
end
