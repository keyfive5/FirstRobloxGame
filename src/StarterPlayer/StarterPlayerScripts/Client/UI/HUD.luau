-- Always-on HUD: coins, teleport bar, side menu, weather banner, boosts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Weather = require(Shared.Weather)
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local HUD = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Teleports
---------------------------------------------------------------------------
function HUD.teleport(target: string)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local cf
	if target == "garden" then
		local idx = player:GetAttribute("PlotIndex")
		local plot = idx and workspace.Plots:FindFirstChild("Plot_" .. idx)
		cf = plot and plot.SpawnPoint.CFrame
	else
		local shop = workspace.World.Shops:FindFirstChild(target)
		cf = shop and shop.TeleportPoint.CFrame
	end
	if cf then
		Sounds.play("whoosh")
		char:PivotTo(cf + Vector3.new(0, 2.5, 0))
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local coinLabel
local displayedCoins = 0
local targetCoins = 0

local function buildTop()
	local top = new("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 150),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = Root.gui,
	})
	Root.scaled(top)

	local pill = Theme.card({
		Name = "Coins",
		Size = UDim2.fromOffset(260, 54),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 160, 30), 90 },
		StrokeColor = Color3.fromRGB(110, 60, 10),
		StrokeThickness = 4,
		Radius = 27,
		Parent = top,
	})
	local coinIcon = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 214, 60),
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = pill,
	}, {
		Theme.corner(23),
		Theme.stroke(Color3.fromRGB(150, 90, 10), 3),
		Theme.gradient(Color3.fromRGB(255, 240, 150), Color3.fromRGB(240, 170, 30), 90),
	})
	Theme.text({ Text = "$", Font = Theme.TitleFont, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(255, 250, 220), strokeColor = Color3.fromRGB(150, 90, 10), Parent = coinIcon })
	coinLabel = Theme.text({
		Text = "0",
		Font = Theme.TitleFont,
		Size = UDim2.new(1, -66, 0, 40),
		Position = UDim2.new(0, 56, 0.5, 2),
		AnchorPoint = Vector2.new(0, 0.5),
		strokeColor = Color3.fromRGB(110, 60, 10),
		strokeThickness = 3,
		maxSize = 34,
		Parent = pill,
	})
	local pillScale = new("UIScale", { Parent = pill })

	-- teleport bar
	local bar = new("Frame", {
		Name = "Teleports",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(540, 44),
		Position = UDim2.new(0.5, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = top,
	}, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	local tps = {
		{ "🌱 Seeds", "seeds", C.green },
		{ "🛠️ Gear", "gear", C.blue },
		{ "🏡 Garden", "garden", C.orange },
		{ "💎 Sell", "sell", C.gold },
	}
	for i, t in ipairs(tps) do
		Theme.button({
			Text = t[1],
			Color = t[3],
			Size = UDim2.fromOffset(124, 42),
			LayoutOrder = i,
			maxSize = 22,
			Parent = bar,
			onClick = function()
				HUD.teleport(t[2])
			end,
		})
	end

	-- weather banner
	local banner = Theme.card({
		Name = "Weather",
		Size = UDim2.fromOffset(480, 36),
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.new(1, 1, 1),
		Gradient = { C.blue, Theme.darken(C.blue, 0.4), 0 },
		Radius = 18,
		Parent = top,
	})
	banner.Visible = false
	local bannerText = Theme.text({ Text = "", Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 20, Parent = banner })

	RunService.Heartbeat:Connect(function()
		-- coin count-up
		if displayedCoins ~= targetCoins then
			local diff = targetCoins - displayedCoins
			if math.abs(diff) < 1 then
				displayedCoins = targetCoins
			else
				displayedCoins += diff * 0.18
			end
			local v = math.floor(displayedCoins + 0.5)
			coinLabel.Text = v < 1e6 and Format.commas(v) or Format.short(v)
		end
		-- weather
		local id = ReplicatedStorage:GetAttribute("WeatherId")
		local ends = ReplicatedStorage:GetAttribute("WeatherEnds") or 0
		local def = id and id ~= "" and Weather.get(id)
		local left = ends - workspace:GetServerTimeNow()
		if def and left > 0 then
			banner.Visible = true
			bannerText.Text = string.format("%s %s  %s  %s", def.icon, string.upper(def.name), Format.clock(left), def.mutation and ("• " .. def.mutation .. " gems!") or "")
			local g = banner:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = ColorSequence.new(def.color, Theme.darken(def.color, 0.45))
			end
		else
			banner.Visible = false
		end
	end)

	State.onChange("coins", function(v)
		local up = v > targetCoins
		targetCoins = v
		if up and State.loaded then
			pillScale.Scale = 1.12
			Theme.tween(pillScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
	State.whenLoaded(function()
		targetCoins = State.data.coins
		displayedCoins = targetCoins
		coinLabel.Text = Format.commas(targetCoins)
	end)
end

local badges = {}
local function sideButton(parent, order: number, icon: string, label: string, color: Color3, onClick)
	local b = Theme.button({
		Name = label,
		Text = "",
		Color = color,
		Size = UDim2.fromOffset(74, 74),
		LayoutOrder = order,
		Radius = 18,
		Parent = parent,
		onClick = onClick,
	})
	Theme.text({ Text = icon, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), stroke = false, maxSize = 36, Parent = b, ZIndex = 3 })
	Theme.text({ Text = label, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -24), maxSize = 17, Parent = b, ZIndex = 3 })
	local badge = Theme.card({
		Name = "Badge",
		Size = UDim2.fromOffset(30, 26),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.red,
		StrokeColor = Color3.fromRGB(90, 10, 20),
		Radius = 13,
		ZIndex = 5,
		Parent = b,
	})
	badge.AutomaticSize = Enum.AutomaticSize.X
	Theme.pad(6, 0).Parent = badge
	local bt = Theme.text({ Text = "!", Size = UDim2.new(0, 0, 1, 0), maxSize = 18, ZIndex = 6, Parent = badge })
	bt.AutomaticSize = Enum.AutomaticSize.X
	bt.TextScaled = false
	bt.TextSize = 17
	badge.Visible = false
	badges[label] = { frame = badge, text = bt }
	return b
end

-- Opens Roblox's invite sheet. Friends who join through it reward the inviter.
function HUD.invite()
	local SocialService = game:GetService("SocialService")
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end

function HUD.setBadge(label: string, text: string?)
	local b = badges[label]
	if b then
		b.frame.Visible = text ~= nil
		b.text.Text = text or ""
	end
end

local function buildSide()
	-- Desktop: bottom-left (chat lives top-left). Mobile: mid-left (thumbstick lives bottom-left).
	local side = new("Frame", {
		Name = "Side",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(168, 336),
		Position = Root.isMobile and UDim2.new(0, 12, 0.42, 0) or UDim2.new(0, 12, 1, -16),
		AnchorPoint = Root.isMobile and Vector2.new(0, 0.5) or Vector2.new(0, 1),
		Parent = Root.gui,
	})
	Root.scaled(side)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(74, 74),
		CellPadding = UDim2.fromOffset(10, 10),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = side,
	})
	sideButton(side, 1, "🎒", "Bag", C.orange, function()
		Root.toggle("bag")
	end)
	sideButton(side, 2, "🛍️", "Store", C.pink, function()
		Root.toggle("store")
	end)
	sideButton(side, 3, "🎁", "Daily", C.green, function()
		Root.toggle("daily")
	end)
	sideButton(side, 4, "⏰", "Gifts", C.blue, function()
		Root.toggle("gifts")
	end)
	sideButton(side, 5, "📖", "Index", C.purple, function()
		Root.toggle("index")
	end)
	sideButton(side, 6, "⚙️", "Settings", C.grey, function()
		Root.toggle("settings")
	end)
	sideButton(side, 7, "👥", "Invite", C.green, function()
		HUD.invite()
	end)

	local function updateBag(bag)
		local cap = Config.BaseBagCapacity + (player:GetAttribute("Pass_BigBag") and Config.BigBagBonus or 0)
		local n = #(bag or {})
		if n >= cap then
			HUD.setBadge("Bag", "FULL")
		elseif n > 0 then
			HUD.setBadge("Bag", tostring(n))
		else
			HUD.setBadge("Bag", nil)
		end
	end
	State.onChange("bag", updateBag)
	State.whenLoaded(function()
		updateBag(State.data.bag)
	end)
