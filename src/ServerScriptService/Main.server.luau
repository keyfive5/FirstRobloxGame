-- Server bootstrap. Order matters: everything hooks DataService.Loaded before
-- DataService starts loading players.
local Server = script.Parent:WaitForChild("Server")

local DataService = require(Server.DataService)
local GardenService = require(Server.GardenService)

GardenService.init()

for _, name in ipairs({ "PlayerService", "ToolService", "ShopService", "SellService", "WeatherService", "MonetizationService", "RewardsService", "QuestService", "LeaderboardService", "AdminService" }) do
	local ok, err = pcall(function()
		require(Server[name]).start()
	end)
	if not ok then
		warn("[Main] failed to start " .. name .. ": " .. tostring(err))
	end
end
GardenService.start()
DataService.start()

-- Studio-only hook so test scripts can drive services: DevHook:Invoke("GardenService", "plant", player, ...)
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevHook"
	hook.OnInvoke = function(service: string, method: string, ...)
		local mod = require(Server[service])
		if method == "__tempProfile" then -- filming/testing: stop saving this player's data
			local profile = mod.get(...)
			if profile then
				profile.temporary = true
			end
			return profile ~= nil
		end
		if method == "__get" then
			local field = ...
			return mod[field]
		end
		return mod[method](...)
	end
	hook.Parent = game:GetService("ServerStorage")
end
print("[Grow a Gem Garden] server ready")
