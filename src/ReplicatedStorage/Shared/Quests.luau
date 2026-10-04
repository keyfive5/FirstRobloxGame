-- Daily quests: three per day (easy / medium / hard), rolled per player per day.
-- Targets and rewards scale with progress (most expensive seed bought).
local Quests = {}

Quests.Pool = {
	{ id = "harvest", text = "Harvest %s gems", event = "harvest", targets = { 20, 40, 75 } },
	{ id = "sell", text = "Sell gems worth $%s", event = "sellValue", mults = { 25, 60, 140 }, mins = { 150, 500, 1500 } },
	{ id = "plant", text = "Plant %s seeds", event = "plant", targets = { 3, 6, 10 } },
	{ id = "mutated", text = "Harvest %s mutated gems", event = "harvestMutated", targets = { 1, 3, 6 } },
	{ id = "buy", text = "Buy %s seeds at the Seed Shop", event = "buySeed", targets = { 3, 6, 10 } },
	{ id = "gear", text = "Use gear %s times", event = "gear", targets = { 1, 2, 4 }, minTopPrice = 2500 },
	{ id = "rare", text = "Harvest %s Rare-or-better gems", event = "harvestRare", targets = { 3, 8, 15 }, minTopPrice = 1500 },
	{ id = "playtime", text = "Play for %s minutes", event = "minutes", targets = { 10, 20, 35 } },
}

Quests.ById = {}
for _, q in ipairs(Quests.Pool) do
	Quests.ById[q.id] = q
end

-- Reward per difficulty slot (coins scale with progress).
Quests.Rewards = {
	{ coinsMult = 3, min = 150, gear = { watering_can = 1 } },
	{ coinsMult = 6, min = 400, gear = { watering_can = 2 } },
	{ coinsMult = 12, min = 1000, gear = { sprinkler = 1 } },
}
Quests.Bonus = { coinsMult = 15, min = 2000, gear = { sprinkler = 1 }, luckMinutes = 10 }

function Quests.day(): number
	return math.floor(os.time() / 86400)
end

-- Deterministic roll of the day's three quests for a player.
function Quests.roll(userId: number, day: number, topPrice: number)
	local rng = Random.new((userId % 1000003) * 31 + day * 7919)
	local pool = {}
	for _, q in ipairs(Quests.Pool) do
		if not q.minTopPrice or topPrice >= q.minTopPrice then
			table.insert(pool, q)
		end
	end
	local list = {}
	for slot = 1, 3 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		local target
		if q.mults then
			target = math.max(q.mins[slot], math.floor(topPrice * q.mults[slot]))
		else
			target = q.targets[slot]
		end
		table.insert(list, { id = q.id, target = target, p = 0, c = false })
	end
	return list
end

return Quests
