-- Client-side weather spectacle: sky/lighting shifts, rain/snow/embers around
-- the camera, lightning bolts and meteors that hit the server-chosen plants.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)

local Sounds = require(script.Parent.Sounds)

local WeatherFX = {}

local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")

local base = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	atmDensity = atm and atm.Density or 0.3,
	atmColor = atm and atm.Color or Color3.new(1, 1, 1),
	atmHaze = atm and atm.Haze or 1,
	ccTint = cc and cc.TintColor or Color3.new(1, 1, 1),
	ccSat = cc and cc.Saturation or 0,
	cloudCover = clouds and clouds.Cover or 0.5,
	cloudDensity = clouds and clouds.Density or 0.6,
	cloudColor = clouds and clouds.Color or Color3.new(1, 1, 1),
}

local PRESETS = {
	glimmer_rain = { ClockTime = 14, Brightness = 1.6, OutdoorAmbient = Color3.fromRGB(110, 120, 150), atmDensity = 0.42, atmColor = Color3.fromRGB(170, 190, 220), atmHaze = 2, ccTint = Color3.fromRGB(225, 235, 255), cloudCover = 0.85, cloudDensity = 0.8, cloudColor = Color3.fromRGB(190, 200, 220) },
	blizzard = { ClockTime = 13, Brightness = 2.2, OutdoorAmbient = Color3.fromRGB(170, 180, 205), atmDensity = 0.55, atmColor = Color3.fromRGB(235, 242, 255), atmHaze = 3, ccTint = Color3.fromRGB(225, 238, 255), ccSat = -0.05, cloudCover = 0.9, cloudDensity = 0.9, cloudColor = Color3.fromRGB(240, 245, 255) },
	heatwave = { ClockTime = 15.5, Brightness = 3.2, OutdoorAmbient = Color3.fromRGB(170, 130, 110), atmDensity = 0.35, atmColor = Color3.fromRGB(255, 200, 150), atmHaze = 2.4, ccTint = Color3.fromRGB(255, 225, 195), ccSat = 0.2, cloudCover = 0.2, cloudDensity = 0.4, cloudColor = Color3.fromRGB(255, 220, 190) },
	thunderstorm = { ClockTime = 17.8, Brightness = 1.0, OutdoorAmbient = Color3.fromRGB(80, 80, 110), atmDensity = 0.48, atmColor = Color3.fromRGB(110, 115, 140), atmHaze = 2.5, ccTint = Color3.fromRGB(200, 205, 235), ccSat = -0.1, cloudCover = 0.95, cloudDensity = 1, cloudColor = Color3.fromRGB(90, 92, 110) },
	meteor_shower = { ClockTime = 20.6, Brightness = 1.4, OutdoorAmbient = Color3.fromRGB(110, 90, 150), atmDensity = 0.3, atmColor = Color3.fromRGB(150, 120, 200), atmHaze = 1.2, ccTint = Color3.fromRGB(235, 215, 255), ccSat = 0.15, cloudCover = 0.35, cloudDensity = 0.4, cloudColor = Color3.fromRGB(160, 140, 200) },
	aurora = { ClockTime = 21.5, Brightness = 1.2, OutdoorAmbient = Color3.fromRGB(80, 140, 140), atmDensity = 0.26, atmColor = Color3.fromRGB(120, 200, 190), atmHaze = 1, ccTint = Color3.fromRGB(215, 255, 245), ccSat = 0.2, cloudCover = 0.15, cloudDensity = 0.3, cloudColor = Color3.fromRGB(150, 220, 210) },
}

local function apply(target, time: number)
	target = target or {}
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	local clock = target.ClockTime or base.ClockTime
	TweenService:Create(Lighting, info, {
		ClockTime = clock,
		Brightness = target.Brightness or base.Brightness,
		OutdoorAmbient = target.OutdoorAmbient or base.OutdoorAmbient,
	}):Play()
	if atm then
		TweenService:Create(atm, info, { Density = target.atmDensity or base.atmDensity, Color = target.atmColor or base.atmColor, Haze = target.atmHaze or base.atmHaze }):Play()
	end
	if cc then
		TweenService:Create(cc, info, { TintColor = target.ccTint or base.ccTint, Saturation = target.ccSat or base.ccSat }):Play()
	end
	if clouds then
		TweenService:Create(clouds, info, { Cover = target.cloudCover or base.cloudCover, Density = target.cloudDensity or base.cloudDensity, Color = target.cloudColor or base.cloudColor }):Play()
	end
