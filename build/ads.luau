-- Edit-time builder: two immersive-ad billboards at the plaza edge. Roblox fills
-- them with paid ads for eligible players and pays the creator per impression.
-- When no ad is active the board shows FallbackImage (the game's own promo art).
-- Run after build/world.luau: node tools/run.mjs build/ads.luau
local world = workspace:WaitForChild("World")
local old = world:FindFirstChild("AdBoards")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "AdBoards"
folder.Parent = world

local WOOD = Color3.fromRGB(150, 104, 64)
local FALLBACK = "rbxassetid://99100169864750" -- marketing/ad_fallback.png

local function board(angleDeg: number)
	local a = math.rad(angleDeg)
	local base = Vector3.new(math.cos(a) * 90, 0, math.sin(a) * 90)
	local cf = CFrame.lookAt(base, Vector3.new(0, 0, 0))
	local m = Instance.new("Model")
	m.Name = "AdBoard"
	m.Parent = folder
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do
			p[k] = v
		end
		p.Parent = m
		return p
	end
	for _, x in ipairs({ -7, 7 }) do
		part({ Size = Vector3.new(1, 16, 1), CFrame = cf * CFrame.new(x, 8, 0.8), Color = WOOD, Material = Enum.Material.Wood })
	end
	part({ Size = Vector3.new(17.2, 10.2, 0.6), CFrame = cf * CFrame.new(0, 11.5, 0.5), Color = Color3.fromRGB(60, 40, 90), Material = Enum.Material.SmoothPlastic })
	local screen = part({ Name = "Screen", Size = Vector3.new(16, 9, 0.4), CFrame = cf * CFrame.new(0, 11.5, 0), Color = Color3.fromRGB(30, 24, 50), Material = Enum.Material.SmoothPlastic })
	local ok, ad = pcall(Instance.new, "AdGui")
	if ok then
		ad.AdShape = Enum.AdShape.HorizontalRectangle
		ad.Face = Enum.NormalId.Front
		ad.EnableVideoAds = true
		ad.FallbackImage = FALLBACK -- our own promo art when no ad is served
		ad.Parent = screen
	end
end

board(45)
board(225)
return "ad boards built"
