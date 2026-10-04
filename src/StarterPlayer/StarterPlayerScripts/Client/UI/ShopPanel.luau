-- Seed Shop + Gear Shop windows (same layout, different catalogs).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Species = require(Shared.Species)
local Gear = require(Shared.Gear)
local Rarity = require(Shared.Rarity)
local Products = require(Shared.Products)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Viewport = require(script.Parent.Viewport)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local ShopPanel = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local function rarityPill(parent, rarity: string, pos: UDim2)
	local tier = Rarity.get(rarity)
	local pill = Theme.card({
		Size = UDim2.fromOffset(96, 22),
		Position = pos,
		Color = tier.color,
		StrokeColor = tier.dark,
		StrokeThickness = 2,
		Radius = 11,
		Parent = parent,
	})
	local grad = Rarity.Gradients[rarity]
	if grad then
		local kps = {}
		for i, c in ipairs(grad) do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#grad - 1), c))
		end
		new("UIGradient", { Color = ColorSequence.new(kps), Parent = pill })
	end
	Theme.text({ Text = string.upper(rarity), Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 14, strokeColor = tier.dark, Parent = pill })
	return pill
end
ShopPanel.rarityPill = rarityPill

local function build(kind: string)
	local isSeed = kind == "seeds"
	local win = Root.window({
		name = kind,
		title = isSeed and "🌱 SEED SHOP" or "🛠️ GEAR SHOP",
		accent = isSeed and C.green or C.blue,
		width = 780,
		height = 520,
	})
	local body = win.body

	local topBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = body })
	local info = Theme.text({
		Text = "New stock every 5 minutes!",
		Size = UDim2.new(0.6, 0, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textDim,
		maxSize = 20,
		Parent = topBar,
	})
	local restockId = Products.devId("Restock")
	if restockId ~= 0 then
		Theme.button({
			Text = "🔄 Restock Now  R$ " .. Products.DevByKey.Restock.price,
			Color = C.purple,
			Size = UDim2.fromOffset(240, 40),
			Position = UDim2.new(1, -4, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			maxSize = 20,
			Parent = topBar,
			onClick = function()
				MarketplaceService:PromptProductPurchase(player, restockId)
			end,
		})
	end

	local list = Root.scroller(body, { size = UDim2.new(1, 0, 1, -50), position = UDim2.fromOffset(0, 50), gap = 8 })
	local rows = {}
	local catalog = isSeed and Species.List or Gear.List

	for i, def in ipairs(catalog) do
		if not def.notSold then
			local tier = Rarity.get(def.rarity)
			local row = Theme.card({
				Name = def.id,
				Size = UDim2.new(1, -14, 0, 92),
				Color = Color3.new(1, 1, 1),
				Gradient = { Theme.darken(tier.color, 0.35), Theme.darken(tier.color, 0.62), 0 },
				StrokeColor = Theme.darken(tier.color, 0.75),
				LayoutOrder = i,
				Parent = list,
			})
			local iconBox = Theme.card({ Size = UDim2.fromOffset(76, 76), Position = UDim2.fromOffset(8, 8), Color = Color3.fromRGB(255, 255, 255), Transparency = 0.82, Stroke = false, Parent = row })
			if isSeed then
				Viewport.gem(iconBox, def.id)
			else
				Theme.text({ Text = def.icon, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), stroke = false, Parent = iconBox })
			end
			Theme.text({ Text = def.name, Size = UDim2.new(0, 300, 0, 30), Position = UDim2.fromOffset(94, 8), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 26, Parent = row })
			rarityPill(row, def.rarity, UDim2.fromOffset(94, 40))
			local sub = isSeed and string.format("%s • %s", def.multi and ("Regrows gems") or "Single big gem", Format.duration(def.grow)) or def.desc
			Theme.text({ Text = sub, Size = UDim2.new(0, 330, 0, 22), Position = UDim2.fromOffset(94, 64), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.textDim, maxSize = 16, strokeThickness = 1.5, Parent = row })
			local price = Theme.text({ Text = "$" .. Format.short(def.price), Size = UDim2.fromOffset(150, 30), Position = UDim2.new(1, -300, 0, 14), TextColor3 = C.gold, maxSize = 26, Parent = row })
			local stock = Theme.text({ Text = "", Size = UDim2.fromOffset(150, 22), Position = UDim2.new(1, -300, 0, 50), maxSize = 18, Parent = row })
			local buy = Theme.button({
				Text = "BUY",
				Color = C.green,
				Size = UDim2.fromOffset(130, 40),
				Position = UDim2.new(1, -10, 0, 8),
				AnchorPoint = Vector2.new(1, 0),
				Font = Theme.TitleFont,
				Parent = row,
			})
			buy.Activated:Connect(function()
				local ok, msg = Net.func(isSeed and "BuySeed" or "BuyGear"):InvokeServer(def.id)
				if ok then
					Sounds.play("pop", 1.1)
					Notify.float("+1 " .. def.name, tier.color)
				else
					Sounds.play("error")
					if msg then
						Notify.toast(msg, "bad")
					end
				end
			end)
			local productKey = (isSeed and "Seed_" or "Gear_") .. def.id
			local pid = Products.devId(productKey)
			if pid ~= 0 then
				Theme.button({
					Text = "R$ " .. tostring(def.robux or "?"),
					Color = C.purple,
					Size = UDim2.fromOffset(130, 32),
					Position = UDim2.new(1, -10, 0, 52),
					AnchorPoint = Vector2.new(1, 0),
					maxSize = 18,
					Parent = row,
					onClick = function()
						MarketplaceService:PromptProductPurchase(player, pid)
					end,
				})
			end
			rows[def.id] = { row = row, buy = buy, stock = stock, price = price, def = def }
		end
	end

	local function refresh()
		local stockData = State.data.stock or {}
		local pool = (isSeed and stockData.seeds or stockData.gear) or {}
		local coins = State.data.coins or 0
		for id, r in pairs(rows) do
			local n = pool[id] or 0
			if n > 0 then
				r.stock.Text = "x" .. n .. " in stock"
				r.stock.TextColor3 = Color3.fromRGB(190, 255, 190)
				local afford = coins >= r.def.price
				Theme.setButtonColor(r.buy, afford and C.green or C.grey)
			else
				r.stock.Text = "NO STOCK"
				r.stock.TextColor3 = Color3.fromRGB(255, 150, 150)
				Theme.setButtonColor(r.buy, C.grey)
			end
		end
	end
	State.onChange("stock", refresh)
	State.onChange("coins", refresh)
	State.whenLoaded(refresh)

	-- live restock countdown
	task.spawn(function()
		while true do
			if Root.isOpen(kind) then
				local left = Config.RestockInterval - (os.time() % Config.RestockInterval)
				win.subtitle.Text = "Restock in " .. Format.clock(left)
				info.Text = isSeed and "Seeds restock every 5 minutes. Rare seeds are rare!" or "Gear restocks with the seed shop."
			end
			task.wait(0.5)
		end
	end)
	return win
end

function ShopPanel.start()
	build("seeds")
	build("gear")
end

return ShopPanel
