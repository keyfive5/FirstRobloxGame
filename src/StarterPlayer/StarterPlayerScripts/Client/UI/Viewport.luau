-- 3D item icons rendered in ViewportFrames (gems, plants).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local GemFactory = require(Shared.Visuals.GemFactory)

local Viewport = {}

local spinning = {} -- [ViewportFrame] = { part, base CFrame, speed }

local function frameCamera(vp: ViewportFrame, size: Vector3, center: Vector3)
	local cam = vp.CurrentCamera or Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude / (2 * math.tan(math.rad(15))) * 0.95
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Magnitude * 0.25, dist), center)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

local function makeFrame(parent: Instance, size: UDim2): ViewportFrame
	return require(script.Parent.Theme).new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = size,
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.fromRGB(255, 255, 250),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = parent,
	})
end

-- Rotating gem of a species (optionally mutated).
function Viewport.gem(parent: Instance, speciesId: string, size: UDim2?, mutations: { string }?)
	local sp = Species.get(speciesId)
	local vp = makeFrame(parent, size or UDim2.fromScale(1, 1))
	if not sp then
		return vp
	end
	local part = GemFactory.make(sp.gem, sp.gemColor, 1, { neon = sp.neon, rainbow = sp.rainbow })
	GemFactory.applyMutations(part, mutations, sp.gemColor, { neon = sp.neon, rainbow = sp.rainbow })
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("ParticleEmitter") or c:IsA("PointLight") then
			c:Destroy()
		end
	end
	part.CFrame = CFrame.new()
	part.Parent = vp
	frameCamera(vp, part.Size, Vector3.zero)
	spinning[vp] = { part = part, speed = 0.9 }
	vp.Destroying:Connect(function()
		spinning[vp] = nil
	end)
	return vp
end

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	for vp, s in pairs(spinning) do
		if vp.Parent and vp.Visible then
			-- only spin when actually on screen
			local win = vp:FindFirstAncestorWhichIsA("LayerCollector")
			if win and win.Enabled then
				s.part.CFrame = CFrame.Angles(0.25, t * s.speed, 0)
			end
		end
	end
end)

return Viewport
