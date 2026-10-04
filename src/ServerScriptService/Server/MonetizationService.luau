-- Game passes + developer products. Receipts are idempotent: every PurchaseId
-- is recorded in the player's save before we tell Roblox it was granted.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local Format = require(Shared.Util.Format)
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)
local GardenService = require(script.Parent.GardenService)
local ShopService = require(script.Parent.ShopService)
local WeatherService = require(script.Parent.WeatherService)

local MonetizationService = {}

local MAX_RECEIPTS = 100

local function setPass(player: Player, key: string, owned: boolean)
	local profile = DataService.get(player)
	if profile then
		profile.passes = profile.passes or {}
		profile.passes[key] = owned or nil
	end
	player:SetAttribute("Pass_" .. key, owned or nil)
end

local function loadPasses(player: Player)
	for _, pass in ipairs(Products.Passes) do
		if pass.id ~= 0 then
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owned then
				setPass(player, pass.key, true)
			end
		end
	end
	-- Studio testing: the place owner gets passes for free when playtesting.
	if game:GetService("RunService"):IsStudio() and player:GetAttribute("StudioAllPasses") then
		for _, pass in ipairs(Products.Passes) do
			setPass(player, pass.key, true)
		end
	end
end

local function grant(player: Player, product)
	local kind = product.kind
	if kind == "coins" then
		local amount = Products.coinAmount(product, Economy.progressPrice(player))
		Economy.addCoins(player, amount, false)
		Sync.notify(player, string.format("💰 +%s coins! Thank you!", Format.short(amount)), "good")
	elseif kind == "restock" then
		ShopService.reroll(player)
	elseif kind == "growall" then
		GardenService.growAll(player)
		Sync.notify(player, "⏩ Your whole garden is fully grown!", "good")
	elseif kind == "boost" then
		local profile = DataService.get(player)
		local t = os.time()
		local cur = profile.data.boosts[product.boost] or 0
		profile.data.boosts[product.boost] = math.max(cur, t) + product.seconds
		Sync.set(player, "boosts", profile.data.boosts)
		Sync.notify(player, string.format("🍀 2x Golden & Rainbow luck for %d more minutes!", math.floor((profile.data.boosts[product.boost] - t) / 60)), "good")
	elseif kind == "weather" then
		WeatherService.trigger(product.weather, player.DisplayName)
	elseif kind == "item" then
		local data = DataService.get(player).data
		local pending = data.pendingPurchase
		local itemKind, itemId
		if pending and pending.r == product.rarity then
			itemKind, itemId = pending.k, pending.i
		else
			-- No recorded intent (shouldn't happen): fall back to a seed of that rarity.
			for _, sp in ipairs(Species.List) do
				if sp.rarity == product.rarity then
					itemKind, itemId = "seed", sp.id
					break
				end
			end
		end
		data.pendingPurchase = nil
		if itemKind == "gear" then
			Economy.addGear(player, itemId, 1)
			local g = Gear.get(itemId)
			Sync.notify(player, string.format("%s You got a %s!", g and g.icon or "", g and g.name or "?"), "good")
		else
			Economy.addSeed(player, itemId, 1)
			local sp = Species.get(itemId)
			Sync.notify(player, string.format("🌱 You got a %s Seed!", sp and sp.name or "?"), "good")
			if sp and sp.price > (data.stats.topPrice or 0) then
				data.stats.topPrice = sp.price
				Sync.set(player, "stats", data.stats)
			end
		end
	else
		return false
	end
	return true
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = profile.data.receipts
	if table.find(receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = Products.DevById[info.ProductId]
	if not product then
		warn("[Monetization] unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grant, player, product)
	if not ok then
		warn("[Monetization] grant failed", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(receipts, info.PurchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	profile.data.stats.robuxSpent = (profile.data.stats.robuxSpent or 0) + (info.CurrencySpent or 0)
	if not DataService.save(player, false) and not profile.temporary then
		-- Receipt id stays recorded in memory, so a retry won't double-grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Products.PassById[passId]
		if pass then
			setPass(player, pass.key, true)
			Sync.notify(player, string.format("%s %s unlocked! Thank you for supporting the game!", pass.icon, pass.name), "rare")
		end
	end)
	DataService.Loaded:Connect(function(player)
		loadPasses(player)
	end)
	-- Rewarded video ads: the player opts in, watches a short ad, and Roblox grants
	-- the AdLuck developer product through ProcessReceipt (AdReward channel).
	local AdService = game:GetService("AdService")
	local lastAd = {}
	Net.event("WatchAd").OnServerEvent:Connect(function(player)
		local product = Products.DevByKey.AdLuck
		if not product or product.id == 0 then
			return
		end
		if lastAd[player] and os.clock() - lastAd[player] < 30 then
			return
		end
		lastAd[player] = os.clock()
		task.spawn(function()
			local ok, err = pcall(function()
				local reward = AdService:CreateAdRewardFromDevProductId(product.id)
				AdService:ShowRewardedVideoAdAsync(player, reward)
			end)
			if not ok then
				warn("[Ads]", err)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAd[player] = nil
	end)

	-- Robux purchase of a specific seed/gear: remember what was clicked, then prompt
	-- the matching rarity-tier product.
	Net.func("RequestItemPurchase").OnServerInvoke = function(player, itemKind, itemId)
		local profile = DataService.get(player)
		if not profile or (itemKind ~= "seed" and itemKind ~= "gear") or type(itemId) ~= "string" then
			return false
		end
		local def = itemKind == "seed" and Species.get(itemId) or Gear.get(itemId)
		if not def or def.notSold then
			return false
		end
		local tier = Products.tierProduct(def.rarity)
		if not tier or tier.id == 0 then
			return false
		end
		profile.data.pendingPurchase = { k = itemKind, i = itemId, r = def.rarity, t = os.time() }
		MarketplaceService:PromptProductPurchase(player, tier.id)
		return true
	end
	-- Client asks the server for the current coin-pack amounts (they scale with progress).
	Net.func("CoinPackAmounts").OnServerInvoke = function(player)
		local out = {}
		for _, p in ipairs(Products.Dev) do
			if p.kind == "coins" then
				out[p.key] = Products.coinAmount(p, Economy.progressPrice(player))
			end
		end
		return out
	end
end

MonetizationService.setPass = setPass
return MonetizationService
