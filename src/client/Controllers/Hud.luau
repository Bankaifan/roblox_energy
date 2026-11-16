--!strict
-- HUD: shows the Snapshot, Delta and Env the server sends (coins, rate, storage, grid level, weather, goal), and its
-- buttons (language, crank, grid expansion) only send intents. No game rules here: the crank value and the grid
-- expansion come from Delta.view (GameCore.view). The shop is the market popup (Controllers/Market). Every label comes
-- from the Locale tables in the current language: the player's locale at the start, switched by the Language button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Locale = require(Config:WaitForChild("Locale") :: ModuleScript) :: any
local ShopView = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("ShopView") :: ModuleScript
) :: any
local BoostView = require(script.Parent.BoostView)
local Theme = require(script.Parent.Parent.Theme)

local Hud = {}

-- A control the player cannot use right now: its text stays readable, its background fades.
local DIMMED_TEXT = 0.3
local DIMMED_BACKGROUND = 0.6
-- The panel is at most this wide; on a narrow screen it shrinks to the screen width instead.
local PANEL_MAX_WIDTH = 300
-- Every row and button uses the same fixed text size. Long text wraps onto a second line and the row grows with it.
local ROW_TEXT = 14
local ROW_MIN_HEIGHT = 36
-- Inner padding: left and right it keeps text off the edge and off the scrollbar; top and bottom it gives wrapped lines air.
local ROW_SIDE_PADDING = 8
local ROW_VERTICAL_PADDING = 4

-- Gives a row or button the shared look: fixed text size, wrapped text, inner padding, and a height that grows with the text.
local function fitRow(control: GuiObject)
	control.Size = UDim2.new(1, 0, 0, ROW_MIN_HEIGHT)
	control.AutomaticSize = Enum.AutomaticSize.Y
	local minHeight = Instance.new("UISizeConstraint")
	minHeight.MinSize = Vector2.new(0, ROW_MIN_HEIGHT)
	minHeight.Parent = control
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, ROW_SIDE_PADDING)
	padding.PaddingRight = UDim.new(0, ROW_SIDE_PADDING)
	padding.PaddingTop = UDim.new(0, ROW_VERTICAL_PADDING)
	padding.PaddingBottom = UDim.new(0, ROW_VERTICAL_PADDING)
	padding.Parent = control
	control.BackgroundColor3 = Theme.colors.window
	control.BorderSizePixel = 0
	Theme.round(control)
end

