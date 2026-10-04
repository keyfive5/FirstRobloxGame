-- Sound effects (Roblox's own UI pack) + quiet background music (APM library,
-- licensed for Roblox experiences). Volumes follow the player's settings.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Sounds = {}

local SFX = {
	click = { "rbxassetid://15675059323", 0.5 },
	pop = { "rbxassetid://15675055424", 0.6 },
	whoosh = { "rbxassetid://15675024286", 0.35 },
	stinger = { "rbxassetid://15675043410", 0.55 },
	notify = { "rbxassetid://15675085146", 0.4 },
	dig = { "rbxassetid://15675075163", 0.5 },
	hello = { "rbxassetid://15675016548", 0.45 },
	coins = { "rbxassetid://16480570986", 0.5 },
	error = { "rbxassetid://15675081158", 0.35 },
	boom = { "rbxasset://sounds/impact_explosion_03.mp3", 0.35 },
	splash = { "rbxasset://sounds/impact_water.mp3", 0.4 },
}

local MUSIC = {
	"rbxassetid://9046598930", -- Watching the Garden Grow
	"rbxassetid://1839578771", -- Charming View Ukulele
	"rbxassetid://1839580320", -- Happy Forever Ukulele
}
local MUSIC_BASE = 0.22

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Volume = 0.6
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 0.5
musicGroup.Parent = SoundService

local cache = {}
for name, def in pairs(SFX) do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def[1]
	s.Volume = def[2]
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	cache[name] = s
end

function Sounds.play(name: string, pitch: number?)
	local s = cache[name]
	if not s then
		return
	end
	if pitch then
		local c = s:Clone()
		c.PlaybackSpeed = pitch
		c.Parent = SoundService
		c:Play()
		c.Ended:Once(function()
			c:Destroy()
		end)
	else
		s:Play()
	end
end

function Sounds.setVolumes(music: number, sfx: number)
	musicGroup.Volume = math.clamp(music, 0, 1)
	sfxGroup.Volume = math.clamp(sfx, 0, 1)
end

function Sounds.start()
	task.spawn(function()
		local list = {}
		for _, s in pairs(cache) do
			table.insert(list, s)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
	task.spawn(function()
		local track = Instance.new("Sound")
		track.Name = "BackgroundMusic"
		track.Volume = MUSIC_BASE
		track.SoundGroup = musicGroup
		track.Parent = SoundService
		local i = math.random(1, #MUSIC)
		while true do
			track.SoundId = MUSIC[i]
			track:Play()
			local t = os.clock()
			track.Ended:Wait()
			if os.clock() - t < 5 then
				task.wait(20) -- failed to load; don't spin
			end
			task.wait(4)
			i = i % #MUSIC + 1
		end
	end)
end

return Sounds
