--!strict
--[[
	ArenaConfig.luau
	Dimensions and counts for the code-built greybox arena. PURE data (no Roblox
	APIs) so it is Lune-testable. Visual styling (colors/materials) lives in
	ArenaService; only layout numbers live here (no magic numbers in the builder).
	Studs unless noted.
]]

local ArenaConfig = {}

-- Floor (square)
ArenaConfig.FLOOR_SIZE = 200
ArenaConfig.FLOOR_THICKNESS = 1
ArenaConfig.FLOOR_Y = 0 -- height of the walkable top surface

-- Perimeter walls
ArenaConfig.WALL_HEIGHT = 30
ArenaConfig.WALL_THICKNESS = 4

-- Player spawns: arranged on a small ring near the center
ArenaConfig.PLAYER_SPAWN_COUNT = 4
ArenaConfig.PLAYER_SPAWN_RADIUS = 12
ArenaConfig.PLAYER_SPAWN_HEIGHT = 3 -- above the floor surface

-- Zombie spawn nodes: arranged around the inside of the perimeter
ArenaConfig.ZOMBIE_NODE_COUNT = 12
ArenaConfig.ZOMBIE_NODE_INSET = 10 -- distance inside the wall
ArenaConfig.ZOMBIE_NODE_HEIGHT = 3 -- above the floor surface

return ArenaConfig
