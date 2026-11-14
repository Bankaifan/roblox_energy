--!strict
-- Saves the run of each player (Bauplan.md, "Speichern"): one ProfileStore profile per player, with a session lock.
-- load starts the session and migrates the saved profile (Migrations/Steps); sync copies the run into the profile
-- before ProfileStore's autosave; release saves and unlocks on leave and on shutdown. In Studio the Mock store is used,
-- so no real save is written. A live server uses the DataStore of STORE_NAME.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Core"):WaitForChild("Data") :: ModuleScript) :: any
local Steps = require(Shared:WaitForChild("Migrations"):WaitForChild("Steps") :: ModuleScript) :: any
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore) :: any

local STORE_NAME = "PowerGrid_Profiles"

local store = ProfileStore.New(STORE_NAME, Data.template())
if RunService:IsStudio() then
	store = store.Mock
end

local DataService = {}
local profiles: { [Player]: any } = {}
local unsaved = 0

-- Writes the run into the profile. The other fields (purchases, grants, settings ...) are kept.
local function write(profile: any, state: any)
	profile.Data = Data.fromState(state, profile.Data)
	profile.Data.lastSeen = os.time()
end

-- Starts the session of a player and loads the profile. Returns the run state and the seconds away since the last
-- save. Returns nil when the profile cannot be loaded (no session is held then) or the player left while loading.
function DataService.load(player: Player): (any?, number)
	local profile = store:StartSessionAsync(`player-{player.UserId}`, {
		Cancel = function(): boolean
			return player.Parent == nil
		end,
	})
	if profile == nil then
		return nil, 0
	end
	local migrated, reason = Data.migrate(profile.Data, Steps)
	if migrated == nil then
		warn(`[DataService] profile of {player.Name} not loaded: {reason}`)
		profile:EndSession()
		return nil, 0
	end
	profile.Data = migrated
	profiles[player] = profile
	return Data.toState(migrated), Data.awaySeconds(migrated.lastSeen, os.time())
end

-- Copies the run into the profile now, so the next autosave writes it.
function DataService.sync(player: Player, state: any)
	local profile = profiles[player]
	if profile ~= nil and profile:IsActive() then
		write(profile, state)
	end
end

-- Writes the last run, saves the profile and unlocks it. state may be nil when nothing changed since the load.
-- DataService.flush waits for the save.
function DataService.release(player: Player, state: any?)
	local profile = profiles[player]
	profiles[player] = nil
	if profile == nil or not profile:IsActive() then
		return
	end
	if state ~= nil then
		write(profile, state)
	end
	unsaved += 1
	local connection: any
	connection = profile.OnAfterSave:Connect(function()
		connection:Disconnect()
		unsaved -= 1
	end)
	profile:EndSession()
end

-- Waits until the saves started by release are done, for at most `seconds` (BindToClose allows about 30 s).
function DataService.flush(seconds: number)
	local deadline = os.clock() + seconds
	while unsaved > 0 and os.clock() < deadline do
		task.wait()
	end
end

return DataService