local function label(parent: Instance, order: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 0.3
	text.Font = Theme.fonts.body
	text.TextColor3 = Theme.colors.text
	text.TextSize = ROW_TEXT
	text.TextWrapped = true
	text.LayoutOrder = order
	fitRow(text)
	text.Parent = parent
	return text
end

local function button(parent: Instance, caption: string, order: number, onClick: () -> ()): TextButton
	local control = Instance.new("TextButton")
	control.Text = caption
	control.Font = Theme.fonts.bold
	control.TextColor3 = Theme.colors.textDark
	control.TextSize = ROW_TEXT
	control.TextWrapped = true
	control.LayoutOrder = order
	fitRow(control)
	control.BackgroundColor3 = Theme.colors.accent
	control.Parent = parent
	control.Activated:Connect(onClick)
	return control
end

-- Dims a control the player cannot use right now; it still shows its caption, readable.
local function dim(control: TextButton, usable: boolean)
	control.TextTransparency = if usable then 0 else DIMMED_TEXT
	control.BackgroundTransparency = if usable then 0 else DIMMED_BACKGROUND
end

local function format(value: number): string
	return string.format("%.1f", value)
end

local short = ShopView.short

-- Crank energy per click: whole numbers as they are, otherwise two decimals.
local function energy(value: number): string
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	return string.format("%.2f", value)
end

-- Builds the HUD in the player's GUI. `net` is ReplicatedStorage.Net. Returns the handlers for the server messages,
-- and `language`, which gives the language in use (the welcome screen follows it).
function Hud.build(net: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	-- The language of every label: the player's locale at the start, then whatever the Language button chose.
	local lang: string = Locale.resolve((Players.LocalPlayer :: Player).LocaleId)
	local function t(key: string, args: { [string]: any }?): string
		return Locale.t(key, lang, args)
	end
	local frame = Instance.new("ScrollingFrame")
	-- Fills the screen minus the margin, at most PANEL_MAX_WIDTH wide; the list scrolls.
	frame.Size = UDim2.new(1, -32, 1, -32)
	frame.Position = UDim2.fromOffset(16, 16)
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = 6
	-- The scrollbar takes its own strip beside the rows, so it never covers their text.
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(PANEL_MAX_WIDTH, math.huge)
	widthLimit.Parent = frame
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	-- Each control gets the next layout order, so the list shows them top to bottom.
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Changes the language and paints every label again. Declared here, written below once the labels exist.
	local paint: () -> ()
	local language = button(frame, "", nextOrder(), function()
		lang = if lang == "en" then "de" else "en"
		paint()
	end)
	local coins = label(frame, nextOrder())
	local rate = label(frame, nextOrder())
	local storage = label(frame, nextOrder())
	local storageHint = label(frame, nextOrder())
	local grid = label(frame, nextOrder())
	local env = label(frame, nextOrder())
	-- The Sunshine Hour button and banner, right under the weather line.
	local boost = BoostView.build(frame, nextOrder, function(): string
		return lang
	end)
	local goal = label(frame, nextOrder())

	local function send(name: string, payload: any?)
		(net:WaitForChild(name) :: RemoteEvent):FireServer(payload)
	end
	-- The latest view from the server; buttons check it before they send.
	local latest: any = nil
	-- The last Snapshot, Delta and Env, kept so a language change can paint them again without waiting for the server.
	local lastSnapshot: any = nil
	local lastDelta: any = nil
	local lastEnv: any = nil

	local crank = button(frame, "", nextOrder(), function()
		send("Crank")
	end)
	local expand = button(frame, "", nextOrder(), function()
		if latest ~= nil and latest.goal ~= nil and latest.goal.allowed then
			send("Prestige")
		end
	end)

	-- Captions and dimming from the server's view: the crank value and the grid expansion.
	local function shop(view: any)
		crank.Text = t("shop.crank", { energy = energy(view.crank) })
		if view.goal ~= nil then
			goal.Text = t("goal.next", { required = short(view.goal.required), earned = short(view.goal.earned) })
			expand.Text = t("goal.expand", { sparks = view.goal.sparks })
			dim(expand, view.goal.allowed)
		else
			goal.Text = t("goal.done")
			expand.Text = t("goal.done")
			dim(expand, false)
		end
	end

	-- Each server message, painted from its data. Only the handlers below pass messages to the Boost view.
	local function storageText(charge: number)
		local fill = if latest ~= nil then latest.storage.fill else 0
		storage.Text = t("hud.storage", { value = format(charge), percent = math.floor(fill * 100 + 0.5) })
	end
	local function applySnapshot(state: any)
		coins.Text = t("hud.coins", { value = format(state.coins) })
		storageText(state.storage.charge)
		grid.Text = t("hud.gridLevel", { level = state.level })
	end
	local function applyDelta(change: any)
		latest = change.view
		coins.Text = t("hud.coins", { value = format(change.coins) })
		rate.Text = t("hud.rate", { value = format(change.rate) })
		storageText(change.charge)
		shop(change.view)
	end
	local function applyEnv(change: any)
		env.Text = t("phase." .. change.phase) .. " / " .. t("weather." .. change.weather)
	end

	-- Sets every caption in the current language, then paints the last server data in it. The server data is
	-- painted again on purpose: shop, storage and env texts are not kept anywhere else.
	paint = function()
		language.Text = t("hud.language", { name = t("language." .. lang) })
		crank.Text = t("action.crank")
		storageHint.Text = t("hud.storageHint")
		expand.Text = t("action.expand")
		if lastSnapshot ~= nil then
			applySnapshot(lastSnapshot)
		end
		if lastDelta ~= nil then
			applyDelta(lastDelta)
		end
		if lastEnv ~= nil then
			applyEnv(lastEnv)
		end
		boost.relabel()
	end
	paint()

	return {
		language = function(): string
			return lang
		end,
		snapshot = function(state: any)
			lastSnapshot = state
			applySnapshot(state)
		end,
		delta = function(change: any)
			lastDelta = change
			applyDelta(change)
			boost.delta(change)
		end,
		env = function(change: any)
			lastEnv = change
			applyEnv(change)
			boost.env(change)
		end,
	}
end

return Hud
