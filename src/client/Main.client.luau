--!strict
-- Client entry point: builds the HUD and connects it to the server messages. Holds no game state of its own.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hud = require(script.Parent.Controllers.Hud)
local WelcomeScreen = require(script.Parent.WelcomeScreen)

local net = ReplicatedStorage:WaitForChild("Net")
local hud = Hud.build(net)
local welcome = WelcomeScreen.build(hud.language)
local snapshot = net:WaitForChild("Snapshot") :: RemoteEvent
local delta = net:WaitForChild("Delta") :: RemoteEvent
local env = net:WaitForChild("Env") :: RemoteEvent
local welcomeMessage = net:WaitForChild("Welcome") :: RemoteEvent
local ready = net:WaitForChild("Ready") :: RemoteEvent
snapshot.OnClientEvent:Connect(hud.snapshot)
delta.OnClientEvent:Connect(hud.delta)
env.OnClientEvent:Connect(hud.env)
welcomeMessage.OnClientEvent:Connect(welcome)
ready:FireServer()
