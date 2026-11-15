--!strict
-- Boosters (Bauplan.md, sections 3 and 4): queue, expiry, the 60-minute stock cap and the factor.
return function(t, load)
	local Boost = load("Core/Boost")
	local Config = load("Config/Boost")
	local cap = Config.stockMaxSeconds
	local seconds = Config.sunshineSeconds

	-- Queue: a purchase during a running block waits behind it and starts when it ends.
	local timer = Boost.new()
	timer = Boost.buy(timer, 100, seconds, "Anna", cap)
	local status = Boost.status(timer, 100)
	t.truthy(status.active, "a purchase starts the booster at once")
	t.equal(status.ends, 100 + seconds, "it runs for 10 minutes")
	t.equal(status.buyer, "Anna", "the buyer is shown")
	local ok: boolean
	timer, ok = Boost.buy(timer, 200, seconds, "Ben", cap)
	t.truthy(ok, "a second purchase is accepted")
	status = Boost.status(timer, 200)
	t.equal(status.ends, 100 + seconds, "the second purchase waits for the first")
	t.equal(status.queued, seconds, "the second block is queued")
	status = Boost.status(timer, 100 + seconds + 50)
	t.equal(status.ends, 100 + 2 * seconds, "the queued block runs right after the first")
	t.equal(status.buyer, "Ben", "the buyer of the running block is shown")
	t.equal(status.queued, 0, "nothing is left in the queue")

	-- Expiry: after the last block the booster is off and the buyer is cleared.
	status = Boost.status(timer, 100 + 2 * seconds)
	t.truthy(not status.active, "the booster is off at its end time")
	t.equal(status.buyer, "", "no buyer after expiry")
	t.equal(Boost.remaining(timer, 100 + 2 * seconds + 1), 0, "no time is left after expiry")

	-- Several blocks run out in one jump of the clock: each starts where the previous one ended.
	local jumped = Boost.new()
	jumped = Boost.buy(jumped, 0, seconds, "Anna", cap)
	jumped = Boost.buy(jumped, 0, seconds, "Ben", cap)
	status = Boost.status(jumped, 2 * seconds + 1)
	t.truthy(not status.active, "two blocks queued at once are both over after 20 minutes")

	-- A purchase after expiry starts at once.
	local later = Boost.buy(Boost.new(), 0, seconds, "Anna", cap)
	later = Boost.buy(later, 1000, seconds, "Carl", cap)
	status = Boost.status(later, 1000)
	t.equal(status.ends, 1000 + seconds, "a purchase after expiry starts now")
	t.equal(status.buyer, "Carl", "the new buyer is shown")

	-- Cap: 60 minutes of stock in total. The seventh 10-minute purchase is refused and nothing changes.
	local full = Boost.new()
	for _ = 1, 6 do
		full, ok = Boost.buy(full, 0, seconds, "Anna", cap)
		t.truthy(ok, "the first six purchases fit into 60 minutes")
	end
	t.equal(Boost.remaining(full, 0), cap, "stock is 60 minutes")
	local refused, refusedOk = Boost.buy(full, 0, seconds, "Anna", cap)
	t.truthy(not refusedOk, "a purchase over 60 minutes is refused")
	t.equal(Boost.remaining(refused, 0), cap, "a refused purchase leaves the stock as it was")
	-- Time that runs out frees stock again: after the first block, 50 minutes are left, so one more fits.
	local freed, freedOk = Boost.buy(full, seconds, seconds, "Anna", cap)
	t.truthy(freedOk, "stock freed by a finished block can be bought again")
	t.equal(Boost.remaining(freed, seconds), cap, "the stock is back at 60 minutes")

	-- Purchases return a new timer; the one passed in is not changed.
	local base = Boost.new()
	local _, baseOk = Boost.buy(base, 0, seconds, "Anna", cap)
	t.truthy(baseOk, "the purchase is accepted")
	t.equal(base.ends, 0, "the timer passed in is not changed")

	-- Factor: a booster doubles, and two boosters at once do not stack in strength.
	t.equal(Boost.multiplier(false, false, Config.factor), 1, "no booster, no factor")
	t.equal(Boost.multiplier(true, false, Config.factor), Config.factor, "Sunshine Hour doubles")
	t.equal(Boost.multiplier(true, true, Config.factor), Config.factor, "Sunshine and Turbo do not stack in strength")
end
