-- What happens when you click with a tool equipped: plant seeds (with a live
-- ghost preview), water plants, place sprinklers, dig plants up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local PlantBuilder = require(Shared.Visuals.PlantBuilder)

local GardenRenderer = require(script.Parent.GardenRenderer)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.UI.Theme)
local Root = require(script.Parent.UI.Root)
local Notify = require(script.Parent.UI.Notify)

local ToolController = {}

local player = Players.LocalPlayer
local equipped: Tool? = nil
local ghost: Model? = nil
local ring: BasePart? = nil
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.6
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
highlight.Enabled = false
highlight.Parent = workspace
local lastTouch: Vector2? = nil
local busy = false

local plantedEvent = Instance.new("BindableEvent")
ToolController.Planted = plantedEvent.Event

local function myPlotModel()
	local idx = player:GetAttribute("PlotIndex")
	return idx and workspace.Plots:FindFirstChild("Plot_" .. idx), idx
end

local function pointerRay()
	local cam = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	if UserInputService.TouchEnabled and lastTouch then
		pos = lastTouch
	end
	return cam:ViewportPointToRay(pos.X, pos.Y)
end

-- Raycast against our own soil beds (and optionally the garden base).
local function hitGarden(includeBase: boolean?)
	local plot = myPlotModel()
	if not plot then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = { plot.Beds }
	if includeBase then
		table.insert(list, plot.Base)
	end
	params.FilterDescendantsInstances = list
	local ray = pointerRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return nil
	end
	local origin = plot.Origin.CFrame
	local lp = origin:PointToObjectSpace(hit.Position)
	return hit, lp, origin
end

local function onBed(x: number, z: number, margin: number): boolean
	local inner = Config.BedPath / 2
	local outer = inner + Config.BedSize.X
	local ax = math.abs(x)
	return ax >= inner + margin and ax <= outer - margin and math.abs(z) <= Config.BedSize.Y / 2 - margin
end

local function canPlantAt(sp, x: number, z: number): boolean
	if not onBed(x, z, math.min(sp.radius * 0.5, 1.2)) then
		return false
	end
	local _, idx = myPlotModel()
	local origin = myPlotModel().Origin.CFrame
	for _, rec in pairs(GardenRenderer.plantsOf(idx)) do
		local lp = origin:PointToObjectSpace(rec.pos)
		if Vector2.new(lp.X - x, lp.Z - z).Magnitude < (rec.sp.radius + sp.radius) * 0.75 then
			return false
		end
	end
	return true
end

local function clearPreview()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if ring then
		ring:Destroy()
		ring = nil
	end
	highlight.Enabled = false
	highlight.Adornee = nil
end

local function makeRing(radius: number, color: Color3)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Size = Vector3.new(0.06, radius * 2, radius * 2)
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.55
	r.Parent = workspace
	return r
end

local function setupPreview(tool: Tool)
	clearPreview()
	local kind, item = tool:GetAttribute("Kind"), tool:GetAttribute("Item")
	if kind == "Seed" then
		local sp = Species.get(item)
		if not sp then
			return
		end
		local m = PlantBuilder.build(sp, 7)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = math.max(d.Transparency, 0.55)
				d.CastShadow = false
			end
		end
		m:ScaleTo(0.6 * (sp.size or 1))
		m.Parent = workspace
		ghost = m
		ring = makeRing(sp.radius * 0.75, Color3.fromRGB(120, 255, 140))
	elseif kind == "Gear" then
		local g = Gear.get(item)
		if g and g.kind == "sprinkler" then
			ring = makeRing(g.radius, g.color or Color3.fromRGB(150, 200, 255))
		end
	end
end

local function confirm(text: string, onYes)
	local holder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 170), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 40, Parent = Root.gui })
	Root.scaled(holder)
	local card = Theme.card({ Size = UDim2.fromScale(1, 1), Color = Color3.new(1, 1, 1), Gradient = { Theme.C.panelTop, Theme.C.panelBottom, 90 }, StrokeThickness = 4, Radius = 18, ZIndex = 40, Parent = holder })
	Theme.text({ Text = text, Size = UDim2.new(1, -30, 0, 70), Position = UDim2.fromOffset(15, 14), maxSize = 24, ZIndex = 41, Parent = card })
	local function done()
		holder:Destroy()
	end
	Theme.button({ Text = "Yes", Color = Theme.C.red, Size = UDim2.fromOffset(150, 48), Position = UDim2.new(0.5, -10, 1, -16), AnchorPoint = Vector2.new(1, 1), ZIndex = 41, Parent = card, onClick = function()
		done()
		onYes()
	end })
	Theme.button({ Text = "No", Color = Theme.C.grey, Size = UDim2.fromOffset(150, 48), Position = UDim2.new(0.5, 10, 1, -16), AnchorPoint = Vector2.new(0, 1), ZIndex = 41, Parent = card, onClick = done })