end

-- Emitter box that follows the camera.
local box = Instance.new("Part")
box.Name = "WeatherBox"
box.Anchored = true
box.CanCollide = false
box.CanQuery = false
box.CanTouch = false
box.Transparency = 1
box.Size = Vector3.new(150, 1, 150)
box.Parent = workspace
local emitter = Instance.new("ParticleEmitter")
emitter.Enabled = false
emitter.EmissionDirection = Enum.NormalId.Bottom
emitter.Parent = box

local rainSound = Instance.new("Sound")
rainSound.SoundId = "rbxassetid://1516791621"
rainSound.Looped = true
rainSound.Volume = 0
rainSound.SoundGroup = SoundService:FindFirstChild("SFX")
rainSound.Parent = SoundService

local auroraParts = {}
local function clearAurora()
	for _, p in ipairs(auroraParts) do
		p:Destroy()
	end
	auroraParts = {}
end

local function makeAurora()
	clearAurora()
	for i = 1, 7 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Size = Vector3.new(260, 70, 1)
		p.Transparency = 0.75
		p.Color = Color3.fromHSV(0.42 + i * 0.05, 0.8, 1)
		p.CastShadow = false
		p:SetAttribute("i", i)
		p.Parent = workspace
		table.insert(auroraParts, p)
	end
end

local function setParticles(id: string?)
	emitter.Enabled = false
	box.Size = Vector3.new(150, 1, 150)
	if id == "glimmer_rain" or id == "thunderstorm" then
		emitter.Texture = SQUARE
		emitter.Color = ColorSequence.new(Color3.fromRGB(190, 215, 255))
		emitter.Size = NumberSequence.new(0.12)
		emitter.Squash = NumberSequence.new(3)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Speed = NumberRange.new(90, 110)
		emitter.Lifetime = NumberRange.new(0.9, 1.1)
		emitter.Transparency = NumberSequence.new(0.35)
		emitter.LightEmission = 0.3
		emitter.Acceleration = Vector3.zero
		emitter.SpreadAngle = Vector2.new(4, 4)
		emitter.Rate = id == "thunderstorm" and 900 or 650
		emitter.Enabled = true
	elseif id == "blizzard" then
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.Size = NumberSequence.new(0.35)
		emitter.Squash = NumberSequence.new(0)
		emitter.Orientation = Enum.ParticleOrientation.FacingCamera
		emitter.Speed = NumberRange.new(14, 22)
		emitter.Lifetime = NumberRange.new(4, 5)
		emitter.Transparency = NumberSequence.new(0.1)
		emitter.LightEmission = 0.5
		emitter.Acceleration = Vector3.new(14, 0, 6)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Rate = 700
		emitter.Enabled = true
	elseif id == "heatwave" then
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 80, 30))
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.Squash = NumberSequence.new(0)
		emitter.Orientation = Enum.ParticleOrientation.FacingCamera
		emitter.Speed = NumberRange.new(2, 5)
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.LightEmission = 1
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 120
		emitter.Enabled = true
	elseif id == "meteor_shower" or id == "aurora" then
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(id == "aurora" and Color3.fromRGB(150, 255, 220) or Color3.fromRGB(220, 180, 255))
		emitter.Size = NumberSequence.new(0.3, 0)
		emitter.Squash = NumberSequence.new(0)
		emitter.Orientation = Enum.ParticleOrientation.FacingCamera
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.LightEmission = 1
		emitter.Acceleration = Vector3.new(0, 1, 0)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 60
		emitter.Enabled = true
	end
end

local currentId = ""
local function onWeather()
	local id = ReplicatedStorage:GetAttribute("WeatherId") or ""
	if id == currentId then
		return
	end
	currentId = id
	apply(PRESETS[id], 4)
	setParticles(id ~= "" and id or nil)
	local rainy = id == "glimmer_rain" or id == "thunderstorm"
	TweenService:Create(rainSound, TweenInfo.new(3), { Volume = rainy and 0.35 or 0 }):Play()
	if rainy and not rainSound.IsPlaying then
		rainSound:Play()
	end
	if id == "aurora" then
		makeAurora()
	else
		clearAurora()
	end
end

