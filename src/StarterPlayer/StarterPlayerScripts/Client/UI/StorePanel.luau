-- Robux store: game passes, coin packs, boosts and weather events.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local Weather = require(Shared.Weather)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local Sounds = require(script.Parent.Parent.Sounds)

local StorePanel = {}
local C = Theme.C
local new = Theme.new
local player = Players.LocalPlayer

local function card(parent, order: number, icon: string, title: string, desc: string, color: Color3)
	local c = Theme.card({
		Size = UDim2.fromOffset(226, 210),
		Color = Color3.new(1, 1, 1),
		Gradient = { Theme.darken(color, 0.2), Theme.darken(color, 0.6), 90 },
		StrokeColor = Theme.darken(color, 0.75),
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.text({ Text = icon, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 8), stroke = false, maxSize = 48, Parent = c })
	Theme.text({ Text = title, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 62), maxSize = 22, Parent = c })
	local descLabel = Theme.text({ Text = desc, Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 92), TextColor3 = Color3.fromRGB(235, 230, 255), maxSize = 16, strokeThickness = 1.5, Parent = c })
	return c, descLabel
end

local function priceButton(parent, price: number, onClick)
	local b, label = Theme.button({
		Text = "R$ " .. price,
		Color = C.green,
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.TitleFont,
		maxSize = 22,
		Parent = parent,
		onClick = onClick,
	})
	return b, label
end

function StorePanel.start()
	local win = Root.window({ name = "store", title = "🛍️ GEM STORE", accent = C.pink, width = 800, height = 540 })
	local body = win.body

	local tabsBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = body }, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	local pages = {}
	local tabButtons = {}
	local function page(name: string)
		local s = Root.scroller(body, { size = UDim2.new(1, 0, 1, -54), position = UDim2.fromOffset(0, 54), grid = UDim2.fromOffset(226, 210), gap = 12 })
		s.Visible = false
		pages[name] = s
		return s
	end
	local function show(name: string)
		for n, p in pairs(pages) do
			p.Visible = n == name
		end
		for n, b in pairs(tabButtons) do
			Theme.setButtonColor(b, n == name and C.pink or C.cardDark)
		end
	end
	for i, t in ipairs({ { "passes", "⭐ Passes" }, { "coins", "$Coins" }, { "boosts", "⚡ Boosts" }, { "weather", "🌦️ Weather" } }) do
		tabButtons[t[1]] = Theme.button({
			Text = t[2],
			Color = C.cardDark,
			Size = UDim2.fromOffset(170, 42),
			LayoutOrder = i,
			maxSize = 20,
			Parent = tabsBar,
			onClick = function()
				Sounds.play("click")
				show(t[1])
			end,
		})
	end

	-- Passes
	local passes = page("passes")
	local passButtons = {}
	for i, p in ipairs(Products.Passes) do
		if p.id ~= 0 then
			local c = card(passes, i, p.icon, p.name, p.desc, C.purple)
			local b, label = priceButton(c, p.price, function()
				MarketplaceService:PromptGamePassPurchase(player, p.id)
			end)
			passButtons[p.key] = { button = b, label = label }
		end
	end
	local function refreshPasses()
		for key, pb in pairs(passButtons) do
			if player:GetAttribute("Pass_" .. key) then
				pb.label.Text = "OWNED"
				Theme.setButtonColor(pb.button, C.grey)
				pb.button.Active = false
			end
		end
	end
	player.AttributeChanged:Connect(function(attr)
		if attr:sub(1, 5) == "Pass_" then
			refreshPasses()
		end
	end)

	-- Coins (amounts scale with progress)
	local coins = page("coins")
	local coinLabels = {}
	for i, p in ipairs(Products.Dev) do
		if p.kind == "coins" and p.id ~= 0 then
			local c, descLabel = card(coins, i, p.icon, p.name, "", C.gold)
			coinLabels[p.key] = descLabel
			priceButton(c, p.price, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	-- Boosts
	local boosts = page("boosts")
	local boostDescs = {
		Restock = "Instantly reroll your Seed & Gear shop stock.",
		GrowAll = "Every plant in your garden finishes growing - right now!",
		LuckPotion = "2x Golden & Rainbow gem chance for 30 minutes.",
	}
	for i, key in ipairs({ "GrowAll", "LuckPotion", "Restock" }) do
		local p = Products.DevByKey[key]
		if p and p.id ~= 0 then
			local c = card(boosts, i, p.icon, p.name, boostDescs[key], C.blue)
			priceButton(c, p.price, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	-- Weather
	local weather = page("weather")
	for i, w in ipairs(Weather.List) do
		local p = Products.DevByKey["Weather_" .. w.id]
		if p and p.id ~= 0 then
			local c = card(weather, i, w.icon, w.name, w.blurb .. " (whole server!)", w.color)
			priceButton(c, w.robux, function()
				MarketplaceService:PromptProductPurchase(player, p.id)
			end)
		end
	end

	local anything = false
	for _, pg in pairs(pages) do
		for _, ch in ipairs(pg:GetChildren()) do
			if ch:IsA("Frame") then
				anything = true
			end
		end
	end
	if not anything then
		Theme.text({ Text = "✨ The Gem Store opens very soon! ✨", Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), maxSize = 30, Parent = body })
		tabsBar.Visible = false
	end

	Root.WindowChanged:Connect(function(name)
		if name ~= "store" then
			return
		end
		refreshPasses()
		task.spawn(function()
			local amounts = Net.func("CoinPackAmounts"):InvokeServer()
			for key, lbl in pairs(coinLabels) do
				if lbl and amounts and amounts[key] then
					lbl.Text = "$" .. Format.short(amounts[key]) .. " coins"
					lbl.TextColor3 = C.gold
				end
			end
		end)
	end)
	show("passes")
end

function StorePanel.openTab(_tab: string)
	Root.open("store")
end

return StorePanel
