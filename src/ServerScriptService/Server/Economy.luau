-- Coins, inventories and every player multiplier in one place.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local DataService = require(script.Parent.DataService)
local Sync = require(script.Parent.Sync)

local Economy = {}

local inventoryChanged = Instance.new("BindableEvent")
Economy.InventoryChanged = inventoryChanged.Event -- (player)

Economy.GlobalSellBoost = 0 -- admin events can raise this

local function profileOf(player: Player)
	return DataService.get(player)
end

function Economy.hasPass(player: Player, key: string): boolean
	local p = profileOf(player)
	return p ~= nil and p.passes ~= nil and p.passes[key] == true
end

local function updateLeaderstat(player: Player, coins: number)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Coins")
	if v then
		v.Value = Format.short(coins)
	end
end

function Economy.coins(player: Player): number
	local p = profileOf(player)
	return p and p.data.coins or 0
end

function Economy.addCoins(player: Player, amount: number, earned: boolean?)
	local p = profileOf(player)
	if not p or amount ~= amount then
		return
	end
	amount = math.floor(amount)
	p.data.coins += amount
	if earned and amount > 0 then
		p.data.stats.earned += amount
	end
	Sync.set(player, "coins", p.data.coins)
	if earned then
		Sync.set(player, "stats", p.data.stats)
	end
	updateLeaderstat(player, p.data.coins)
end

function Economy.spend(player: Player, amount: number): boolean
	local p = profileOf(player)
	if not p or amount < 0 or p.data.coins < amount then
		return false
	end
	p.data.coins -= math.floor(amount)
	Sync.set(player, "coins", p.data.coins)
	updateLeaderstat(player, p.data.coins)
	return true
end

local function adjust(player: Player, field: string, id: string, n: number): boolean
	local p = profileOf(player)
	if not p then
		return false
	end
	local inv = p.data[field]
	local have = inv[id] or 0
	if have + n < 0 then
		return false
	end
	inv[id] = (have + n > 0) and (have + n) or nil
	Sync.set(player, field, inv)
	inventoryChanged:Fire(player)
	return true
end

function Economy.addSeed(player: Player, id: string, n: number?)
	return adjust(player, "seeds", id, n or 1)
end

function Economy.takeSeed(player: Player, id: string, n: number?)
	return adjust(player, "seeds", id, -(n or 1))
end

function Economy.addGear(player: Player, id: string, n: number?)
	return adjust(player, "gear", id, n or 1)
end

function Economy.takeGear(player: Player, id: string, n: number?)
	return adjust(player, "gear", id, -(n or 1))
end

function Economy.bagCapacity(player: Player): number
	return Config.BaseBagCapacity + (Economy.hasPass(player, "BigBag") and Config.BigBagBonus or 0)
end

function Economy.plantCap(player: Player): number
	return Config.BasePlantCap + (Economy.hasPass(player, "SuperGarden") and Config.SuperGardenBonus or 0)
end

function Economy.speedMult(player: Player): number
	return Economy.hasPass(player, "SpeedyGrowth") and Config.SpeedyGrowthMult or 1
end

function Economy.boostActive(player: Player, id: string): boolean
	local p = profileOf(player)
	local t = p and p.data.boosts[id]
	return t ~= nil and t > os.time()
end

function Economy.luckMult(player: Player): number
	local m = 1
	if Economy.hasPass(player, "LuckyGardener") then
		m *= Config.LuckyGardenerMult
	end
	if Economy.boostActive(player, "luck") then
		m *= 2
	end
	return m
end

function Economy.friendCount(player: Player): number
	local n = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and player:GetAttribute("Friend_" .. other.UserId) then
			n += 1
		end
	end
	return n
end

-- Breakdown table for UI + total multiplier.
function Economy.sellBreakdown(player: Player)
	local parts = {}
	local total = 1
	if Economy.hasPass(player, "VIP") then
		total += Config.VipSellBonus
		table.insert(parts, { "VIP", Config.VipSellBonus })
	end
	local friends = math.min(Economy.friendCount(player) * Config.FriendBoostPer, Config.FriendBoostMax)
	if friends > 0 then
		total += friends
		table.insert(parts, { "Friends", friends })
	end
	if Economy.GlobalSellBoost > 0 then
		total += Economy.GlobalSellBoost
		table.insert(parts, { "Event", Economy.GlobalSellBoost })
	end
	return total, parts
end

function Economy.sellMult(player: Player): number
	local m = Economy.sellBreakdown(player)
	return m
end

-- Scales Robux coin packs and rewards with how far the player has progressed.
function Economy.progressPrice(player: Player): number
	local p = profileOf(player)
	return p and math.max(p.data.stats.topPrice or 10, 10) or 10
end

return Economy
