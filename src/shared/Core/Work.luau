--!strict
-- Hold timing check for land work (design 0018, issue 107). No clock of its own: the caller passes `now` in seconds.
-- One hold at a time per session; a hold counts only if it finishes on the target it began on, after at least
-- TOLERANCE x its duration.
export type Session = { target: string?, startedAt: number }

local Module = {}

Module.TOLERANCE = 0.9

function Module.new(): Session
	return { target = nil, startedAt = 0 }
end

-- Starts a hold on `target`. A new begin replaces an unfinished one (one hold at a time).
function Module.begin(session: Session, target: string, now: number)
	session.target = target
	session.startedAt = now
end

-- True only for the target the hold began on, at least TOLERANCE x `hold` seconds after `begin`. Every call ends the
-- current hold, so a failed finish needs a new begin.
function Module.finish(session: Session, target: string, now: number, hold: number): boolean
	local began = session.target
	local startedAt = session.startedAt
	session.target = nil
	if began == nil or began ~= target then
		return false
	end
	return now - startedAt >= Module.TOLERANCE * hold
end

return Module
