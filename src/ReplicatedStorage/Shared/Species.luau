-- Every plant in the game. Adding a new seed is just a new entry here.
--   price      coin cost of one seed
--   grow       seconds until the plant is fully grown
--   multi      true = keeps producing gems (regrow seconds per gem), false = one big gem
--   slots      gems the plant carries at once (multi only)
--   value      coin value of one gem at size 1.0 with no mutations
--   carat      displayed carat weight at size 1.0
--   style      PlantBuilder recipe; radius = footprint for spacing checks
--   robux      Robux price shown on the "buy now" button
local Species = {}

Species.List = {
	{
		id = "quartz", name = "Quartz Sprout", rarity = "Common",
		price = 10, grow = 20, multi = false, slots = 1, value = 18, carat = 0.6,
		style = "sprout", radius = 1.5, robux = 9,
		gem = "Cluster", gemColor = Color3.fromRGB(236, 240, 255), gemSize = 1.15,
		leaf = Color3.fromRGB(110, 205, 95), stem = Color3.fromRGB(90, 170, 80),
		desc = "A tiny sprout that pops a sparkling quartz cluster.",
	},
	{
		id = "amber", name = "Amber Berry", rarity = "Common",
		price = 45, grow = 40, multi = true, regrow = 25, slots = 3, value = 9, carat = 0.4,
		style = "bush", radius = 2.0, robux = 15,
		gem = "Round", gemColor = Color3.fromRGB(255, 160, 40), gemSize = 0.75,
		leaf = Color3.fromRGB(76, 170, 72), stem = Color3.fromRGB(110, 78, 48),
		desc = "Bushy and generous. Keeps growing honey-gold amber.",
	},
	{
		id = "rosequartz", name = "Rose Quartz Tulip", rarity = "Uncommon",
		price = 160, grow = 60, multi = false, slots = 1, value = 300, carat = 1.2,
		style = "tulip", radius = 1.6, robux = 25,
		gem = "Heart", gemColor = Color3.fromRGB(255, 150, 190), gemSize = 1.25,
		leaf = Color3.fromRGB(96, 190, 96), stem = Color3.fromRGB(86, 160, 76), accent = Color3.fromRGB(255, 186, 214),
		desc = "Blooms into a single heart-cut rose quartz.",
	},
	{
		id = "amethyst", name = "Amethyst Bush", rarity = "Uncommon",
		price = 500, grow = 90, multi = true, regrow = 40, slots = 4, value = 40, carat = 0.8,
		style = "bush", radius = 2.2, robux = 35,
		gem = "Rhombic", gemColor = Color3.fromRGB(168, 92, 255), gemSize = 0.8,
		leaf = Color3.fromRGB(70, 150, 110), stem = Color3.fromRGB(96, 70, 52),
		desc = "Purple crystals cluster all over its leaves.",
	},
	{
		id = "topaz", name = "Topaz Sunflower", rarity = "Rare",
		price = 1500, grow = 150, multi = false, slots = 1, value = 2800, carat = 2.4,
		style = "sunflower", radius = 1.8, robux = 49,
		gem = "Brilliant", gemColor = Color3.fromRGB(255, 186, 40), gemSize = 1.45,
		leaf = Color3.fromRGB(90, 176, 70), stem = Color3.fromRGB(96, 156, 60), accent = Color3.fromRGB(255, 214, 60),
		desc = "Turns to the sun, then hands you one huge topaz.",
	},
	{
		id = "ruby", name = "Ruby Rose", rarity = "Rare",
		price = 4000, grow = 180, multi = true, regrow = 60, slots = 4, value = 260, carat = 1.0,
		style = "rose", radius = 2.1, robux = 69,
		gem = "Rhombic", gemColor = Color3.fromRGB(240, 30, 70), gemSize = 0.85,
		leaf = Color3.fromRGB(50, 130, 60), stem = Color3.fromRGB(60, 110, 50),
		desc = "Thorny, proud, and dripping with rubies.",
	},
	{
		id = "sapphire", name = "Sapphire Lily", rarity = "Epic",
		price = 12000, grow = 240, multi = true, regrow = 75, slots = 5, value = 650, carat = 1.3,
		style = "lotus", radius = 2.4, robux = 99,
		gem = "Brilliant", gemColor = Color3.fromRGB(40, 110, 255), gemSize = 0.85,
		leaf = Color3.fromRGB(60, 170, 110), stem = Color3.fromRGB(70, 150, 90), accent = Color3.fromRGB(200, 225, 255),
		desc = "Floats on a tiny pond and grows deep-blue sapphires.",
	},
	{
		id = "citrine", name = "Citrine Cactus", rarity = "Epic",
		price = 30000, grow = 300, multi = false, slots = 1, value = 60000, carat = 4.0,
		style = "cactus", radius = 1.9, robux = 129,
		gem = "Octa", gemColor = Color3.fromRGB(255, 140, 0), gemSize = 1.0,
		leaf = Color3.fromRGB(70, 160, 90), stem = Color3.fromRGB(60, 140, 80), accent = Color3.fromRGB(255, 120, 160),
		desc = "Prickly outside. One enormous citrine inside.",
	},
	{
		id = "emerald", name = "Emerald Vine", rarity = "Legendary",
		price = 80000, grow = 360, multi = true, regrow = 90, slots = 6, value = 3000, carat = 1.6,
		style = "vine", radius = 2.5, robux = 179,
		gem = "Emerald", gemColor = Color3.fromRGB(20, 200, 90), gemSize = 0.62,
		leaf = Color3.fromRGB(56, 160, 70), stem = Color3.fromRGB(128, 92, 56),
		desc = "Climbs its trellis and hangs heavy with emeralds.",
	},
	{
		id = "jade", name = "Jade Bamboo", rarity = "Legendary",
		price = 220000, grow = 420, multi = true, regrow = 100, slots = 5, value = 9500, carat = 2.0,
		style = "bamboo", radius = 2.2, robux = 229,
		gem = "Round", gemColor = Color3.fromRGB(70, 200, 140), gemSize = 0.62,
		leaf = Color3.fromRGB(110, 200, 90), stem = Color3.fromRGB(150, 205, 110),
		desc = "Tall, calm stalks with smooth jade beads.",
	},
	{
		id = "opal", name = "Opal Orchid", rarity = "Mythic",
		price = 700000, grow = 540, multi = true, regrow = 120, slots = 5, value = 28000, carat = 2.2,
		style = "orchid", radius = 2.2, robux = 299, glow = true,
		gem = "Octa", gemColor = Color3.fromRGB(235, 225, 255), gemSize = 0.42, shimmer = true,
		leaf = Color3.fromRGB(70, 150, 90), stem = Color3.fromRGB(80, 130, 80), accent = Color3.fromRGB(250, 210, 255),
		desc = "Rare orchids whose opals shimmer every color.",
	},
	{
		id = "moonstone", name = "Moonstone Mushroom", rarity = "Mythic",
		price = 2000000, grow = 600, multi = true, regrow = 140, slots = 6, value = 70000, carat = 2.6,
		style = "mushroom", radius = 2.6, robux = 349, glow = true,
		gem = "Brilliant", gemColor = Color3.fromRGB(200, 225, 255), gemSize = 0.55,
		leaf = Color3.fromRGB(230, 230, 245), stem = Color3.fromRGB(235, 225, 210), accent = Color3.fromRGB(120, 140, 255),
		desc = "Glows at night. Moonstones sprout from its cap.",
	},
	{
		id = "diamond", name = "Diamond Tree", rarity = "Divine",
		price = 7500000, grow = 900, multi = true, regrow = 180, slots = 8, value = 210000, carat = 3.0,
		style = "tree", radius = 3.4, robux = 449, glow = true,
		gem = "Brilliant", gemColor = Color3.fromRGB(235, 250, 255), gemSize = 0.95,
		leaf = Color3.fromRGB(170, 230, 255), stem = Color3.fromRGB(150, 150, 170),
		desc = "A legend among gardeners. Grows real diamonds.",
	},
	{
		id = "sunstone", name = "Sunstone Palm", rarity = "Divine",
		price = 20000000, grow = 1080, multi = true, regrow = 200, slots = 6, value = 650000, carat = 3.5,
		style = "palm", radius = 3.2, robux = 499, glow = true,
		gem = "Round", gemColor = Color3.fromRGB(255, 120, 40), gemSize = 1.15, neon = true,
		leaf = Color3.fromRGB(90, 190, 80), stem = Color3.fromRGB(170, 120, 70),
		desc = "Burning-bright sunstone coconuts. Handle with care.",
	},
	{
		id = "prism", name = "Prism Lotus", rarity = "Prismatic",
		price = 75000000, grow = 1500, multi = true, regrow = 240, slots = 6, value = 2000000, carat = 4.2,
		style = "prismlotus", radius = 2.8, robux = 799, glow = true,
		gem = "Brilliant", gemColor = Color3.fromRGB(255, 255, 255), gemSize = 1.0, rainbow = true,
		leaf = Color3.fromRGB(120, 210, 170), stem = Color3.fromRGB(110, 190, 150), accent = Color3.fromRGB(255, 255, 255),
		desc = "The rarest bloom on the island. Every gem is a rainbow.",
	},
}

Species.ById = {}
for i, s in ipairs(Species.List) do
	s.order = i
	Species.ById[s.id] = s
end

function Species.get(id: string)
	return Species.ById[id]
end

return Species
