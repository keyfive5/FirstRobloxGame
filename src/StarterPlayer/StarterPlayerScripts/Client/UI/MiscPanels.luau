-- Daily rewards, playtime gifts, the gem index (collection book) and settings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Rarity = require(Shared.Rarity)
local Rewards = require(Shared.Rewards)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local HUD = require(script.Parent.HUD)
local Viewport = require(script.Parent.Viewport)
local ShopPanel = require(script.Parent.ShopPanel)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local MiscPanels = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local function describe(spec): { string }
	local lines = {}
	local coins = Rewards.coins(spec, State.data.stats and State.data.stats.topPrice or 10)
	if coins > 0 then
		table.insert(lines, "$" .. Format.short(coins))
	end
	for id, n in pairs(spec.seeds or {}) do
		local sp = Species.get(id)
		table.insert(lines, string.format("%dx %s", n, sp and sp.name or id))
	end
	for id, n in pairs(spec.gear or {}) do
		local g = Gear.get(id)
		table.insert(lines, string.format("%s %dx %s", g and g.icon or "", n, g and g.name or id))
	end
	return lines
end

---------------------------------------------------------------------------
-- Daily
---------------------------------------------------------------------------
local function buildDaily()
	local win = Root.window({ name = "daily", title = "🎁 DAILY REWARDS", accent = C.green, width = 800, height = 420 })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 220), Parent = win.body }, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	local tiles = {}
	for day = 1, Config.DailyCycle do
		local tile = Theme.card({ Size = UDim2.fromOffset(100, 210), Color = Color3.new(1, 1, 1), Gradient = { C.card, C.cardDark, 90 }, LayoutOrder = day, Parent = row })
		Theme.text({ Text = "DAY " .. day, Font = Theme.TitleFont, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 8), maxSize = 24, Parent = tile })
		local desc = Theme.text({ Text = "", Size = UDim2.new(1, -10, 0, 150), Position = UDim2.fromOffset(5, 44), TextColor3 = Color3.fromRGB(240, 236, 255), maxSize = 15, strokeThickness = 1.5, TextYAlignment = Enum.TextYAlignment.Top, Parent = tile })
		tiles[day] = { tile = tile, desc = desc }
	end
	local status = Theme.text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 232), maxSize = 22, Parent = win.body })
	local claim, claimLabel = Theme.button({ Text = "CLAIM", Color = C.green, Size = UDim2.fromOffset(260, 54), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.TitleFont, Parent = win.body })

	local info
	local function refresh()
		info = Net.func("DailyStatus"):InvokeServer()
		if not info then
			return
		end
		for day, t in ipairs(tiles) do
			t.desc.Text = table.concat(describe(Rewards.Daily[day]), "\n")
			local isNext = day == info.nextDay
			local done = day < info.nextDay
			local g = t.tile:FindFirstChildOfClass("UIGradient")
			if isNext and info.canClaim then
				g.Color = ColorSequence.new(Theme.lighten(C.green, 0.1), Theme.darken(C.green, 0.4))
			elseif done then
				g.Color = ColorSequence.new(C.grey, Theme.darken(C.grey, 0.4))
			else
				g.Color = ColorSequence.new(C.card, C.cardDark)
			end
		end
		if info.canClaim then
			claimLabel.Text = "CLAIM DAY " .. info.nextDay
			Theme.setButtonColor(claim, C.green)
			status.Text = "Your reward is ready! Come back every day to keep your streak."
			HUD.setBadge("Daily", "!")
		else
			claimLabel.Text = "COME BACK TOMORROW"
			Theme.setButtonColor(claim, C.grey)
			status.Text = "Next reward in " .. Format.duration(info.resetsIn)
			HUD.setBadge("Daily", nil)
		end
	end
	claim.Activated:Connect(function()
		if info and info.canClaim then
			local ok = Net.func("ClaimDaily"):InvokeServer()
			if ok then
				Sounds.play("stinger")
			end
			refresh()
		end
	end)
	Root.WindowChanged:Connect(function(name)
		if name == "daily" then
			task.spawn(refresh)
		end
	end)
	State.whenLoaded(function()
		task.spawn(refresh)
	end)
end

