--!strict
-- Measurement points for the evaluation (Bauplan.md, section 7, M4): session length, first grid expansion, storage bought,
-- shop opens and purchases. Only counts and times in seconds are kept: no player id, name, receipt or product id.
-- Pure: the caller passes the clock in seconds and reads the report; nothing is stored or sent anywhere.
local Metrics = {}

export type Metrics = {
	startedAt: number,
	firstExpansionSeconds: number?, -- seconds after the start, set by the first grid expansion only
	storageBought: number,
	shopOpens: number,
	purchases: number,
}

export type Report = {
	sessionSeconds: number,
	firstExpansionSeconds: number?,
	storageBought: number,
	shopOpens: number,
	purchases: number,
}

function Metrics.new(now: number): Metrics
	return { startedAt = now, firstExpansionSeconds = nil, storageBought = 0, shopOpens = 0, purchases = 0 }
end

-- Only the first expansion counts; later ones do not change the time.
function Metrics.gridExpanded(metrics: Metrics, now: number)
	if metrics.firstExpansionSeconds == nil then
		metrics.firstExpansionSeconds = math.max(0, now - metrics.startedAt)
	end
end

function Metrics.storageBought(metrics: Metrics)
	metrics.storageBought += 1
end

function Metrics.shopOpened(metrics: Metrics)
	metrics.shopOpens += 1
end

function Metrics.purchased(metrics: Metrics)
	metrics.purchases += 1
end

-- The numbers of the session so far. A clock that goes backwards reads as no time passed.
function Metrics.report(metrics: Metrics, now: number): Report
	return {
		sessionSeconds = math.max(0, now - metrics.startedAt),
		firstExpansionSeconds = metrics.firstExpansionSeconds,
		storageBought = metrics.storageBought,
		shopOpens = metrics.shopOpens,
		purchases = metrics.purchases,
	}
end

return Metrics
