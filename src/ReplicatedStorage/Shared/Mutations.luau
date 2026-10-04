-- Gem mutations. "growth" mutations are rolled when a gem starts growing and are
-- exclusive (Rainbow beats Golden). "weather" mutations are added by weather
-- events and stack. Value = base * size^2 * growthMult * (1 + sum(weatherMult - 1)).
local Mutations = {}

Mutations.List = {
	{ id = "Golden", kind = "growth", mult = 20, chance = 1 / 70, color = Color3.fromRGB(255, 205, 50) },
	{ id = "Rainbow", kind = "growth", mult = 50, chance = 1 / 700, color = Color3.fromRGB(255, 120, 220) },
	{ id = "Glimmering", kind = "weather", mult = 2, color = Color3.fromRGB(150, 230, 255) },
	{ id = "Frozen", kind = "weather", mult = 8, color = Color3.fromRGB(170, 220, 255) },
	{ id = "Charged", kind = "weather", mult = 30, color = Color3.fromRGB(110, 190, 255) },
	{ id = "Molten", kind = "weather", mult = 15, color = Color3.fromRGB(255, 110, 40) },
	{ id = "Cosmic", kind = "weather", mult = 60, color = Color3.fromRGB(170, 90, 255) },
	{ id = "Celestial", kind = "weather", mult = 100, color = Color3.fromRGB(110, 255, 210) },
}

Mutations.ById = {}
for i, m in ipairs(Mutations.List) do
	m.order = i
	Mutations.ById[m.id] = m
end

function Mutations.get(id: string)
	return Mutations.ById[id]
end

-- Combined multiplier for a list of mutation ids.
function Mutations.multiplier(list: { string }?): number
	if not list then
		return 1
	end
	local growth, weather = 1, 0
	for _, id in ipairs(list) do
		local m = Mutations.ById[id]
		if m then
			if m.kind == "growth" then
				growth = math.max(growth, m.mult)
			else
				weather += m.mult - 1
			end
		end
	end
	return growth * (1 + weather)
end

-- Sorted copy (growth first, then by order) for stable display strings.
function Mutations.sorted(list: { string }?): { string }
	local out = table.clone(list or {})
	table.sort(out, function(a, b)
		local ma, mb = Mutations.ById[a], Mutations.ById[b]
		return (ma and ma.order or 99) < (mb and mb.order or 99)
	end)
	return out
end

return Mutations
