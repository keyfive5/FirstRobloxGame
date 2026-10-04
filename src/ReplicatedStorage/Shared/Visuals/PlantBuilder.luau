-- Builds a plant model out of primitive parts from a species "style" recipe.
-- PlantBuilder.build(species, seed) -> model, slots
--   model : Model whose PrimaryPart "Root" sits at the soil surface (origin)
--   slots : list of { cf = CFrame, mode = "up" | "hang" | "out" | "center" }
--           where gems attach, in the model's local space at full size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlantBuilder = {}

local Shapes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Shapes")

local V = Vector3.new
local CF = CFrame.new
local UP = V(0, 1, 0)
local SOIL = Color3.fromRGB(86, 60, 42)

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
end

local function vary(c: Color3, rng: Random, amt: number?): Color3
	local h, s, v = c:ToHSV()
	amt = amt or 0.06
	return Color3.fromHSV((h + (rng:NextNumber() - 0.5) * amt * 0.3) % 1, math.clamp(s + (rng:NextNumber() - 0.5) * amt, 0, 1), math.clamp(v + (rng:NextNumber() - 0.5) * amt * 1.5, 0, 1))
end

local function shade(c: Color3, k: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * k, 0, 1))
end

local Builder = {}
Builder.__index = Builder

function Builder.new(rng: Random)
	local m = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = CF()
	quiet(root)
	root.Parent = m
	m.PrimaryPart = root
	return setmetatable({ model = m, rng = rng, slots = {} }, Builder)
end

function Builder:part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = self.model
	return p
end