end

-- Little row of active boosts under the side menu.
local function buildBoosts()
	local row = new("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 28),
		Position = UDim2.new(0.5, 0, 0, 160),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = Root.gui,
	}, { Theme.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	Root.scaled(row)
	local labels = {}
	local function chip(key: string, color: Color3)
		local c = Theme.card({ Size = UDim2.fromOffset(170, 28), Color = Color3.new(1, 1, 1), Gradient = { color, Theme.darken(color, 0.4), 0 }, Radius = 14, Parent = row })
		local t = Theme.text({ Text = "", Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 16, Parent = c })
		c.Visible = false
		labels[key] = { card = c, text = t }
	end
	chip("luck", C.green)
	chip("friends", C.blue)
	chip("sell", C.gold)
	-- Free boost offer via opt-in rewarded ad
	local Ads = require(script.Parent.Parent.Ads)
	local adChip = Theme.button({ Text = "📺 Free Luck Boost!", Color = C.purple, Size = UDim2.fromOffset(190, 30), Radius = 15, maxSize = 16, Parent = row })
	adChip.Visible = false
	adChip.Activated:Connect(function()
		adChip.Visible = false
		Ads.watch()
	end)
	task.spawn(function()
		task.wait(90)
		while true do
			local luckEnds = State.data.boosts and State.data.boosts.luck or 0
			if luckEnds < os.time() and Ads.enabled() then
				adChip.Visible = Ads.available()
			else
				adChip.Visible = false
			end
			task.wait(300)
		end
	end)
	task.spawn(function()
		while true do
			local now = os.time()
			local luckEnds = State.data.boosts and State.data.boosts.luck or 0
			labels.luck.card.Visible = luckEnds > now
			labels.luck.text.Text = "🍀 Luck x2  " .. Format.clock(luckEnds - now)
			local friends = 0
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player and player:GetAttribute("Friend_" .. other.UserId) then
					friends += 1
				end
			end
			local fb = math.min(friends * Config.FriendBoostPer, Config.FriendBoostMax)
			labels.friends.card.Visible = fb > 0
			labels.friends.text.Text = string.format("👥 Friends +%d%% sell", fb * 100)
			local sb = ReplicatedStorage:GetAttribute("SellBoost") or 0
			local sbEnds = ReplicatedStorage:GetAttribute("SellBoostEnds") or 0
			labels.sell.card.Visible = sb > 0 and sbEnds > now
			labels.sell.text.Text = string.format("🎉 Sell +%d%%  %s", sb * 100, Format.clock(sbEnds - now))
			task.wait(1)
		end
	end)
end

function HUD.start()
	buildTop()
	buildSide()
	buildBoosts()
end

return HUD
