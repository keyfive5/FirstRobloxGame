-- Daily quests: progress from gameplay events, claimable rewards, and a bonus
-- for finishing all three. Rerolls automatically each new day.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Quests)
local Species = require(Shared.Species)
local Rarity = require(Shared.Rarity)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)
local GardenService = require(script.Parent.GardenService)
local SellService = require(script.Parent.SellService)
local ShopService = require(script.Parent.ShopService)
local RewardsService = require(script.Parent.RewardsService)

local QuestService = {}

local dirty = {}

local function ensure(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local q = profile.data.quests
	local today = Quests.day()
	if q.day ~= today then
		q.day = today
		q.list = Quests.roll(player.UserId, today, Economy.progressPrice(player))
		q.bonus = false
		dirty[player] = true
	end
	return q
end

local function progress(player: Player, event: string, amount: number)
	local q = ensure(player)
	if not q then
		return
	end
	for _, entry in ipairs(q.list) do
		local def = Quests.ById[entry.id]
		if def and def.event == event and entry.p < entry.target then
			local before = entry.p
			entry.p = math.min(entry.target, entry.p + amount)
			dirty[player] = true
			if before < entry.target and entry.p >= entry.target then
				Sync.notify(player, "📜 Quest complete! Claim your reward in Quests.", "good")
			end
		end
	end
end
QuestService.progress = progress

local function claim(player: Player, index: number)
	local q = ensure(player)
	local entry = q and q.list[index]
	if not entry or entry.c or entry.p < entry.target then
		return false
	end
	entry.c = true
	RewardsService.give(player, Quests.Rewards[index], "📜 Quest reward: ")
	dirty[player] = true
	return true
end

local function claimBonus(player: Player)
	local q = ensure(player)
	if not q or q.bonus then
		return false
	end
	for _, entry in ipairs(q.list) do
		if not entry.c then
			return false
		end
	end
	q.bonus = true
	RewardsService.give(player, Quests.Bonus, "🏆 All quests done! ")
	local profile = DataService.get(player)
	local t = os.time()
	profile.data.boosts.luck = math.max(profile.data.boosts.luck or 0, t) + Quests.Bonus.luckMinutes * 60
	Sync.set(player, "boosts", profile.data.boosts)
	dirty[player] = true
	return true
end

function QuestService.start()
	GardenService.Harvested:Connect(function(player, gem)
		progress(player, "harvest", 1)
		if gem.m and #gem.m > 0 then
			progress(player, "harvestMutated", 1)
		end
		local sp = Species.get(gem.s)
		if sp and Rarity.rank(sp.rarity) >= Rarity.rank("Rare") then
			progress(player, "harvestRare", 1)
		end
	end)
	GardenService.Planted:Connect(function(player)
		progress(player, "plant", 1)
	end)
	GardenService.GearUsed:Connect(function(player)
		progress(player, "gear", 1)
	end)
	SellService.Sold:Connect(function(player, total)
		progress(player, "sellValue", math.floor(total))
	end)
	ShopService.Bought:Connect(function(player, kind)
		if kind == "seed" then
			progress(player, "buySeed", 1)
		end
	end)
	Net.func("ClaimQuest").OnServerInvoke = function(player, index)
		return claim(player, tonumber(index) or 0)
	end
	Net.func("ClaimQuestBonus").OnServerInvoke = function(player)
		return claimBonus(player)
	end
	DataService.Loaded:Connect(function(player)
		ensure(player)
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	-- playtime minutes + batched syncing
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			if tick % 60 == 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					progress(p, "minutes", 1)
				end
			end
			for p in pairs(dirty) do
				local profile = DataService.get(p)
				if profile then
					ensure(p)
					Sync.set(p, "quests", profile.data.quests)
				end
				dirty[p] = nil
			end
		end
	end)
end

return QuestService
