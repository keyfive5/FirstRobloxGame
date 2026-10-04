-- Edit-time asset builder: carves faceted gem meshes with CSG and stores them in
-- ReplicatedStorage.Assets.Gems. Run with: node tools/run.mjs build/gems.luau
-- Each gem is a convex polyhedron: a tight bounding block with every facet
-- plane subtracted away, so the template's Size equals its real extents.

local RS = game:GetService("ReplicatedStorage")
local assets = RS:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = RS
local old = assets:FindFirstChild("Gems")
if old then old:Destroy() end
local gems = Instance.new("Folder")
gems.Name = "Gems"

local work = Instance.new("Folder")
work.Name = "_GemWork"
work.Parent = workspace

local S = 10
local function cutter(n: Vector3, d: number)
	n = n.Unit
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(S, S, S)
	local c = n * (d + S / 2)
	local up = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = n:Cross(up).Unit
	local up2 = right:Cross(n).Unit
	p.CFrame = CFrame.fromMatrix(c, right, up2, -n)
	p.Parent = work
	return p
end

local function convex(name: string, bounds: Vector3, planes)
	local base = Instance.new("Part")
	base.Anchored = true
	base.Size = bounds
	base.CFrame = CFrame.new()
	base.Parent = work
	local cutters = {}
	for _, pl in ipairs(planes) do
		table.insert(cutters, cutter(pl[1], pl[2]))
	end
	local u = base:SubtractAsync(cutters, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	base:Destroy()
	for _, p in ipairs(cutters) do
		p:Destroy()
	end
	u.Name = name
	u.UsePartColor = true
	u.Anchored = true
	u.CanCollide = false
	u.CanTouch = false
	u.CanQuery = false
	u.CastShadow = false
	u.Material = Enum.Material.Glass
	u.Reflectance = 0.12
	u.Color = Color3.new(1, 1, 1)
	u.Parent = work
	return u
end

local function ring(n: number, offsetDeg: number, tiltDeg: number, d: number, out)
	for k = 0, n - 1 do
		local a = math.rad(k * 360 / n + offsetDeg)
		local h = Vector3.new(math.cos(a), 0, math.sin(a))
		local t = math.rad(tiltDeg)
		table.insert(out, { h * math.cos(t) + Vector3.new(0, math.sin(t), 0), d })
	end
end

-- Round brilliant: table, crown, girdle, pavilion.
do
	local planes = { { Vector3.new(0, 1, 0), 0.32 } }
	ring(8, 0, 0, 1.0, planes)
	ring(8, 22.5, 38, 0.86, planes)
	ring(8, 0, -48, 0.70, planes)
	local g = convex("Brilliant", Vector3.new(2.1, 2.1, 2.1), planes)
	g.Parent = gems
end

-- Hexagonal crystal shard with a pointed tip.
local shard
do
	local planes = {}
	ring(6, 0, 0, 0.42, planes)
	ring(6, 0, 58, 1.05, planes)
	shard = convex("Shard", Vector3.new(1, 2.4, 1), planes)
end

-- Rhombic dodecahedron (garnet-style).
do
	local planes = {}
	for _, v in
		ipairs({
			Vector3.new(1, 1, 0), Vector3.new(1, -1, 0), Vector3.new(-1, 1, 0), Vector3.new(-1, -1, 0),
			Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1),
			Vector3.new(0, 1, 1), Vector3.new(0, 1, -1), Vector3.new(0, -1, 1), Vector3.new(0, -1, -1),
		})
	do
		table.insert(planes, { v, 0.8 })
	end
	local g = convex("Rhombic", Vector3.new(2.3, 2.3, 2.3), planes)
	g.Parent = gems
end

-- Stretched octahedron.
do
	local planes = {}
	for _, x in ipairs({ 1, -1 }) do
		for _, y in ipairs({ 1, -1 }) do
			for _, z in ipairs({ 1, -1 }) do
				table.insert(planes, { Vector3.new(x, y * 1.35, z), 0.95 })
			end
		end
	end
	local g = convex("Octa", Vector3.new(2.6, 2.6, 2.6), planes)
	g.Parent = gems
end

