-- Daily streak + playtime gift tables (shared so the UI can preview rewards).
-- coinsMult scales with the most expensive seed the player has bought.
local Rewards = {}

Rewards.Daily = {
	{ coinsMult = 2, min = 100, seeds = { amber = 2 } },
	{ coinsMult = 3, min = 250, seeds = { rosequartz = 2 } },
	{ coinsMult = 4, min = 400, gear = { watering_can = 2 } },
	{ coinsMult = 5, min = 600, seeds = { amethyst = 2 } },
	{ coinsMult = 6, min = 900, seeds = { topaz = 1 }, gear = { watering_can = 2 } },
	{ coinsMult = 8, min = 1500, gear = { sprinkler = 1 } },
	{ coinsMult = 12, min = 3000, seeds = { ruby = 1, sapphire = 1 }, gear = { sprinkler = 1 } },
}

Rewards.Gifts = {
	{ coinsMult = 1, min = 60, seeds = { amber = 1 } },
	{ coinsMult = 2, min = 150, gear = { watering_can = 1 } },
	{ coinsMult = 3, min = 400, seeds = { amethyst = 1 } },
	{ coinsMult = 5, min = 1000, gear = { sprinkler = 1 }, seeds = { ruby = 1 } },
}

function Rewards.coins(spec, topPrice: number): number
	if spec.coins then
		return spec.coins
	end
	if not spec.coinsMult then
		return 0
	end
	return math.max(spec.min or 0, math.floor((topPrice or 10) * spec.coinsMult))
end

return Rewards