---------------------------------------------------------------------------
-- Playtime gifts
---------------------------------------------------------------------------
local function buildGifts()
	local win = Root.window({ name = "gifts", title = "⏰ PLAYTIME GIFTS", accent = C.blue, width = 760, height = 400 })
	Theme.text({ Text = "Stay and play to unlock free gifts every session!", Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.textDim, maxSize = 20, Parent = win.body })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 260), Position = UDim2.fromOffset(0, 36), Parent = win.body }, { Theme.list(Enum.FillDirection.Horizontal, 12) })
	local tiles = {}
	for i, need in ipairs(Config.PlaytimeGifts) do
		local tile = Theme.card({ Size = UDim2.fromOffset(170, 250), Color = Color3.new(1, 1, 1), Gradient = { C.card, C.cardDark, 90 }, LayoutOrder = i, Parent = row })
		Theme.text({ Text = "🎁", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), stroke = false, maxSize = 46, Parent = tile })
		local desc = Theme.text({ Text = "", Size = UDim2.new(1, -12, 0, 90), Position = UDim2.fromOffset(6, 58), maxSize = 16, strokeThickness = 1.5, TextYAlignment = Enum.TextYAlignment.Top, Parent = tile })
		local btn, label = Theme.button({ Text = Format.duration(need), Color = C.grey, Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), maxSize = 20, Parent = tile })
		btn.Activated:Connect(function()
			local ok, msg = Net.func("ClaimGift"):InvokeServer(i)
			if not ok and msg then
				Notify.toast(msg, "info")
			end
		end)
		tiles[i] = { desc = desc, btn = btn, label = label, need = need }
	end
	local claimed = {}
	local function poll()
		local s = Net.func("GiftStatus"):InvokeServer()
		claimed = s and s.claimed or {}
		return s
	end
	task.spawn(function()
		State.waitLoaded()
		local status = poll()
		local start = os.clock() - (status and status.elapsed or 0)
		local lastPoll = os.clock()
		while true do
			if os.clock() - lastPoll > 15 or Root.isOpen("gifts") and os.clock() - lastPoll > 2 then
				poll()
				lastPoll = os.clock()
			end
			local elapsed = os.clock() - start
			local ready = 0
			for i, t in ipairs(tiles) do
				t.desc.Text = table.concat(describe(Rewards.Gifts[i]), "\n")
				if claimed[i] or claimed[tostring(i)] then
					t.label.Text = "CLAIMED"
					Theme.setButtonColor(t.btn, C.grey)
				elseif elapsed >= t.need then
					t.label.Text = "CLAIM!"
					Theme.setButtonColor(t.btn, C.green)
					ready += 1
				else
					t.label.Text = Format.clock(t.need - elapsed)
					Theme.setButtonColor(t.btn, C.cardDark)
				end
			end
			HUD.setBadge("Gifts", ready > 0 and tostring(ready) or nil)
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------------------
-- Index (collection book)
---------------------------------------------------------------------------
local function buildIndex()
	local win = Root.window({ name = "index", title = "📖 GEM INDEX", accent = C.purple, width = 800, height = 540 })
	local grid = Root.scroller(win.body, { grid = UDim2.fromOffset(170, 190), gap = 10 })
	local cards = {}
	for i, sp in ipairs(Species.List) do
		local tier = Rarity.get(sp.rarity)
		local c = Theme.card({ Size = UDim2.fromOffset(170, 190), Color = Color3.new(1, 1, 1), Gradient = { Theme.darken(tier.color, 0.3), Theme.darken(tier.color, 0.65), 90 }, StrokeColor = Theme.darken(tier.color, 0.75), LayoutOrder = i, Parent = grid })
		local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 90), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), Parent = c })
		local vp = Viewport.gem(box, sp.id)
		local lock = Theme.text({ Text = "?", Font = Theme.TitleFont, Size = UDim2.fromScale(1, 1), maxSize = 60, Parent = box })
		local name = Theme.text({ Text = sp.name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 100), maxSize = 18, Parent = c })
		ShopPanel.rarityPill(c, sp.rarity, UDim2.new(0.5, -48, 0, 128))
		local val = Theme.text({ Text = "", Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 156), TextColor3 = C.gold, maxSize = 16, Parent = c })
		cards[sp.id] = { vp = vp, lock = lock, name = name, val = val, sp = sp }
	end
	local function refresh()
		local found, total = 0, 0
		local disc = State.data.discovered or {}
		for id, cd in pairs(cards) do
			total += 1
			local known = disc[id] == true
			if known then
				found += 1
			end
			cd.vp.Visible = known
			cd.lock.Visible = not known
			cd.name.Text = known and cd.sp.name or "???"
			cd.val.Text = known and ("Worth $" .. Format.short(cd.sp.value) .. "+") or ("Seed: $" .. Format.short(cd.sp.price))
		end
		win.subtitle.Text = string.format("%d / %d discovered", found, total)
	end
	State.onChange("discovered", refresh)
	State.whenLoaded(refresh)