-- Emerald (step) cut, standing upright (long axis = Y) with the table facing -Z.
do
	local planes = {
		{ Vector3.new(1, 0, 0), 0.72 }, { Vector3.new(-1, 0, 0), 0.72 },
		{ Vector3.new(0, 1, 0), 1.0 }, { Vector3.new(0, -1, 0), 1.0 },
		{ Vector3.new(1, 1, 0), 1.12 }, { Vector3.new(-1, 1, 0), 1.12 },
		{ Vector3.new(1, -1, 0), 1.12 }, { Vector3.new(-1, -1, 0), 1.12 },
		{ Vector3.new(0, 0, -1), 0.34 },
		{ Vector3.new(1, 0, -1), 0.6 }, { Vector3.new(-1, 0, -1), 0.6 },
		{ Vector3.new(0, 1, -1), 0.77 }, { Vector3.new(0, -1, -1), 0.77 },
		{ Vector3.new(1, 0, 1.5), 0.74 }, { Vector3.new(-1, 0, 1.5), 0.74 },
		{ Vector3.new(0, 1, 1.5), 0.9 }, { Vector3.new(0, -1, 1.5), 0.9 },
		{ Vector3.new(0, 0, 1), 0.5 },
	}
	local g = convex("Emerald", Vector3.new(1.6, 2.1, 1.0), planes)
	g.Parent = gems
end

-- Heart: two rounded lobes + a point, carved from a flat slab.
do
	local planes = {
		{ Vector3.new(0, 0, 1), 0.38 }, { Vector3.new(0, 0, -1), 0.38 },
		{ Vector3.new(1, -1.1, 0), 0.62 }, { Vector3.new(-1, -1.1, 0), 0.62 },
		{ Vector3.new(1, 0.25, 0), 1.0 }, { Vector3.new(-1, 0.25, 0), 1.0 },
		{ Vector3.new(0.35, 1, 0), 0.82 }, { Vector3.new(-0.35, 1, 0), 0.82 },
		{ Vector3.new(1, 1, 0), 1.08 }, { Vector3.new(-1, 1, 0), 1.08 },
		{ Vector3.new(0.6, 0.4, 1), 0.62 }, { Vector3.new(-0.6, 0.4, 1), 0.62 },
		{ Vector3.new(0.6, 0.4, -1), 0.62 }, { Vector3.new(-0.6, 0.4, -1), 0.62 },
	}
	local heart = convex("HeartBase", Vector3.new(2.2, 2.0, 0.8), planes)
	-- notch between the lobes
	local notch = Instance.new("Part")
	notch.Anchored = true
	notch.Size = Vector3.new(0.6, 0.6, 2)
	notch.CFrame = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(45))
	notch.Parent = work
	local g = heart:SubtractAsync({ notch }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	heart:Destroy()
	notch:Destroy()
	g.Name = "Heart"
	g.UsePartColor = true
	g.Anchored = true
	g.CanCollide = false
	g.CanTouch = false
	g.CanQuery = false
	g.CastShadow = false
	g.Material = Enum.Material.Glass
	g.Reflectance = 0.12
	g.Parent = gems
end

-- Cluster: one tall shard flanked by two smaller tilted ones.
do
	local a = shard:Clone()
	a.CFrame = CFrame.new(0, 0.2, 0)
	a.Parent = work
	local b = shard:Clone()
	b.Size = shard.Size * 0.7
	b.CFrame = CFrame.new(0.42, -0.25, 0.1) * CFrame.Angles(0, 0, math.rad(-28))
	b.Parent = work
	local c = shard:Clone()
	c.Size = shard.Size * 0.6
	c.CFrame = CFrame.new(-0.38, -0.32, -0.15) * CFrame.Angles(math.rad(-12), 0, math.rad(30))
	c.Parent = work
	local g = a:UnionAsync({ b, c }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	a:Destroy()
	b:Destroy()
	c:Destroy()
	g.Name = "Cluster"
	g.UsePartColor = true
	g.Anchored = true
	g.CanCollide = false
	g.CanTouch = false
	g.CanQuery = false
	g.CastShadow = false
	g.Material = Enum.Material.Glass
	g.Reflectance = 0.12
	g.Parent = gems
end

shard.Parent = gems
gems.Parent = assets
work:Destroy()

local out = {}
for _, g in ipairs(gems:GetChildren()) do
	table.insert(out, g.Name .. " " .. tostring(g.Size))
end
table.sort(out)
return table.concat(out, "\n")
