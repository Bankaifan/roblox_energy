--!strict
-- PolicyService wrapper (Bauplan.md, sections 4 and 5): asks Roblox for the policy of a player once per session, on the
-- first use, and keeps the answer until the player leaves. A failed call counts as restricted, so the shop stays
-- hidden for that player. Only the paid-item rule is read: the MVP has no random items and no ads (Bauplan section 5).
local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")

local PolicyService = {}
local cache: { [Player]: boolean } = {}

-- True when this player may see and buy paid items. The Roblox call runs once per session (cached per player).
function PolicyService.paidItemsAllowed(player: Player): boolean
	local allowed = cache[player]
	if allowed == nil then
		local ok, info = pcall(function(): any
			return RobloxPolicy:GetPolicyInfoForPlayerAsync(player)
		end)
		allowed = ok and type(info) == "table" and info.ArePaidRandomItemsRestricted == false
		cache[player] = allowed
	end
	return allowed
end

-- Drops the cached answer of a player who left.
function PolicyService.forget(player: Player)
	cache[player] = nil
end

Players.PlayerRemoving:Connect(PolicyService.forget)

return PolicyService
