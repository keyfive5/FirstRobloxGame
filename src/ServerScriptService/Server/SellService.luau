-- Selling gems at the Gem Trader, plus favoriting so prized gems never get sold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Value = require(Shared.Util.Value)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)

local SellService = {}

local soldEvent = Instance.new("BindableEvent")
SellService.Sold = soldEvent.Event -- (player, total, count)

local function nearTrader(player: Player): boolean
	if Economy.hasPass(player, "SellAnywhere") then
		return true
	end
	local shop = workspace.World.Shops:FindFirstChild("sell")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not shop or not hrp then
		return false
	end
	return (hrp.Position - shop.PromptPart.Position).Magnitude <= Config.ShopRange
end

local function sell(player: Player, filter: (any) -> boolean)
	local profile = DataService.get(player)
	if not profile then
		return false, "Not loaded"
	end
	if not nearTrader(player) then
		return false, "Visit the Gem Trader to sell!"
	end
	local data = profile.data
	local mult = Economy.sellMult(player)
	local keep, removed = {}, {}
	local total = 0
	for _, gem in ipairs(data.bag) do
		if not gem.f and filter(gem) then
			total += Value.base(gem) * mult
			table.insert(removed, gem.id)
		else
			table.insert(keep, gem)
		end
	end
	if #removed == 0 then
		return false, "Nothing to sell!"
	end
	data.bag = keep
	data.stats.sold += #removed
	Economy.addCoins(player, total, true)
	Sync.bagRemove(player, removed)
	soldEvent:Fire(player, total, #removed)
	return true, math.floor(total), #removed
end

function SellService.start()
	Net.func("SellAll").OnServerInvoke = function(player)
		return sell(player, function()
			return true
		end)
	end
	Net.func("SellIds").OnServerInvoke = function(player, ids)
		if type(ids) ~= "table" then
			return false
		end
		local set = {}
		for i, id in ipairs(ids) do
			if i > 1000 then
				break
			end
			if type(id) == "string" then
				set[id] = true
			end
		end
		return sell(player, function(gem)
			return set[gem.id] == true
		end)
	end
	Net.func("FavoriteIds").OnServerInvoke = function(player, ids, on)
		local profile = DataService.get(player)
		if not profile or type(ids) ~= "table" then
			return false
		end
		local set = {}
		for _, id in ipairs(ids) do
			if type(id) == "string" then
				set[id] = true
			end
		end
		for _, gem in ipairs(profile.data.bag) do
			if set[gem.id] then
				gem.f = on and true or nil
			end
		end
		Sync.set(player, "bag", profile.data.bag)
		return true
	end
	Net.func("SellQuote").OnServerInvoke = function(player)
		local mult, parts = Economy.sellBreakdown(player)
		return mult, parts
	end
end

return SellService
