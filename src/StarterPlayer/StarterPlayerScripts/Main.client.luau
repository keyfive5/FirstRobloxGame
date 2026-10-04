-- Client bootstrap.
local Client = script.Parent:WaitForChild("Client")
local UI = Client:WaitForChild("UI")

local State = require(Client.State)
State.start()

local modules = {
	Client.Sounds,
	UI.Notify,
	UI.HUD,
	UI.ShopPanel,
	UI.BagPanel,
	UI.StorePanel,
	UI.MiscPanels,
	Client.GardenRenderer,
	Client.ToolController,
	Client.WeatherFX,
	Client.Interactions,
	Client.Tutorial,
}
for _, m in ipairs(modules) do
	task.spawn(function()
		local ok, err = pcall(function()
			require(m).start()
		end)
		if not ok then
			warn("[Client] " .. m.Name .. " failed: " .. tostring(err))
		end
	end)
end
