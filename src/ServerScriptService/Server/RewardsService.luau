-- Daily login streak, session playtime gifts, promo codes and the tutorial.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)

local RewardsService = {}

local Rewards = require(Shared.Rewards)
RewardsService.Daily = Rewards.Daily
RewardsService.Gifts = Rewards.Gifts

-- Codes are case-insensitive. Add new ones here for social media drops.
RewardsService.Codes = {
	RELEASE = { coins = 500, seeds = { amber = 3, rosequartz = 1 } },
	GEMS = { coins = 250, gear = { watering_can = 2 } },
	SPARKLE = { seeds = { amethyst = 1 } },
	THANKYOU = { coins = 1000, gear = { sprinkler = 1 } },
}

local sessionStart = {}
local giftsClaimed = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function give(player: Player, spec, label: string)
	local parts = {}
	if spec.coinsMult or spec.coins then
		local amount = Rewards.coins(spec, Economy.progressPrice(player))
		Economy.addCoins(player, amount, false)
		table.insert(parts, "$" .. Format.short(amount))
	end
	for id, n in pairs(spec.seeds or {}) do
		Economy.addSeed(player, id, n)
		local sp = Species.get(id)
		table.insert(parts, string.format("%dx %s Seed", n, sp and sp.name or id))
	end
	for id, n in pairs(spec.gear or {}) do
		Economy.addGear(player, id, n)
		local g = Gear.get(id)
		table.insert(parts, string.format("%dx %s", n, g and g.name or id))
	end
	Sync.notify(player, label .. table.concat(parts, ", "), "good")
end

function RewardsService.dailyStatus(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local d = profile.data.daily
	local t = today()
	local canClaim = d.last < t
	local streak = d.streak
	if canClaim and d.last < t - 1 then
		streak = 0 -- streak broken; next claim is day 1
	end
	return { canClaim = canClaim, streak = streak, nextDay = (streak % Config.DailyCycle) + 1, resetsIn = (t + 1) * 86400 - os.time() }
end

function RewardsService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local d = profile.data.daily
	local t = today()
	if d.last >= t then
		return false, "Come back tomorrow!"
	end
	if d.last < t - 1 then
		d.streak = 0
	end
	d.streak += 1
	d.last = t
	local day = ((d.streak - 1) % Config.DailyCycle) + 1
	give(player, RewardsService.Daily[day], string.format("🎁 Day %d reward: ", day))
	Sync.set(player, "daily", d)
	return true, day
end

function RewardsService.claimGift(player: Player, index: number)
	local need = Config.PlaytimeGifts[index]
	local start = sessionStart[player]
	if not need or not start then
		return false
	end
	giftsClaimed[player] = giftsClaimed[player] or {}
	if giftsClaimed[player][index] then
		return false, "Already claimed!"
	end
	if os.time() - start < need then
		return false, "Not ready yet!"
	end
	giftsClaimed[player][index] = true
	give(player, RewardsService.Gifts[index], "⏰ Gift: ")
	return true
end

function RewardsService.redeem(player: Player, code: string)
	local profile = DataService.get(player)
	if not profile or type(code) ~= "string" then
		return false, "Try again"
	end
	code = string.upper((code:gsub("%s", ""))):sub(1, 30)
	local spec = RewardsService.Codes[code]
	if not spec then
		return false, "That code doesn't exist (yet!)"
	end
	if profile.data.codes[code] then
		return false, "You already used this code!"
	end
	profile.data.codes[code] = true
	give(player, spec, "🎉 Code redeemed: ")
	return true
end

function RewardsService.start()
	Net.func("DailyStatus").OnServerInvoke = function(player)
		return RewardsService.dailyStatus(player)
	end
	Net.func("ClaimDaily").OnServerInvoke = function(player)
		return RewardsService.claimDaily(player)
	end
	Net.func("GiftStatus").OnServerInvoke = function(player)
		local start = sessionStart[player] or os.time()
		return { elapsed = os.time() - start, claimed = giftsClaimed[player] or {} }
	end
	Net.func("ClaimGift").OnServerInvoke = function(player, index)
		return RewardsService.claimGift(player, tonumber(index) or 0)
	end
	Net.func("Redeem").OnServerInvoke = function(player, code)
		return RewardsService.redeem(player, code)
	end
	Net.func("SetTutorial").OnServerInvoke = function(player, step)
		local profile = DataService.get(player)
		if profile and type(step) == "number" and step > profile.data.tutorial and (step <= 20 or step == 99) then
			profile.data.tutorial = math.floor(step)
			Sync.set(player, "tutorial", profile.data.tutorial)
		end
		return true
	end
	Net.func("SaveSettings").OnServerInvoke = function(player, settings)
		local profile = DataService.get(player)
		if profile and type(settings) == "table" then
			for _, k in ipairs({ "music", "sfx" }) do
				local v = tonumber(settings[k])
				if v then
					profile.data.settings[k] = math.clamp(v, 0, 1)
				end
			end
		end
		return true
	end
	DataService.Loaded:Connect(function(player, profile)
		sessionStart[player] = os.time()
		player:SetAttribute("SessionStart", sessionStart[player])
		-- Invite rewards: whoever invited this player gets a gift (once per friend).
		local ok, join = pcall(player.GetJoinData, player)
		local referrerId = ok and join and join.ReferredByPlayerId
		if referrerId and referrerId ~= 0 and referrerId ~= player.UserId then
			local referrer = Players:GetPlayerByUserId(referrerId)
			local rp = referrer and DataService.get(referrer)
			if rp then
				rp.data.referrals = rp.data.referrals or {}
				if not rp.data.referrals[tostring(player.UserId)] then
					rp.data.referrals[tostring(player.UserId)] = true
					give(referrer, { coinsMult = 10, min = 2000, gear = { sprinkler = 1 } }, "👥 " .. player.DisplayName .. " joined from your invite! ")
				end
			end
			if not profile.data.referredBy then
				profile.data.referredBy = referrerId
				give(player, { coins = 250, seeds = { amber = 2 } }, "👋 Welcome gift for joining a friend: ")
			end
		end
	end)
	Net.func("FavPrompted").OnServerInvoke = function(player)
		local profile = DataService.get(player)
		if profile and not profile.data.favPrompted then
			profile.data.favPrompted = true
			return true -- client may show the favorite prompt once
		end
		return false
	end
	-- Bank session playtime right before the final save.
	DataService.Releasing:Connect(function(player, profile)
		if sessionStart[player] then
			profile.data.stats.playtime += os.time() - sessionStart[player]
			sessionStart[player] = os.time()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			sessionStart[player] = nil
			giftsClaimed[player] = nil
		end)
	end)
end

function RewardsService.sessionSeconds(player: Player): number
	return sessionStart[player] and (os.time() - sessionStart[player]) or 0
end

return RewardsService