function Builder:ellipsoid(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = self:part(size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function Builder:ball(center: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	return self:part(V(d, d, d), CF(center), color, material, Enum.PartType.Ball)
end

-- Cylinder spanning two points.
function Builder:cyl(a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material?): Part
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf
	if len < 1e-3 then
		cf = CF(mid)
	elseif math.abs((b - a).Unit.Y) > 0.999 then
		cf = CF(mid) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return self:part(V(len, d, d), cf, color, material, Enum.PartType.Cylinder)
end

-- Flat disk lying on the ground plane.
function Builder:disk(center: Vector3, d: number, h: number, color: Color3, material: Enum.Material?): Part
	return self:part(V(h, d, d), CF(center) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

-- Flattened ellipsoid that starts at `base` and points along `dir`.
-- `faceUp` controls which way the flat side faces (defaults to world up).
function Builder:leaf(base: Vector3, dir: Vector3, len: number, width: number, color: Color3, thick: number?, faceUp: Vector3?): Part
	dir = dir.Unit
	local up = faceUp or UP
	if math.abs(dir:Dot(up.Unit)) > 0.98 then
		up = V(1, 0, 0)
	end
	local cf = CFrame.lookAt(base + dir * len / 2, base + dir * len, up)
	return self:ellipsoid(V(width, thick or 0.12, len), cf, color)
end

function Builder:dome(baseCenter: Vector3, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local d = Shapes.Dome:Clone()
	d.Size = size
	d.CFrame = CF(baseCenter + V(0, size.Y / 2, 0))
	d.Color = color
	d.Material = material or Enum.Material.SmoothPlastic
	quiet(d)
	d.Parent = self.model
	return d
end

function Builder:mound(r: number)
	self:ellipsoid(V(r * 2, 0.4, r * 2), CF(0, 0.02, 0), SOIL, Enum.Material.Ground)
end

function Builder:slot(cf: CFrame, mode: string)
	table.insert(self.slots, { cf = cf, mode = mode })
end

-- Orientation whose UpVector is `up`.
local function upFrame(pos: Vector3, up: Vector3): CFrame
	up = up.Unit
	local ref = math.abs(up.Y) > 0.95 and V(0, 0, 1) or UP
	local right = ref:Cross(up).Unit
	local back = right:Cross(up).Unit
	return CFrame.fromMatrix(pos, right, up, back)
end

local function ringDir(i: number, n: number, offset: number?): Vector3
	local a = (i - 1) / n * math.pi * 2 + (offset or 0)
	return V(math.cos(a), 0, math.sin(a))
end

---------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------
local Styles = {}

function Styles.sprout(b, sp)
	b:mound(0.9)
	b:cyl(V(0, 0, 0), V(0, 1.15, 0), 0.22, sp.stem)
	b:leaf(V(0, 0.45, 0), V(1, 0.55, 0.1), 1.05, 0.5, sp.leaf)
	b:leaf(V(0, 0.6, 0), V(-1, 0.7, -0.2), 0.95, 0.46, shade(sp.leaf, 0.9))
	b:slot(CF(0, 1.1, 0), "up")
end

function Styles.bush(b, sp)
	local rng = b.rng
	b:mound(1.25)
	b:cyl(V(0, 0, 0), V(0, 0.9, 0), 0.35, sp.stem)
	b:ellipsoid(V(2.7, 2.0, 2.7), CF(0, 1.55, 0), vary(sp.leaf, rng))
	b:ellipsoid(V(1.9, 1.6, 1.9), CF(0.75, 1.95, 0.35), vary(shade(sp.leaf, 1.1), rng))
	b:ellipsoid(V(1.8, 1.5, 1.8), CF(-0.65, 1.85, -0.45), vary(shade(sp.leaf, 0.9), rng))
	b:ellipsoid(V(1.5, 1.3, 1.5), CF(0.1, 2.45, -0.15), vary(sp.leaf, rng))
	local n = sp.slots
	local off = rng:NextNumber() * math.pi
	for i = 1, n do
		local d = ringDir(i, n, off)
		local y = (i % 2 == 0) and 1.25 or 1.9
		local r = 1.38 * math.sqrt(math.max(0, 1 - ((y - 1.55) / 1.05) ^ 2)) + 0.05
		local pos = V(d.X * r, y, d.Z * r)
		local normal = (V(d.X, (y - 1.55) * 0.8, d.Z)).Unit
		b:slot(CFrame.lookAt(pos, pos + normal), "out")
	end
end

function Styles.tulip(b, sp)
	b:mound(0.8)
	b:cyl(V(0, 0, 0), V(0, 2.3, 0), 0.2, sp.stem)
	b:leaf(V(0, 0.1, 0), V(0.35, 1, 0.1), 1.8, 0.45, sp.leaf)
	b:leaf(V(0, 0.1, 0), V(-0.4, 1, -0.15), 1.6, 0.42, shade(sp.leaf, 0.9))
	for i = 1, 5 do
		local d = ringDir(i, 5)
		local base = V(0, 2.2, 0) + d * 0.15
		b:leaf(base, d * 0.5 + UP, 1.15, 0.62, vary(sp.accent, b.rng, 0.04), 0.16)
	end
	b:slot(CF(0, 2.35, 0), "up")
end

function Styles.sunflower(b, sp)
	b:mound(0.9)
	local top = V(0, 3.0, 0)
	b:cyl(V(0, 0, 0), top, 0.28, sp.stem)
	b:leaf(V(0, 0.9, 0), V(1, 0.4, 0), 1.3, 0.55, sp.leaf)
	b:leaf(V(0, 1.5, 0), V(-1, 0.45, 0.2), 1.2, 0.5, shade(sp.leaf, 0.9))
	b:leaf(V(0, 2.1, 0), V(0.2, 0.5, 1), 1.0, 0.45, sp.leaf)
	local head = CF(top) * CFrame.Angles(math.rad(35), 0, 0)
	local look = head.LookVector
	b:part(V(0.3, 1.75, 1.75), head * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(110, 70, 34), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for i = 1, 12 do
		local a = (i - 1) / 12 * math.pi * 2
		local d = head.RightVector * math.cos(a) + head.UpVector * math.sin(a)
		b:leaf(top + d * 0.7 + look * 0.02, d, 0.95, 0.4, vary(sp.accent, b.rng, 0.05), 0.1, look)
	end
	local pos = top + look * 0.12
	b:slot(CFrame.fromMatrix(pos, head.RightVector, look), "up")
end

function Styles.rose(b, sp)
	local rng = b.rng
	b:mound(1.1)
	b:ellipsoid(V(2.2, 1.1, 2.2), CF(0, 0.6, 0), shade(sp.leaf, 0.9))
	b:ellipsoid(V(1.6, 1.0, 1.6), CF(0.3, 0.9, -0.2), sp.leaf)
	local n = sp.slots
	local off = rng:NextNumber() * math.pi
	for i = 1, n do
		local d = ringDir(i, n, off)
		local tip = V(d.X * 0.9, 2.0 + (i % 2) * 0.4, d.Z * 0.9)
		local base = V(d.X * 0.3, 0.8, d.Z * 0.3)
		b:cyl(base, tip, 0.13, sp.stem)
		b:leaf((base + tip) / 2, d + V(0, 0.3, 0), 0.55, 0.3, sp.leaf)
		b:ellipsoid(V(0.5, 0.28, 0.5), CF(tip), shade(sp.leaf, 0.8))
		b:slot(CF(tip + V(0, 0.08, 0)), "up")
	end
end

local function pond(b, d: number, water: Color3, rimColor: Color3, rimMaterial: Enum.Material?)
	b:disk(V(0, 0.06, 0), d + 0.35, 0.12, rimColor, rimMaterial or Enum.Material.Slate)
	local w = b:disk(V(0, 0.1, 0), d, 0.14, water, Enum.Material.Glass)
	w.Transparency = 0.15
	w.Reflectance = 0.25
end

function Styles.lotus(b, sp)
	pond(b, 3.8, Color3.fromRGB(70, 150, 210), Color3.fromRGB(120, 112, 104))
	local pads = {}
	for i = 1, 4 do
		local d = ringDir(i, 4, math.pi / 4)
		local c = d * 1.25 + V(0, 0.19, 0)
		b:disk(c, 1.15, 0.06, vary(sp.leaf, b.rng))
		table.insert(pads, c)
	end
	for i = 1, 8 do
		local d = ringDir(i, 8)
		b:leaf(V(0, 0.2, 0) + d * 0.25, d * 0.8 + V(0, 0.6, 0), 0.95, 0.45, vary(sp.accent, b.rng, 0.04), 0.14)
	end
	for i = 1, 6 do
		local d = ringDir(i, 6, 0.4)
		b:leaf(V(0, 0.25, 0) + d * 0.1, d * 0.35 + UP, 0.8, 0.38, Color3.new(1, 1, 1), 0.12)
	end
	b:slot(CF(0, 0.6, 0), "up")
	for i = 1, math.min(#pads, sp.slots - 1) do
		b:slot(CF(pads[i] + V(0, 0.03, 0)), "up")
	end
end

function Styles.cactus(b, sp)
	b:mound(0.9)
	local g = sp.stem
	b:part(V(3.0, 1.1, 1.1), CF(0, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), g, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	b:ball(V(0, 3.0, 0), 1.1, g)
	b:cyl(V(0.45, 1.3, 0), V(1.05, 1.3, 0), 0.55, g)
	b:cyl(V(1.05, 1.3, 0), V(1.05, 2.2, 0), 0.55, g)
	b:ball(V(1.05, 2.2, 0), 0.55, g)
	b:cyl(V(-0.45, 1.9, 0), V(-0.95, 1.9, 0), 0.5, shade(g, 0.95))
	b:cyl(V(-0.95, 1.9, 0), V(-0.95, 2.6, 0), 0.5, shade(g, 0.95))
	b:ball(V(-0.95, 2.6, 0), 0.5, shade(g, 0.95))
	b:ball(V(1.05, 2.5, 0), 0.32, sp.accent)
	b:ball(V(-0.95, 2.86, 0), 0.3, sp.accent)
	for i = 1, 8 do
		local a = i * 0.9
		local y = 0.6 + (i % 4) * 0.6
		local d = V(math.cos(a), 0, math.sin(a))
		b:part(V(0.05, 0.05, 0.3), CFrame.lookAt(V(0, y, 0) + d * 0.6, V(0, y, 0) + d * 2), Color3.fromRGB(245, 240, 220))
	end
	b:slot(CF(0, 3.45, 0), "up")
end

function Styles.vine(b, sp)
	b:mound(1.2)
	local wood = sp.stem
	b:part(V(0.22, 3.8, 0.22), CF(-1.25, 1.9, 0), wood, Enum.Material.Wood)
	b:part(V(0.22, 3.8, 0.22), CF(1.25, 1.9, 0), wood, Enum.Material.Wood)
	for _, y in ipairs({ 1.3, 2.4, 3.5 }) do
		b:part(V(2.7, 0.16, 0.16), CF(0, y, 0), shade(wood, 1.1), Enum.Material.Wood)
	end
	local pts = { V(-1.1, 0.2, 0.08), V(-0.4, 0.9, 0.12), V(0.6, 1.4, 0.12), V(1.1, 2.1, 0.12), V(0.2, 2.6, 0.12), V(-0.9, 3.1, 0.12), V(-0.2, 3.75, 0.12), V(0.8, 3.9, 0.1) }
	for i = 1, #pts - 1 do
		b:cyl(pts[i], pts[i + 1], 0.12, sp.leaf)
		local d = (pts[i + 1] - pts[i]).Unit
		b:leaf(pts[i], V(-d.Y, 0.4, 1), 0.55, 0.38, vary(sp.leaf, b.rng), 0.1)
		b:leaf(pts[i], V(d.Y, 0.3, -1), 0.5, 0.34, vary(sp.leaf, b.rng), 0.1)
	end
	local n = 0
	for _, y in ipairs({ 3.5, 2.4 }) do
		for _, x in ipairs({ -0.75, 0, 0.75 }) do
			n += 1
			if n <= sp.slots then
				b:cyl(V(x, y, 0), V(x, y - 0.3, 0), 0.06, sp.leaf)
				b:slot(CF(x, y - 0.25, 0), "hang")
			end
		end
	end
end

function Styles.bamboo(b, sp)
	b:mound(1.0)
	local stalks = { { V(0, 0, 0), 4.4 }, { V(0.6, 0, 0.3), 3.6 }, { V(-0.55, 0, 0.38), 3.9 } }
	local nodes = {}
	for si, s in ipairs(stalks) do
		local base, h = s[1], s[2]
		b:cyl(base, base + V(0, h, 0), 0.38, vary(sp.stem, b.rng, 0.04))
		local y = 0.9
		while y < h - 0.2 do
			b:part(V(0.1, 0.46, 0.46), CF(base + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), shade(sp.stem, 0.78), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			table.insert(nodes, { pos = base + V(0, y, 0), out = (base.Magnitude > 0.01) and V(base.X, 0, base.Z).Unit or V(0, 0, -1), si = si })
			y += 0.9
		end
		for k = 1, 3 do
			local a = k * 2.1 + si
			b:leaf(base + V(0, h - 0.1, 0), V(math.cos(a), 0.3, math.sin(a)), 1.4, 0.32, vary(sp.leaf, b.rng), 0.08)
		end
	end
	local picks = { 2, 5, 7, 9, 3, 6, 8, 4, 1 }
	local used = 0
	for _, idx in ipairs(picks) do
		local nd = nodes[idx]
		if nd and used < sp.slots then
			used += 1
			local pos = nd.pos + nd.out * 0.32
			b:slot(CFrame.lookAt(pos, pos + nd.out), "center")
		end
	end
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	return p0:Lerp(p1, t):Lerp(p1:Lerp(p2, t), t)
end

function Styles.orchid(b, sp)
	b:mound(1.0)
	for i = 1, 3 do
		local d = ringDir(i, 3, 0.5)
		b:leaf(V(0, 0.1, 0), d + V(0, 0.22, 0), 1.5, 0.7, vary(sp.leaf, b.rng), 0.1)
	end
	local arcs = { { dir = V(1, 0, 0.2).Unit, ts = { 0.55, 0.8, 1.0 } }, { dir = V(-0.8, 0, -0.5).Unit, ts = { 0.7, 1.0 } } }
	local count = 0
	for _, arc in ipairs(arcs) do
		local p0, p1, p2 = V(0, 0.2, 0), arc.dir * 0.3 + V(0, 2.4, 0), arc.dir * 1.5 + V(0, 2.5, 0)
		local prev = p0
		for k = 1, 7 do
			local p = bezier(p0, p1, p2, k / 7)
			b:cyl(prev, p, 0.1, sp.stem)
			prev = p
		end
		for _, t in ipairs(arc.ts) do
			count += 1
			if count <= sp.slots then
				local p = bezier(p0, p1, p2, t) + V(0, -0.25, 0)
				local face = (arc.dir + V(0, -0.2, 0)).Unit
				local frame = CFrame.lookAt(p, p + face)
				for k = 1, 5 do
					local a = k / 5 * math.pi * 2
					local d = frame.RightVector * math.cos(a) + frame.UpVector * math.sin(a)
					b:leaf(p, d, 0.5, 0.34, vary(sp.accent, b.rng, 0.05), 0.08, face)
				end
				b:slot(frame, "out")
			end
		end
	end
end

function Styles.mushroom(b, sp)
	b:mound(1.3)
	b:ellipsoid(V(1.5, 0.5, 1.5), CF(0, 0.2, 0), sp.stem)
	b:part(V(2.0, 1.0, 1.0), CF(0, 1.0, 0) * CFrame.Angles(0, 0, math.pi / 2), sp.stem, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local capBase, capR, capH = 1.95, 1.9, 1.7
	b:disk(V(0, capBase + 0.04, 0), capR * 2 - 0.1, 0.12, shade(sp.stem, 0.8))
	b:dome(V(0, capBase, 0), V(capR * 2, capH, capR * 2), sp.leaf)
	local function capPoint(x: number, z: number)
		local r = math.sqrt(x * x + z * z)
		local y = capBase + capH * math.sqrt(math.max(0, 1 - (r / capR) ^ 2))
		local n = V(x / (capR * capR), (y - capBase) / (capH * capH), z / (capR * capR)).Unit
		return V(x, y, z), n
	end
	for i = 1, 7 do
		local a = i * 2.4
		local r = 0.7 + (i % 3) * 0.35
		local p, n = capPoint(math.cos(a) * r, math.sin(a) * r)
		local spot = b:ellipsoid(V(0.42, 0.1, 0.42), upFrame(p, n), sp.accent, Enum.Material.Neon)
		spot.Transparency = 0.1
	end
	local p0, n0 = capPoint(0, 0)
	b:slot(upFrame(p0 - n0 * 0.05, n0), "up")
	for i = 1, sp.slots - 1 do
		local d = ringDir(i, sp.slots - 1, 0.3)
		local p, n = capPoint(d.X * 1.15, d.Z * 1.15)
		b:slot(upFrame(p - n * 0.05, n), "up")
	end
end

function Styles.tree(b, sp)
	b:mound(1.7)
	local bark = sp.stem
	b:cyl(V(0, 0, 0), V(0, 2.1, 0), 0.95, bark)
	b:cyl(V(0, 2.0, 0), V(0, 3.5, 0), 0.7, shade(bark, 1.05))
	for i = 1, 3 do
		local d = ringDir(i, 3, 0.6)
		b:cyl(V(0, 0.35, 0), d * 0.8 + V(0, -0.05, 0), 0.32, shade(bark, 0.9))
		b:cyl(V(0, 2.9, 0), d * 1.35 + V(0, 4.0, 0), 0.34, bark)
	end
	local crystal = sp.id == "diamond"
	local mat = crystal and Enum.Material.Glass or Enum.Material.SmoothPlastic
	local blobs = {
		{ V(4.4, 2.7, 4.4), V(0, 4.7, 0) }, { V(2.7, 2.1, 2.7), V(1.35, 4.5, 0.6) },
		{ V(2.7, 2.1, 2.7), V(-1.25, 4.55, -0.7) }, { V(2.6, 1.9, 2.6), V(0.2, 5.5, -0.2) },
		{ V(2.3, 1.8, 2.3), V(-0.4, 4.4, 1.3) },
	}
	for _, bl in ipairs(blobs) do
		local p = b:ellipsoid(bl[1], CF(bl[2]), vary(sp.leaf, b.rng, 0.05), mat)
		if crystal then
			p.Transparency = 0.12
			p.Reflectance = 0.2
		end
	end
	local n = sp.slots
	for i = 1, n do
		local d = ringDir(i, n, 0.2)
		local r = (i % 2 == 0) and 1.75 or 2.05
		local top = d * r + V(0, 3.95 + (i % 2) * 0.25, 0)
		b:cyl(top + V(0, 0.45, 0), top, 0.06, shade(bark, 0.9))
		b:slot(CF(top), "hang")
	end
end

function Styles.palm(b, sp)
	b:mound(1.5)
	local pos = V(0, 0, 0)
	for k = 1, 6 do
		local dir = V(math.sin(k * 0.075), math.cos(k * 0.075), 0).Unit
		local nxt = pos + dir * 0.86
		b:cyl(pos, nxt, 0.64 - k * 0.035, (k % 2 == 0) and sp.stem or shade(sp.stem, 0.88), Enum.Material.Wood)
		pos = nxt
	end
	local top = pos
	b:ball(top, 0.55, shade(sp.leaf, 0.8))
	for i = 1, 7 do
		local d = ringDir(i, 7, 0.3)
		b:leaf(top, d * 0.9 + V(0, 0.18, 0), 1.6, 0.8, vary(sp.leaf, b.rng), 0.1)
		b:leaf(top + d * 1.45 + V(0, 0.22, 0), d * 0.8 + V(0, -0.55, 0), 1.5, 0.7, vary(shade(sp.leaf, 0.9), b.rng), 0.1)
	end
	for i = 1, sp.slots do
		local d = ringDir(i, sp.slots, 0.5)
		b:slot(CF(top + d * 0.42 + V(0, -0.42 - (i % 2) * 0.22, 0)), "center")
	end
end

function Styles.prismlotus(b, sp)
	b:disk(V(0, 0.05, 0), 5.2, 0.1, Color3.fromRGB(70, 60, 110), Enum.Material.Slate)
	local glow = b:disk(V(0, 0.08, 0), 4.95, 0.1, Color3.fromRGB(200, 160, 255), Enum.Material.Neon)
	glow.Transparency = 0.25
	local w = b:disk(V(0, 0.12, 0), 4.6, 0.14, Color3.fromRGB(90, 120, 220), Enum.Material.Glass)
	w.Transparency = 0.15
	w.Reflectance = 0.3
	for i = 1, 10 do
		local d = ringDir(i, 10)
		local p = b:leaf(V(0, 0.22, 0) + d * 0.3, d * 0.85 + V(0, 0.55, 0), 1.35, 0.58, Color3.fromHSV((i - 1) / 10, 0.45, 1), 0.14)
		p.Material = Enum.Material.Glass
		p.Reflectance = 0.15
	end
	for i = 1, 7 do
		local d = ringDir(i, 7, 0.3)
		local p = b:leaf(V(0, 0.3, 0) + d * 0.12, d * 0.35 + UP, 1.05, 0.42, Color3.fromHSV(((i - 1) / 7 + 0.5) % 1, 0.35, 1), 0.12)
		p.Material = Enum.Material.Glass
	end
	b:cyl(V(0, 0.3, 0), V(0, 1.15, 0), 0.22, Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	for i = 1, sp.slots do
		local d = ringDir(i, sp.slots, 0.31)
		b:slot(CF(d * 1.55 + V(0, 0.95, 0)), "up")
	end
end

---------------------------------------------------------------------------

function PlantBuilder.hasStyle(style: string): boolean
	return Styles[style] ~= nil
end

function PlantBuilder.build(sp, seed: number?)
	local rng = Random.new(seed or 1)
	local b = Builder.new(rng)
	local style = Styles[sp.style] or Styles.sprout
	style(b, sp)
	b.model.Name = sp.id
	return b.model, b.slots
end

-- Where a gem of `size` should sit for a slot (local space).
function PlantBuilder.gemCFrame(slot, size: Vector3, spin: number?): CFrame
	local cf = slot.cf
	local rot = CFrame.Angles(0, spin or 0, 0)
	if slot.mode == "up" then
		return cf * CF(0, size.Y / 2, 0) * rot
	elseif slot.mode == "hang" then
		return cf * CF(0, -size.Y / 2, 0) * rot
	elseif slot.mode == "out" then
		return cf * CF(0, 0, -size.Z * 0.35) * rot
	end
	return cf * rot
end

return PlantBuilder
