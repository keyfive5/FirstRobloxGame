-- Robux products. Ids are filled in after the passes/products are created on
-- the Creator Hub; anything left at 0 is hidden from the store automatically.
local Products = {}

Products.Passes = {
	{ key = "VIP", id = 0, price = 249, icon = "👑", name = "VIP", desc = "+25% gem sell price, VIP chat tag & golden name." },
	{ key = "LuckyGardener", id = 0, price = 199, icon = "🍀", name = "Lucky Gardener", desc = "2x chance for Golden & Rainbow gems." },
	{ key = "SpeedyGrowth", id = 0, price = 299, icon = "⚡", name = "Speedy Growth", desc = "All your plants grow 25% faster." },
	{ key = "SuperGarden", id = 0, price = 149, icon = "🌿", name = "Super Garden", desc = "+40 plant slots in your garden." },
	{ key = "BigBag", id = 0, price = 99, icon = "🎒", name = "Big Bag", desc = "+300 gem bag space." },
	{ key = "SellAnywhere", id = 0, price = 149, icon = "💰", name = "Sell Anywhere", desc = "Open the sell menu from anywhere." },
}

-- Developer products (repeatable). `grant` is handled by MonetizationService.
Products.Dev = {
	{ key = "Coins1", id = 0, price = 25, icon = "💰", name = "Pouch of Coins", kind = "coins", mult = 3, min = 300 },
	{ key = "Coins2", id = 0, price = 99, icon = "💰", name = "Bag of Coins", kind = "coins", mult = 14, min = 1500 },
	{ key = "Coins3", id = 0, price = 399, icon = "💎", name = "Chest of Coins", kind = "coins", mult = 65, min = 7500 },
	{ key = "Coins4", id = 0, price = 1499, icon = "👑", name = "Vault of Coins", kind = "coins", mult = 280, min = 35000 },
	{ key = "Restock", id = 0, price = 29, icon = "🔄", name = "Restock Shops", kind = "restock" },
	{ key = "GrowAll", id = 0, price = 79, icon = "⏩", name = "Grow Everything", kind = "growall" },
	{ key = "LuckPotion", id = 0, price = 49, icon = "🔮", name = "Luck Potion (30 min)", kind = "boost", boost = "luck", seconds = 1800 },
	{ key = "Weather_glimmer_rain", id = 0, kind = "weather", weather = "glimmer_rain" },
	{ key = "Weather_blizzard", id = 0, kind = "weather", weather = "blizzard" },
	{ key = "Weather_heatwave", id = 0, kind = "weather", weather = "heatwave" },
	{ key = "Weather_thunderstorm", id = 0, kind = "weather", weather = "thunderstorm" },
	{ key = "Weather_meteor_shower", id = 0, kind = "weather", weather = "meteor_shower" },
	{ key = "Weather_aurora", id = 0, kind = "weather", weather = "aurora" },
	-- One product per seed / gear so a receipt always knows exactly what to grant.
	{ key = "Seed_quartz", id = 0, kind = "seed", item = "quartz" },
	{ key = "Seed_amber", id = 0, kind = "seed", item = "amber" },
	{ key = "Seed_rosequartz", id = 0, kind = "seed", item = "rosequartz" },
	{ key = "Seed_amethyst", id = 0, kind = "seed", item = "amethyst" },
	{ key = "Seed_topaz", id = 0, kind = "seed", item = "topaz" },
	{ key = "Seed_ruby", id = 0, kind = "seed", item = "ruby" },
	{ key = "Seed_sapphire", id = 0, kind = "seed", item = "sapphire" },
	{ key = "Seed_citrine", id = 0, kind = "seed", item = "citrine" },
	{ key = "Seed_emerald", id = 0, kind = "seed", item = "emerald" },
	{ key = "Seed_jade", id = 0, kind = "seed", item = "jade" },
	{ key = "Seed_opal", id = 0, kind = "seed", item = "opal" },
	{ key = "Seed_moonstone", id = 0, kind = "seed", item = "moonstone" },
	{ key = "Seed_diamond", id = 0, kind = "seed", item = "diamond" },
	{ key = "Seed_sunstone", id = 0, kind = "seed", item = "sunstone" },
	{ key = "Seed_prism", id = 0, kind = "seed", item = "prism" },
	{ key = "Gear_watering_can", id = 0, kind = "gear", item = "watering_can" },
	{ key = "Gear_sprinkler", id = 0, kind = "gear", item = "sprinkler" },
	{ key = "Gear_golden_sprinkler", id = 0, kind = "gear", item = "golden_sprinkler" },
	{ key = "Gear_lucky_lantern", id = 0, kind = "gear", item = "lucky_lantern" },
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

function Products.passId(key: string): number
	local p = Products.PassByKey[key]
	return p and p.id or 0
end

return Products
