-- Gem bag (view anywhere) and the Gem Trader (sell) window. Gems are grouped by
-- species + mutations so a big bag stays readable.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Mutations = require(Shared.Mutations)
local Rarity = require(Shared.Rarity)
local Config = require(Shared.Config)
local Value = require(Shared.Util.Value)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local BagPanel = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function groupBag(bag)
	local groups, list = {}, {}
	for _, gem in ipairs(bag) do
		local muts = Mutations.sorted(gem.m)
		local huge = Value.isHuge(gem)
		local key = gem.s .. "|" .. table.concat(muts, ",") .. (huge and "|H" or "")
		local g = groups[key]
		if not g then
			g = { key = key, s = gem.s, m = muts, huge = huge, ids = {}, value = 0, count = 0, best = 0, fav = true }
			groups[key] = g
			table.insert(list, g)
		end
		table.insert(g.ids, gem.id)
		g.count += 1
		g.value += Value.base(gem)
		g.best = math.max(g.best, Value.carat(gem))
		if not gem.f then
			g.fav = false
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	return list
end

local function nameRich(g): string
	local sp = Species.get(g.s)
	local parts = {}
	if g.huge then
		table.insert(parts, '<font color="#FF9AE6">HUGE</font>')
	end
	for _, id in ipairs(g.m) do
		local m = Mutations.get(id)
		table.insert(parts, string.format('<font color="%s">%s</font>', hex(m and m.color or Color3.new(1, 1, 1)), id))
	end
	table.insert(parts, sp and sp.name or g.s)
	return table.concat(parts, " ")
end

