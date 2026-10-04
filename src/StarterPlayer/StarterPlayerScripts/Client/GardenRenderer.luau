-- Renders every garden on the client from the replicated plant data:
-- smooth growth, gems swelling until ripe, mutation effects, harvest prompts
-- (own garden only) and sprinklers.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Value = require(Shared.Util.Value)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local PlantBuilder = require(Shared.Visuals.PlantBuilder)
local GemFactory = require(Shared.Visuals.GemFactory)

local Sounds = require(script.Parent.Sounds)

local GardenRenderer = {}

local player = Players.LocalPlayer
local plants = {} -- [folder] = record
local byPlot = {} -- [plotIndex] = { [id] = record }
local sprinklers = {} -- [folder] = record
local renderFolder = Instance.new("Folder")
renderFolder.Name = "GardenRender"
renderFolder.Parent = workspace

local harvestEvent = Net.event("Harvest")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_RANGE = 90

local ripeEvent = Instance.new("BindableEvent")
GardenRenderer.Ripened = ripeEvent.Event -- (record) own plants only
local harvestedLocal = Instance.new("BindableEvent")
GardenRenderer.HarvestPressed = harvestedLocal.Event

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myPlot(): number?
	return player:GetAttribute("PlotIndex")
end

local function plotOrigin(index: number): CFrame?
	local plot = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot_" .. index)
	return plot and plot.Origin.CFrame
end

local function decode(json: string?)
	if not json or json == "" then
		return {}
	end
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok then
		return {}
	end
	local out = {}
	for i, f in ipairs(raw) do
		out[i] = { r = f[1], w = f[2], m = f[3] or {} }
	end
	return out
end

local function mutKey(m): string
	return table.concat(m or {}, ",")
end

---------------------------------------------------------------------------
-- Fruits (gems)
---------------------------------------------------------------------------
local function destroyFruit(f)
	if f.part then
		f.part:Destroy()
		f.part = nil
	end
	f.prompt = nil
	f.ripeShown = false
end

local function setEmitters(part: BasePart, on: boolean)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("ParticleEmitter") then
			c.Enabled = on
		end
	end
end

local function makePrompt(rec, slot: number, f)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Harvest"
	local gem = { s = rec.sp.id, w = f.w, m = f.m }
	p.ObjectText = string.format("%s • %s • $%s", Value.label(gem), Format.carat(Value.carat(gem)), Format.short(Value.base(gem)))
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.Triggered:Connect(function()
		f.pendingUntil = now() + 2.5
		destroyFruit(f)
		Sounds.play("pop", 0.95 + math.random() * 0.15)
		harvestEvent:FireServer(rec.id, slot)
		harvestedLocal:Fire(rec, gem)
	end)
	return p
end

