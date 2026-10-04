-- First-time player guide: a glowing trail + instruction banner that walks a
-- new player through plant -> grow -> harvest -> sell -> buy.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local Theme = require(script.Parent.UI.Theme)
local Root = require(script.Parent.UI.Root)
local Notify = require(script.Parent.UI.Notify)
local State = require(script.Parent.State)
local GardenRenderer = require(script.Parent.GardenRenderer)
local ToolController = require(script.Parent.ToolController)
local Sounds = require(script.Parent.Sounds)

local Tutorial = {}
local player = Players.LocalPlayer
local DONE = 99

local STEPS = {
	[0] = { text = "🌱 Equip your Quartz Seed and click the soil in your garden to plant it!", target = "bed" },
	[1] = { text = "⏳ Your plant is growing! Gems appear when it's fully grown.", target = "plant" },
	[2] = { text = "💎 Your gem is ripe! Walk up to it and press E (or tap) to harvest.", target = "plant" },
	[3] = { text = "💰 Take your gem to the Gem Trader and sell it! (use the 💎 Sell button)", target = "sell" },
	[4] = { text = "🛒 Buy more seeds at the Seed Shop to grow your garden!", target = "seeds" },
}

local banner, bannerText, beam, a0, a1, arrow
local step = DONE

local function setStep(n: number)
	if n <= step and step ~= DONE then
		return
	end
	step = n
	Net.func("SetTutorial"):InvokeServer(n)
	if n == DONE then
		Notify.big("YOU'RE A GEM GARDENER!", "Grow rarer gems, catch weather mutations, get rich!", Theme.C.gold)
		Sounds.play("stinger")
		task.delay(6, Tutorial.askFavorite)
	else
		Sounds.play("notify")
	end
end

local function targetPos(): Vector3?
	local def = STEPS[step]
	if not def then
		return nil
	end
	local idx = player:GetAttribute("PlotIndex")
	if def.target == "bed" then
		local plot = idx and workspace.Plots:FindFirstChild("Plot_" .. idx)
		if plot then
			return (plot.Origin.CFrame * CFrame.new(16, 0, -18)).Position
		end
	elseif def.target == "plant" then
		for _, rec in pairs(GardenRenderer.plantsOf(idx or 0)) do
			return rec.pos
		end
	elseif def.target == "sell" or def.target == "seeds" then
		local shop = workspace.World.Shops:FindFirstChild(def.target)
		return shop and shop.PromptPart.Position
	end
	return nil
end

local function build()
	banner = Theme.card({
		Name = "Tutorial",
		Size = UDim2.fromOffset(620, 54),
		Position = UDim2.new(0.5, 0, 0, 196),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.C.green, Theme.darken(Theme.C.green, 0.45), 0 },
		StrokeColor = Theme.darken(Theme.C.green, 0.7),
		Radius = 18,
		Parent = Root.gui,
	})
	Root.scaled(banner)
	bannerText = Theme.text({ Text = "", Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 22, Parent = banner })
	banner.Visible = false

	local holder = Instance.new("Part")
	holder.Name = "TutorialTarget"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Parent = workspace
	a1 = Instance.new("Attachment")
	a1.Parent = holder
	a0 = Instance.new("Attachment")
	beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(120, 255, 160))
	beam.Width0 = 0.8
	beam.Width1 = 0.8
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Transparency = NumberSequence.new(0.2)
	beam.Segments = 20
	beam.CurveSize0 = 4
	beam.Enabled = false
	beam.Parent = holder
	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(80, 80)
	arrow.StudsOffset = Vector3.new(0, 7, 0)
	arrow.AlwaysOnTop = true
	arrow.Adornee = holder
	arrow.Enabled = false
	arrow.Parent = holder
	Theme.text({ Text = "⬇", Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 230, 90), strokeThickness = 3, Parent = arrow })
end

-- One-time "favorite this game" prompt (no reward attached).
function Tutorial.askFavorite()
	if game.PlaceId == 0 then
		return
	end
	if Net.func("FavPrompted"):InvokeServer() then
		pcall(function()
			game:GetService("AvatarEditorService"):PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end
end

function Tutorial.start()
	build()
	State.waitLoaded()
	step = State.data.tutorial or 0
	if step >= DONE then
		return
	end
	-- progress hooks
	ToolController.Planted:Connect(function()
		if step == 0 then
			setStep(1)
		end
	end)
	GardenRenderer.Ripened:Connect(function()
		if step <= 1 then
			setStep(2)
		end
	end)
	State.Changed:Connect(function(key)
		if key == "bagAdd" and step <= 2 then
			setStep(3)
		elseif key == "stats" and step == 3 and (State.data.stats.sold or 0) > 0 then
			setStep(4)
		elseif key == "seeds" and step == 4 then
			setStep(DONE)
		end
	end)
	-- a returning player who already has plants skips ahead
	if step == 0 and (State.data.stats.planted or 0) > 0 then
		setStep(1)
	end

	RunService.Heartbeat:Connect(function()
		local active = step < DONE and STEPS[step] ~= nil
		banner.Visible = active and Root.current() == nil
		if not active then
			beam.Enabled = false
			arrow.Enabled = false
			return
		end
		bannerText.Text = STEPS[step].text
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local pos = targetPos()
		if hrp and pos then
			if a0.Parent ~= hrp then
				a0.Parent = hrp
			end
			a1.Parent.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
			local far = (hrp.Position - pos).Magnitude > 10
			beam.Enabled = far
			arrow.Enabled = true
			arrow.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.8, 0)
		else
			beam.Enabled = false
			arrow.Enabled = false
		end
	end)
end

return Tutorial
