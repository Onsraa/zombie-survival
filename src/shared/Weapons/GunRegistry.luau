--!strict
--[[
	GunRegistry.luau
	Aggregates every gun definition from Guns/* into one lookup. Adding a gun = add an
	entry to the appropriate Guns/<Category>.luau file (or a new file required here).
]]

local Types = require(script.Parent.Types)

type GunDef = Types.GunDef

local gunsFolder = script.Parent.Guns
local sources = {
	require(gunsFolder.Handguns),
	require(gunsFolder.AssaultRifles),
	require(gunsFolder.SMGs),
	require(gunsFolder.Shotguns),
	require(gunsFolder.LMGs),
	require(gunsFolder.WonderWeapons),
}

local all: { [string]: GunDef } = {}
for _, source in sources do
	for id, def in source :: { [string]: GunDef } do
		all[id] = def
	end
end

local GunRegistry = {}

GunRegistry.STARTING_WEAPON = "m1911"

function GunRegistry.get(id: string): GunDef?
	return all[id]
end

function GunRegistry.getAll(): { [string]: GunDef }
	return all
end

function GunRegistry.getByCategory(category: string): { [string]: GunDef }
	local result: { [string]: GunDef } = {}
	for id, def in all do
		if def.category == category then
			result[id] = def
		end
	end
	return result
end

return GunRegistry
