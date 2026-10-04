-- Server-wide weather events. While active, gems on grown plants can pick up the
-- event's mutation; `chance` = odds a gem gets it if exposed for the whole event.
-- "strike" events hit one random plant at a time instead.
local Weather = {}

Weather.List = {
	{
		id = "glimmer_rain", name = "Glimmer Rain", icon = "🌧️", weight = 50, duration = 180,
		mutation = "Glimmering", chance = 0.55, growBoost = 1.5,
		blurb = "Plants grow 50% faster and gems may turn Glimmering (x2)!",
		color = Color3.fromRGB(120, 190, 255),
	},
	{
		id = "blizzard", name = "Blizzard", icon = "❄️", weight = 26, duration = 150,
		mutation = "Frozen", chance = 0.18, growBoost = 1.0,
		blurb = "Freezing winds! Gems may become Frozen (x8).",
		color = Color3.fromRGB(190, 230, 255),
	},
	{
		id = "heatwave", name = "Heatwave", icon = "🔥", weight = 14, duration = 150,
		mutation = "Molten", chance = 0.12, growBoost = 1.25,
		blurb = "Scorching heat! Gems may melt into Molten (x15).",
		color = Color3.fromRGB(255, 140, 60),
	},
	{
		id = "thunderstorm", name = "Thunderstorm", icon = "⚡", weight = 16, duration = 150,
		mutation = "Charged", strike = true, strikeEvery = { 3, 6 }, growBoost = 1.3,
		blurb = "Lightning strikes plants and Charges their gems (x30)!",
		color = Color3.fromRGB(150, 160, 255),
	},
	{
		id = "meteor_shower", name = "Meteor Shower", icon = "☄️", weight = 5, duration = 120,
		mutation = "Cosmic", strike = true, strikeEvery = { 4, 8 }, growBoost = 1.0,
		blurb = "Meteors crash into gardens! Hit gems turn Cosmic (x60)!",
		color = Color3.fromRGB(190, 110, 255),
	},
	{
		id = "aurora", name = "Aurora", icon = "🌌", weight = 1.5, duration = 180,
		mutation = "Celestial", chance = 0.05, growBoost = 1.5,
		blurb = "A rare Aurora! Gems may become Celestial (x100)!",
		color = Color3.fromRGB(110, 255, 210),
	},
}

Weather.ById = {}
for i, w in ipairs(Weather.List) do
	w.order = i
	Weather.ById[w.id] = w
end

function Weather.get(id: string)
	return Weather.ById[id]
end

function Weather.pick(rng: Random)
	local total = 0
	for _, w in ipairs(Weather.List) do
		total += w.weight
	end
	local r = rng:NextNumber() * total
	for _, w in ipairs(Weather.List) do
		r -= w.weight
		if r <= 0 then
			return w
		end
	end
	return Weather.List[1]
end

return Weather
