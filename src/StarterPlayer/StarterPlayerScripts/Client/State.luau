-- Client-side mirror of the player's save (pushed by the server's Sync module).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local State = {
	data = {
		coins = 0, seeds = {}, gear = {}, bag = {}, stats = { earned = 0, topPrice = 10 },
		stock = { seeds = {}, gear = {} }, daily = {}, tutorial = 0, boosts = {}, settings = { music = 0.25, sfx = 0.6 }, discovered = {},
	},
	loaded = false,
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- (key)
local loadedEvent = Instance.new("BindableEvent")
State.Loaded = loadedEvent.Event

local function fire(key: string)
	changed:Fire(key)
end

function State.get(key: string)
	return State.data[key]
end

function State.onChange(key: string, fn)
	return State.Changed:Connect(function(k)
		if k == key then
			fn(State.data[key])
		end
	end)
end

-- Run fn now if data already arrived, and again on every future full snapshot.
function State.whenLoaded(fn)
	if State.loaded then
		task.spawn(fn)
	end
	return State.Loaded:Connect(fn)
end

function State.waitLoaded()
	while not State.loaded do
		State.Loaded:Wait()
	end
end

function State.start()
	Net.event("State").OnClientEvent:Connect(function(kind, a, b)
		if kind == "full" then
			for k, v in pairs(a) do
				State.data[k] = v
			end
			State.loaded = true
			for k in pairs(a) do
				fire(k)
			end
			loadedEvent:Fire()
		elseif kind == "set" then
			State.data[a] = b
			fire(a)
		elseif kind == "bagAdd" then
			table.insert(State.data.bag, a)
			fire("bag")
			changed:Fire("bagAdd", a)
		elseif kind == "bagRemove" then
			local remove = {}
			for _, id in ipairs(a) do
				remove[id] = true
			end
			local keep = {}
			for _, g in ipairs(State.data.bag) do
				if not remove[g.id] then
					table.insert(keep, g)
				end
			end
			State.data.bag = keep
			fire("bag")
		elseif kind == "bagUpdate" then
			for i, g in ipairs(State.data.bag) do
				if g.id == a.id then
					State.data.bag[i] = a
				end
			end
			fire("bag")
		end
	end)
end

return State
