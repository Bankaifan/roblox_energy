--!strict
-- PlotPublic (Bauplan.md, section 5): the counts, level and cosmetics of a plot, sent to all players at most once every
-- Effects.plotPublicSeconds per plot. Core/Cosmetics builds the message; this service only keeps the timing. Called once a
-- second for every run by Session.tick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Core"):WaitForChild("Cosmetics") :: ModuleScript) :: any
local Effects = require(Shared:WaitForChild("Config"):WaitForChild("Effects") :: ModuleScript) :: any
local DataService = require(script.Parent.DataService)

local PlotPublicService = {}
-- The server time of the last PlotPublic per player.
local sentAt: { [Player]: number } = {}

-- Sends the player's plot to all players when the last send is old enough. The owner's passes and chosen cosmetics come
-- from the profile; the level and the plant counts from the run state.
function PlotPublicService.tick(remotes: { [string]: RemoteEvent }, player: Player, state: any)
	local now = workspace:GetServerTimeNow()
	if not Cosmetics.publicDue(sentAt[player], now, Effects.plotPublicSeconds) then
		return
	end
	local profile = DataService.profileOf(player)
	if profile == nil then
		return
	end
	sentAt[player] = now
	local data = profile.Data
	remotes.PlotPublic:FireAllClients(
		Cosmetics.publicState(player.Name, state.level, state.plants, data.passes, data.cosmetics or {})
	)
end

-- Drops the timing of a player who left.
function PlotPublicService.forget(player: Player)
	sentAt[player] = nil
end

return PlotPublicService