local function updateFruit(rec, slot: number, f, t: number, alpha: number, near: boolean)
	local sp = rec.sp
	local visible, ripeness
	if sp.multi then
		visible = alpha >= 1
		ripeness = math.clamp(1 - (f.r - t) / math.max(sp.regrow, 1), 0, 1)
	else
		visible = alpha >= 0.35
		ripeness = math.clamp((alpha - 0.35) / 0.65, 0, 1)
	end
	if f.pendingUntil and t < f.pendingUntil then
		visible = false
	end
	local slotDef = rec.slots[slot]
	if not visible or not slotDef then
		if f.part then
			destroyFruit(f)
		end
		return
	end
	local ripe = t >= f.r
	if ripe then
		ripeness = 1
	end
	local opts = { neon = sp.neon, rainbow = sp.rainbow, shimmer = sp.shimmer }
	if not f.part then
		f.part = GemFactory.make(sp.gem, sp.gemColor, 1, opts)
		f.base = f.part.Size
		f.scale = -1
		f.mk = nil
		f.spin = (rec.seed % 628) / 100 + slot
		f.part.Parent = rec.gemFolder
	end
	if f.mk ~= mutKey(f.m) then
		f.mk = mutKey(f.m)
		GemFactory.applyMutations(f.part, f.m, sp.gemColor, opts)
		f.ripeShown = false
		if f.prompt then
			f.prompt:Destroy()
			f.prompt = nil
		end
	end
	local s = (0.28 + 0.72 * ripeness) * (f.w or 1) * sp.gemSize
	if math.abs(s - f.scale) > 0.015 or rec.scaleChanged then
		f.scale = s
		f.part.Size = f.base * s
		local cf = slotDef.cf
		if rec.scale ~= 1 then
			cf = cf - cf.Position + cf.Position * rec.scale
		end
		f.part.CFrame = rec.baseCF * PlantBuilder.gemCFrame({ cf = cf, mode = slotDef.mode }, f.part.Size, f.spin)
	end
	if ripe and not f.ripeShown then
		f.ripeShown = true
		local e = Instance.new("ParticleEmitter")
		e.Name = "Ripe"
		e.Texture = SPARKLE
		e.Rate = 2.5
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(0.3, 0.8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.Parent = f.part
		if sp.glow and not f.part:FindFirstChildOfClass("PointLight") then
			local l = Instance.new("PointLight")
			l.Color = sp.gemColor
			l.Range = 6
			l.Brightness = 0.8
			l.Shadows = false
			l.Parent = f.part
		end
		if rec.mine then
			f.prompt = makePrompt(rec, slot, f)
			f.prompt.Parent = f.part
			ripeEvent:Fire(rec)
		end
	elseif not ripe and f.ripeShown then
		local e = f.part:FindFirstChild("Ripe")
		if e then
			e:Destroy()
		end
		if f.prompt then
			f.prompt:Destroy()
			f.prompt = nil
		end
		f.ripeShown = false
	end
	if f.part then
		local want = near
		if f.emittersOn ~= want then
			f.emittersOn = want
			setEmitters(f.part, want)
		end
	end
end

---------------------------------------------------------------------------
-- Plants
---------------------------------------------------------------------------
local function applyFruitData(rec)
	local data = decode(rec.folder:GetAttribute("F"))
	for i = 1, math.max(#data, #rec.fruits) do
		local nf = data[i]
		local of = rec.fruits[i]
		if not nf then
			if of then
				destroyFruit(of)
			end
			rec.fruits[i] = nil
		elseif not of then
			rec.fruits[i] = nf
		else
			if math.abs((of.r or 0) - nf.r) > 0.5 or math.abs((of.w or 0) - nf.w) > 0.001 then
				-- a new gem started growing in this slot (or it was boosted)
				local sameGem = math.abs((of.w or 0) - nf.w) < 0.001
				if not sameGem then
					destroyFruit(of)
					of.pendingUntil = nil
				end
				of.r = nf.r
				of.w = nf.w
				of.scale = -1
			end
			of.m = nf.m
		end
	end
end

local function addPlant(folder: Folder, plotIndex: number)
	local sp = Species.get(folder:GetAttribute("S"))
	local origin = plotOrigin(plotIndex)
	if not sp or not origin then
		return
	end
	local seed = folder:GetAttribute("RS") or 1
	local model, slots = PlantBuilder.build(sp, seed)
	local yaw = (seed % 360) * math.pi / 180
	local baseCF = origin * CFrame.new(folder:GetAttribute("X"), 0, folder:GetAttribute("Z")) * CFrame.Angles(0, yaw, 0)
	model:PivotTo(baseCF)
	model.Parent = renderFolder
	-- gems live outside the model so Model:ScaleTo never touches them
	local gemFolder = Instance.new("Folder")
	gemFolder.Name = "Gems_" .. folder.Name
	gemFolder.Parent = renderFolder
	local rec = {
		folder = folder,
		id = folder.Name,
		plot = plotIndex,
		sp = sp,
		model = model,
		slots = slots,
		baseCF = baseCF,
		pos = baseCF.Position,
		seed = seed,
		gemFolder = gemFolder,
		scale = 1,
		fruits = {},
		mine = plotIndex == myPlot(),
		T = folder:GetAttribute("T"),
		G = folder:GetAttribute("G"),
	}
	-- start tiny so it visibly grows
	local alpha = math.clamp((now() - rec.T) / math.max(rec.G, 0.01), 0, 1)
	if alpha < 1 then
		rec.scale = 0.22 + 0.78 * (1 - (1 - alpha) ^ 2)
		model:ScaleTo(rec.scale)
	end
	rec.wasGrown = alpha >= 1
	applyFruitData(rec)
	folder:GetAttributeChangedSignal("F"):Connect(function()
		applyFruitData(rec)
	end)
	folder:GetAttributeChangedSignal("T"):Connect(function()
		rec.T = folder:GetAttribute("T")
	end)
	folder:GetAttributeChangedSignal("G"):Connect(function()
		rec.G = folder:GetAttribute("G")
	end)
	plants[folder] = rec
	byPlot[plotIndex] = byPlot[plotIndex] or {}
	byPlot[plotIndex][rec.id] = rec
	-- planting puff
	if alpha < 0.05 then
		local puff = Instance.new("Part")
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.Transparency = 1
		puff.Size = Vector3.one
		puff.CFrame = baseCF
		puff.Parent = renderFolder
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(140, 100, 70))
		e.Size = NumberSequence.new(0.8, 0)
		e.Speed = NumberRange.new(2, 4)
		e.Lifetime = NumberRange.new(0.4, 0.7)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Rate = 0
		e.Parent = puff
		e:Emit(14)
		task.delay(1, function()
			puff:Destroy()
		end)
	end
end

local function removePlant(folder: Folder)
	local rec = plants[folder]
	if not rec then
		return
	end
	plants[folder] = nil
	if byPlot[rec.plot] then
		byPlot[rec.plot][rec.id] = nil
	end
	rec.model:Destroy()
	rec.gemFolder:Destroy()
end

local function updatePlant(rec, t: number, camPos: Vector3)
	local alpha = math.clamp((t - (rec.T or 0)) / math.max(rec.G or 1, 0.01), 0, 1)
	rec.scaleChanged = false
	local target = alpha >= 1 and 1 or (0.22 + 0.78 * (1 - (1 - alpha) ^ 2))
	if math.abs(target - rec.scale) > 0.012 or (target == 1 and rec.scale ~= 1) then
		rec.scale = target
		rec.model:ScaleTo(target)
		rec.scaleChanged = true
	end
	if alpha >= 1 and not rec.wasGrown then
		rec.wasGrown = true
		if rec.mine then
			Sounds.play("pop", 1.3)
		end
	end
	local near = (rec.pos - camPos).Magnitude < PARTICLE_RANGE
	for i, f in pairs(rec.fruits) do
		updateFruit(rec, i, f, t, alpha, near)
	end
end

---------------------------------------------------------------------------
-- Sprinklers
---------------------------------------------------------------------------
local function addSprinkler(folder: Folder, plotIndex: number)
	local g = Gear.get(folder:GetAttribute("G"))
	local origin = plotOrigin(plotIndex)
	if not g or not origin then
		return
	end
	local cf = origin * CFrame.new(folder:GetAttribute("X"), 0, folder:GetAttribute("Z"))
	local m = Instance.new("Model")
	m.Name = "Sprinkler"
	local function p(props)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		for k, v in pairs(props) do
			part[k] = v
		end
		part.Parent = m
		return part
	end
	p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.6, 1.6), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal })
	p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.3, 0.3), CFrame = cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(140, 140, 150), Material = Enum.Material.Metal })
	local head = p({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, 2.0, 0), Color = g.color or Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	local ring = p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, g.radius * 2, g.radius * 2), CFrame = cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = g.color or Color3.fromRGB(150, 200, 255), Material = Enum.Material.Neon, Transparency = 0.82 })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = SPARKLE
	spray.Color = ColorSequence.new(g.id == "lucky_lantern" and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(170, 220, 255))
	spray.Size = NumberSequence.new(0.35, 0.1)
	spray.Speed = NumberRange.new(8, 12)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.SpreadAngle = Vector2.new(70, 70)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.Rate = 30
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = head
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 30)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 60
	bb.AlwaysOnTop = true
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	m.Parent = renderFolder
	sprinklers[folder] = { model = m, label = label, ends = folder:GetAttribute("E"), name = g.name, ring = ring }
