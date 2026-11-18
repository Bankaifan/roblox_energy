--!strict
-- Tutorial per player (Core/Tutorial): the facts of the run decide the step, the step is saved in the profile and sent to
-- the client, which shows one line of text. Cranks and the opened market are counted here; everything else is read from
-- the run state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Core"):WaitForChild("Tutorial") :: ModuleScript
) :: any
local DataService = require(script.Parent.DataService)

type Entry = { progress: any, started: number, cranks: number, marketOpened: boolean }
local entries: { [Player]: Entry } = {}

local TutorialService = {}

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if entry == nil then
		local profile = DataService.profileOf(player)
		local data = if profile ~= nil then profile.Data else nil
		entry = {
			progress = {
				index = if data ~= nil and type(data.tutorial) == "number" then data.tutorial else 1,
				done = data ~= nil and data.tutorialDone == true,
			},
			started = os.clock(),
			cranks = 0,
			marketOpened = false,
		}
		entries[player] = entry
	end
	return entry :: Entry
end

local function save(player: Player, progress: any)
	local profile = DataService.profileOf(player)
	if profile ~= nil then
		profile.Data.tutorial = progress.index
		profile.Data.tutorialDone = progress.done
	end
end

-- Tells the client the current step ("" when the tutorial is done).
function TutorialService.send(remotes: { [string]: RemoteEvent }, player: Player)
	local progress = entryOf(player).progress
	remotes.Tutorial:FireClient(player, { id = Tutorial.current(progress) or "", index = progress.index })
end

function TutorialService.crank(player: Player)
	local entry = entryOf(player)
	entry.cranks += 1
end

function TutorialService.marketOpened(player: Player)
	entryOf(player).marketOpened = true
end

function TutorialService.skip(remotes: { [string]: RemoteEvent }, player: Player)
	local entry = entryOf(player)
	entry.progress = Tutorial.skip(entry.progress)
	save(player, entry.progress)
	TutorialService.send(remotes, player)
end

-- Once per second with the run state: moves on when the current step is done.
function TutorialService.observe(remotes: { [string]: RemoteEvent }, player: Player, state: any)
	local entry = entryOf(player)
	if entry.progress.done then
		return
	end
	local facts = Tutorial.facts(state, os.clock() - entry.started, entry.cranks, entry.marketOpened)
	local progress = Tutorial.step(entry.progress, facts)
	if progress.index ~= entry.progress.index or progress.done ~= entry.progress.done then
		entry.progress = progress
		save(player, progress)
		TutorialService.send(remotes, player)
	end
end

function TutorialService.forget(player: Player)
	entries[player] = nil
end

return TutorialService
