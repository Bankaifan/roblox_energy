--!strict
-- Client entry point: builds the HUD and connects it to the server messages. Holds no game state of its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Hud = require(script.Parent.Controllers.Hud)
local Market = require(script.Parent.Controllers.Market)
local PlotFx = require(script.Parent.Controllers.PlotFx)
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
snapshot.OnClientEvent:Connect(hud.snapshot)
delta.OnClientEvent:Connect(function(change: any)
	hud.delta(change)
	market.delta(change)
end)
env.OnClientEvent:Connect(hud.env)
welcomeMessage.OnClientEvent:Connect(welcome)
-- Only the market's "ShopPrompt" and the control board's "ControlPrompt" (made by PlotService) open the market popup; no message to the server is needed.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "ShopPrompt" then
		market.open(prompt)
	elseif prompt.Name == "ControlPrompt" then
		-- The control board opens the same popup on the storage tab, where the rule slots are.
		market.open(prompt, "storage")
	end
end)
ready:FireServer()
