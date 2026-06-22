--!strict
--[[
	BarrierService.luau
	Boarded windows on the arena perimeter. A newly spawned zombie is assigned to a barrier
	and must tear off its planks (held there, playing the remove-planks animation) before it
	can chase; players hold a prompt to re-board planks for points. The Carpenter power-up
	re-boards every barrier at once.

	MVP note: the barrier is a LOGICAL gate at the spawn point — it gates the zombie's chase
	(the breach phase in ZombieService) and drives the repair loop. Planks are visual
	(non-colliding), so it does not cut a physical hole in the sealed arena wall.

	Public API:
		BarrierService.build()
		BarrierService.getBarrierCount() -> number
		BarrierService.getPosition(id)   -> Vector3?
		BarrierService.tearPlank(id)     -> boolean   (zombie removed a plank)
		BarrierService.repairOne(id, p?) -> boolean   (player re-boarded a plank; awards points)
		BarrierService.isBreached(id)    -> boolean
		BarrierService.repairAll()                    (Carpenter power-up)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local SessionService = require(script.Parent.SessionService)

local BARRIER_COUNT = 6
local PLANKS_PER_BARRIER = 6
local REPAIR_POINTS = 10
local PERIMETER_INSET = 6
local PLANK_HOLD = 0.5 -- seconds to re-board one plank
local REPAIR_DISTANCE = 14 -- server anti-exploit re-check

local FRAME_COLOR = Color3.fromRGB(40, 30, 22)
local PLANK_COLOR = Color3.fromRGB(120, 85, 45)

type Barrier = {
	id: number,
	position: Vector3,
	planks: number,
	plankParts: { BasePart },
	prompt: ProximityPrompt,
}

local BarrierService = {}

local barriers: { Barrier } = {}

local function updatePrompt(barrier: Barrier)
	barrier.prompt.Enabled = barrier.planks < PLANKS_PER_BARRIER
end

function BarrierService.tearPlank(id: number): boolean
	local barrier = barriers[id]
	if not barrier or barrier.planks <= 0 then
		return false
	end
	local part = barrier.plankParts[barrier.planks]
	if part then
		part.Transparency = 1
	end
	barrier.planks -= 1
	updatePrompt(barrier)
	return true
end

function BarrierService.repairOne(id: number, player: Player?): boolean
	local barrier = barriers[id]
	if not barrier or barrier.planks >= PLANKS_PER_BARRIER then
		return false
	end
	barrier.planks += 1
	local part = barrier.plankParts[barrier.planks]
	if part then
		part.Transparency = 0
	end
	updatePrompt(barrier)
	if player then
		SessionService.addPoints(player, REPAIR_POINTS)
	end
	return true
end

function BarrierService.isBreached(id: number): boolean
	local barrier = barriers[id]
	return barrier ~= nil and barrier.planks <= 0
end

function BarrierService.getBarrierCount(): number
	return #barriers
end

function BarrierService.getPosition(id: number): Vector3?
	local barrier = barriers[id]
	return barrier and barrier.position
end

function BarrierService.repairAll()
	for _, barrier in barriers do
		while barrier.planks < PLANKS_PER_BARRIER do
			BarrierService.repairOne(barrier.id, nil)
		end
	end
end

local function ringPosition(index: number, count: number, radius: number, y: number): Vector3
	local angle = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function buildBarrier(id: number, position: Vector3): Barrier
	local model = Instance.new("Model")
	model.Name = "Barrier" .. id

	local facing = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))

	local function post(offsetX: number)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(0.6, 8, 0.6)
		p.CFrame = facing * CFrame.new(offsetX, 0, 0)
		p.Color = FRAME_COLOR
		p.Material = Enum.Material.Wood
		p.Parent = model
	end
	post(-3.5)
	post(3.5)

	local plankParts: { BasePart } = {}
	for i = 1, PLANKS_PER_BARRIER do
		local plank = Instance.new("Part")
		plank.Name = "Plank" .. i
		plank.Anchored = true
		plank.CanCollide = false -- visual gate; the breach phase (AI) is the real gate
		plank.Size = Vector3.new(8, 0.8, 0.5)
		plank.CFrame = facing * CFrame.new(0, -3 + (i - 1) * 1.2, 0)
		plank.Color = PLANK_COLOR
		plank.Material = Enum.Material.WoodPlanks
		plank.Parent = model
		plankParts[i] = plank
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Window"
	prompt.ActionText = `Repair [+{REPAIR_POINTS}]`
	prompt.HoldDuration = PLANK_HOLD
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- only when a plank is missing
	prompt.Parent = plankParts[1]
	prompt.Triggered:Connect(function(player: Player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= REPAIR_DISTANCE then
			BarrierService.repairOne(id, player)
		end
	end)

	model.Parent = Workspace:FindFirstChild("Arena") or Workspace

	return {
		id = id,
		position = position,
		planks = PLANKS_PER_BARRIER,
		plankParts = plankParts,
		prompt = prompt,
	}
end

function BarrierService.build()
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		for _, child in arena:GetChildren() do
			if string.match(child.Name, "^Barrier%d+$") then
				child:Destroy()
			end
		end
	end
	table.clear(barriers)

	local radius = ArenaConfig.FLOOR_SIZE / 2 - ArenaConfig.WALL_THICKNESS - PERIMETER_INSET
	local y = ArenaConfig.FLOOR_Y + 4
	for i = 1, BARRIER_COUNT do
		barriers[i] = buildBarrier(i, ringPosition(i, BARRIER_COUNT, radius, y))
	end
	print(`[BarrierService] {BARRIER_COUNT} barriers built ({PLANKS_PER_BARRIER} planks each)`)
end

return BarrierService