end

---------------------------------------------------------------------------
-- Settings + codes
---------------------------------------------------------------------------
local function buildSettings()
	local win = Root.window({ name = "settings", title = "⚙️ SETTINGS", accent = C.grey, width = 560, height = 440 })
	local body = win.body
	local levels = { { "Off", 0 }, { "Low", 0.25 }, { "Med", 0.5 }, { "High", 1 } }
	local function selector(y: number, label: string, key: string)
		Theme.text({ Text = label, Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(4, y), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = body })
		local buttons = {}
		for i, lv in ipairs(levels) do
			buttons[i] = Theme.button({
				Text = lv[1],
				Color = C.cardDark,
				Size = UDim2.fromOffset(80, 40),
				Position = UDim2.fromOffset(160 + (i - 1) * 88, y),
				maxSize = 20,
				Parent = body,
				onClick = function()
					State.data.settings[key] = lv[2]
					require(script.Parent.Parent.Sounds).setVolumes(State.data.settings.music, State.data.settings.sfx)
					Net.func("SaveSettings"):InvokeServer(State.data.settings)
					Sounds.play("click")
					for j, b in ipairs(buttons) do
						Theme.setButtonColor(b, j == i and C.green or C.cardDark)
					end
				end,
			})
		end
		local function sync()
			local v = State.data.settings and State.data.settings[key] or 0.5
			local best, bi = 99, 1
			for i, lv in ipairs(levels) do
				if math.abs(lv[2] - v) < best then
					best, bi = math.abs(lv[2] - v), i
				end
			end
			for j, b in ipairs(buttons) do
				Theme.setButtonColor(b, j == bi and C.green or C.cardDark)
			end
		end
		State.whenLoaded(sync)
		sync()
	end
	selector(4, "🎵 Music", "music")
	selector(56, "🔊 Sounds", "sfx")

	Theme.text({ Text = "🎟️ Codes", Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(4, 120), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = body })
	local boxBg = Theme.card({ Size = UDim2.fromOffset(250, 44), Position = UDim2.fromOffset(160, 118), Color = Color3.fromRGB(30, 22, 60), Parent = body })
	local box = new("TextBox", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Font = Theme.Font,
		TextScaled = true,
		PlaceholderText = "Enter code...",
		PlaceholderColor3 = Color3.fromRGB(150, 140, 190),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		ClearTextOnFocus = false,
		Parent = boxBg,
	})
	Theme.button({
		Text = "Redeem",
		Color = C.green,
		Size = UDim2.fromOffset(110, 44),
		Position = UDim2.fromOffset(420, 118),
		maxSize = 20,
		Parent = body,
		onClick = function()
			local ok, msg = Net.func("Redeem"):InvokeServer(box.Text)
			if not ok then
				Notify.toast(msg or "Invalid code", "bad")
			else
				box.Text = ""
			end
		end,
	})
	Theme.text({ Text = "Follow the game for new codes every update! Try: RELEASE", Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(4, 172), TextColor3 = C.textDim, maxSize = 17, Parent = body })
	Theme.text({ Text = "Grow a Gem Garden • plant seeds, harvest gems, get rich!\nTip: weather events mutate gems for HUGE multipliers.", Size = UDim2.new(1, -10, 0, 60), Position = UDim2.new(0, 4, 1, -64), TextColor3 = C.textDim, maxSize = 16, strokeThickness = 1.5, Parent = body })
end

function MiscPanels.start()
	buildDaily()
	buildGifts()
	buildIndex()
	buildSettings()
	State.whenLoaded(function()
		local s = State.data.settings or {}
		Sounds.setVolumes(s.music or 0.25, s.sfx or 0.6)
	end)
end

return MiscPanels
