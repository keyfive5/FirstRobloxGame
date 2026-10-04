-- Player save data with session locking (prevents item duplication when a
-- player hops servers), autosave, and graceful fallback when DataStores are
-- unavailable (e.g. unpublished Studio sessions).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- (player, profile)
local releasingEvent = Instance.new("BindableEvent")
DataService.Releasing = releasingEvent.Event -- (player, profile) just before the final save

local LOCK_TIMEOUT = 15 * 60 -- a lock older than this is considered abandoned
local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local function template()
	return {
		v = Config.DataVersion,
		coins = Config.StartCoins,
		seeds = table.clone(Config.StarterSeeds),
		gear = table.clone(Config.StarterGear),
		bag = {},
		nextGemId = 1,
		garden = { plants = {}, sprinklers = {}, nextId = 1 },
		stock = { w = -1, r = 0, seeds = {}, gear = {} },
		stats = { earned = 0, harvested = 0, planted = 0, playtime = 0, bestValue = 0, bestGem = nil, topPrice = 10, sold = 0, joins = 0 },
		discovered = {},
		daily = { last = -1, streak = 0 },
		codes = {},
		tutorial = 0,
		receipts = {},
		boosts = {},
		settings = { music = 0.25, sfx = 0.6 },
		firstJoin = os.time(),
		lastSeen = os.time(),
	}
end
DataService.template = template

-- Fill in keys that were added after this save was created. Only structural
-- tables are merged deeply; inventories (seeds, gear) are never topped up.
local DEEP = { garden = true, stock = true, stats = true, daily = true, settings = true }
local function reconcile(data, tmpl, deep: boolean?)
	for k, v in pairs(tmpl) do
		if data[k] == nil then
			data[k] = (type(v) == "table") and table.clone(v) or v
		elseif (deep or DEEP[k]) and type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v, true)
		end
	end
end

local function key(userId: number): string
	return "u_" .. userId
end

local function loadFromStore(player: Player)
	if not storeOk or not store then
		return nil, "nostore"
	end
	local now = os.time()
	for attempt = 1, 8 do
		local locked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player.UserId), function(old)
				old = old or template()
				local lock = old._lock
				if lock and lock.job ~= game.JobId and now - (lock.t or 0) < LOCK_TIMEOUT and attempt < 8 then
					locked = true
					return nil -- leave untouched, retry shortly
				end
				old._lock = { job = game.JobId, t = now }
				return old
			end)
		end)
		if ok and result and not locked then
			return result
		end
		if not player.Parent then
			return nil, "left"
		end
		task.wait(locked and 4 or 2 + attempt)
	end
	return nil, "failed"
end

function DataService.save(player: Player, release: boolean?): boolean
	local profile = DataService.Profiles[player]
	if not profile or profile.temporary then
		return profile ~= nil
	end
	local data = profile.data
	data.lastSeen = os.time()
	local ok, err = pcall(function()
		store:UpdateAsync(key(player.UserId), function(old)
			if old and old._lock and old._lock.job ~= game.JobId then
				-- Another server stole the session (we were presumed dead). Never overwrite it.
				profile.stolen = true
				return nil
			end
			data._lock = (not release) and { job = game.JobId, t = os.time() } or nil
			return data
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	end
	return ok and not profile.stolen
end

function DataService.get(player: Player)
	return DataService.Profiles[player]
end

-- Yields until the player's profile is loaded (or they leave).
function DataService.wait(player: Player)
	while player.Parent and not DataService.Profiles[player] do
		task.wait(0.1)
	end
	return DataService.Profiles[player]
end

local function onPlayerAdded(player: Player)
	local data, reason = loadFromStore(player)
	if not player.Parent then
		return
	end
	local profile = { player = player, temporary = false, joinedAt = os.time() }
	if data then
		reconcile(data, template())
		profile.data = data
	else
		if reason ~= "nostore" and not RunService:IsStudio() then
			player:Kick("Your garden couldn't be loaded right now. Please rejoin in a minute!")
			return
		end
		profile.data = template()
		profile.temporary = true
		warn("[DataService] using temporary data for", player.Name, reason)
	end
	profile.data.stats.joins += 1
	DataService.Profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	releasingEvent:Fire(player, profile)
	DataService.save(player, true)
	DataService.Profiles[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(DataService.Profiles) do
				task.spawn(DataService.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player, profile in pairs(DataService.Profiles) do
			pending += 1
			task.spawn(function()
				releasingEvent:Fire(player, profile)
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

-- Short unique ids for gems / plants.
function DataService.newId(profile, field: string): string
	local data = profile.data
	local n = data[field] or 1
	data[field] = n + 1
	return string.format("%x", n)
end

DataService.HttpService = HttpService
return DataService
