--!strict
-- Client entry point: builds the HUD and connects it to the server messages. Holds no game state of its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Hud = require(script.Parent.Controllers.Hud)
local Market = require(script.Parent.Controllers.Market)
local PlotFx = require(script.Parent.Controllers.PlotFx)
local TutorialArrow = require(script.Parent.Controllers.TutorialArrow)
local TutorialGuide = require(script.Parent.Controllers.TutorialGuide)
local TutorialHotbar = require(script.Parent.Controllers.TutorialHotbar)
local WelcomeScreen = require(script.Parent.WelcomeScreen)
local LeaderboardScreen = require(script.Parent.LeaderboardScreen)

PlotFx.start()
local net = ReplicatedStorage:WaitForChild("Net")
local hud = Hud.build(net)
local market = Market.build(net, hud.language)
local welcome = WelcomeScreen.build(hud.language)
LeaderboardScreen.build(net, hud.language)
local snapshot = net:WaitForChild("Snapshot") :: RemoteEvent
local delta = net:WaitForChild("Delta") :: RemoteEvent
local env = net:WaitForChild("Env") :: RemoteEvent
local welcomeMessage = net:WaitForChild("Welcome") :: RemoteEvent
local ready = net:WaitForChild("Ready") :: RemoteEvent
local plotPublic = net:WaitForChild("PlotPublic") :: RemoteEvent
local tutorial = net:WaitForChild("Tutorial") :: RemoteEvent
local marketOpened = net:WaitForChild("MarketOpened") :: RemoteEvent
snapshot.OnClientEvent:Connect(hud.snapshot)
local guide = TutorialGuide.build({
	hud = hud,
	market = market,
	pointAt = TutorialArrow.build(),
	hotbar = TutorialHotbar.build(),
})
delta.OnClientEvent:Connect(function(change: any)
	hud.delta(change)
	market.delta(change)
	guide.delta(change)
end)
env.OnClientEvent:Connect(hud.env)
tutorial.OnClientEvent:Connect(function(change: any)
	hud.tutorial(change)
	guide.tutorial(change)
end)
welcomeMessage.OnClientEvent:Connect(welcome)
-- PlotPublic (the other plots' cosmetics) is sent to everyone; nothing draws it yet. A listener keeps the remote queue from filling up.
plotPublic.OnClientEvent:Connect(function() end)
-- Only the market's "ShopPrompt" and the control board's "ControlPrompt" (made by PlotService) open the market popup; no message to the server is needed.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "ShopPrompt" then
		market.open(prompt)
		marketOpened:FireServer()
	elseif prompt.Name == "ControlPrompt" then
		-- The control board opens the same popup on the storage tab, where the rule slots are.
		market.open(prompt, "storage")
	elseif prompt.Name == "ControlInfo" then
		market.open(prompt, "production")
	end
end)
ready:FireServer()