end

local function onActivated(tool: Tool)
	if busy then
		return
	end
	local kind, item = tool:GetAttribute("Kind"), tool:GetAttribute("Item")
	if kind == "Seed" then
		local sp = Species.get(item)
		local hit, lp = hitGarden(false)
		if not hit then
			Notify.toast("Click on the soil in YOUR garden to plant!", "info")
			return
		end
		if not canPlantAt(sp, lp.X, lp.Z) then
			Sounds.play("error")
			return
		end
		busy = true
		local ok, msg = Net.func("Plant"):InvokeServer(item, lp.X, lp.Z)
		busy = false
		if ok then
			Sounds.play("pop", 0.8)
			plantedEvent:Fire(item)
		elseif msg then
			Notify.toast(msg, "bad")
		end
	elseif kind == "Gear" then
		local g = Gear.get(item)
		local _, idx = myPlotModel()
		if g.kind == "sprinkler" then
			local hit, lp = hitGarden(true)
			if not hit then
				Notify.toast("Place it inside your garden!", "info")
				return
			end
			busy = true
			local ok, msg = Net.func("PlaceSprinkler"):InvokeServer(item, lp.X, lp.Z)
			busy = false
			if ok then
				Sounds.play("splash")
			elseif msg then
				Notify.toast(msg, "bad")
			end
			return
		end
		local hit = hitGarden(false)
		local rec = hit and GardenRenderer.nearestPlant(idx, hit.Position, 3)
		if not rec then
			Notify.toast("Click on one of your plants.", "info")
			return
		end
		if g.kind == "water" then
			busy = true
			local ok, msg = Net.func("Water"):InvokeServer(rec.id)
			busy = false
			if ok then
				Sounds.play("splash")
				Notify.float("💧 Watered!", Color3.fromRGB(140, 210, 255))
			elseif msg then
				Notify.toast(msg, "bad")
			end
		elseif g.kind == "shovel" then
			confirm(string.format("Dig up this %s?\nIt will be gone forever.", rec.sp.name), function()
				local ok = Net.func("Dig"):InvokeServer(rec.id)
				if ok then
					Sounds.play("dig")
				end
			end)
		end
	end
end

local function hookTool(tool: Tool)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Equipped:Connect(function()
		equipped = tool
		setupPreview(tool)
	end)
	tool.Unequipped:Connect(function()
		if equipped == tool then
			equipped = nil
			clearPreview()
		end
	end)
	tool.Activated:Connect(function()
		onActivated(tool)
	end)
end

local function watchContainer(c: Instance)
	for _, t in ipairs(c:GetChildren()) do
		hookTool(t)
	end
	c.ChildAdded:Connect(hookTool)
end

function ToolController.start()
	local function onChar(char)
		watchContainer(char)
	end
	if player.Character then
		onChar(player.Character)
	end
	player.CharacterAdded:Connect(onChar)
	watchContainer(player:WaitForChild("Backpack"))
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			watchContainer(c)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch and not processed then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.TouchMoved:Connect(function(input, processed)
		if not processed then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local tool = equipped
		if not tool or not tool.Parent then
			if ghost or ring then
				clearPreview()
			end
			return
		end
		local kind, item = tool:GetAttribute("Kind"), tool:GetAttribute("Item")
		if kind == "Seed" and ghost then
			local sp = Species.get(item)
			local hit, lp, origin = hitGarden(false)
			if hit then
				local cf = origin * CFrame.new(lp.X, 0, lp.Z)
				ghost:PivotTo(cf)
				ring.CFrame = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2)
				local ok = canPlantAt(sp, lp.X, lp.Z)
				ring.Color = ok and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 90, 90)
				ghost.Parent = workspace
				ring.Transparency = 0.55
			else
				ghost.Parent = nil
				ring.Transparency = 1
			end
		elseif kind == "Gear" then
			local g = Gear.get(item)
			if g and g.kind == "sprinkler" and ring then
				local hit, lp, origin = hitGarden(true)
				if hit then
					ring.CFrame = origin * CFrame.new(lp.X, 0.06, lp.Z) * CFrame.Angles(0, 0, math.pi / 2)
					ring.Transparency = 0.6
				else
					ring.Transparency = 1
				end
			elseif g and (g.kind == "water" or g.kind == "shovel") then
				local hit = hitGarden(false)
				local _, idx = myPlotModel()
				local rec = hit and GardenRenderer.nearestPlant(idx, hit.Position, 3)
				if rec then
					highlight.Adornee = rec.model
					highlight.FillColor = g.kind == "water" and Color3.fromRGB(90, 170, 255) or Color3.fromRGB(255, 90, 90)
					highlight.Enabled = true
				else
					highlight.Enabled = false
				end
			end
		end
	end)
end

return ToolController
