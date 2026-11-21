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
	themed: boolean, -- Plot Themes owned: the plot shows the design (ground, fence and sign)
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
		themed = owns(passes, "themes"),
	}
end

-- The prestige level as a whole number from 0. A missing, negative, NaN or infinite level counts as 0.
local function wholeLevel(value: any): number
	if type(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- The pass a slot needs and its list of items.
local SLOTS = {
	[Cosmetics.SLOT_NEON] = { pass = "neon", items = Cosmetics.NEON_COLOURS },
	[Cosmetics.SLOT_THEME] = { pass = "themes", items = Cosmetics.THEMES },
}

-- SetCosmetic: the choice with `item` set in `slot`, or nil when the slot is unknown, the pass is not owned or the item
-- is not in the slot's list. Keys are kept as text (what a profile saves); the given choice is not changed.
function Cosmetics.choose(
	passes: { [string]: any },
	choice: { [any]: any },
	slot: number,
	item: string
): { [string]: string }?
	local entry = SLOTS[slot]
	if entry == nil or not owns(passes, entry.pass) or table.find(entry.items, item) == nil then
		return nil
	end
	local result: { [string]: string } = {}
	for key, value in choice do
		if type(value) == "string" then
			result[tostring(key)] = value
		end
	end
	result[tostring(slot)] = item
	return result
end

-- The item after `current` in the slot's list (the first when `current` is not in it); nil for an unknown slot.
function Cosmetics.nextItem(slot: number, current: string?): string?
	local entry = SLOTS[slot]
	if entry == nil then
		return nil
	end
	local at = if current ~= nil then table.find(entry.items, current) else nil
	return entry.items[((at or 0) % #entry.items) + 1]
end

-- RGB (0 to 255) of each glow colour.
local NEON_RGB = {
	green = { 60, 255, 120 },
	cyan = { 60, 230, 255 },
	magenta = { 255, 60, 220 },
	gold = { 255, 200, 40 },
}

function Cosmetics.neonRgb(id: string): { number }
	return NEON_RGB[id] or NEON_RGB[Cosmetics.NEON_COLOURS[1]]
end

-- The three designs of Plot Themes: ground (the border strip), fence (posts and rails) and sign (the name board), RGB.
local THEME_LOOKS = {
	classic = { ground = { 96, 150, 70 }, fence = { 150, 110, 70 }, sign = { 190, 150, 100 } },
	desert = { ground = { 214, 180, 120 }, fence = { 170, 100, 60 }, sign = { 232, 120, 70 } },
	night = { ground = { 40, 56, 96 }, fence = { 70, 80, 120 }, sign = { 20, 28, 56 } },
}

function Cosmetics.themeLook(id: string): { ground: { number }, fence: { number }, sign: { number } }
	return THEME_LOOKS[id] or THEME_LOOKS[Cosmetics.THEMES[1]]
end

-- Upgrade Fireworks: true when a grid expansion happened (the level went up) and the owner has the pass.
function Cosmetics.fireworksDue(before: any, after: any, fireworks: boolean): boolean
	return fireworks and wholeLevel(after) > wholeLevel(before)
end

-- The server message of an expansion with fireworks.
function Cosmetics.expansionNotice(owner: string, level: any): string
	return `{owner} expanded the grid to level {wholeLevel(level)}!`
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
