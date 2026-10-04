-- Garden gear sold at the Gear Shop (restocks with the seed shop).
--   water      : click a plant to skip part of its remaining grow time
--   sprinkler  : place in your garden; boosts plants in radius for `duration` seconds
--   shovel     : remove a plant (never consumed, never sold)
local Gear = {}

Gear.List = {
	{
		id = "watering_can", name = "Watering Can", icon = "💧", rarity = "Common",
		price = 2500, kind = "water", skip = 0.3, robux = 15,
		stock = { 1.0, 2, 5 },
		desc = "Water a plant to skip 30% of its remaining grow time.",
	},
	{
		id = "sprinkler", name = "Sprinkler", icon = "⛲", rarity = "Uncommon",
		price = 25000, kind = "sprinkler", duration = 300, radius = 14, growBoost = 1.5, sizeBoost = 0, luck = 1,
		robux = 49, stock = { 0.75, 1, 3 }, color = Color3.fromRGB(150, 200, 255),
		desc = "Plants within 14 studs grow 50% faster for 5 minutes.",
	},
	{
		id = "golden_sprinkler", name = "Golden Sprinkler", icon = "🌟", rarity = "Epic",
		price = 400000, kind = "sprinkler", duration = 300, radius = 18, growBoost = 2.0, sizeBoost = 0.2, luck = 1,
		robux = 129, stock = { 0.25, 1, 2 }, color = Color3.fromRGB(255, 205, 60),
		desc = "2x growth and 20% bigger gems within 18 studs for 5 minutes.",
	},
	{
		id = "lucky_lantern", name = "Lucky Lantern", icon = "🏮", rarity = "Legendary",
		price = 3000000, kind = "sprinkler", duration = 300, radius = 16, growBoost = 1.25, sizeBoost = 0, luck = 4,
		robux = 199, stock = { 0.1, 1, 1 }, color = Color3.fromRGB(255, 90, 90),
		desc = "4x Golden & Rainbow chance within 16 studs for 5 minutes.",
	},
	{
		id = "shovel", name = "Shovel", icon = "⛏️", rarity = "Common",
		price = 0, kind = "shovel", notSold = true,
		desc = "Dig up a plant you no longer want.",
	},
}

Gear.ById = {}
for i, g in ipairs(Gear.List) do
	g.order = i
	Gear.ById[g.id] = g
end

function Gear.get(id: string)
	return Gear.ById[id]
end

return Gear