end

local function removeSprinkler(folder: Folder)
	local s = sprinklers[folder]
	if s then
		s.model:Destroy()
		sprinklers[folder] = nil
	end
end

---------------------------------------------------------------------------
-- Watching replicated gardens
---------------------------------------------------------------------------
local function watchPlot(plotFolder: Folder)
	local index = plotFolder:GetAttribute("Index")
	for _, c in ipairs(plotFolder:GetChildren()) do
		if c.Name ~= "Sprinklers" then
			task.spawn(addPlant, c, index)
		end
	end
	plotFolder.ChildAdded:Connect(function(c)
		if c.Name ~= "Sprinklers" then
			addPlant(c, index)
		end
	end)
	plotFolder.ChildRemoved:Connect(function(c)
		removePlant(c)
	end)
	local spr = plotFolder:WaitForChild("Sprinklers")
	for _, c in ipairs(spr:GetChildren()) do
		addSprinkler(c, index)
	end
	spr.ChildAdded:Connect(function(c)
		addSprinkler(c, index)
	end)
	spr.ChildRemoved:Connect(removeSprinkler)
end

-- Public helpers for tools ------------------------------------------------
function GardenRenderer.nearestPlant(plotIndex: number, worldPos: Vector3, maxDist: number?)
	local best, bestD = nil, maxDist or 3
	for _, rec in pairs(byPlot[plotIndex] or {}) do
		local d = Vector2.new(rec.pos.X - worldPos.X, rec.pos.Z - worldPos.Z).Magnitude
		if d < bestD + rec.sp.radius * 0.5 then
			best, bestD = rec, d
		end
	end
	return best
