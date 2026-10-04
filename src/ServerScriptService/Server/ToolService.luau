-- Keeps each player's Backpack in sync with their seeds and gear: one Tool per
-- item type, with the count in its name ("Ruby Rose Seed x3").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local GemFactory = require(Shared.Visuals.GemFactory)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)

local ToolService = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function decorate(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

local function seedHandle(sp): BasePart
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(1.1, 1.4, 0.2)
	h.Color = Color3.fromRGB(236, 220, 180)
	h.Material = Enum.Material.Fabric
	decorate(h)
	local band = Instance.new("Part")
	band.Size = Vector3.new(1.12, 0.45, 0.22)
	band.Color = sp.gemColor
	band.Material = Enum.Material.SmoothPlastic
	decorate(band)
	band.CFrame = h.CFrame * CFrame.new(0, 0.3, 0)
	band.Parent = h
	weld(h, band)
	local gem = GemFactory.make(sp.gem, sp.gemColor, 0.32, { neon = sp.neon })
	decorate(gem)
	gem.CFrame = h.CFrame * CFrame.new(0, -0.22, -0.18)
	gem.Parent = h
	weld(h, gem)
	return h
end

local function gearHandle(g): BasePart
	local h = Instance.new("Part")
	h.Name = "Handle"
	decorate(h)
	if g.kind == "water" then
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(1.3, 1.2, 1.2)
		h.Color = Color3.fromRGB(90, 170, 230)
		h.Material = Enum.Material.Metal
		local spout = Instance.new("Part")
		spout.Size = Vector3.new(0.25, 0.25, 1.4)
		spout.Color = Color3.fromRGB(70, 140, 200)
		spout.Material = Enum.Material.Metal
		decorate(spout)
		spout.CFrame = h.CFrame * CFrame.new(0, 0.2, -0.9) * CFrame.Angles(math.rad(25), 0, 0)
		spout.Parent = h
		weld(h, spout)
	elseif g.kind == "shovel" then
		h.Size = Vector3.new(0.25, 2.6, 0.25)
		h.Color = Color3.fromRGB(140, 96, 60)
		h.Material = Enum.Material.Wood
		local blade = Instance.new("Part")
		blade.Size = Vector3.new(0.9, 1.0, 0.12)
		blade.Color = Color3.fromRGB(170, 170, 180)
		blade.Material = Enum.Material.Metal
		decorate(blade)
		blade.CFrame = h.CFrame * CFrame.new(0, -1.6, 0)
		blade.Parent = h
		weld(h, blade)
	else
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(0.6, 1.2, 1.2)
		h.Color = g.color or Color3.fromRGB(150, 200, 255)
		h.Material = Enum.Material.Metal
		local top = Instance.new("Part")
		top.Shape = Enum.PartType.Ball
		top.Size = Vector3.new(0.7, 0.7, 0.7)
		top.Color = g.color or Color3.new(1, 1, 1)
		top.Material = Enum.Material.Neon
		decorate(top)
		top.CFrame = h.CFrame * CFrame.new(0.5, 0, 0)
		top.Parent = h
		weld(h, top)
	end
	return h
end

local function makeTool(kind: string, id: string): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Kind", kind)
	tool:SetAttribute("Item", id)
	if kind == "Seed" then
		local sp = Species.get(id)
		seedHandle(sp).Parent = tool
		tool.ToolTip = sp.name .. " (" .. sp.rarity .. ")"
		tool.Grip = CFrame.new(0, -0.2, 0)
	else
		local g = Gear.get(id)
		gearHandle(g).Parent = tool
		tool.ToolTip = g.desc
		if g.kind == "shovel" then
			tool.Grip = CFrame.new(0, 0.6, 0)
		end
	end
	return tool
end

local function toolName(kind: string, id: string, count: number): string
	if kind == "Seed" then
		return string.format("%s Seed x%d", Species.get(id).name, count)
	end
	local g = Gear.get(id)
	if g.kind == "shovel" then
		return g.name
	end
	return string.format("%s x%d", g.name, count)
end

function ToolService.sync(player: Player)
	local profile = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local want = {}
	local order = {}
	for _, sp in ipairs(Species.List) do
		local n = profile.data.seeds[sp.id]
		if n and n > 0 then
			want["Seed:" .. sp.id] = n
			table.insert(order, { "Seed", sp.id })
		end
	end
	for _, g in ipairs(Gear.List) do
		local n = profile.data.gear[g.id]
		if n and n > 0 then
			want["Gear:" .. g.id] = n
			table.insert(order, { "Gear", g.id })
		end
	end
	local have = {}
	local containers = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, c in ipairs(containers) do
		for _, tool in ipairs(c:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("Kind") then
				local key = tool:GetAttribute("Kind") .. ":" .. tool:GetAttribute("Item")
				if not want[key] or have[key] then
					tool:Destroy()
				else
					have[key] = tool
					tool.Name = toolName(tool:GetAttribute("Kind"), tool:GetAttribute("Item"), want[key])
				end
			end
		end
	end
	for _, o in ipairs(order) do
		local key = o[1] .. ":" .. o[2]
		if not have[key] then
			local tool = makeTool(o[1], o[2])
			tool.Name = toolName(o[1], o[2], want[key])
			tool.Parent = backpack
		end
	end
end

function ToolService.start()
	Economy.InventoryChanged:Connect(function(player)
		ToolService.sync(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			ToolService.sync(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	DataService.Loaded:Connect(function(player)
		ToolService.sync(player)
	end)
end

return ToolService
