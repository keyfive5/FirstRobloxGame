-- Edit-time builder for reusable organic shapes (stored in ReplicatedStorage.Assets.Shapes).
-- Run with: node tools/run.mjs build/shapes.luau
local RS = game:GetService("ReplicatedStorage")
local assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = RS
local old = assets:FindFirstChild("Shapes")
if old then
	old:Destroy()
end
local shapes = Instance.new("Folder")
shapes.Name = "Shapes"

local work = Instance.new("Folder")
work.Name = "_ShapeWork"
work.Parent = workspace

local function finish(u: BasePart, name: string)
	u.Name = name
	u.UsePartColor = true
	u.Anchored = true
	u.CanCollide = false
	u.CanTouch = false
	u.CanQuery = false
	u.Material = Enum.Material.SmoothPlastic
	u.Parent = shapes
end

-- Dome: top half of a sphere, 2 x 1 x 2, origin at the flat base center... the
-- union's pivot ends up at its bounding-box center (y = 0.5 above the base).
do
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.Size = Vector3.new(2, 2, 2)
	ball.CFrame = CFrame.new()
	ball.Parent = work
	local cut = Instance.new("Part")
	cut.Anchored = true
	cut.Size = Vector3.new(4, 2, 4)
	cut.CFrame = CFrame.new(0, -1, 0)
	cut.Parent = work
	local u = ball:SubtractAsync({ cut }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	ball:Destroy()
	cut:Destroy()
	finish(u, "Dome")
end

-- Ring: flat annulus, 2 x 0.12 x 2 (used for sprinkler / planting radius markers).
do
	local outer = Instance.new("Part")
	outer.Shape = Enum.PartType.Cylinder
	outer.Anchored = true
	outer.Size = Vector3.new(0.12, 2, 2)
	outer.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	outer.Parent = work
	local inner = Instance.new("Part")
	inner.Shape = Enum.PartType.Cylinder
	inner.Anchored = true
	inner.Size = Vector3.new(0.5, 1.88, 1.88)
	inner.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	inner.Parent = work
	local u = outer:SubtractAsync({ inner }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	outer:Destroy()
	inner:Destroy()
	finish(u, "Ring")
	u.Material = Enum.Material.Neon
end

shapes.Parent = assets
work:Destroy()
local out = {}
for _, s in ipairs(shapes:GetChildren()) do
	table.insert(out, s.Name .. " " .. tostring(s.Size))
end
return table.concat(out, "\n")
