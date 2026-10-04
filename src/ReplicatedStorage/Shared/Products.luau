-- Robux products (created on the Creator Hub for universe 10769287665).
-- Anything left at id 0 is hidden from the store automatically.
local Products = {}

Products.Passes = {
	{ key = "VIP", id = 2006067133, price = 249, icon = "👑", name = "VIP", desc = "+25% gem sell price, VIP chat tag & golden name." },
	{ key = "LuckyGardener", id = 2004909084, price = 199, icon = "🍀", name = "Lucky Gardener", desc = "2x chance for Golden & Rainbow gems." },
	{ key = "SpeedyGrowth", id = 2007069130, price = 299, icon = "⚡", name = "Speedy Growth", desc = "All your plants grow 25% faster." },
	{ key = "SuperGarden", id = 2004939150, price = 149, icon = "🌿", name = "Super Garden", desc = "+40 plant slots in your garden." },
	{ key = "BigBag", id = 2006457077, price = 99, icon = "🎒", name = "Big Bag", desc = "+300 gem bag space." },
	{ key = "SellAnywhere", id = 2007039090, price = 149, icon = "💰", name = "Sell Anywhere", desc = "Open the sell menu from anywhere." },
}

-- Developer products (repeatable). `grant` is handled by MonetizationService.
Products.Dev = {
	{ key = "Coins1", id = 3716404433, price = 25, icon = "💰", name = "Pouch of Coins", kind = "coins", mult = 3, min = 300 },
	{ key = "Coins2", id = 3716404478, price = 99, icon = "💰", name = "Bag of Coins", kind = "coins", mult = 14, min = 1500 },
	{ key = "Coins3", id = 3716404482, price = 399, icon = "💎", name = "Chest of Coins", kind = "coins", mult = 65, min = 7500 },
	{ key = "Coins4", id = 3716404491, price = 1499, icon = "👑", name = "Vault of Coins", kind = "coins", mult = 280, min = 35000 },
	{ key = "Restock", id = 3716404498, price = 29, icon = "🔄", name = "Restock Shops", kind = "restock" },
	{ key = "GrowAll", id = 3716404506, price = 79, icon = "⏩", name = "Grow Everything", kind = "growall" },
	{ key = "LuckPotion", id = 3716404515, price = 49, icon = "🔮", name = "Luck Potion (30 min)", kind = "boost", boost = "luck", seconds = 1800 },
	{ key = "Weather_glimmer_rain", id = 3716404519, kind = "weather", weather = "glimmer_rain", price = 49 },
	{ key = "Weather_blizzard", id = 3716404525, kind = "weather", weather = "blizzard", price = 79 },
	{ key = "Weather_heatwave", id = 3716404528, kind = "weather", weather = "heatwave", price = 99 },
	{ key = "Weather_thunderstorm", id = 3716404532, kind = "weather", weather = "thunderstorm", price = 129 },
	{ key = "Weather_meteor_shower", id = 3716404539, kind = "weather", weather = "meteor_shower", price = 249 },
	{ key = "Weather_aurora", id = 3716404547, kind = "weather", weather = "aurora", price = 399 },
	-- Seeds & gear are bought with one product per rarity tier. The server records
	-- which item the player clicked (pendingPurchase) before prompting.
	{ key = "Tier_Common", id = 3716404555, kind = "item", rarity = "Common", price = 15 },
	{ key = "Tier_Uncommon", id = 3716404567, kind = "item", rarity = "Uncommon", price = 29 },
	{ key = "Tier_Rare", id = 3716404583, kind = "item", rarity = "Rare", price = 59 },
	{ key = "Tier_Epic", id = 3716404594, kind = "item", rarity = "Epic", price = 99 },
	{ key = "Tier_Legendary", id = 3716404606, kind = "item", rarity = "Legendary", price = 199 },
	{ key = "Tier_Mythic", id = 3716404611, kind = "item", rarity = "Mythic", price = 349 },
	{ key = "Tier_Divine", id = 3716404624, kind = "item", rarity = "Divine", price = 499 },
	{ key = "Tier_Prismatic", id = 3716404639, kind = "item", rarity = "Prismatic", price = 799 },
}

Products.PassByKey = {}
Products.PassById = {}
for _, p in ipairs(Products.Passes) do
	Products.PassByKey[p.key] = p
	if p.id ~= 0 then
		Products.PassById[p.id] = p
	end
end

Products.DevByKey = {}
Products.DevById = {}
for _, p in ipairs(Products.Dev) do
	Products.DevByKey[p.key] = p
	if p.id ~= 0 then
		Products.DevById[p.id] = p
	end
end

function Products.devId(key: string): number
	local p = Products.DevByKey[key]
	return p and p.id or 0
end

-- Coin packs scale with the most expensive seed the player has bought.
function Products.coinAmount(product, topPrice: number): number
	return math.max(product.min or 0, math.floor((topPrice or 10) * (product.mult or 1)))
end

function Products.tierProduct(rarity: string)
	return Products.DevByKey["Tier_" .. rarity]
end

function Products.passId(key: string): number
	local p = Products.PassByKey[key]
	return p and p.id or 0
end

return Products
