--!strict
-- Visible cosmetics of a plot (Bauplan.md, sections 3 and 4): what other players see of a plot, as flags. Pure: the
-- caller passes the owned passes, the chosen cosmetics and the plot level; nothing is read from the game, the profile or
-- Roblox. This module only knows ids; the client draws the colours, and the server sends PlotPublic built here.
local Cosmetics = {}

-- The glow colours of the Neon Plants and the three plot themes, by id. The first of each is the default.
Cosmetics.NEON_COLOURS = { "green", "cyan", "magenta", "gold" }
Cosmetics.THEMES = { "classic", "desert", "night" }
-- The slots of SetCosmetic: the glow colour and the theme.
Cosmetics.SLOT_NEON = 1
Cosmetics.SLOT_THEME = 2

-- What a plot shows for the passes its owner has. neon is the chosen glow colour (nil without the pass); theme is the
-- chosen design ("classic" without the pass).
export type Flags = {
	founder: boolean, -- Founder Pack: the founder sign and the golden crank
	premium: boolean, -- Premium Tariff: the golden meter house
	vip: boolean, -- Grid VIP: the name tag and the glowing lines
	fireworks: boolean, -- Upgrade Fireworks: fireworks and a server message at each upgrade
	neon: string?, -- Neon Plants: the glow colour, nil without the pass
	theme: string, -- Plot Themes: the design
}

local function owns(passes: { [string]: any }, id: string): boolean
	return passes[id] == true
end

-- The chosen item of a slot when it is in the list, else nil. Saved keys may come back as text, so both are read.
local function chosen(choice: { [any]: any }, slot: number, list: { string }): string?
	local item = choice[slot]
	if item == nil then
		item = choice[tostring(slot)]
	end
	if type(item) == "string" and table.find(list, item) ~= nil then
		return item
	end
	return nil
end

-- The visual flags of a plot. A chosen colour or theme counts only with its pass and when it is in its list; otherwise
-- the default shows.
function Cosmetics.flags(passes: { [string]: any }, choice: { [any]: any }): Flags
	local neon: string? = nil
	if owns(passes, "neon") then
		neon = chosen(choice, Cosmetics.SLOT_NEON, Cosmetics.NEON_COLOURS) or Cosmetics.NEON_COLOURS[1]
	end
	local theme = Cosmetics.THEMES[1]
	if owns(passes, "themes") then
		theme = chosen(choice, Cosmetics.SLOT_THEME, Cosmetics.THEMES) or theme
	end
	return {
		founder = owns(passes, "founder"),
		premium = owns(passes, "premium"),
		vip = owns(passes, "grid_vip"),
		fireworks = owns(passes, "fireworks"),
		neon = neon,
		theme = theme,
	}
end

-- The prestige level as a whole number from 0. A missing, negative, NaN or infinite level counts as 0.
local function wholeLevel(value: any): number
	if type(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- The PlotPublic payload of one plot: the owner's name (the plot model carries it), the level, the count of each plant
-- (only numbers are copied) and the visual flags. Nothing else of the run leaves the server.
function Cosmetics.publicState(
	owner: string,
	level: any,
	plants: { [any]: any },
	passes: { [string]: any },
	choice: { [any]: any }
): { [string]: any }
	local counts: { [number]: number } = {}
	for index, count in plants do
		if type(index) == "number" and type(count) == "number" and count == count then
			counts[index] = math.floor(count)
		end
	end
	return {
		owner = owner,
		level = wholeLevel(level),
		plants = counts,
		cosmetics = Cosmetics.flags(passes, choice),
	}
end

-- PlotPublic goes out at most once per plot in `every` seconds (Effects.plotPublicSeconds). True when `last`, the time
-- of the previous send, is nil (none yet) or `every` seconds or more before `now`.
function Cosmetics.publicDue(last: number?, now: number, every: number): boolean
	return last == nil or now - last >= every
end

return Cosmetics
