-- Seed + gear shops. Every player has a personal stock that rerolls on a
-- shared clock (Config.RestockInterval). The roll is seeded by user + window so
-- rejoining can't reroll it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Rarity = require(Shared.Rarity)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)

local ShopService = {}

local boughtEvent = Instance.new("BindableEvent")
ShopService.Bought = boughtEvent.Event -- (player, kind, id)

local function window(): number
	return math.floor(os.time() / Config.RestockInterval)
end
ShopService.window = window

local function roll(userId: number, w: number, rerolls: number)
	local r = Random.new((userId % 2147483) * 7919 + w * 104729 + rerolls * 15485863)
	local seeds, gear = {}, {}
	for _, sp in ipairs(Species.List) do
		local tier = Rarity.get(sp.rarity)
		if r:NextNumber() < tier.stockChance then
			seeds[sp.id] = r:NextInteger(tier.stock[1], tier.stock[2])
		end
	end
	seeds.quartz = math.max(seeds.quartz or 0, 8)
	for _, g in ipairs(Gear.List) do
		if not g.notSold and g.stock then
			if r:NextNumber() < g.stock[1] then
				gear[g.id] = r:NextInteger(g.stock[2], g.stock[3])
			end
		end
	end
	return seeds, gear
end

-- Make sure the player's stock matches the current window; returns true if it changed.
function ShopService.refresh(player: Player, force: boolean?): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local stock = profile.data.stock
	local w = window()
	if stock.w ~= w or force then
		if stock.w ~= w then
			stock.r = 0
		end
		stock.w = w
		stock.seeds, stock.gear = roll(player.UserId, w, stock.r)
		Sync.set(player, "stock", stock)
		return true
	end
	return false
end

function ShopService.reroll(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	profile.data.stock.r += 1
	ShopService.refresh(player, true)
	Sync.notify(player, "🔄 Your shops have been restocked!", "good")
	return true
end

local function buy(player: Player, kind: string, id: string)
	local profile = DataService.get(player)
	if not profile or type(id) ~= "string" then
		return false, "Not loaded"
	end
	ShopService.refresh(player)
	local stock = profile.data.stock
	local def = (kind == "seed") and Species.get(id) or Gear.get(id)
	if not def or def.notSold then
		return false, "Unknown item"
	end
	local pool = (kind == "seed") and stock.seeds or stock.gear
	if (pool[id] or 0) <= 0 then
		return false, "Out of stock! Restocks soon."
	end
	if not Economy.spend(player, def.price) then
		return false, "Not enough coins!"
	end
	pool[id] -= 1
	if kind == "seed" then
		Economy.addSeed(player, id, 1)
		local stats = profile.data.stats
		if def.price > (stats.topPrice or 0) then
			stats.topPrice = def.price
			Sync.set(player, "stats", stats)
		end
	else
		Economy.addGear(player, id, 1)
	end
	Sync.set(player, "stock", stock)
	boughtEvent:Fire(player, kind, id)
	return true
end

function ShopService.start()
	Net.func("BuySeed").OnServerInvoke = function(player, id)
		return buy(player, "seed", id)
	end
	Net.func("BuyGear").OnServerInvoke = function(player, id)
		return buy(player, "gear", id)
	end
	DataService.Loaded:Connect(function(player)
		ShopService.refresh(player)
	end)
	-- Push fresh stock to everyone when the restock clock ticks over.
	task.spawn(function()
		local last = window()
		while true do
			task.wait(1)
			local w = window()
			if w ~= last then
				last = w
				for _, p in ipairs(Players:GetPlayers()) do
					if ShopService.refresh(p) then
						Sync.notify(p, "🌱 The Seed & Gear shops just restocked!", "good")
					end
				end
			end
		end
	end)
end

return ShopService
