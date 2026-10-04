-- Join flow: leaderstats, garden assignment, first state push, friend boost
-- detection, and spawning players at their own garden gate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Sync)
local ShopService = require(script.Parent.ShopService)

local PlayerService = {}

local function toGarden(player: Player)
	local cf = GardenService.spawnCFrame(player)
	local char = player.Character
	if cf and char then
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			char:PivotTo(cf + Vector3.new(0, 2.5, 0))
		end
	end
end

local function linkFriends(player: Player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend and player.Parent and other.Parent then
					player:SetAttribute("Friend_" .. other.UserId, true)
					other:SetAttribute("Friend_" .. player.UserId, true)
				end
			end)
		end
	end
end

local function onLoaded(player: Player, profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = Format.short(profile.data.coins)
	coins.Parent = ls
	ls.Parent = player

	local plot = GardenService.assign(player)
	if not plot then
		player:Kick("This server's gardens are all taken - please join another server!")
		return
	end
	ShopService.refresh(player)
	Sync.full(player, profile.data)
	linkFriends(player)
	if player.Character then
		task.spawn(toGarden, player)
	end
end

function PlayerService.start()
	DataService.Loaded:Connect(onLoaded)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			if GardenService.plotOf(player) then
				task.wait(0.1)
				toGarden(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, other in ipairs(Players:GetPlayers()) do
			other:SetAttribute("Friend_" .. player.UserId, nil)
		end
	end)
end

PlayerService.toGarden = toGarden
return PlayerService
