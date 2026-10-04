-- World interactions: shop prompts open their windows, shop billboards show
-- live info, and shop windows close when you walk away.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Root = require(script.Parent.UI.Root)
local Sounds = require(script.Parent.Sounds)

local Interactions = {}
local player = Players.LocalPlayer

local WINDOW_FOR = { seeds = "seeds", gear = "gear", sell = "sell", store = "store" }

function Interactions.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local shopId = prompt:GetAttribute("ShopId")
		if shopId and WINDOW_FOR[shopId] then
			Sounds.play("click")
			Root.open(WINDOW_FOR[shopId])
		end
	end)

	local shops = workspace:WaitForChild("World"):WaitForChild("Shops")
	task.spawn(function()
		while true do
			local left = Config.RestockInterval - (os.time() % Config.RestockInterval)
			for _, shop in ipairs(shops:GetChildren()) do
				local bb = shop:FindFirstChild("BillboardPart") and shop.BillboardPart:FindFirstChild("Info")
				local t = bb and bb:FindFirstChild("Text")
				if t then
					local id = shop.Name
					if id == "seeds" or id == "gear" then
						t.Text = "🔄 Restock in " .. Format.clock(left)
					elseif id == "sell" then
						t.Text = "💰 Sell your gems here!"
					elseif id == "store" then
						t.Text = "✨ Passes • Boosts • Weather"
					end
				end
			end
			-- auto-close shop windows when walking away
			local cur = Root.current()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if cur and hrp then
				for shopId, win in pairs(WINDOW_FOR) do
					if win == cur and (shopId ~= "sell" or not player:GetAttribute("Pass_SellAnywhere")) and shopId ~= "store" then
						local shop = shops:FindFirstChild(shopId)
						if shop and (hrp.Position - shop.PromptPart.Position).Magnitude > 30 then
							Root.close()
						end
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

return Interactions