end

function GardenRenderer.plantsOf(plotIndex: number)
	return byPlot[plotIndex] or {}
end

function GardenRenderer.ripeCount(plotIndex: number): number
	local n, t = 0, now()
	for _, rec in pairs(byPlot[plotIndex] or {}) do
		local alpha = (t - rec.T) / math.max(rec.G, 0.01)
		for _, f in pairs(rec.fruits) do
			if alpha >= 1 and t >= f.r then
				n += 1
			end
		end
	end
	return n
end

function GardenRenderer.start()
	local gardens = ReplicatedStorage:WaitForChild("Gardens")
	for _, pf in ipairs(gardens:GetChildren()) do
		task.spawn(watchPlot, pf)
	end
	gardens.ChildAdded:Connect(watchPlot)

	-- When our plot index arrives, re-flag ownership on already-built plants.
	player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
		local mine = myPlot()
		for _, rec in pairs(plants) do
			rec.mine = rec.plot == mine
		end
	end)

	-- Throttled update loop: a slice of plants per frame.
	local list, cursor, lastRebuild = {}, 1, 0
	RunService.Heartbeat:Connect(function()
		local t = now()
		if os.clock() - lastRebuild > 1 then
			lastRebuild = os.clock()
			list = {}
			for _, rec in pairs(plants) do
				table.insert(list, rec)
			end
		end
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local budget = math.max(25, math.ceil(#list / 8))
		for _ = 1, math.min(budget, #list) do
			if cursor > #list then
				cursor = 1
			end
			local rec = list[cursor]
			cursor += 1
			if rec and rec.model.Parent then
				updatePlant(rec, t, camPos)
			end
		end
		for folder, s in pairs(sprinklers) do
			local left = (s.ends or 0) - t
			if left <= 0 then
				removeSprinkler(folder)
			else
				s.label.Text = string.format("%s %s", s.name, Format.clock(left))
			end
		end
	end)

	-- Rainbow + shimmer gems cycle colors.
	RunService.RenderStepped:Connect(function()
		local h = (os.clock() * 0.25) % 1
		for _, p in ipairs(CollectionService:GetTagged(GemFactory.RainbowTag)) do
			if p:IsDescendantOf(renderFolder) then
				p.Color = Color3.fromHSV((h + (p.Position.X + p.Position.Z) * 0.01) % 1, 0.65, 1)
			end
		end
		for _, p in ipairs(CollectionService:GetTagged(GemFactory.ShimmerTag)) do
			if p:IsDescendantOf(renderFolder) then
				p.Color = Color3.fromHSV((h * 0.6 + p.Position.Y * 0.05) % 1, 0.18, 1)
			end
		end
	end)
end

return GardenRenderer
