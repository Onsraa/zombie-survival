--!strict
--[[
	ArenaService.luau
	Builds the code-built greybox arena at runtime (floor, perimeter walls, player
	spawns, perimeter zombie-spawn nodes) and registers collision groups. Keeping
	the arena in code means it is version-controlled and reproducible; a Studio-
	authored map can replace it later by swapping this builder for a cloned model.

	Public API:
		ArenaService.build()            -> Model     (idempotent; rebuilds)
		ArenaService.getZombieSpawns()  -> { BasePart }
		ArenaService.getPlayerSpawns()  -> { BasePart }
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)

local ARENA_MODEL_NAME = "Arena"

-- Greybox styling (kept out of ArenaConfig so config stays pure data).
local FLOOR_COLOR = Color3.fromRGB(56, 56, 60)
local WALL_COLOR = Color3.fromRGB(38, 38, 42)
local SPAWN_COLOR = Color3.fromRGB(60, 130, 90)

local ArenaService = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Register collision groups idempotently (RegisterCollisionGroup throws on dupes,
-- CollisionGroupSetCollidable throws on unregistered — guard both).
local function registerCollisionGroups()
	local zombies = Constants.CollisionGroups.Zombies
	local characters = Constants.CollisionGroups.Characters

	for _, name in { zombies, characters } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end

	-- Zombies never collide with each other: avoids horde clumping/blocking and
	-- cuts physics cost massively (the key mobile-perf win for 24 concurrent NPCs).
	PhysicsService:CollisionGroupSetCollidable(zombies, zombies, false)
	-- Zombies do collide with players (contact-damage detection in ZombieService).
	PhysicsService:CollisionGroupSetCollidable(zombies, characters, true)
end

local function buildFloor(parent: Model)
	local size = Vector3.new(ArenaConfig.FLOOR_SIZE, ArenaConfig.FLOOR_THICKNESS, ArenaConfig.FLOOR_SIZE)
	local position = Vector3.new(0, ArenaConfig.FLOOR_Y - ArenaConfig.FLOOR_THICKNESS / 2, 0)
	local floor = makePart("Floor", size, position, FLOOR_COLOR)
	floor.Parent = parent
end

local function buildWalls(parent: Model)
	local half = ArenaConfig.FLOOR_SIZE / 2
	local thickness = ArenaConfig.WALL_THICKNESS
	local height = ArenaConfig.WALL_HEIGHT
	local y = ArenaConfig.FLOOR_Y + height / 2
	local span = ArenaConfig.FLOOR_SIZE + thickness * 2 -- overlap corners
	local offset = half + thickness / 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(span, height, thickness), pos = Vector3.new(0, y, -offset) },
		{ name = "WallSouth", size = Vector3.new(span, height, thickness), pos = Vector3.new(0, y, offset) },
		{ name = "WallEast", size = Vector3.new(thickness, height, span), pos = Vector3.new(offset, y, 0) },
		{ name = "WallWest", size = Vector3.new(thickness, height, span), pos = Vector3.new(-offset, y, 0) },
	}

	for _, w in walls do
		makePart(w.name, w.size, w.pos, WALL_COLOR).Parent = parent
	end
end

-- Evenly distribute `count` points on a ring of `radius` around the origin.
local function ringPosition(index: number, count: number, radius: number, y: number): Vector3
	local angle = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function buildPlayerSpawns(parent: Model)
	local folder = Instance.new("Folder")
	folder.Name = "PlayerSpawns"
	folder.Parent = parent

	local y = ArenaConfig.FLOOR_Y + ArenaConfig.PLAYER_SPAWN_HEIGHT
	for i = 1, ArenaConfig.PLAYER_SPAWN_COUNT do
		local pos = ringPosition(i, ArenaConfig.PLAYER_SPAWN_COUNT, ArenaConfig.PLAYER_SPAWN_RADIUS, y)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "PlayerSpawn" .. i
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = pos
		spawn.Color = SPAWN_COLOR
		spawn.Material = Enum.Material.Metal
		spawn.Neutral = true
		spawn.Duration = 0 -- no spawn forcefield
		CollectionService:AddTag(spawn, Constants.Tags.PlayerSpawn)
		spawn.Parent = folder
	end
end

local function buildZombieNodes(parent: Model)
	local folder = Instance.new("Folder")
	folder.Name = "ZombieSpawns"
	folder.Parent = parent

	local radius = ArenaConfig.FLOOR_SIZE / 2 - ArenaConfig.ZOMBIE_NODE_INSET
	local y = ArenaConfig.FLOOR_Y + ArenaConfig.ZOMBIE_NODE_HEIGHT
	for i = 1, ArenaConfig.ZOMBIE_NODE_COUNT do
		local pos = ringPosition(i, ArenaConfig.ZOMBIE_NODE_COUNT, radius, y)
		local node = Instance.new("Part")
		node.Name = "ZombieSpawn" .. i
		node.Anchored = true
		node.CanCollide = false
		node.CanQuery = false
		node.CanTouch = false
		node.Transparency = 1 -- invisible marker
		node.Size = Vector3.new(2, 2, 2)
		node.Position = pos
		CollectionService:AddTag(node, Constants.Tags.ZombieSpawn)
		node.Parent = folder
	end
end

function ArenaService.build(): Model
	registerCollisionGroups()

	local existing = Workspace:FindFirstChild(ARENA_MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = ARENA_MODEL_NAME

	buildFloor(arena)
	buildWalls(arena)
	buildPlayerSpawns(arena)
	buildZombieNodes(arena)

	arena.Parent = Workspace
	print(
		`[ArenaService] Arena built ({ArenaConfig.PLAYER_SPAWN_COUNT} player spawns, {ArenaConfig.ZOMBIE_NODE_COUNT} zombie nodes)`
	)
	return arena
end

local function getTaggedParts(tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
		end
	end
	return parts
end

function ArenaService.getZombieSpawns(): { BasePart }
	return getTaggedParts(Constants.Tags.ZombieSpawn)
end

function ArenaService.getPlayerSpawns(): { BasePart }
	return getTaggedParts(Constants.Tags.PlayerSpawn)
end

return ArenaService
