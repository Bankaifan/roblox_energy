--!strict
-- The look of the client UI in one place: a power-grid palette (night-blue panels, electric yellow, grid green),
-- the fonts and the icon glyphs. HUD and popups take their colours from here, so they stay in one style.
local Theme = {}

Theme.colors = {
	backdrop = Color3.fromRGB(4, 8, 16), -- dims the world behind a popup
	window = Color3.fromRGB(16, 26, 44), -- popup body, HUD rows
	panel = Color3.fromRGB(24, 38, 62), -- tab buttons, pills
	card = Color3.fromRGB(30, 48, 78), -- offer cards
	cardDim = Color3.fromRGB(22, 32, 50), -- locked cards
	iconTile = Color3.fromRGB(12, 20, 36),
	stroke = Color3.fromRGB(58, 84, 124),
	accent = Color3.fromRGB(255, 200, 0), -- electric yellow: title, active tab, prices, selection
	energy = Color3.fromRGB(80, 210, 255), -- cyan: hints that lead somewhere, active settings
	good = Color3.fromRGB(60, 190, 80), -- grid green: buy, owned (the colour of a full battery)
	bad = Color3.fromRGB(226, 84, 84), -- close, missing coins
	disabled = Color3.fromRGB(70, 82, 104),
	text = Color3.fromRGB(240, 246, 255),
	textMuted = Color3.fromRGB(160, 178, 206),
	textDark = Color3.fromRGB(16, 22, 34), -- on yellow and green
}

Theme.fonts = {
	title = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	body = Enum.Font.GothamMedium,
}

Theme.corner = 10

-- Icon glyphs by card icon id (Core/ShopView); `fallback` covers an id without its own glyph.
Theme.icons = {
	fallback = "⚡",
	upgrade = "⚡",
	container = "📦",
	rule = "📋",
	["plant.1"] = "🔆",
	["plant.2"] = "💧",
	["plant.3"] = "🏠",
	["plant.4"] = "🌀",
	["plant.5"] = "🌞",
	["plant.6"] = "💨",
	["mode.charge"] = "🔋",
	["mode.sell"] = "💰",
	["mode.auto"] = "🤖",
	["tool.scythe"] = "🌾",
	["tool.rails"] = "📏",
	["tool.shovel"] = "🌊",
	["tool.hammer"] = "🔨",
	["tool.wrench"] = "🔧",
	["tool.drum"] = "🔌",
	["tool.tamper"] = "🧱",
	["tool.pliers"] = "🔗",
} :: { [string]: string }

function Theme.icon(id: string): string
	return Theme.icons[id] or Theme.icons.fallback
end

-- Rounds the corners of a control.
function Theme.round(control: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.corner)
	corner.Parent = control
end

-- Gives a control a thin outline and returns it, so its colour can follow a state.
function Theme.outline(control: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = control
	return stroke
end

return Theme
