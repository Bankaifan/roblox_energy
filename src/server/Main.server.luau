--!strict
-- Server entry point: one RemoteEvent per message in ReplicatedStorage.Net, the run of each player, and the 1-second step.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net") :: ModuleScript) :: any
local Services = script.Parent:WaitForChild("Services")
local Session = require(Services.Session)
local Action = require(Services.Action)

local folder = Instance.new("Folder")
folder.Name = "Net"
folder.Parent = ReplicatedStorage
local remotes: { [string]: RemoteEvent } = {}
for name in Net.messages do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end

Action.start(remotes)
game:BindToClose(Session.close)
Players.PlayerAdded:Connect(Session.start)
Players.PlayerRemoving:Connect(function(player: Player)
	Session.stop(player)
	Action.forget(player)
end)
for _, player in Players:GetPlayers() do
	-- Each join waits for its profile; spawned so the others and the 1-second step do not wait.
	task.spawn(Session.start, player)
end

local last = os.clock()
while true do
	task.wait(1)
	local now = os.clock()
	Session.tick(remotes, now - last)
	last = now
end
