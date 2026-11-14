--!strict
-- Client messages (Bauplan, section 5): the per-player limit of each message, Net.check, then Session.
-- More than 30 messages in one second is logged; the third such second removes the player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net") :: ModuleScript) :: any
local Session = require(script.Parent.Session)

local FLOOD_LIMIT = 30
local FLOOD_STRIKES = 3

type Window = { start: number, count: number }
local windows: { [Player]: { [string]: Window } } = {}
local strikes: { [Player]: number } = {}
local Action = {}

-- Counts one message under `key` in the current window of `per` seconds; returns the count so far.
local function tally(player: Player, key: string, per: number): number
	local perPlayer = windows[player] or {}
	windows[player] = perPlayer
	local now = os.clock()
	local window = perPlayer[key]
	if window == nil or now - window.start >= per then
		window = { start = now, count = 0 }
		perPlayer[key] = window
	end
	window.count += 1
	return window.count
end

local function receive(remotes: { [string]: RemoteEvent }, player: Player, name: string, limit: any, payload: any)
	local count = tally(player, "all", 1)
	if count == FLOOD_LIMIT + 1 then
		strikes[player] = (strikes[player] or 0) + 1
		warn(`{player.Name} sent more than {FLOOD_LIMIT} messages in a second ({strikes[player]} of {FLOOD_STRIKES})`)
		if strikes[player] >= FLOOD_STRIKES then
			player:Kick("Too many messages.")
		end
	end
	if count > FLOOD_LIMIT or tally(player, name, limit.per) > limit.max then
		return
	end
	local ok, action = Net.check(name, payload)
	if not ok then
		return
	end
	if action.type == "Ready" then
		Session.ready(remotes, player)
	else
		Session.apply(remotes, player, action)
	end
end

-- Connects every client message of Net to its RemoteEvent.
function Action.start(remotes: { [string]: RemoteEvent })
	for name, message in Net.messages do
		if message.direction == "client" then
			remotes[name].OnServerEvent:Connect(function(player: Player, payload: any)
				receive(remotes, player, name, message.limit, payload)
			end)
		end
	end
end

-- Drops the counters of a player who left.
function Action.forget(player: Player)
	windows[player] = nil
	strikes[player] = nil
end

return Action
