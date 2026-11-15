--!strict
-- Timed boosters (Bauplan.md, section 3, Sunshine Hour, and section 4, Turbo Feed-in). A timer is the running block plus a
-- queue: a queued block starts exactly where the block before it ends. `now` is server time in seconds, so Lune and
-- Studio agree. Pure functions: nothing is changed in place.
export type Block = { seconds: number, buyer: string }
export type Timer = { ends: number, buyer: string, queue: { Block } }
export type Status = { active: boolean, ends: number, buyer: string, queued: number }

local Boost = {}

function Boost.new(): Timer
	return { ends = 0, buyer = "", queue = {} }
end

-- Starts the queued blocks whose time has come. Each one starts where the previous one ended, so no time is lost
-- between two blocks even if nobody asked for a while.
function Boost.advance(timer: Timer, now: number): Timer
	local result: Timer = { ends = timer.ends, buyer = timer.buyer, queue = table.clone(timer.queue) }
	while result.ends <= now and #result.queue > 0 do
		local block = table.remove(result.queue, 1) :: Block
		result.ends += block.seconds
		result.buyer = block.buyer
	end
	return result
end

-- Seconds left in stock: the running block plus everything queued.
function Boost.remaining(timer: Timer, now: number): number
	local result = Boost.advance(timer, now)
	local total = math.max(0, result.ends - now)
	for _, block in result.queue do
		total += block.seconds
	end
	return total
end

-- The status for the HUD: active while a block runs, with its end time, buyer and the seconds still queued behind it.
function Boost.status(timer: Timer, now: number): Status
	local result = Boost.advance(timer, now)
	local queued = 0
	for _, block in result.queue do
		queued += block.seconds
	end
	local active = result.ends > now
	return {
		active = active,
		ends = if active then result.ends else 0,
		buyer = if active then result.buyer else "",
		queued = queued,
	}
end

-- Adds `seconds` for `buyer`. A purchase while a block runs queues behind it; otherwise it starts now. It is refused
-- (and the timer returned unchanged) when the stock would go over `cap` seconds.
function Boost.buy(timer: Timer, now: number, seconds: number, buyer: string, cap: number): (Timer, boolean)
	local result = Boost.advance(timer, now)
	if Boost.remaining(result, now) + seconds > cap then
		return timer, false
	end
	if result.ends > now then
		table.insert(result.queue, { seconds = seconds, buyer = buyer })
	else
		result.ends = now + seconds
		result.buyer = buyer
	end
	return result, true
end

-- The factor a player gets: `factor` while any booster runs, 1 otherwise. Boosters do not stack in strength.
function Boost.multiplier(sunshine: boolean, turbo: boolean, factor: number): number
	if sunshine or turbo then
		return factor
	end
	return 1
end

return Boost
