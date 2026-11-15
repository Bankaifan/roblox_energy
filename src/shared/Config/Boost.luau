--!strict
-- Boosters (Bauplan.md, sections 3 and 4). Product defaults until Daniel decides (Bauplan section 10): daily limits on,
-- stock at most 60 minutes. Change the numbers here only.
return {
	-- Generation (Sunshine Hour) or own income (Turbo Feed-in) is multiplied by this while a booster runs.
	-- Boosters do not stack in strength: with both running the factor is still this one value.
	factor = 2,
	sunshineSeconds = 600, -- Sunshine Hour: 10 minutes for every player on the server
	turboSeconds = 900, -- Turbo Feed-in: 15 minutes for one player
	stockMaxSeconds = 3600, -- queued plus running time may not exceed 60 minutes
	-- Roblox product IDs come from the Creator Hub in Milestone 3. 0 means "not set": the purchase prompt is not opened.
	products = {
		sunshine = 0,
		turbo = 0,
	},
}