local function build(mode: string)
	local selling = mode == "sell"
	local win = Root.window({
		name = mode,
		title = selling and "💎 GEM TRADER" or "🎒 GEM BAG",
		accent = selling and C.gold or C.orange,
		width = 780,
		height = 520,
	})
	local body = win.body
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = body })
	local countLabel = Theme.text({ Text = "", Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.fromOffset(4, 0), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = top })
	local multLabel = Theme.text({ Text = "", Size = UDim2.new(0.45, 0, 0, 22), Position = UDim2.fromOffset(4, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.textDim, maxSize = 18, Parent = top })
	local sellAll, sellAllLabel = Theme.button({
		Text = "SELL ALL",
		Color = C.gold,
		Size = UDim2.fromOffset(300, 50),
		Position = UDim2.new(1, -4, 0, 2),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.TitleFont,
		maxSize = 24,
		Parent = top,
	})
	local empty = Theme.text({
		Text = "Your bag is empty.\nHarvest ripe gems in your garden to fill it!",
		Size = UDim2.new(1, -40, 0, 80),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = C.textDim,
		maxSize = 24,
		Parent = body,
	})
	local list = Root.scroller(body, { size = UDim2.new(1, 0, 1, -62), position = UDim2.fromOffset(0, 62), gap = 6 })

	local mult = 1
	local function canSell(): boolean
		return selling or player:GetAttribute("Pass_SellAnywhere") == true
	end

	local function render()
		if not Root.isOpen(mode) then
			return
		end
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local bag = State.data.bag or {}
		local cap = Config.BaseBagCapacity + (player:GetAttribute("Pass_BigBag") and Config.BigBagBonus or 0)
		countLabel.Text = string.format("🎒 %d / %d gems", #bag, cap)
		local groups = groupBag(bag)
		local total = 0
		for _, g in ipairs(groups) do
			if not g.fav then
				total += g.value
			end
		end
		total *= mult
		empty.Visible = #groups == 0
		sellAll.Visible = canSell()
		sellAllLabel.Text = total > 0 and ("SELL ALL  $" .. Format.short(total)) or "SELL ALL"
		Theme.setButtonColor(sellAll, total > 0 and C.gold or C.grey)
		if not canSell() then
			multLabel.Text = "Sell at the Gem Trader in the plaza!"
		end
		for i, g in ipairs(groups) do
			if i > 80 then
				break
			end
			local sp = Species.get(g.s)
			local tier = Rarity.get(sp and sp.rarity or "Common")
			local row = Theme.card({
				Size = UDim2.new(1, -14, 0, 64),
				Color = Color3.new(1, 1, 1),
				Gradient = { Theme.darken(tier.color, 0.4), Theme.darken(tier.color, 0.65), 0 },
				StrokeColor = Theme.darken(tier.color, 0.75),
				LayoutOrder = i,
				Parent = list,
			})
			local iconColor = sp and sp.gemColor or Color3.new(1, 1, 1)
			if table.find(g.m, "Golden") then
				iconColor = Mutations.get("Golden").color
			elseif table.find(g.m, "Rainbow") then
				iconColor = Color3.fromHSV((os.clock() * 0.2) % 1, 0.6, 1)
			end
			local icon = Theme.gemIcon(iconColor, 52, row)
			icon.Position = UDim2.fromOffset(8, 6)
			Theme.text({ Text = nameRich(g), RichText = true, Size = UDim2.new(0, 360, 0, 26), Position = UDim2.fromOffset(68, 6), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 22, Parent = row })
			Theme.text({ Text = string.format("x%d  •  up to %s  •  %s", g.count, Format.carat(g.best), sp and sp.rarity or ""), Size = UDim2.new(0, 360, 0, 20), Position = UDim2.fromOffset(68, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.textDim, maxSize = 16, strokeThickness = 1.5, Parent = row })
			Theme.text({ Text = "$" .. Format.short(g.value * mult), Size = UDim2.fromOffset(130, 30), Position = UDim2.new(1, -250, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextColor3 = C.gold, maxSize = 22, Parent = row })
			local fav = Theme.button({
				Text = g.fav and "★" or "☆",
				Color = g.fav and C.gold or C.cardDark,
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.new(1, -112, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				maxSize = 26,
				Parent = row,
			})
			fav.Activated:Connect(function()
				Sounds.play("click")
				Net.func("FavoriteIds"):InvokeServer(g.ids, not g.fav)
			end)
			if canSell() then
				local sb = Theme.button({
					Text = "SELL",
					Color = g.fav and C.grey or C.green,
					Size = UDim2.fromOffset(58, 44),
					Position = UDim2.new(1, -8, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					maxSize = 18,
					Parent = row,
				})
				sb.Activated:Connect(function()
					if g.fav then
						Notify.toast("Unfavorite (☆) these gems to sell them.", "info")
						return
					end
					local ok, amount, n = Net.func("SellIds"):InvokeServer(g.ids)
					if ok then
						Sounds.play("coins")
						Notify.float(string.format("+$%s (%d)", Format.short(amount), n), C.gold)
					elseif amount then
						Notify.toast(amount, "bad")
					end
				end)
			end
		end
	end

	sellAll.Activated:Connect(function()
		local ok, amount, n = Net.func("SellAll"):InvokeServer()
		if ok then
			Sounds.play("coins")
			Notify.big("+$" .. Format.short(amount), string.format("Sold %d gems!", n), C.gold)
		elseif amount then
			Notify.toast(amount, "bad")
		end
	end)

	local function onOpen()
		if canSell() then
			task.spawn(function()
				local m, parts = Net.func("SellQuote"):InvokeServer()
				mult = m or 1
				local bits = {}
				for _, p in ipairs(parts or {}) do
					table.insert(bits, string.format("%s +%d%%", p[1], p[2] * 100))
				end
				multLabel.Text = #bits > 0 and string.format("Sell bonus x%.2f (%s)", mult, table.concat(bits, ", ")) or "Tip: VIP and playing with friends boost sell prices!"
				render()
			end)
		end
		render()
	end
	Root.WindowChanged:Connect(function(name)
		if name == mode then
			onOpen()
		end
	end)
	State.onChange("bag", render)
	return win
end

function BagPanel.start()
	build("bag")
	build("sell")
end

return BagPanel
