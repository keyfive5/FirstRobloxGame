-- Rarity tiers: display colors and how often each tier shows up in a restock.
local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Prismatic" }

Rarity.Tiers = {
	Common = { rank = 1, color = Color3.fromRGB(190, 196, 204), dark = Color3.fromRGB(96, 104, 116), stockChance = 1.0, stock = { 6, 18 } },
	Uncommon = { rank = 2, color = Color3.fromRGB(102, 222, 96), dark = Color3.fromRGB(38, 128, 44), stockChance = 0.75, stock = { 3, 8 } },
	Rare = { rank = 3, color = Color3.fromRGB(70, 160, 255), dark = Color3.fromRGB(24, 82, 176), stockChance = 0.45, stock = { 2, 5 } },
	Epic = { rank = 4, color = Color3.fromRGB(186, 98, 255), dark = Color3.fromRGB(100, 36, 168), stockChance = 0.22, stock = { 1, 3 } },
	Legendary = { rank = 5, color = Color3.fromRGB(255, 196, 46), dark = Color3.fromRGB(170, 104, 10), stockChance = 0.09, stock = { 1, 2 } },
	Mythic = { rank = 6, color = Color3.fromRGB(255, 78, 132), dark = Color3.fromRGB(160, 20, 70), stockChance = 0.035, stock = { 1, 1 } },
	Divine = { rank = 7, color = Color3.fromRGB(120, 246, 255), dark = Color3.fromRGB(20, 130, 160), stockChance = 0.012, stock = { 1, 1 } },
	Prismatic = { rank = 8, color = Color3.fromRGB(255, 255, 255), dark = Color3.fromRGB(90, 60, 160), stockChance = 0.004, stock = { 1, 1 } },
}

-- Colors for gradient-styled tiers (UI uses these for UIGradient keypoints).
Rarity.Gradients = {
	Divine = { Color3.fromRGB(255, 240, 140), Color3.fromRGB(120, 246, 255) },
	Prismatic = {
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 230, 110),
		Color3.fromRGB(70, 170, 255), Color3.fromRGB(190, 100, 255),
	},
}

function Rarity.get(name: string)
	return Rarity.Tiers[name] or Rarity.Tiers.Common
end

function Rarity.rank(name: string): number
	return Rarity.get(name).rank
end

return Rarity
