-- Server-wide weather events: random schedule + Robux-triggered events.
-- Current weather is mirrored as ReplicatedStorage attributes for clients.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Weather = require(Shared.Weather)
local Net = require(Shared.Net)

local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Sync)

local WeatherService = {}

local rng = Random.new()
local active = nil -- { def, endsAt }
local queue = {}
local nextNatural = 0
local strikeEvent = Net.event("Strike")

local function now()
	return workspace:GetServerTimeNow()
end

local function publish()
	ReplicatedStorage:SetAttribute("WeatherId", active and active.def.id or "")
	ReplicatedStorage:SetAttribute("WeatherEnds", active and active.endsAt or 0)
	ReplicatedStorage:SetAttribute("WeatherBy", active and active.by or "")
end

function WeatherService.current()
	if active and active.endsAt > now() then
		return active.def
	end
	return nil
end

function WeatherService.trigger(id: string, by: string?)
	local def = Weather.get(id)
	if not def then
		return false
	end
	if active then
		table.insert(queue, { id = id, by = by })
		if by then
			Sync.notifyAll(string.format("%s %s bought a %s! It starts right after the current weather.", def.icon, by, def.name), "rare")
		end
		return true
	end
	active = { def = def, endsAt = now() + def.duration, by = by, nextStrike = now() + 3 }
	publish()
	if by then
		Sync.notifyAll(string.format("%s %s summoned a %s! %s", def.icon, by, def.name, def.blurb), "rare")
	else
		Sync.notifyAll(string.format("%s A %s has started! %s", def.icon, def.name, def.blurb), "rare")
	end
	return true
end

local function stop()
	active = nil
	publish()
	if #queue > 0 then
		local q = table.remove(queue, 1)
		task.delay(3, function()
			WeatherService.trigger(q.id, q.by)
		end)
	else
		nextNatural = now() + rng:NextNumber(Config.WeatherGapMin, Config.WeatherGapMax)
	end
end

local function loop()
	nextNatural = now() + Config.FirstWeatherDelay
	publish()
	while true do
		task.wait(0.5)
		local t = now()
		if active then
			if t >= active.endsAt then
				stop()
			elseif active.def.strike and t >= active.nextStrike then
				local every = active.def.strikeEvery
				active.nextStrike = t + rng:NextNumber(every[1], every[2])
				local pos = GardenService.strike(active.def.mutation)
				if not pos then
					local a = rng:NextNumber() * math.pi * 2
					local r = rng:NextNumber(70, 200)
					pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				end
				strikeEvent:FireAllClients(active.def.id, pos)
			end
		elseif t >= nextNatural and #queue == 0 then
			WeatherService.trigger(Weather.pick(rng).id)
		end
	end
end

function WeatherService.start()
	GardenService.setWeatherProvider(WeatherService.current)
	task.spawn(loop)
end

return WeatherService
