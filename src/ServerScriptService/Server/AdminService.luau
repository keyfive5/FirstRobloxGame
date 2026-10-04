-- Chat commands for the game owner (and anyone while testing in Studio).
--   /coins 1000   /seed ruby 5   /gear sprinkler 2   /weather meteor_shower
--   /setweather aurora|clear (instant)   /restock   /growall   /strike [meteor_shower]   /announce text   /sellboost 50 10  (percent, minutes)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)

local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)
local GardenService = require(script.Parent.GardenService)
local ShopService = require(script.Parent.ShopService)
local WeatherService = require(script.Parent.WeatherService)

local AdminService = {}

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 254
end

local commands = {}
commands.coins = function(p, n)
	Economy.addCoins(p, tonumber(n) or 1000, false)
end
commands.seed = function(p, id, n)
	if Species.get(id or "") then
		Economy.addSeed(p, id, tonumber(n) or 1)
	end
end
commands.gear = function(p, id, n)
	if Gear.get(id or "") then
		Economy.addGear(p, id, tonumber(n) or 1)
	end
end
commands.weather = function(p, id)
	WeatherService.trigger(id or "glimmer_rain", p.DisplayName)
end
commands.setweather = function(_, id)
	WeatherService.force(id or "clear")
end
commands.strike = function(_, kind)
	WeatherService.strikeNow(kind)
end
commands.restock = function(p)
	ShopService.reroll(p)
end
commands.growall = function(p)
	GardenService.growAll(p)
end
commands.announce = function(_, ...)
	Sync.notifyAll("📢 " .. table.concat({ ... }, " "), "rare")
end
commands.sellboost = function(_, pct, minutes)
	local boost = (tonumber(pct) or 50) / 100
	local secs = (tonumber(minutes) or 10) * 60
	Economy.GlobalSellBoost = boost
	ReplicatedStorage:SetAttribute("SellBoost", boost)
	ReplicatedStorage:SetAttribute("SellBoostEnds", os.time() + secs)
	Sync.notifyAll(string.format("🎉 SELL BOOST! All gems sell for +%d%% for %d minutes!", boost * 100, secs / 60), "rare")
	task.delay(secs, function()
		if ReplicatedStorage:GetAttribute("SellBoostEnds") <= os.time() then
			Economy.GlobalSellBoost = 0
			ReplicatedStorage:SetAttribute("SellBoost", 0)
		end
	end)
end

function AdminService.run(player: Player, msg: string)
	if msg:sub(1, 1) ~= "/" or not AdminService.isAdmin(player) then
		return false
	end
	local args = string.split(msg:sub(2), " ")
	local cmd = table.remove(args, 1)
	local fn = commands[string.lower(cmd or "")]
	if fn then
		local ok, err = pcall(fn, player, table.unpack(args))
		if not ok then
			warn("[Admin]", err)
		end
		return true
	end
	return false
end

function AdminService.start()
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			AdminService.run(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return AdminService