---------------------------------------------------------------------------
-- Strikes
---------------------------------------------------------------------------
local function flash()
	local b = Lighting.Brightness
	Lighting.Brightness = b + 4
	if cc then
		cc.Brightness = 0.35
		TweenService:Create(cc, TweenInfo.new(0.35), { Brightness = 0.02 }):Play()
	end
	task.delay(0.08, function()
		Lighting.Brightness = b
	end)
end

local function burst(pos: Vector3, color: Color3, texture: string, count: number, speed: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(1.6, 0)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(count)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

local function bolt(pos: Vector3)
	local pts = { pos + Vector3.new(math.random(-20, 20), 140, math.random(-20, 20)) }
	for i = 1, 9 do
		local t = i / 10
		local p = pts[1]:Lerp(pos, t) + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		table.insert(pts, p)
	end
	table.insert(pts, pos)
	local parts = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(190, 220, 255)
		seg.Size = Vector3.new(0.7, 0.7, (b - a).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		seg.Parent = workspace
		table.insert(parts, seg)
	end
	flash()
	burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(150, 210, 255), SPARKLE, 40, 25)
	Sounds.play("boom", 0.7)
	task.delay(0.12, function()
		for _, s in ipairs(parts) do
			TweenService:Create(s, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.wait(0.35)
		for _, s in ipairs(parts) do
			s:Destroy()
		end
	end)
end

local function meteor(pos: Vector3, silent: boolean?)
	local start = pos + Vector3.new(math.random(40, 80), 170, math.random(-40, 40))
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 150, 60)
	ball.Size = Vector3.new(4, 4, 4)
	ball.CFrame = CFrame.new(start)
	ball.Parent = workspace
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.5, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.5, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(190, 90, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = ball
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = FIRE
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60))
	fire.Size = NumberSequence.new(3, 0)
	fire.Rate = 60
	fire.Lifetime = NumberRange.new(0.3, 0.5)
	fire.LightEmission = 1
	fire.Parent = ball
	local tw = TweenService:Create(ball, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(pos) })
	tw:Play()
	tw.Completed:Connect(function()
		ball:Destroy()
		burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 170, 80), FIRE, 40, 30)
		burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(190, 120, 255), SPARKLE, 50, 35)
		burst(pos, Color3.fromRGB(120, 110, 130), SMOKE, 20, 12)
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(200, 140, 255)
		ring.Size = Vector3.new(0.2, 2, 2)
		ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.6), { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }):Play()
		task.delay(0.7, function()
			ring:Destroy()
		end)
		if not silent then
			Sounds.play("boom", 0.9)
		end
	end)
end

function WeatherFX.start()
	ReplicatedStorage:GetAttributeChangedSignal("WeatherId"):Connect(onWeather)
	onWeather()
	Net.event("Strike").OnClientEvent:Connect(function(id, pos)
		if typeof(pos) ~= "Vector3" then
			return
		end
		if id == "meteor_shower" then
			meteor(pos)
		else
			bolt(pos)
		end
	end)
	local lastAmbient = 0
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local cpos = cam.CFrame.Position
		box.CFrame = CFrame.new(cpos.X, cpos.Y + 45, cpos.Z) + cam.CFrame.LookVector * Vector3.new(30, 0, 30)
		if #auroraParts > 0 then
			local t = os.clock()
			for _, p in ipairs(auroraParts) do
				local i = p:GetAttribute("i")
				p.CFrame = CFrame.new(cpos.X + math.sin(t * 0.2 + i) * 30, 170 + i * 6, cpos.Z - 160 + i * 18) * CFrame.Angles(0.3 + math.sin(t * 0.5 + i) * 0.15, math.sin(t * 0.1 + i) * 0.3, 0)
				p.Transparency = 0.7 + math.sin(t * 0.8 + i * 1.3) * 0.1
			end
		end
		-- background thunder flashes / shooting stars
		if currentId == "thunderstorm" and os.clock() - lastAmbient > 6 and math.random() < 0.01 then
			lastAmbient = os.clock()
			flash()
		elseif currentId == "meteor_shower" and os.clock() - lastAmbient > 1.5 and math.random() < 0.03 then
			lastAmbient = os.clock()
			local a = math.random() * math.pi * 2
			local far = cpos + Vector3.new(math.cos(a) * 300, -30, math.sin(a) * 300)
			meteor(far, true)
		end
	end)
end

return WeatherFX
