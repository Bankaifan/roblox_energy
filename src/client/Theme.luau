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
	["mode.forecast"] = "🔮",
	["mode.auto"] = "🤖",
	["tool.scythe"] = "🌾",
	["tool.rails"] = "📏",
	["tool.shovel"] = "🌊",
	["tool.hammer"] = "🔨",
	["tool.wrench"] = "🔧",
	["tool.drum"] = "🔌",
	["tool.tamper"] = "🧱",
	["tool.pliers"] = "🔗",
	["tab.sparks"] = "✨",
	["tab.production"] = "📊",
	["tab.extras"] = "🎁",
	["offer.pass"] = "🎟️",
	["offer.product"] = "🎁",
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

local ScreenFit = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("ScreenFit") :: ModuleScript
) :: any

function Theme.fitFactor(viewport: Vector2): number
	return ScreenFit.factor(viewport.X, viewport.Y)
end

-- Gives every top-level control of `gui` a UIScale that follows the viewport. A UIScale only scales the size (positions
-- and anchors stay), so a size that is relative to the screen (scale part) is divided by the factor and keeps its screen
-- share: a full-screen backdrop still covers the screen. Do not use it on a gui that scales itself (Market).
-- `base` is the unscaled Size the owner set, `written` the Size `apply` last wrote. The owner may set Size after the control
-- has its Parent, or resize it later, so a Size that is not `written` is taken as the new base (see `track`) at once,
-- not only at the next viewport change; otherwise that change would reset the control to its older Size.
type Entry = { control: GuiObject, base: UDim2, written: UDim2, scale: UIScale }

-- Gives every top-level control of `gui` a UIScale that follows the viewport. A UIScale only scales the size (positions
-- and anchors stay), so a size that is relative to the screen (scale part) is divided by the factor and keeps its screen
-- share: a full-screen backdrop still covers the screen. Do not use it on a gui that scales itself (Market).
function Theme.fitScreen(gui: ScreenGui)
	local camera = workspace.CurrentCamera :: Camera
	local tracked: { Entry } = {}
	local function apply(entry: Entry)
		local factor = Theme.fitFactor(camera.ViewportSize)
		local base = entry.base
		local function axis(part: UDim): UDim
			if part.Scale == 0 then
				return part
			end
			return UDim.new(part.Scale / factor, part.Offset / factor)
		end
		entry.scale.Scale = factor
		if base.X.Scale ~= 0 or base.Y.Scale ~= 0 then
			local size = UDim2.new(axis(base.X), axis(base.Y))
			-- Stored before the write: the Size signal fires on it and must see it as our own write.
			entry.written = size
			entry.control.Size = size
		else
			entry.written = base
		end
	end
	local function track(entry: Entry)
		entry.control:GetPropertyChangedSignal("Size"):Connect(function()
			if entry.control.Size ~= entry.written then
				entry.base = entry.control.Size
				apply(entry)
			end
		end)
	end
	local function attach(child: Instance)
		if not child:IsA("GuiObject") or child:FindFirstChildOfClass("UIScale") ~= nil then
			return
		end
		local scale = Instance.new("UIScale")
		scale.Name = "FitScale"
		scale.Parent = child
		local entry: Entry = { control = child, base = child.Size, written = child.Size, scale = scale }
		table.insert(tracked, entry)
		apply(entry)
		track(entry)
	end
	for _, child in gui:GetChildren() do
		attach(child)
	end
	gui.ChildAdded:Connect(attach)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, entry in tracked do
			apply(entry)
		end
	end)
end

return Theme
