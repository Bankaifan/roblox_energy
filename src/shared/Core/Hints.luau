--!strict
-- Purchase hints (Bauplan.md, section 4, 'Platz im Spielverlauf'): which hint may show where and when. Pure functions:
-- the caller passes every fact in `state`, nothing is read from the game, the profile or Roblox. A hint is never a
-- pop-up or a countdown; it only says whether the screen may show its line.
export type Hint = "founder" | "smartHub" | "premium" | "vip" | "longMeter"
export type Place = "shop" | "rules" | "market" | "welcome"
export type State = {
	place: Place, -- where the player is: the shop, the rules menu, the market terminal or the welcome screen
	playSeconds: number, -- seconds of play; no hint before the first hint minute (Config/Shop)
	storageBought: boolean, -- Speicher bought (U17 Home Battery)
	controlBought: boolean, -- Regelzentrale bought (U21 Control Center)
	gridLevel: number, -- Netz-Stufe, 0 before the first grid expansion
	offlineCapped: boolean, -- the time away reached the offline cap
	owned: { [string]: boolean }, -- passes the player owns, keyed by hint
}

local Hints = {}

-- The place and the fact each hint needs, besides the minute and the pass not being owned.
local function condition(hint: Hint, state: State): boolean
	if hint == "founder" then
		return state.place == "shop" and state.storageBought
	elseif hint == "smartHub" then
		return state.place == "rules" and state.controlBought
	elseif hint == "premium" then
		return state.place == "market" and state.gridLevel >= 1
	elseif hint == "vip" then
		return state.place == "shop" and state.gridLevel >= 2
	elseif hint == "longMeter" then
		return state.place == "welcome" and state.offlineCapped
	end
	return false
end

-- True when `hint` may show now: from `firstSeconds` of play on, in its place, once its fact holds, and never for a pass
-- the player already owns.
function Hints.allowed(hint: Hint, state: State, firstSeconds: number): boolean
	if state.playSeconds < firstSeconds or state.owned[hint] then
		return false
	end
	return condition(hint, state)
end

return Hints
