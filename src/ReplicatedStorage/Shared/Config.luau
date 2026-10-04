-- Global tuning knobs. Gameplay numbers live here (and in Species/Gear/etc.)
-- so balancing never needs code changes.
local Config = {}

Config.GameName = "Grow a Gem Garden"
Config.DataStoreName = "GemGarden_Live_1"
Config.DataVersion = 1

-- World layout ---------------------------------------------------------------
Config.HubCenter = Vector3.new(0, 0, 0)
Config.GroundY = 0
Config.MaxPlots = 8
Config.PlotRadius = 138 -- hub center -> plot center
Config.PlotSize = Vector2.new(66, 74) -- width (x), depth (z)
Config.BedSize = Vector2.new(24, 56) -- each of the two soil beds
Config.BedPath = 8 -- path between the beds
Config.BedHeight = 1 -- soil top sits this far above ground

-- Economy ------------------------------------------------------------------
Config.StartCoins = 20
Config.StarterSeeds = { quartz = 3 }
Config.StarterGear = { shovel = 1 }
Config.RestockInterval = 300 -- seconds; personal seed + gear stock rerolls on this clock
Config.BaseBagCapacity = 150
Config.BigBagBonus = 300
Config.BasePlantCap = 60
Config.SuperGardenBonus = 40
Config.FriendBoostPer = 0.10
Config.FriendBoostMax = 0.50
Config.VipSellBonus = 0.25
Config.SpeedyGrowthMult = 1.25 -- plants grow this much faster with the pass
Config.LuckyGardenerMult = 2 -- natural mutation chance multiplier

-- Gem sizes: value scales with size^2 -------------------------------------------
Config.SizeMin = 0.85
Config.SizeSpread = 0.75 -- normal gems land in [SizeMin, SizeMin + SizeSpread]
Config.HugeChance = 1 / 90
Config.HugeMin = 2.0
Config.HugeMax = 3.4

-- Server pacing ----------------------------------------------------------------
Config.AutosaveInterval = 90
Config.GardenTick = 5 -- seconds between growth/weather ticks
Config.WeatherGapMin = 7 * 60
Config.WeatherGapMax = 12 * 60
Config.FirstWeatherDelay = 150

-- Interaction ranges (studs) ------------------------------------------------------
Config.HarvestRange = 22
Config.ShopRange = 26
Config.PlantRange = 60

-- Rewards ----------------------------------------------------------------------
Config.PlaytimeGifts = { 5 * 60, 15 * 60, 30 * 60, 60 * 60 }
Config.DailyCycle = 7

return Config
