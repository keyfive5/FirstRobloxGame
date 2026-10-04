-- Edit-time world builder. Creates terrain, lighting, the hub plaza, shop stalls
-- (run by garden gnomes), leaderboards and the 8 player gardens.
-- Run with: node tools/run.mjs build/world.luau
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Config = (function()
	local c = RS.Shared.Config:Clone()
	c.Parent = RS.Shared
	local r = require(c)
	c:Destroy()
	return r
end)()

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local rng = Random.new(20261004)

for _, n in ipairs({ "World", "Plots", "Preview", "Proto" }) do
	local o = workspace:FindFirstChild(n)
	if o then
		o:Destroy()
	end
end
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("SpawnLocation") or (c:IsA("BasePart") and c.Name == "Baseplate") then
		c:Destroy()
	end
end

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspace

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function part(parent: Instance, props): Part
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Mesh" then
			p[k] = v
		end
	end
	if props.Mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = props.Mesh
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function cylY(parent, center: Vector3, d: number, h: number, color: Color3, material, props)
	local p = part(parent, {
		Shape = Enum.PartType.Cylinder, Size = V(h, d, d),
		CFrame = CF(center) * CFrame.Angles(0, 0, rad(90)), Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	return p
end

local function cylBetween(parent, a: Vector3, b: Vector3, d: number, color: Color3, material)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf
	if math.abs((b - a).Unit.Y) > 0.999 then
		cf = CF(mid) * CFrame.Angles(0, 0, rad(90))
	else
		cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, rad(90), 0)
	end
	return part(parent, { Shape = Enum.PartType.Cylinder, Size = V(len, d, d), CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3, opts)
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.ppu or 40
	sg.LightInfluence = 0
	sg.Brightness = 1.2
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = opts.font or Enum.Font.LuckiestGuy
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = opts.stroke or Color3.fromRGB(40, 24, 10)
	t.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = t
	return sg, t
end

local WOOD = Color3.fromRGB(150, 104, 64)
local WOOD_DARK = Color3.fromRGB(110, 74, 44)
local STONE = Color3.fromRGB(196, 190, 178)
local STONE_DARK = Color3.fromRGB(150, 144, 134)
local GRASS = Color3.fromRGB(96, 178, 74)
local SOIL = Color3.fromRGB(104, 72, 48)
local WHITE = Color3.fromRGB(250, 248, 240)

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------
do
	for _, c in ipairs(Lighting:GetChildren()) do
		c:Destroy()
	end
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(86, 84, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 132, 146)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.GeographicLatitude = 35

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.27
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(200, 222, 245)
	atm.Decay = Color3.fromRGB(120, 140, 175)
	atm.Glare = 0.25
	atm.Haze = 1.1
	atm.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.14
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.52
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

---------------------------------------------------------------------------
-- Terrain: grassy island, beach ring, sea, distant islets
---------------------------------------------------------------------------
do
	local T = workspace.Terrain
	T:Clear()
	T.WaterColor = Color3.fromRGB(40, 150, 190)
	T.WaterTransparency = 0.55
	T.WaterReflectance = 0.6
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 8
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 178, 76))
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 164, 66))
	T:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(232, 214, 164))
	T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 122, 132))

	T:FillBlock(CF(0, -14, 0), V(2048, 20, 2048), Enum.Material.Water)
	T:FillBlock(CF(0, -30, 0), V(2048, 12, 2048), Enum.Material.Sand)
	-- Solid island body: full cells up to y = -4 (renders a surface at -2).
	T:FillCylinder(CF(0, -12, 0), 8, 300, Enum.Material.Sand)
	T:FillCylinder(CF(0, -8, 0), 8, 288, Enum.Material.Sand)
	T:FillCylinder(CF(0, -8, 0), 8, 270, Enum.Material.Grass)

	-- Top voxel layer (y -4..0) written by hand: occupancy 0.5 puts the grass
	-- surface at exactly y = 0. Under the plaza, paths and gardens it is left
	-- empty so tall grass never pokes through the floors.
	local plotFrames = {}
	for i = 1, Config.MaxPlots do
		local a = rad((i - 1) * (360 / Config.MaxPlots) + 22.5)
		local c = V(math.cos(a) * Config.PlotRadius, 0, math.sin(a) * Config.PlotRadius)
		table.insert(plotFrames, { cf = CFrame.lookAt(c, V(0, 0, 0)), dir = V(math.cos(a), 0, math.sin(a)) })
	end
	local function carved(x: number, z: number): boolean
		local r = math.sqrt(x * x + z * z)
		if r < 58 then
			return true
		end
		for _, pf in ipairs(plotFrames) do
			local lp = pf.cf:PointToObjectSpace(V(x, 0, z))
			if math.abs(lp.X) < Config.PlotSize.X / 2 - 1.5 and math.abs(lp.Z) < Config.PlotSize.Y / 2 - 1.5 then
				return true
			end
			-- path strip from the hub to the gate
			local along = V(x, 0, z):Dot(pf.dir)
			local side = (V(x, 0, z) - pf.dir * along).Magnitude
			if along > 50 and along < Config.PlotRadius - Config.PlotSize.Y / 2 + 1 and side < 5 then
				return true
			end
		end
		return false
	end
	local R = 304
	local region = Region3.new(V(-R, -4, -R), V(R, 0, R)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(region, 4)
	local size = mats.Size
	local minX, minZ = region.CFrame.Position.X - region.Size.X / 2, region.CFrame.Position.Z - region.Size.Z / 2
	for xi = 1, size.X do
		for zi = 1, size.Z do
			local x, z = minX + (xi - 0.5) * 4, minZ + (zi - 0.5) * 4
			local r = math.sqrt(x * x + z * z)
			local m, o = Enum.Material.Air, 0
			if r < 268 then
				if carved(x, z) then
					m, o = Enum.Material.Ground, 0.3 -- no grass decoration under floors
				else
					m, o = Enum.Material.Grass, 0.5
				end
			elseif r < 284 then
				m, o = Enum.Material.Sand, 0.3
			end
			mats[xi][1][zi] = m
			occ[xi][1][zi] = o
		end
	end
	T:WriteVoxels(region, 4, mats, occ)

	-- Gentle hills around the rim, kept clear of garden directions.
	for i = 0, 15 do
		local a = rad(i * 22.5 + 11.25)
		local r = 236 + rng:NextNumber(-6, 10)
		local pos = V(math.cos(a) * r, -8, math.sin(a) * r)
		T:FillBall(pos, rng:NextNumber(22, 34), Enum.Material.Grass)
		if i % 2 == 0 then
			T:FillBall(pos + V(rng:NextNumber(-8, 8), 10, rng:NextNumber(-8, 8)), rng:NextNumber(10, 16), Enum.Material.Rock)
		end
	end
	-- Far islets for the horizon.
	for i = 1, 7 do
		local a = rad(i * 51 + 10)
		local r = rng:NextNumber(520, 760)
		local pos = V(math.cos(a) * r, -14, math.sin(a) * r)
		local size = rng:NextNumber(40, 80)
		T:FillBall(pos, size, Enum.Material.Rock)
		T:FillBall(pos + V(0, size * 0.45, 0), size * 0.7, Enum.Material.Grass)
	end
end

---------------------------------------------------------------------------
-- Decorative builders
---------------------------------------------------------------------------
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = world

local function tree(pos: Vector3, scale: number, kind: string?)
	local m = model(decor, "Tree")
	local trunkH = 6 * scale
	cylBetween(m, pos, pos + V(0, trunkH, 0), 1.3 * scale, Color3.fromRGB(122, 84, 52), Enum.Material.Wood)
	local leaf = kind == "blossom" and Color3.fromRGB(255, 176, 210) or Color3.fromRGB(rng:NextInteger(70, 96), rng:NextInteger(150, 178), rng:NextInteger(60, 80))
	local blobs = { { V(0, 0, 0), 7 }, { V(2.2, -0.8, 1), 5 }, { V(-2.0, -0.6, -1.2), 5.2 }, { V(0.4, 2.2, -0.3), 4.6 } }
	for _, b in ipairs(blobs) do
		part(m, { Shape = Enum.PartType.Ball, Size = V(b[2], b[2], b[2]) * scale, CFrame = CF(pos + V(0, trunkH + 1.5 * scale, 0) + b[1] * scale), Color = leaf, Material = Enum.Material.SmoothPlastic, CastShadow = true })
	end
	for _, p in ipairs(m:GetChildren()) do
		p.CanCollide = p.Shape == Enum.PartType.Cylinder
	end
	return m
end

local function crystal(pos: Vector3, scale: number, color: Color3)
	local m = model(decor, "Crystal")
	local gems = RS.Assets.Gems
	for k = 1, 4 do
		local s = gems.Shard:Clone()
		local h = (k == 1) and 1 or rng:NextNumber(0.45, 0.75)
		s.Size = gems.Shard.Size * scale * h * V(1.2, 1, 1.2)
		local tilt = (k == 1) and 0 or rad(rng:NextNumber(18, 38))
		local yaw = rad(k * 97)
		s.CFrame = CF(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, tilt) * CF(0, s.Size.Y * 0.4, 0)
		s.Color = color
		s.Material = Enum.Material.Glass
		s.Reflectance = 0.15
		s.CanCollide = true
		s.CastShadow = true
		s.Parent = m
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10 * math.min(scale, 3)
	glow.Brightness = 0.8
	glow.Parent = m:FindFirstChildWhichIsA("BasePart")
	return m
end

local function flowerPatch(center: Vector3, count: number, spread: number)
	local m = model(decor, "Flowers")
	local palette = { Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 70) }
	for _ = 1, count do
		local p = center + V(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
		cylBetween(m, p, p + V(0, 0.9, 0), 0.12, Color3.fromRGB(80, 150, 70))
		part(m, { Shape = Enum.PartType.Ball, Size = V(0.55, 0.55, 0.55), CFrame = CF(p + V(0, 1.0, 0)), Color = palette[rng:NextInteger(1, #palette)], CanCollide = false, CastShadow = false })
	end
	for _, p in ipairs(m:GetChildren()) do
		p.CanCollide = false
		p.CanQuery = false
	end
	return m
end

local function lamp(pos: Vector3, height: number?)
	local m = model(decor, "Lamp")
	height = height or 9
	cylBetween(m, pos, pos + V(0, height, 0), 0.5, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	part(m, { Size = V(1.6, 0.3, 1.6), CFrame = CF(pos + V(0, height + 0.15, 0)), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	local bulb = part(m, { Size = V(1.1, 1.4, 1.1), CFrame = CF(pos + V(0, height - 0.6, 0)), Color = Color3.fromRGB(255, 226, 160), Material = Enum.Material.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 214, 150)
	l.Range = 16
	l.Brightness = 1.2
	l.Shadows = false
	l.Parent = bulb
	return m
end

---------------------------------------------------------------------------
-- Hub plaza
---------------------------------------------------------------------------
local hub = model(world, "Hub")
local HUB_R = 60
do
	cylY(hub, V(0, 0.2, 0), HUB_R * 2, 0.6, STONE, Enum.Material.Pavement)
	cylY(hub, V(0, 0.25, 0), HUB_R * 2 - 6, 0.62, Color3.fromRGB(214, 206, 190), Enum.Material.Pavement)
	-- decorative rings
	for _, r in ipairs({ 22, 40 }) do
		local seg = 48
		for i = 1, seg do
			local a = rad(i / seg * 360)
			local pos = V(math.cos(a) * r, 0.58, math.sin(a) * r)
			part(hub, { Size = V(2 * math.pi * r / seg + 0.2, 0.1, 1.4), CFrame = CFrame.lookAt(pos, pos + V(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(0, rad(90), 0), Color = STONE_DARK, Material = Enum.Material.Pavement, CanCollide = false })
		end
	end

	-- Fountain with the giant Heart Crystal.
	local f = model(hub, "Fountain")
	cylY(f, V(0, 1.2, 0), 26, 2.2, STONE_DARK, Enum.Material.Slate)
	local water = cylY(f, V(0, 1.6, 0), 23, 2.2, Color3.fromRGB(70, 170, 220), Enum.Material.Glass)
	water.Transparency = 0.25
	water.Reflectance = 0.3
	water.CanCollide = false
	cylY(f, V(0, 3.0, 0), 8, 4.5, STONE, Enum.Material.Slate)
	cylY(f, V(0, 5.4, 0), 10, 0.6, STONE_DARK, Enum.Material.Slate)
	local core = crystal(V(0, 5.6, 0), 4.6, Color3.fromRGB(150, 110, 255))
	core.Name = "HeartCrystal"
	core.Parent = f
	for i = 1, 6 do
		local a = rad(i * 60 + 30)
		crystal(V(math.cos(a) * 9.3, 2.4, math.sin(a) * 9.3), 1.1, Color3.fromHSV(i / 6, 0.55, 1)).Parent = f
	end
	-- spawn ring around the fountain (fallback spawns)
	for i = 1, 4 do
		local a = rad(i * 90 + 45)
		local s = Instance.new("SpawnLocation")
		s.Anchored = true
		s.Size = V(6, 0.4, 6)
		s.CFrame = CF(math.cos(a) * 19, 0.75, math.sin(a) * 19)
		s.Transparency = 1
		s.CanCollide = false
		s.Duration = 0
		s.Neutral = true
		s.Parent = hub
		local decal = s:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end
	for i = 1, 8 do
		local a = rad(i * 45)
		lamp(V(math.cos(a) * (HUB_R - 4), 0.5, math.sin(a) * (HUB_R - 4)))
	end
end

---------------------------------------------------------------------------
-- Gnome shopkeeper
---------------------------------------------------------------------------
local function gnome(parent: Instance, cf: CFrame, hatColor: Color3, shirt: Color3, name: string)
	local m = model(parent, name)
	local function P(props)
		props.CanCollide = false
		props.CastShadow = true
		return part(m, props)
	end
	local s = 1.25
	local function at(x, y, z)
		return cf * CF(x * s, y * s, z * s)
	end
	P({ Size = V(1.0, 0.5, 1.2) * s, CFrame = at(-0.45, 0.25, -0.1), Color = Color3.fromRGB(70, 46, 30), Mesh = Enum.MeshType.Sphere })
	P({ Size = V(1.0, 0.5, 1.2) * s, CFrame = at(0.45, 0.25, -0.1), Color = Color3.fromRGB(70, 46, 30), Mesh = Enum.MeshType.Sphere })
	P({ Size = V(2.2, 2.6, 2.0) * s, CFrame = at(0, 1.7, 0), Color = shirt, Mesh = Enum.MeshType.Sphere })
	P({ Size = V(2.15, 0.35, 1.95) * s, CFrame = at(0, 1.2, 0), Color = Color3.fromRGB(60, 40, 26), Mesh = Enum.MeshType.Sphere })
	P({ Size = V(0.5, 0.4, 0.2) * s, CFrame = at(0, 1.2, -0.95), Color = Color3.fromRGB(255, 210, 80), Material = Enum.Material.Metal })
	P({ Size = V(1.9, 1.9, 1.9) * s, CFrame = at(0, 3.35, 0), Color = Color3.fromRGB(255, 205, 170), Shape = Enum.PartType.Ball })
	P({ Size = V(1.9, 1.7, 1.2) * s, CFrame = at(0, 2.75, -0.45), Color = WHITE, Mesh = Enum.MeshType.Sphere })
	P({ Size = V(0.6, 0.6, 0.6) * s, CFrame = at(0, 3.3, -0.95), Color = Color3.fromRGB(255, 150, 140), Shape = Enum.PartType.Ball })
	for _, x in ipairs({ -0.38, 0.38 }) do
		P({ Size = V(0.26, 0.32, 0.12) * s, CFrame = at(x, 3.68, -0.86), Color = Color3.fromRGB(30, 24, 30), Mesh = Enum.MeshType.Sphere })
		P({ Size = V(0.55, 0.12, 0.2) * s, CFrame = at(x, 3.95, -0.8) * CFrame.Angles(0, 0, x > 0 and -0.2 or 0.2), Color = WHITE })
	end
	-- cone hat from stacked tapered cylinders
	local y, d = 3.95, 2.25
	for k = 1, 7 do
		local h = 0.42
		P({ Shape = Enum.PartType.Cylinder, Size = V(h, d, d) * s, CFrame = at(0, y + h / 2, 0.08 * k) * CFrame.Angles(0, 0, rad(90)), Color = hatColor })
		y += h * 0.92
		d *= 0.76
	end
	P({ Shape = Enum.PartType.Ball, Size = V(0.4, 0.4, 0.4) * s, CFrame = at(0, y + 0.1, 0.62), Color = hatColor })
	-- arms
	for _, x in ipairs({ -1, 1 }) do
		P({ Size = V(0.7, 1.5, 0.7) * s, CFrame = at(x * 1.05, 1.9, -0.25) * CFrame.Angles(rad(-30), 0, x * rad(18)), Color = shirt, Mesh = Enum.MeshType.Sphere })
		P({ Size = V(0.6, 0.6, 0.6) * s, CFrame = at(x * 1.25, 1.25, -0.65), Color = Color3.fromRGB(255, 205, 170), Shape = Enum.PartType.Ball })
	end
	return m
end

---------------------------------------------------------------------------
-- Shop stalls
---------------------------------------------------------------------------
local shops = Instance.new("Folder")
shops.Name = "Shops"
shops.Parent = world

local function stall(id: string, title: string, angleDeg: number, stripeA: Color3, stripeB: Color3, hat: Color3, shirt: Color3, promptText: string)
	local a = rad(angleDeg)
	local r = 44
	local pos = V(math.cos(a) * r, 0.55, math.sin(a) * r)
	local cf = CFrame.lookAt(pos, V(0, 0.55, 0)) -- faces the fountain
	local m = model(shops, id)
	m:SetAttribute("ShopId", id)
	local function at(x, y, z)
		return cf * CF(x, y, z)
	end
	-- floor & counter
	part(m, { Size = V(16, 0.5, 11), CFrame = at(0, 0.25, 1.5), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks })
	local counter = part(m, { Name = "Counter", Size = V(12, 3.2, 2), CFrame = at(0, 2.1, -1.5), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(m, { Size = V(12.6, 0.4, 2.6), CFrame = at(0, 3.9, -1.5), Color = WOOD_DARK, Material = Enum.Material.Wood })
	-- back wall + posts
	part(m, { Size = V(16, 9, 0.8), CFrame = at(0, 4.8, 6.6), Color = Color3.fromRGB(236, 226, 206), Material = Enum.Material.Plaster })
	for _, x in ipairs({ -7.6, 7.6 }) do
		part(m, { Size = V(0.8, 10, 0.8), CFrame = at(x, 5.3, -3.2), Color = WOOD, Material = Enum.Material.Wood })
		part(m, { Size = V(0.8, 10, 0.8), CFrame = at(x, 5.3, 6.2), Color = WOOD, Material = Enum.Material.Wood })
	end
	-- striped awning
	local n = 8
	for i = 0, n - 1 do
		local x = -8 + (i + 0.5) * (16 / n)
		local stripe = part(m, { Size = V(16 / n, 0.3, 10.6), CFrame = at(x, 10.2, 1.4) * CFrame.Angles(rad(-12), 0, 0), Color = (i % 2 == 0) and stripeA or stripeB, Material = Enum.Material.Fabric })
		stripe.CanCollide = false
		local flap = part(m, { Size = V(16 / n, 1.2, 0.2), CFrame = at(x, 10.7, -4.0), Color = (i % 2 == 0) and stripeA or stripeB, Material = Enum.Material.Fabric })
		flap.CanCollide = false
	end
	-- title sign
	local sign = part(m, { Name = "Sign", Size = V(13, 3.2, 0.6), CFrame = at(0, 13.2, -3.6), Color = WOOD_DARK, Material = Enum.Material.Wood })
	part(m, { Size = V(13.8, 4, 0.4), CFrame = at(0, 13.2, -3.4), Color = Color3.fromRGB(80, 52, 30), Material = Enum.Material.Wood })
	label(sign, Enum.NormalId.Front, title, Color3.fromRGB(255, 244, 214))
	-- shelves with decoration behind the counter
	part(m, { Size = V(12, 0.4, 1.6), CFrame = at(0, 4.6, 5.6), Color = WOOD, Material = Enum.Material.Wood })
	part(m, { Size = V(12, 0.4, 1.6), CFrame = at(0, 7.2, 5.6), Color = WOOD, Material = Enum.Material.Wood })
	gnome(m, at(0, 0.5, 2.2), hat, shirt, "Gnome")
	-- interaction point
	local promptPart = part(m, { Name = "PromptPart", Size = V(4, 4, 4), CFrame = at(0, 3, -3.5), Transparency = 1, CanCollide = false, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("ShopId", id)
	prompt.Parent = promptPart
	-- teleport target in front of the counter
	local tp = part(m, { Name = "TeleportPoint", Size = V(2, 1, 2), CFrame = at(0, 3, -8) * CFrame.Angles(0, rad(180), 0), Transparency = 1, CanCollide = false, CanQuery = false })
	tp:SetAttribute("ShopId", id)
	-- floating billboard (timer / hint), filled in at runtime
	local bbPart = part(m, { Name = "BillboardPart", Size = V(1, 1, 1), CFrame = at(0, 16.5, -3.6), Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromScale(12, 2.2)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = bbPart
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = ""
	t.Parent = bb
	return m, cf
end

do
	local seedShop, seedCF = stall("seeds", "SEED SHOP", -90, Color3.fromRGB(110, 200, 90), WHITE, Color3.fromRGB(220, 50, 50), Color3.fromRGB(70, 130, 220), "Browse Seeds")
	local gearShop, gearCF = stall("gear", "GEAR SHOP", 0, Color3.fromRGB(80, 150, 230), WHITE, Color3.fromRGB(70, 110, 230), Color3.fromRGB(230, 140, 40), "Browse Gear")
	local sellShop, sellCF = stall("sell", "GEM TRADER", 90, Color3.fromRGB(240, 190, 50), WHITE, Color3.fromRGB(150, 70, 220), Color3.fromRGB(60, 160, 90), "Sell Gems")
	local store, storeCF = stall("store", "GEM STORE", 180, Color3.fromRGB(190, 90, 240), WHITE, Color3.fromRGB(255, 190, 40), Color3.fromRGB(200, 60, 120), "Open Store")
	-- counter props: seed sacks, tools, gems
	local function sack(cf, color)
		part(seedShop, { Size = V(1.6, 1.8, 1.6), CFrame = cf, Color = Color3.fromRGB(214, 190, 140), Material = Enum.Material.Fabric, Mesh = Enum.MeshType.Sphere, CanCollide = false })
		part(seedShop, { Size = V(1.2, 0.5, 1.2), CFrame = cf * CF(0, 0.85, 0), Color = color, Mesh = Enum.MeshType.Sphere, CanCollide = false })
	end
	sack(seedCF * CF(-4, 4.9, -1.5), Color3.fromRGB(255, 180, 60))
	sack(seedCF * CF(-1.6, 4.9, -1.5), Color3.fromRGB(180, 100, 255))
	sack(seedCF * CF(4, 4.9, -1.5), Color3.fromRGB(255, 80, 110))
	for i = 1, 5 do
		local g = RS.Assets.Gems.Brilliant:Clone()
		g.Size = g.Size * 0.9
		g.CFrame = sellCF * CF(-4.5 + i * 1.6, 4.55, -1.5) * CFrame.Angles(0, i, 0)
		g.Color = Color3.fromHSV(i / 5, 0.7, 1)
		g.Parent = sellShop
	end
	for i = 1, 4 do
		local g = RS.Assets.Gems.Cluster:Clone()
		g.Size = g.Size * 1.2
		g.CFrame = storeCF * CF(-4.5 + i * 1.8, 5.4, -1.5) * CFrame.Angles(0, i * 0.7, 0)
		g.Color = Color3.fromHSV(i / 4 + 0.1, 0.5, 1)
		g.Parent = store
	end
	-- watering cans on the gear counter
	for i = 1, 3 do
		local base = gearCF * CF(-4 + i * 2.2, 4.6, -1.5)
		part(gearShop, { Shape = Enum.PartType.Cylinder, Size = V(1.2, 1.1, 1.1), CFrame = base * CFrame.Angles(0, 0, rad(90)), Color = Color3.fromHSV(i / 3, 0.5, 0.9), Material = Enum.Material.Metal, CanCollide = false })
		part(gearShop, { Size = V(0.2, 0.2, 1.2), CFrame = base * CF(0, 0.2, -0.8) * CFrame.Angles(rad(30), 0, 0), Color = Color3.fromHSV(i / 3, 0.5, 0.8), Material = Enum.Material.Metal, CanCollide = false })
	end
end

---------------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------------
local boards = Instance.new("Folder")
boards.Name = "Leaderboards"
boards.Parent = world
local function board(id: string, title: string, angleDeg: number, color: Color3)
	local a = rad(angleDeg)
	local pos = V(math.cos(a) * 50, 0.55, math.sin(a) * 50)
	local cf = CFrame.lookAt(pos, V(0, 0.55, 0))
	local m = model(boards, id)
	for _, x in ipairs({ -5.2, 5.2 }) do
		part(m, { Size = V(0.8, 15, 0.8), CFrame = cf * CF(x, 7.5, 0.6), Color = WOOD, Material = Enum.Material.Wood })
	end
	local panel = part(m, { Name = "Panel", Size = V(10, 12, 0.6), CFrame = cf * CF(0, 8.8, 0), Color = Color3.fromRGB(34, 30, 48), Material = Enum.Material.SmoothPlastic })
	part(m, { Size = V(10.8, 12.8, 0.4), CFrame = cf * CF(0, 8.8, 0.3), Color = color, Material = Enum.Material.Neon })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Board"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Parent = panel
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.12, 0)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = title
	t.Parent = sg
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.13)
	list.Size = UDim2.fromScale(0.92, 0.85)
	list.Parent = sg
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.005, 0)
	layout.Parent = list
	m:SetAttribute("BoardId", id)
	return m
end
board("earned", "TOP GARDENERS", 135, Color3.fromRGB(255, 200, 60))
board("value", "RAREST GEMS", 225, Color3.fromRGB(190, 120, 255))
board("playtime", "MOST DEDICATED", 315, Color3.fromRGB(110, 220, 255))

---------------------------------------------------------------------------
-- Gardens
---------------------------------------------------------------------------
local PW, PD = Config.PlotSize.X, Config.PlotSize.Y
local BW, BD = Config.BedSize.X, Config.BedSize.Y
local PATH = Config.BedPath
local BED_TOP = 0.5 + Config.BedHeight

local plotColors = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 180, 80), Color3.fromRGB(250, 230, 90), Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(90, 200, 230), Color3.fromRGB(110, 140, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 130, 200),
}

for i = 1, Config.MaxPlots do
	local angle = rad((i - 1) * (360 / Config.MaxPlots) + 22.5)
	local center = V(math.cos(angle) * Config.PlotRadius, 0, math.sin(angle) * Config.PlotRadius)
	local cf = CFrame.lookAt(center, V(0, 0, 0)) -- -Z (front) faces the hub
	local plot = model(plotsFolder, "Plot_" .. i)
	plot:SetAttribute("Index", i)
	plot:SetAttribute("Color", plotColors[i])
	local function at(x, y, z)
		return cf * CF(x, y, z)
	end

	part(plot, { Name = "Base", Size = V(PW, 1, PD), CFrame = at(0, 0, 0), Color = GRASS, Material = Enum.Material.Grass })
	local origin = part(plot, { Name = "Origin", Size = V(1, 1, 1), CFrame = at(0, BED_TOP, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	origin:SetAttribute("BedTop", BED_TOP)

	-- beds with wooden frames
	local beds = Instance.new("Folder")
	beds.Name = "Beds"
	beds.Parent = plot
	for side = -1, 1, 2 do
		local x = side * (PATH / 2 + BW / 2)
		local bed = part(beds, { Name = "Bed", Size = V(BW, BED_TOP - 0.5 + 0.2, BD), CFrame = at(x, (BED_TOP + 0.3) / 2, 0), Color = SOIL, Material = Enum.Material.Ground })
		bed.CFrame = at(x, BED_TOP - bed.Size.Y / 2, 0)
		bed:SetAttribute("PlotIndex", i)
		local fh, ft = 1.0, 0.8
		for _, z in ipairs({ -BD / 2 - ft / 2, BD / 2 + ft / 2 }) do
			part(plot, { Size = V(BW + ft * 2, fh, ft), CFrame = at(x, BED_TOP - fh / 2 + 0.25, z), Color = WOOD, Material = Enum.Material.WoodPlanks, CanQuery = false })
		end
		for _, dx in ipairs({ -BW / 2 - ft / 2, BW / 2 + ft / 2 }) do
			part(plot, { Size = V(ft, fh, BD), CFrame = at(x + dx, BED_TOP - fh / 2 + 0.25, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanQuery = false })
		end
	end

	-- center path
	for k = 0, 8 do
		local z = -PD / 2 + 3 + k * ((PD - 6) / 8)
		part(plot, { Size = V(PATH - 2.4, 0.3, 6), CFrame = at(0, 0.6, z) * CFrame.Angles(0, rad(rng:NextNumber(-4, 4)), 0), Color = Color3.fromRGB(rng:NextInteger(184, 204), rng:NextInteger(178, 196), rng:NextInteger(166, 182)), Material = Enum.Material.Slate, CanQuery = false })
	end

	-- picket fence with a gate gap at the front
	local fence = model(plot, "Fence")
	local function fenceLine(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local mid = (a + b) / 2
		for _, h in ipairs({ 1.1, 2.3 }) do
			part(fence, { Size = V(0.3, 0.35, len), CFrame = CFrame.lookAt(mid + V(0, h, 0), mid + V(0, h, 0) + dir), Color = WHITE, CanQuery = false })
		end
		local posts = math.floor(len / 2.2)
		for k = 0, posts do
			local p = a + dir * (k * len / posts)
			part(fence, { Size = V(0.5, 3.0, 0.5), CFrame = CFrame.lookAt(p + V(0, 1.5, 0), p + V(0, 1.5, 0) + dir), Color = WHITE, CanQuery = false })
		end
	end
	local hx, hz = PW / 2 - 0.5, PD / 2 - 0.5
	local gate = 7
	local function w(x, z)
		return (cf * CF(x, 0.5, z)).Position
	end
	fenceLine(w(-hx, -hz), w(-gate, -hz))
	fenceLine(w(gate, -hz), w(hx, -hz))
	fenceLine(w(hx, -hz), w(hx, hz))
	fenceLine(w(hx, hz), w(-hx, hz))
	fenceLine(w(-hx, hz), w(-hx, -hz))
	-- gate arch
	local arch = model(plot, "Arch")
	for _, x in ipairs({ -gate, gate }) do
		part(arch, { Size = V(1, 9, 1), CFrame = at(x, 4.5, -hz), Color = WOOD, Material = Enum.Material.Wood })
	end
	local archTop = part(arch, { Name = "ArchSign", Size = V(gate * 2 + 2, 2.6, 0.6), CFrame = at(0, 9.2, -hz), Color = WOOD_DARK, Material = Enum.Material.Wood })
	local _, nameLabel = label(archTop, Enum.NormalId.Front, "EMPTY GARDEN", Color3.fromRGB(255, 244, 214), { ppu = 30 })
	nameLabel.Name = "OwnerName"
	local backLabelGui, backLabel = label(archTop, Enum.NormalId.Back, "EMPTY GARDEN", Color3.fromRGB(255, 244, 214), { ppu = 30 })
	backLabel.Name = "OwnerNameBack"
	backLabelGui.Name = "BackGui"
	-- colored flag/banner on the arch
	part(arch, { Name = "Banner", Size = V(gate * 2 + 2.6, 0.5, 0.8), CFrame = at(0, 10.75, -hz), Color = plotColors[i], Material = Enum.Material.SmoothPlastic })
	-- owner avatar board beside the gate
	local avatarPost = part(plot, { Size = V(0.6, 6, 0.6), CFrame = at(gate + 4, 3, -hz - 1.5), Color = WOOD, Material = Enum.Material.Wood })
	local avatarBoard = part(plot, { Name = "AvatarBoard", Size = V(4.4, 4.4, 0.4), CFrame = at(gate + 4, 6.6, -hz - 1.5) * CFrame.Angles(0, rad(180), 0), Color = WHITE })
	local asg = Instance.new("SurfaceGui")
	asg.Name = "Avatar"
	asg.Face = Enum.NormalId.Back
	asg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	asg.PixelsPerStud = 40
	asg.LightInfluence = 0
	asg.Parent = avatarBoard
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundColor3 = plotColors[i]
	img.Size = UDim2.fromScale(1, 1)
	img.Image = ""
	img.Parent = asg
	local _ = avatarPost

	-- corner lamps
	for _, c in ipairs({ { -hx + 1.5, -hz + 1.5 }, { hx - 1.5, -hz + 1.5 }, { -hx + 1.5, hz - 1.5 }, { hx - 1.5, hz - 1.5 } }) do
		local l = lamp((cf * CF(c[1], 0.5, c[2])).Position, 7)
		l.Parent = plot
	end

	-- spawn point just inside the gate, facing into the garden
	local sp = part(plot, { Name = "SpawnPoint", Size = V(2, 1, 2), CFrame = at(0, 3.5, -hz + 4) * CFrame.Angles(0, rad(180), 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local _ = sp

	-- path from the hub to the gate
	local gateWorld = w(0, -hz - 1)
	local hubEdge = V(math.cos(angle), 0, math.sin(angle)) * (HUB_R - 2)
	local len = (gateWorld - hubEdge).Magnitude
	part(world, { Name = "Path", Size = V(12, 0.4, len), CFrame = CFrame.lookAt((gateWorld + hubEdge) / 2 + V(0, 0.32, 0), gateWorld + V(0, 0.32, 0)), Color = Color3.fromRGB(206, 196, 176), Material = Enum.Material.Pavement })
	part(world, { Name = "PathEdge", Size = V(13.4, 0.36, len), CFrame = CFrame.lookAt((gateWorld + hubEdge) / 2 + V(0, 0.28, 0), gateWorld + V(0, 0.28, 0)), Color = STONE_DARK, Material = Enum.Material.Pavement })
	-- flowers & lamps along the path
	for k = 1, 2 do
		local t = k / 3
		local p = hubEdge:Lerp(gateWorld, t)
		local side = V(-math.sin(angle), 0, math.cos(angle))
		flowerPatch(p + side * 9, 6, 2)
		flowerPatch(p - side * 9, 6, 2)
	end
end

---------------------------------------------------------------------------
-- Scenery between gardens and around the rim
---------------------------------------------------------------------------
for i = 1, Config.MaxPlots do
	local a = rad((i - 1) * 45 + 45) -- between gardens
	local r = Config.PlotRadius
	local p = V(math.cos(a) * r, 0, math.sin(a) * r)
	tree(p + V(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), rng:NextNumber(1.1, 1.4), (i % 3 == 0) and "blossom" or nil)
	crystal(V(math.cos(a) * (r - 30), 0.2, math.sin(a) * (r - 30)), rng:NextNumber(1.4, 2.2), Color3.fromHSV(rng:NextNumber(), 0.55, 1))
	tree(V(math.cos(a) * (r + 40), 0, math.sin(a) * (r + 40)), rng:NextNumber(1.2, 1.6))
	flowerPatch(V(math.cos(a) * (r - 16), 0, math.sin(a) * (r - 16)), 10, 4)
	-- benches near the hub
	local bp = V(math.cos(a) * 66, 0.5, math.sin(a) * 66)
	local bcf = CFrame.lookAt(bp, V(0, 0.5, 0))
	local bench = model(decor, "Bench")
	part(bench, { Size = V(6, 0.4, 1.8), CFrame = bcf * CF(0, 1.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(bench, { Size = V(6, 1.6, 0.3), CFrame = bcf * CF(0, 2.6, 0.9), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -2.6, 2.6 }) do
		part(bench, { Size = V(0.4, 1.4, 1.6), CFrame = bcf * CF(x, 0.9, 0), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal })
	end
end
for i = 0, 23 do
	local a = rad(i * 15 + rng:NextNumber(-4, 4))
	local r = rng:NextNumber(205, 228)
	local p = V(math.cos(a) * r, 0, math.sin(a) * r)
	if i % 3 == 0 then
		crystal(p, rng:NextNumber(2.4, 4.2), Color3.fromHSV(rng:NextNumber(), 0.5, 1))
	else
		tree(p, rng:NextNumber(1.2, 1.8), (i % 5 == 0) and "blossom" or nil)
	end
end

-- Invisible boundary so nobody wanders off into the endless sea.
local walls = Instance.new("Folder")
walls.Name = "Boundary"
walls.Parent = world
for i = 1, 36 do
	local a = rad(i * 10)
	local r = 330
	local p = V(math.cos(a) * r, 40, math.sin(a) * r)
	part(walls, { Size = V(2 * math.pi * r / 36 + 2, 120, 2), CFrame = CFrame.lookAt(p, V(0, 40, 0)), Transparency = 1, CanQuery = false })
end

local count = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") then
		count += 1
	end
end
return "world built, parts: " .. count
