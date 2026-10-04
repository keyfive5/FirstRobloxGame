-- Gem value math shared by server (authoritative) and client (display).
-- A gem record is { s = speciesId, w = size, m = { mutationIds } }.
local Shared = script.Parent.Parent
local Species = require(Shared.Species)
local Mutations = require(Shared.Mutations)

local Value = {}

function Value.base(gem): number
	local sp = Species.get(gem.s)
	if not sp then
		return 0
	end
	local w = gem.w or 1
	return sp.value * w * w * Mutations.multiplier(gem.m)
end

function Value.carat(gem): number
	local sp = Species.get(gem.s)
	return (sp and sp.carat or 1) * (gem.w or 1)
end

-- Display name like "Golden Frozen Ruby Rose".
function Value.label(gem): string
	local sp = Species.get(gem.s)
	local name = sp and sp.name or "Gem"
	local muts = Mutations.sorted(gem.m)
	if #muts > 0 then
		return table.concat(muts, " ") .. " " .. name
	end
	return name
end

function Value.isHuge(gem): boolean
	return (gem.w or 1) >= 2
end

return Value
