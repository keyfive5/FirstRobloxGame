-- Gardens: plot assignment, planting, growth, gems, harvesting, watering,
-- sprinklers and weather effects. Plant state lives in the player's save and is
-- mirrored to ReplicatedStorage.Gardens (attributes) so clients can render it.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Mutations = require(Shared.Mutations)
local Gear = require(Shared.Gear)
local Value = require(Shared.Util.Value)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Sync = require(script.Parent.Sync)

local GardenService = {}

local plots = {} -- index -> plot record
local byPlayer = {} -- player -> plot record
local rng = Random.new()
local weatherProvider = nil -- set by WeatherService: () -> def?

local gardensFolder = Instance.new("Folder")
gardensFolder.Name = "Gardens"
gardensFolder.Parent = ReplicatedStorage

local harvestedEvent = Instance.new("BindableEvent")
GardenService.Harvested = harvestedEvent.Event -- (player, gem, value)
local plantedEvent = Instance.new("BindableEvent")
GardenService.Planted = plantedEvent.Event -- (player, speciesId)
local gearEvent = Instance.new("BindableEvent")
GardenService.GearUsed = gearEvent.Event -- (player, gearId)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

---------------------------------------------------------------------------
-- Plot setup
---------------------------------------------------------------------------
function GardenService.init()
	for _, model in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
		local index = model:GetAttribute("Index")
		local folder = Instance.new("Folder")
		folder.Name = "Plot_" .. index
		folder:SetAttribute("Index", index)
		folder:SetAttribute("OwnerId", 0)
		local spr = Instance.new("Folder")
		spr.Name = "Sprinklers"
		spr.Parent = folder
		folder.Parent = gardensFolder
		plots[index] = {
			index = index,
			model = model,
			origin = model.Origin.CFrame,
			folder = folder,
			sprFolder = spr,
			owner = nil,
			plantFolders = {},
		}
	end
end

function GardenService.setWeatherProvider(fn)
	weatherProvider = fn
end

function GardenService.plotOf(player: Player)
	return byPlayer[player]
end

function GardenService.plotByIndex(i: number)
	return plots[i]
end

function GardenService.worldPos(plot, x: number, z: number): Vector3
	return (plot.origin * CFrame.new(x, 0, z)).Position
end

local function setSign(plot, player: Player?)
	local arch = plot.model:FindFirstChild("Arch")
	local sign = arch and arch:FindFirstChild("ArchSign")
	local text = player and (string.upper(player.DisplayName) .. "'S GARDEN") or "EMPTY GARDEN"
	if sign then
		for _, gui in ipairs(sign:GetChildren()) do
			local t = gui:FindFirstChildWhichIsA("TextLabel")
			if t then
				t.Text = text
			end
		end
	end
	local board = plot.model:FindFirstChild("AvatarBoard")
	local img = board and board:FindFirstChild("Avatar") and board.Avatar:FindFirstChild("Image")
	if img then
		img.Image = player and ("rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150") or ""
	end
end

