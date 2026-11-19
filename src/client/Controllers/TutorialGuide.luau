--!strict
-- Tutorial guide (design tutorial-v2, section 4.6): collects the step id from the server, the last Delta (coins, rate, view),
-- the tool in the hand and the market popup, asks Core/TutorialView what to show and drives the HUD line, the world arrow, the
-- hotbar pointer, the market highlight and the expand pulse. Presentation only; nothing here is trusted by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local TutorialView = require(Shared:WaitForChild("Core"):WaitForChild("TutorialView") :: ModuleScript) :: any
local Upgrades = require(Config:WaitForChild("Upgrades") :: ModuleScript) :: any
local Land = require(Config:WaitForChild("Land") :: ModuleScript) :: any

local TutorialGuide = {}

local DONE_SECONDS = 12 -- the closing line
local NUDGE_QUIET = 10 -- no nudge this soon after a step change
local NUDGE_REPEAT = 120 -- seconds between two shows of the same nudge
local NUDGE_SHOWS = 3 -- per session
local NUDGE_SECONDS = 8
local SILENT = { grow = true, expand = true } -- steps whose silence is on purpose (no nudges)

type Parts = {
	hud: any,
	market: any,
	pointAt: (string) -> (),
	hotbar: (string?, string) -> (),
}

function TutorialGuide.build(parts: Parts): { tutorial: (any) -> (), delta: (any) -> () }
	local stepId = ""
	local lastId = ""
	local stepSince = os.clock()
	local latest: any = nil -- the last Delta
	local hand: string? = nil
	local nudges: { [string]: { shows: number, last: number } } = {}
	local nudgeUntil = 0
	local nudgeKey = ""
	local doneUntil = 0
	local player = Players.LocalPlayer :: Player

	local function refresh()
		local now = os.clock()
		if doneUntil > 0 then
			if now < doneUntil then
				return
			end
			doneUntil = 0
			parts.hud.tutorialLine("", nil, false)
		end
		if stepId == "" or latest == nil then
			parts.pointAt("")
			parts.hotbar(nil, parts.hud.language())
			parts.market.highlight(nil)
			parts.hud.pulse("expand", false)
			return
		end
		local popup = parts.market.state()
		local input = {
			coins = latest.coins,
			rate = latest.rate,
			view = latest.view,
			upgrades = Upgrades,
			land = Land,
			hand = hand,
			popup = if popup.open then popup.tab else nil,
		}
		local shown = TutorialView.present(stepId, input)
		if shown.key == nil and not SILENT[stepId] and now - stepSince >= NUDGE_QUIET then
			local nudge = TutorialView.nudge(input)
			if nudge ~= nil and nudge.key ~= nil then
				local record = nudges[nudge.key] or { shows = 0, last = -math.huge }
				if now < nudgeUntil and nudgeKey == nudge.key then
					shown = nudge
				elseif record.shows < NUDGE_SHOWS and now - record.last >= NUDGE_REPEAT then
					record.shows += 1
					record.last = now
					nudges[nudge.key] = record
					nudgeKey = nudge.key
					nudgeUntil = now + NUDGE_SECONDS
					shown = nudge
				end
			end
		end
		parts.hud.tutorialLine(shown.key or "", shown.args)
		-- No world or hotbar pointer while a popup is open; inside the market only the tab and card outline show.
		local open = popup.open
		parts.pointAt(if open then "" else shown.target or "")
		parts.hotbar(if open or shown.hotbar == hand then nil else shown.hotbar, parts.hud.language())
		parts.market.highlight(
			if open and (shown.tab ~= nil or shown.card ~= nil) then { tab = shown.tab, card = shown.card } else nil
		)
		parts.hud.pulse("expand", shown.button == "expand")
	end

	-- The tool in the hand: the Tool child of the character, named by its ToolId attribute.
	local function watch(character: Model)
		local function look()
			hand = nil
			for _, child in character:GetChildren() do
				if child:IsA("Tool") then
					hand = child:GetAttribute("ToolId") :: string?
				end
			end
			refresh()
		end
		character.ChildAdded:Connect(look)
		character.ChildRemoved:Connect(look)
		look()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character ~= nil then
		watch(player.Character)
	end

	-- The popup can open or change tab without a message: look a few times a second.
	task.spawn(function()
		while true do
			task.wait(0.25)
			refresh()
		end
	end)

	return {
		tutorial = function(change: any)
			stepId = change.id
			if stepId ~= lastId then
				if lastId == "expand" and stepId == "" then
					-- The first expansion finished the tutorial: one closing line (a skip never shows it).
					parts.hud.tutorialLine("tutorial.done", nil, true)
					doneUntil = os.clock() + DONE_SECONDS
				end
				stepSince = os.clock()
				lastId = stepId
			end
			refresh()
		end,
		delta = function(change: any)
			latest = change
			refresh()
		end,
	}
end

return TutorialGuide
