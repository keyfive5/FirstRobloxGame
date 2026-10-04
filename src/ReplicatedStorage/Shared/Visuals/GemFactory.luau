-- Creates gem parts from the CSG templates in ReplicatedStorage.Assets.Gems and
-- dresses them up for mutations (materials, particles, lights).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Mutations = require(Shared.Mutations)

local GemFactory = {}

local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Gems")

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"

GemFactory.RainbowTag = "RainbowGem"
GemFactory.ShimmerTag = "ShimmerGem"

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
end

-- Base size (studs) of a template at scale 1.
function GemFactory.baseSize(shape: string): Vector3
	if shape == "Round" then
		return Vector3.new(1, 1, 1)
	end
	local t = templates:FindFirstChild(shape)
	return t and t.Size or Vector3.new(1, 1, 1)
end

-- shape: template name or "Round"; scale multiplies the template size.
function GemFactory.make(shape: string, color: Color3, scale: number, opts): BasePart
	opts = opts or {}
	local p: BasePart
	if shape == "Round" then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(scale, scale, scale)
		p = ball
	else
		local t = templates:FindFirstChild(shape) or templates.Brilliant
		p = t:Clone()
		p.Size = t.Size * scale
	end
	quiet(p)
	p.Name = "Gem"
	p.Color = color
	p.Material = opts.neon and Enum.Material.Neon or Enum.Material.Glass
	p.Reflectance = opts.neon and 0 or 0.12
	p.Transparency = 0
	if opts.rainbow then
		CollectionService:AddTag(p, GemFactory.RainbowTag)
	elseif opts.shimmer then
		CollectionService:AddTag(p, GemFactory.ShimmerTag)
	end
	return p
end

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.texture or SPARKLE
	e.Rate = props.rate or 4
	e.Lifetime = props.lifetime or NumberRange.new(0.6, 1.1)
	e.Speed = props.speed or NumberRange.new(0.4, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = props.light or 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(props.color or Color3.new(1, 1, 1))
	e.Size = props.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = props.transparency or NumberSequence.new(0.1)
	e.Acceleration = props.accel or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Restyle a gem part for its mutations. Safe to call repeatedly.
function GemFactory.applyMutations(p: BasePart, list: { string }?, baseColor: Color3, opts)
	opts = opts or {}
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("ParticleEmitter") or c:IsA("PointLight") then
			c:Destroy()
		end
	end
	CollectionService:RemoveTag(p, GemFactory.RainbowTag)
	p.Color = baseColor
	p.Material = opts.neon and Enum.Material.Neon or Enum.Material.Glass
	p.Reflectance = opts.neon and 0 or 0.12
	if opts.rainbow then
		CollectionService:AddTag(p, GemFactory.RainbowTag)
	end

	local has = {}
	for _, id in ipairs(list or {}) do
		has[id] = true
	end
	local scale = math.clamp(p.Size.Magnitude / 2.2, 0.5, 3)
	local function sz(a)
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a * scale), NumberSequenceKeypoint.new(1, 0) })
	end

	if has.Rainbow then
		CollectionService:AddTag(p, GemFactory.RainbowTag)
		p.Material = Enum.Material.Glass
		emitter(p, { color = Color3.fromRGB(255, 220, 255), rate = 6, size = sz(0.3) })
	elseif has.Golden then
		p.Color = Color3.fromRGB(255, 196, 40)
		p.Material = Enum.Material.Foil
		p.Reflectance = 0.35
		emitter(p, { color = Color3.fromRGB(255, 230, 120), rate = 3, size = sz(0.25) })
	end

	local growth = has.Rainbow or has.Golden
	local fx = 0
	local function slot()
		fx += 1
		return fx <= 2
	end

	if has.Celestial and slot() then
		if not growth then
			p.Color = Color3.fromRGB(120, 255, 220)
		end
		emitter(p, { color = Color3.fromRGB(150, 255, 230), rate = 7, size = sz(0.35), accel = Vector3.new(0, 1.5, 0) })
		light(p, Color3.fromRGB(110, 255, 210), 8, 1.4)
	end
	if has.Cosmic and slot() then
		if not growth then
			p.Color = p.Color:Lerp(Color3.fromRGB(150, 70, 255), 0.6)
		end
		emitter(p, { color = Color3.fromRGB(200, 140, 255), rate = 6, size = sz(0.32), speed = NumberRange.new(0.2, 0.6) })
		light(p, Color3.fromRGB(170, 90, 255), 7, 1.2)
	end
	if has.Charged and slot() then
		emitter(p, { texture = SPARKS, color = Color3.fromRGB(140, 210, 255), rate = 8, size = sz(0.35), speed = NumberRange.new(1, 2.5) })
		light(p, Color3.fromRGB(120, 190, 255), 6, 1)
	end
	if has.Molten and slot() then
		if not growth then
			p.Color = p.Color:Lerp(Color3.fromRGB(255, 80, 10), 0.7)
		end
		emitter(p, { texture = FIRE, color = Color3.fromRGB(255, 140, 50), rate = 6, size = sz(0.4), accel = Vector3.new(0, 2, 0), transparency = NumberSequence.new(0.3) })
		light(p, Color3.fromRGB(255, 120, 40), 6, 1.2)
	end
	if has.Frozen and slot() then
		if not growth then
			p.Color = p.Color:Lerp(Color3.fromRGB(190, 230, 255), 0.6)
			p.Material = Enum.Material.Ice
		end
		emitter(p, { color = Color3.fromRGB(220, 240, 255), rate = 4, size = sz(0.22), accel = Vector3.new(0, -1, 0) })
	end
	if has.Glimmering and slot() then
		emitter(p, { color = Color3.fromRGB(170, 230, 255), rate = 5, size = sz(0.22) })
	end
end

-- Total multiplier helper re-exported for convenience.
GemFactory.multiplier = Mutations.multiplier

return GemFactory
