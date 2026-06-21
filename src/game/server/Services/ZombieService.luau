--!strict
--[[
	ZombieService.luau
	Spawns and drives the zombie horde (server-authoritative). Zombies are server-
	owned Humanoid models in Workspace, so their movement auto-replicates to clients
	with no per-frame remotes. Difficulty (health/speed/count/cap) comes from
	ZombieConfig. Each zombie runs a throttled, staggered pathfinding chase.

	Public API:
		ZombieService.init()                       -- build template (yields once)
		ZombieService.spawn(round)        -> Model? -- one zombie (nil if at cap)
		ZombieService.spawnWave(count, round)       -- spawn up to `count`, staggered
		ZombieService.damageZombie(model, amount, killer?)  -- server-auth damage + points
		ZombieService.getAliveCount()     -> number
		ZombieService.despawnAll()
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local Trove = require(ReplicatedStorage.Shared.Util.Trove)
local ArenaService = require(script.Parent.ArenaService)
local SessionService = require(script.Parent.SessionService)

local ZOMBIE_COLOR = Color3.fromRGB(72, 92, 58)
local SPAWN_HEIGHT_OFFSET = 3 -- lift above the node so the rig settles onto the floor
local DEATH_LINGER = 1.5 -- seconds a corpse remains before cleanup

local AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 6,
}

local ZombieService = {}

local template: Model? = nil
local zombiesFolder: Folder? = nil
local alive: { [Model]: Trove.Trove } = {}
local aliveCount = 0

-- ---- helpers --------------------------------------------------------------

local function ensureZombiesFolder(): Folder
	if zombiesFolder and zombiesFolder.Parent then
		return zombiesFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = Workspace
	zombiesFolder = folder
	return folder
end

local function getHumanoid(model: Model): Humanoid?
	local h = model:FindFirstChildOfClass("Humanoid")
	return h :: Humanoid?
end

local function getRoot(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return r :: BasePart?
end

-- Nearest alive player's root + humanoid to a world position.
local function findNearestTarget(fromPos: Vector3): (BasePart?, Humanoid?)
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestDist = math.huge

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root and hum.Health > 0 then
			local dist = (root.Position - fromPos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestRoot = root
				bestHum = hum
			end
		end
	end

	return bestRoot, bestHum
end

-- ---- template -------------------------------------------------------------

local function createTemplate(): Model
	local desc = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
	model.Name = "Zombie"

	local root = getRoot(model)
	if root then
		model.PrimaryPart = root
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = Constants.CollisionGroups.Zombies
			part.Color = ZOMBIE_COLOR
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	local humanoid = getHumanoid(model)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = true
	end

	model.Parent = ServerStorage
	return model
end

-- ---- AI -------------------------------------------------------------------

local function runAi(model: Model, humanoid: Humanoid, root: BasePart, path: Path)
	-- Stagger so 24 zombies don't all recompute on the same frame.
	task.wait(math.random() * ZombieConfig.REPATH_INTERVAL)

	local lastAttack = 0

	while model.Parent and humanoid.Health > 0 do
		local targetRoot, targetHum = findNearestTarget(root.Position)

		if targetRoot and targetHum then
			local dist = (targetRoot.Position - root.Position).Magnitude

			if dist <= ZombieConfig.ATTACK_RANGE then
				humanoid:Move(Vector3.zero) -- stop and strike
				local now = os.clock()
				if now - lastAttack >= ZombieConfig.ATTACK_COOLDOWN then
					lastAttack = now
					targetHum:TakeDamage(ZombieConfig.CONTACT_DAMAGE)
				end
			else
				local ok = pcall(function()
					path:ComputeAsync(root.Position, targetRoot.Position)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					local waypoints = path:GetWaypoints()
					-- waypoints[1] is the current position; step toward the next.
					local nextPoint = waypoints[2] or waypoints[1]
					if nextPoint then
						humanoid:MoveTo(nextPoint.Position)
					end
				else
					-- Open ground / no grid path: walk straight at the target.
					humanoid:MoveTo(targetRoot.Position)
				end
			end
		end

		task.wait(ZombieConfig.REPATH_INTERVAL)
	end
end

-- ---- lifecycle ------------------------------------------------------------

local function onZombieDied(model: Model)
	local trove = alive[model]
	if not trove then
		return
	end
	alive[model] = nil
	aliveCount -= 1
	CollectionService:RemoveTag(model, Constants.Tags.Zombie)
	trove:Clean()
	task.delay(DEATH_LINGER, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function ZombieService.init()
	if not template then
		template = createTemplate()
	end
	ensureZombiesFolder()
	print("[ZombieService] Initialized")
end

function ZombieService.spawn(round: number): Model?
	local tmpl = template
	if not tmpl then
		warn("[ZombieService] spawn before init")
		return nil
	end
	if aliveCount >= ZombieConfig.MAX_CONCURRENT then
		return nil
	end

	local nodes = ArenaService.getZombieSpawns()
	if #nodes == 0 then
		warn("[ZombieService] no zombie spawn nodes")
		return nil
	end

	local model = tmpl:Clone()
	local humanoid = getHumanoid(model)
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		return nil
	end

	humanoid.MaxHealth = ZombieConfig.getHealth(round)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = ZombieConfig.getWalkSpeed(round)

	local node = nodes[math.random(1, #nodes)]
	model:PivotTo(node.CFrame + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0))

	CollectionService:AddTag(model, Constants.Tags.Zombie)
	model.Parent = ensureZombiesFolder()

	-- Server authority over physics (anti-exploit + consistent simulation).
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local trove = Trove.new()
	alive[model] = trove
	aliveCount += 1

	local path = PathfindingService:CreatePath(AGENT_PARAMS)
	trove:Add(path)
	trove:Connect(humanoid.Died, function()
		onZombieDied(model)
	end)

	task.spawn(runAi, model, humanoid, root, path)
	return model
end

function ZombieService.spawnWave(count: number, round: number)
	task.spawn(function()
		for _ = 1, count do
			if aliveCount >= ZombieConfig.MAX_CONCURRENT then
				-- Wait for room under the concurrency cap.
				repeat
					task.wait(0.2)
				until aliveCount < ZombieConfig.MAX_CONCURRENT
			end
			ZombieService.spawn(round)
			task.wait(0.25) -- spacing so they don't pop in on one frame
		end
	end)
end

function ZombieService.damageZombie(model: Model, amount: number, killer: Player?)
	local humanoid = getHumanoid(model)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:TakeDamage(amount)

	if killer then
		SessionService.addPoints(killer, ZombieConfig.POINTS_PER_HIT)
		if humanoid.Health <= 0 then
			SessionService.addPoints(killer, ZombieConfig.POINTS_PER_KILL)
			SessionService.addKill(killer)
		end
	end
end

function ZombieService.getAliveCount(): number
	return aliveCount
end

function ZombieService.despawnAll()
	for model, trove in alive do
		trove:Clean()
		CollectionService:RemoveTag(model, Constants.Tags.Zombie)
		model:Destroy()
	end
	table.clear(alive)
	aliveCount = 0
end

return ZombieService