---------------------------------------------------------------------------
-- Replication helpers
---------------------------------------------------------------------------
local function encodeFruits(fr): string
	local out = table.create(#fr)
	for i, f in ipairs(fr) do
		out[i] = { round2(f.r), round2(f.w), f.m }
	end
	return HttpService:JSONEncode(out)
end

local function publishPlant(plot, id: string, plant)
	local f = plot.plantFolders[id]
	if not f then
		f = Instance.new("Folder")
		f.Name = id
		f:SetAttribute("S", plant.s)
		f:SetAttribute("X", plant.x)
		f:SetAttribute("Z", plant.z)
		f:SetAttribute("RS", plant.rs)
		plot.plantFolders[id] = f
	end
	f:SetAttribute("T", round2(plant.t))
	f:SetAttribute("G", round2(plant.g))
	f:SetAttribute("F", encodeFruits(plant.fr))
	if not f.Parent then
		f.Parent = plot.folder
	end
end

local function unpublishPlant(plot, id: string)
	local f = plot.plantFolders[id]
	if f then
		f:Destroy()
		plot.plantFolders[id] = nil
	end
end

local function publishSprinkler(plot, s)
	local f = plot.sprFolder:FindFirstChild(s.id)
	if not f then
		f = Instance.new("Folder")
		f.Name = s.id
		f:SetAttribute("G", s.g)
		f:SetAttribute("X", s.x)
		f:SetAttribute("Z", s.z)
		f:SetAttribute("E", s.e)
		f.Parent = plot.sprFolder
	end
end

---------------------------------------------------------------------------
-- Gem rolls
---------------------------------------------------------------------------
local function sprinklerEffects(plot, profile, x: number, z: number, t: number)
	local grow, size, luck = 1, 0, 1
	for _, s in ipairs(profile.data.garden.sprinklers) do
		if s.e > t then
			local g = Gear.get(s.g)
			if g and (Vector2.new(s.x - x, s.z - z)).Magnitude <= g.radius then
				grow = math.max(grow, g.growBoost or 1)
				size = math.max(size, g.sizeBoost or 0)
				luck = math.max(luck, g.luck or 1)
			end
		end
	end
	return grow, size, luck
end

local function rollSize(): number
	if rng:NextNumber() < Config.HugeChance then
		return rng:NextNumber(Config.HugeMin, Config.HugeMax)
	end
	return Config.SizeMin + (rng:NextNumber() ^ 2.2) * Config.SizeSpread
end

local function rollFruit(player: Player, plot, profile, plant, readyAt: number)
	local _, sizeBoost, sprLuck = sprinklerEffects(plot, profile, plant.x, plant.z, now())
	local luck = Economy.luckMult(player) * sprLuck
	local m = {}
	if rng:NextNumber() < Mutations.get("Rainbow").chance * luck then
		table.insert(m, "Rainbow")
	elseif rng:NextNumber() < Mutations.get("Golden").chance * luck then
		table.insert(m, "Golden")
	end
	return { r = readyAt, w = round2(rollSize() * (1 + sizeBoost)), m = m }
end

---------------------------------------------------------------------------
-- Assign / release
---------------------------------------------------------------------------
local function restore(player: Player, plot, profile)
	local garden = profile.data.garden
	-- drop sprinklers that expired while offline
	local live = {}
	for _, s in ipairs(garden.sprinklers) do
		if s.e > now() then
			table.insert(live, s)
			publishSprinkler(plot, s)
		end
	end
	garden.sprinklers = live
	for id, plant in pairs(garden.plants) do
		if Species.get(plant.s) then
			publishPlant(plot, id, plant)
		else
			garden.plants[id] = nil
		end
	end
end

function GardenService.assign(player: Player)
	if byPlayer[player] then
		return byPlayer[player]
	end
	local profile = DataService.get(player)
	for i = 1, Config.MaxPlots do
		local plot = plots[i]
		if plot and not plot.owner then
			plot.owner = player
			byPlayer[player] = plot
			plot.folder:SetAttribute("OwnerId", player.UserId)
			plot.folder:SetAttribute("OwnerName", player.DisplayName)
			player:SetAttribute("PlotIndex", i)
			setSign(plot, player)
			restore(player, plot, profile)
			return plot
		end
	end
	return nil
end

function GardenService.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	for id in pairs(plot.plantFolders) do
		unpublishPlant(plot, id)
	end
	plot.sprFolder:ClearAllChildren()
	plot.folder:SetAttribute("OwnerId", 0)
	plot.folder:SetAttribute("OwnerName", nil)
	setSign(plot, nil)
end

function GardenService.spawnCFrame(player: Player): CFrame?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	return plot.model.SpawnPoint.CFrame
end

---------------------------------------------------------------------------
-- Validation helpers
---------------------------------------------------------------------------
local function countPlants(profile): number
	local n = 0
	for _ in pairs(profile.data.garden.plants) do
		n += 1
	end
	return n
end
GardenService.countPlants = countPlants

local function onBed(x: number, z: number, margin: number): boolean
	local inner = Config.BedPath / 2
	local outer = inner + Config.BedSize.X
	local ax = math.abs(x)
	return ax >= inner + margin and ax <= outer - margin and math.abs(z) <= Config.BedSize.Y / 2 - margin
end

local function nearPlayer(player: Player, pos: Vector3, range: number): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local d = hrp.Position - pos
	return Vector2.new(d.X, d.Z).Magnitude <= range and math.abs(d.Y) < 30
end

local function ctx(player: Player)
	local profile = DataService.get(player)
	local plot = byPlayer[player]
	if not profile or not plot then
		return nil
	end
	return profile, plot
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function GardenService.plant(player: Player, speciesId: string, x: number, z: number)
	local profile, plot = ctx(player)
	if not profile then
		return false, "Your garden is still loading!"
	end
	local sp = Species.get(speciesId)
	if not sp or type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false
	end
	if (profile.data.seeds[speciesId] or 0) <= 0 then
		return false, "You don't have that seed."
	end
	x, z = round2(x), round2(z)
	if not onBed(x, z, math.min(sp.radius * 0.5, 1.2)) then
		return false, "Plant inside your soil beds!"
	end
	if countPlants(profile) >= Economy.plantCap(player) then
		return false, "Your garden is full! Dig up a plant or get Super Garden."
	end
	for _, other in pairs(profile.data.garden.plants) do
		local osp = Species.get(other.s)
		local minDist = ((osp and osp.radius or 1.5) + sp.radius) * 0.75
		if (Vector2.new(other.x - x, other.z - z)).Magnitude < minDist then
			return false, "Too close to another plant!"
		end
	end
	if not nearPlayer(player, GardenService.worldPos(plot, x, z), Config.PlantRange) then
		return false, "Get closer to your garden!"
	end
	if not Economy.takeSeed(player, speciesId, 1) then
		return false
	end

	local garden = profile.data.garden
	local id = string.format("%x", garden.nextId)
	garden.nextId += 1
	local t = now()
	local speed = Economy.speedMult(player)
	local plant = { s = speciesId, x = x, z = z, t = t, g = round2(sp.grow / speed), rs = rng:NextInteger(1, 1e6), fr = {} }
	local ready = t + plant.g
	if sp.multi then
		for i = 1, sp.slots do
			plant.fr[i] = rollFruit(player, plot, profile, plant, ready + (i - 1) * 1.5)
		end
	else
		plant.fr[1] = rollFruit(player, plot, profile, plant, ready)
	end
	garden.plants[id] = plant
	local stats = profile.data.stats
	stats.planted += 1
	if sp.price > (stats.topPrice or 0) then
		stats.topPrice = sp.price
	end
	publishPlant(plot, id, plant)
	plantedEvent:Fire(player, speciesId)
	return true, id
end

local function announceIfRare(player: Player, gem, value: number)
	local muts = {}
	for _, m in ipairs(gem.m or {}) do
		muts[m] = true
	end
	local sp = Species.get(gem.s)
	local rareSpecies = sp and (sp.rarity == "Divine" or sp.rarity == "Prismatic")
	local big = Value.isHuge(gem)
	if muts.Rainbow or muts.Celestial or muts.Cosmic or rareSpecies or (big and (muts.Golden or muts.Charged)) or value >= 5e6 then
		local label = (big and "HUGE " or "") .. Value.label(gem)
		Sync.notifyAll(string.format("✨ %s harvested a %s worth %s!", player.DisplayName, label, Format.short(value)), "rare")
	end
end

function GardenService.harvest(player: Player, plantId: string, slot: number)
	local profile, plot = ctx(player)
	if not profile or type(plantId) ~= "string" or type(slot) ~= "number" then
		return false
	end
	local plant = profile.data.garden.plants[plantId]
	if not plant then
		return false
	end
	local sp = Species.get(plant.s)
	local fruit = plant.fr[slot]
	local t = now()
	if not sp or not fruit or t + 0.75 < fruit.r then
		return false
	end
	if not nearPlayer(player, GardenService.worldPos(plot, plant.x, plant.z), Config.HarvestRange) then
		return false, "Too far away!"
	end
	local data = profile.data
	if #data.bag >= Economy.bagCapacity(player) then
		return false, "Your bag is full! Sell gems at the Gem Trader."
	end
	local gem = { id = string.format("%x", data.nextGemId), s = plant.s, w = fruit.w, m = fruit.m }
	data.nextGemId += 1
	table.insert(data.bag, gem)
	local value = Value.base(gem)
	local stats = data.stats
	stats.harvested += 1
	if value > (stats.bestValue or 0) then
		stats.bestValue = value
		stats.bestGem = { s = gem.s, w = gem.w, m = gem.m }
	end
	if not data.discovered[gem.s] then
		data.discovered[gem.s] = true
		Sync.set(player, "discovered", data.discovered)
	end

	if sp.multi then
		local speed = Economy.speedMult(player)
		plant.fr[slot] = rollFruit(player, plot, profile, plant, t + sp.regrow * rng:NextNumber(0.85, 1.15) / speed)
		publishPlant(plot, plantId, plant)
	else
		data.garden.plants[plantId] = nil
		unpublishPlant(plot, plantId)
	end
	Sync.bagAdd(player, gem)
	Sync.set(player, "stats", stats)
	announceIfRare(player, gem, value)
	harvestedEvent:Fire(player, gem, value)
	return true, gem
end

function GardenService.dig(player: Player, plantId: string)
	local profile, plot = ctx(player)
	if not profile or type(plantId) ~= "string" then
		return false
	end
	if (profile.data.gear.shovel or 0) <= 0 then
		return false
	end
	local plant = profile.data.garden.plants[plantId]
	if not plant then
		return false
	end
	profile.data.garden.plants[plantId] = nil
	unpublishPlant(plot, plantId)
	return true
end

function GardenService.water(player: Player, plantId: string)
	local profile, plot = ctx(player)
	if not profile or type(plantId) ~= "string" then
		return false
	end
	local plant = profile.data.garden.plants[plantId]
	if not plant then
		return false
	end
	local g = Gear.get("watering_can")
	local t = now()
	local grownAt = plant.t + plant.g
	local anything = grownAt > t
	for _, f in ipairs(plant.fr) do
		if f.r > t then
			anything = true
		end
	end
	if not anything then
		return false, "This plant is already fully grown!"
	end
	if not Economy.takeGear(player, "watering_can", 1) then
		return false, "You need a Watering Can."
	end
	if grownAt > t then
		local skip = (grownAt - t) * g.skip
		plant.t -= skip
		for _, f in ipairs(plant.fr) do
			f.r -= skip
		end
	else
		for _, f in ipairs(plant.fr) do
			if f.r > t then
				f.r -= (f.r - t) * g.skip
			end
		end
	end
	publishPlant(plot, plantId, plant)
	gearEvent:Fire(player, "watering_can")
	return true
end

function GardenService.placeSprinkler(player: Player, gearId: string, x: number, z: number)
	local profile, plot = ctx(player)
	local g = Gear.get(gearId)
	if not profile or not g or g.kind ~= "sprinkler" or type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false
	end
	if math.abs(x) > Config.PlotSize.X / 2 - 2 or math.abs(z) > Config.PlotSize.Y / 2 - 2 then
		return false, "Place it inside your garden!"
	end
	local garden = profile.data.garden
	local t = now()
	local active = 0
	for _, s in ipairs(garden.sprinklers) do
		if s.e > t then
			active += 1
		end
	end
	if active >= 8 then
		return false, "You already have 8 sprinklers running!"
	end
	if not nearPlayer(player, GardenService.worldPos(plot, x, z), Config.PlantRange) then
		return false, "Get closer to your garden!"
	end
	if not Economy.takeGear(player, gearId, 1) then
		return false
	end
	local s = { id = "s" .. string.format("%x", garden.nextId), g = gearId, x = round2(x), z = round2(z), e = round2(t + g.duration) }
	garden.nextId += 1
	table.insert(garden.sprinklers, s)
	publishSprinkler(plot, s)
	gearEvent:Fire(player, gearId)
	return true
end

-- Robux: finish every growing plant and ripen every gem.
function GardenService.growAll(player: Player): boolean
	local profile, plot = ctx(player)
	if not profile then
		return false
	end
	local t = now()
	for id, plant in pairs(profile.data.garden.plants) do
		if plant.t + plant.g > t then
			plant.t = t - plant.g
		end
		for _, f in ipairs(plant.fr) do
			if f.r > t then
				f.r = t
			end
		end
		publishPlant(plot, id, plant)
	end
	return true
end

---------------------------------------------------------------------------
-- Weather hooks
---------------------------------------------------------------------------
-- Lightning / meteor: hit one plant (with gems) somewhere on the server.
function GardenService.strike(mutation: string): Vector3?
	local candidates = {}
	for player, plot in pairs(byPlayer) do
		local profile = DataService.get(player)
		if profile then
			for id, plant in pairs(profile.data.garden.plants) do
				if #plant.fr > 0 then
					table.insert(candidates, { player = player, plot = plot, id = id, plant = plant })
				end
			end
		end
	end
	if #candidates == 0 then
		-- strike an empty spot on the island for show
		return nil
	end
	local c = candidates[rng:NextInteger(1, #candidates)]
	for _, f in ipairs(c.plant.fr) do
		if not table.find(f.m, mutation) then
			table.insert(f.m, mutation)
		end
	end
	publishPlant(c.plot, c.id, c.plant)
	Sync.notify(c.player, string.format("%s hit your %s! Its gems are now %s!", mutation == "Cosmic" and "☄️ A meteor" or "⚡ Lightning", Species.get(c.plant.s).name, mutation), "rare")
	return GardenService.worldPos(c.plot, c.plant.x, c.plant.z)
end

local function tick(dt: number)
	local t = now()
	local w = weatherProvider and weatherProvider() or nil
	local weatherBoost = w and w.growBoost or 1
	local mutChance = 0
	if w and w.mutation and w.chance and not w.strike then
		-- w.chance = probability a gem exposed for the whole event gets mutated
		mutChance = 1 - (1 - w.chance) ^ (dt / w.duration)
	end
	for player, plot in pairs(byPlayer) do
		local profile = DataService.get(player)
		if profile then
			local garden = profile.data.garden
			-- expire sprinklers
			for i = #garden.sprinklers, 1, -1 do
				local s = garden.sprinklers[i]
				if s.e <= t then
					table.remove(garden.sprinklers, i)
					local f = plot.sprFolder:FindFirstChild(s.id)
					if f then
						f:Destroy()
					end
				end
			end
			for id, plant in pairs(garden.plants) do
				local sprGrow = sprinklerEffects(plot, profile, plant.x, plant.z, t)
				local boost = math.min(weatherBoost * sprGrow, 4)
				local extra = dt * (boost - 1)
				local changed = false
				if extra > 0 then
					if plant.t + plant.g > t then
						plant.t -= extra
						changed = true
					end
					for _, f in ipairs(plant.fr) do
						if f.r > t then
							f.r -= extra
							changed = true
						end
					end
				end
				if mutChance > 0 and plant.t + plant.g <= t then
					for _, f in ipairs(plant.fr) do
						if not table.find(f.m, w.mutation) and rng:NextNumber() < mutChance then
							table.insert(f.m, w.mutation)
							changed = true
						end
					end
				end
				if changed then
					publishPlant(plot, id, plant)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
function GardenService.start()
	local lastHarvest = {}
	Net.event("Harvest").OnServerEvent:Connect(function(player, plantId, slot)
		local c = os.clock()
		local rec = lastHarvest[player] or { t = c, n = 0 }
		if c - rec.t > 1 then
			rec.t, rec.n = c, 0
		end
		rec.n += 1
		lastHarvest[player] = rec
		if rec.n > 25 then
			return
		end
		local ok, msg = GardenService.harvest(player, plantId, slot)
		if not ok and msg then
			Sync.notify(player, msg, "bad")
		end
	end)
	Net.func("Plant").OnServerInvoke = function(player, speciesId, x, z)
		local ok, msg = GardenService.plant(player, speciesId, x, z)
		return ok, msg
	end
	Net.func("Dig").OnServerInvoke = function(player, plantId)
		return GardenService.dig(player, plantId)
	end
	Net.func("Water").OnServerInvoke = function(player, plantId)
		return GardenService.water(player, plantId)
	end
	Net.func("PlaceSprinkler").OnServerInvoke = function(player, gearId, x, z)
		return GardenService.placeSprinkler(player, gearId, x, z)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastHarvest[player] = nil
	end)
	DataService.Releasing:Connect(function(player)
		GardenService.release(player)
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.GardenTick)
			local c = os.clock()
			local ok, err = pcall(tick, c - last)
			if not ok then
				warn("[GardenService] tick error:", err)
			end
			last = c
		end
	end)
end

return GardenService
