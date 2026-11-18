--!strict
-- Tutorial hotbar pointer (design tutorial-v2, section 4.4): the Roblox hotbar is CoreGui and cannot be styled, so this is an
-- own ScreenGui with a bobbing arrow and the tool's name above the hotbar strip. It shows on request, hides while a popup is
-- open and when the tool is already in the hand (the guide decides both and calls `show(nil)`).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local Locale = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Locale") :: ModuleScript
) :: any

local TutorialHotbar = {}

local BOB = 6 -- pixels of up and down
local ABOVE = 96 -- pixels above the bottom edge: clear of the hotbar strip

-- Returns `show(tool: string?, lang: string)`; nil hides the pointer.
function TutorialHotbar.build(): (string?, string) -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHotbar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Size = UDim2.fromOffset(220, 56)
	frame.Parent = gui

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Theme.fonts.body
	name.TextSize = 18
	name.TextColor3 = Theme.colors.accent
	name.TextStrokeTransparency = 0.4
	name.Parent = frame

	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Position = UDim2.fromScale(0, 0.5)
	glyph.Size = UDim2.fromScale(1, 0.5)
	glyph.Text = "▼"
	glyph.TextSize = 26
	glyph.TextColor3 = Theme.colors.accent
	glyph.TextStrokeTransparency = 0.3
	glyph.Parent = frame

	RunService.Heartbeat:Connect(function()
		if gui.Enabled then
			frame.Position = UDim2.new(0.5, 0, 1, -ABOVE + math.sin(os.clock() * 4) * BOB)
		end
	end)

	return function(tool: string?, lang: string)
		gui.Enabled = tool ~= nil
		if tool ~= nil then
			name.Text = Locale.t("tool." .. tool, lang)
		end
	end
end

return TutorialHotbar
