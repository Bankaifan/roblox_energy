--!strict
-- Server boosters (Bauplan.md, sections 3 and 4): one Sunshine Hour for the whole server, one Turbo Feed-in per player.
-- The rules live in Core/Boost; this service keeps the timers in memory and answers Env and Session. The purchases
-- (ProcessReceipt, PurchaseService) call buySunshine and buyTurbo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boost = require(Shared:WaitForChild("Core"):WaitForChild("Boost") :: ModuleScript) :: any
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Boost") :: ModuleScript) :: any

local BoostService = {}
local sunshine: any = Boost.new()
local turbo: { [Player]: any } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Sunshine Hour for every player, bought by `buyer` (the name on the banner). False when the stock is full.
function BoostService.buySunshine(buyer: string): boolean
	local nextTimer, ok = Boost.buy(sunshine, now(), Config.sunshineSeconds, buyer, Config.stockMaxSeconds)
	sunshine = nextTimer
	return ok
end

-- Turbo Feed-in for one player. False when that player's stock is full.
function BoostService.buyTurbo(player: Player): boolean
	local timer = turbo[player] or Boost.new()
	local nextTimer, ok = Boost.buy(timer, now(), Config.turboSeconds, player.Name, Config.stockMaxSeconds)
	turbo[player] = nextTimer
	return ok
end

-- The Sunshine Hour now: active, end time (server time), buyer and the seconds queued behind it.
function BoostService.sunshineStatus(): any
	return Boost.status(sunshine, now())
end

-- Seconds of the player's own Turbo Feed-in left, 0 when off.
function BoostService.turboRemaining(player: Player): number
	local timer = turbo[player]
	if timer == nil then
		return 0
	end
	return Boost.remaining(timer, now())
end

-- The factor this player's generation gets this second: Config.factor while any booster runs, else 1.
function BoostService.multiplierFor(player: Player): number
	local sunshineOn = Boost.status(sunshine, now()).active
	return Boost.multiplier(sunshineOn, BoostService.turboRemaining(player) > 0, Config.factor)
end

function BoostService.forget(player: Player)
	turbo[player] = nil
end

-- Clears every booster. For the Studio test only.
function BoostService.reset()
	sunshine = Boost.new()
	table.clear(turbo)
end

return BoostService
