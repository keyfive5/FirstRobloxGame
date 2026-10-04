-- Daily quests window.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Quests)
local Rewards = require(Shared.Rewards)
local Gear = require(Shared.Gear)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Theme)
local Root = require(script.Parent.Root)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.Parent.State)
local Sounds = require(script.Parent.Parent.Sounds)

local QuestPanel = {}
local C = Theme.C
local new = Theme.new

local function rewardText(spec): string
	local parts = {}
	local coins = Rewards.coins(spec, State.data.stats and State.data.stats.topPrice or 10)
	if coins > 0 then
		table.insert(parts, "$" .. Format.short(coins))
	end
	for id, n in pairs(spec.gear or {}) do
		local g = Gear.get(id)
		table.insert(parts, string.format("%s x%d", g and g.icon or "", n))
	end
	if spec.luckMinutes then
		table.insert(parts, string.format("🍀 %dm luck", spec.luckMinutes))
	end
	return table.concat(parts, "  ")
end

function QuestPanel.start()
	local win = Root.window({ name = "quests", title = "📜 DAILY QUESTS", accent = C.orange, width = 720, height = 470 })
	local body = win.body
	local rows = {}
	local difficulty = { "EASY", "MEDIUM", "HARD" }
	local diffColor = { C.green, C.blue, C.purple }
	for i = 1, 3 do
		local row = Theme.card({ Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, (i - 1) * 100), Color = Color3.new(1, 1, 1), Gradient = { Theme.darken(diffColor[i], 0.35), Theme.darken(diffColor[i], 0.65), 0 }, StrokeColor = Theme.darken(diffColor[i], 0.75), Parent = body })
		Theme.text({ Text = difficulty[i], Size = UDim2.fromOffset(110, 20), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.lighten(diffColor[i], 0.4), maxSize = 16, Parent = row })
		local title = Theme.text({ Text = "", Size = UDim2.new(1, -220, 0, 28), Position = UDim2.fromOffset(14, 28), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 24, Parent = row })
		local barBg = Theme.card({ Size = UDim2.new(1, -220, 0, 18), Position = UDim2.fromOffset(14, 62), Color = Color3.fromRGB(25, 18, 45), StrokeThickness = 2, Radius = 9, Parent = row })
		local bar = Theme.card({ Size = UDim2.fromScale(0, 1), Color = C.gold, Stroke = false, Radius = 9, Parent = barBg })
		local barText = Theme.text({ Text = "", Size = UDim2.fromScale(1, 1), maxSize = 14, strokeThickness = 1.5, ZIndex = 3, Parent = barBg })
		local reward = Theme.text({ Text = "", Size = UDim2.fromOffset(190, 22), Position = UDim2.new(1, -200, 0, 8), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.gold, maxSize = 16, Parent = row })
		local btn, label = Theme.button({ Text = "CLAIM", Color = C.grey, Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -12, 1, -10), AnchorPoint = Vector2.new(1, 1), Font = Theme.TitleFont, maxSize = 20, Parent = row })
		btn.Activated:Connect(function()
			if Net.func("ClaimQuest"):InvokeServer(i) then
				Sounds.play("stinger")
			end
		end)
		rows[i] = { title = title, bar = bar, barText = barText, reward = reward, btn = btn, label = label }
	end
	local bonus = Theme.card({ Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 306), Color = Color3.new(1, 1, 1), Gradient = { C.gold, Theme.darken(C.gold, 0.45), 0 }, StrokeColor = Color3.fromRGB(110, 60, 10), Parent = body })
	local bonusText = Theme.text({ Text = "", Size = UDim2.new(1, -200, 1, -12), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, maxSize = 20, Parent = bonus })
	local bonusBtn, bonusLabel = Theme.button({ Text = "CLAIM", Color = C.grey, Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Font = Theme.TitleFont, maxSize = 20, Parent = bonus })
	bonusBtn.Activated:Connect(function()
		if Net.func("ClaimQuestBonus"):InvokeServer() then
			Sounds.play("stinger")
		end
	end)

	local function refresh()
		local q = State.data.quests
		if not q or not q.list then
			return
		end
		local claimable, allClaimed = 0, true
		for i, row in ipairs(rows) do
			local e = q.list[i]
			local def = e and Quests.ById[e.id]
			if def then
				local targetText = def.event == "sellValue" and Format.short(e.target) or tostring(e.target)
				row.title.Text = string.format(def.text, targetText)
				local frac = math.clamp(e.p / math.max(e.target, 1), 0, 1)
				row.bar.Size = UDim2.fromScale(frac, 1)
				row.barText.Text = (def.event == "sellValue" and Format.short(e.p) or tostring(e.p)) .. " / " .. targetText
				row.reward.Text = rewardText(Quests.Rewards[i])
				if e.c then
					row.label.Text = "DONE ✓"
					Theme.setButtonColor(row.btn, C.grey)
				elseif e.p >= e.target then
					row.label.Text = "CLAIM!"
					Theme.setButtonColor(row.btn, C.green)
					claimable += 1
				else
					row.label.Text = "CLAIM"
					Theme.setButtonColor(row.btn, C.cardDark)
				end
				if not e.c then
					allClaimed = false
				end
			end
		end
		bonusText.Text = "🏆 Finish all 3 quests: " .. rewardText(Quests.Bonus)
		if q.bonus then
			bonusLabel.Text = "DONE ✓"
			Theme.setButtonColor(bonusBtn, C.grey)
		elseif allClaimed then
			bonusLabel.Text = "CLAIM!"
			Theme.setButtonColor(bonusBtn, C.green)
			claimable += 1
		else
			bonusLabel.Text = "LOCKED"
			Theme.setButtonColor(bonusBtn, C.cardDark)
		end
		HUD.setBadge("Quests", claimable > 0 and tostring(claimable) or nil)
	end
	State.onChange("quests", refresh)
	State.onChange("stats", refresh)
	State.whenLoaded(refresh)
	task.spawn(function()
		while true do
			if Root.isOpen("quests") then
				local left = (Quests.day() + 1) * 86400 - os.time()
				win.subtitle.Text = "New quests in " .. Format.duration(left)
			end
			task.wait(1)
		end
	end)
end

return QuestPanel
