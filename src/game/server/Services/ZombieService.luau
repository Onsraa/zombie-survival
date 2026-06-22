--!strict
--[[
	ZombieService.luau
	Spawns and drives the zombie horde (server-authoritative). Zombies are server-
	owned models in Workspace, so their movement auto-replicates to clients with no
	per-frame remotes. Difficulty (health/speed/count/cap) comes from ZombieConfig.
	Each zombie runs a throttled, staggered pathfinding chase and is paired with a
	ZombieController (animations + gore; legs blow off via explode() → crawl).

	Template: cloned from ReplicatedStorage.Assets.Models.Zombie (themed, Motor6D rig).

	Public API:
		ZombieService.init()                       -- prepare template + folder
		ZombieService.spawn(round)        -> Model? -- one zombie (nil if at cap)
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
local ZombieControllerModule = require(script.Parent.ZombieController)
local CombatModifiers = require(script.Parent.CombatModifiers)
local PlayerState = require(script.Parent.PlayerState)

local ZombieController = ZombieControllerModule.ZombieController
type Controller = ZombieControllerModule.ZombieController

local SPAWN_HEIGHT_OFFSET = 3 -- lift above the node so the rig settles onto the floor
local DEATH_LINGER = 1.5 -- seconds a corpse remains before cleanup
local RUN_ANIM_THRESHOLD = 16 -- WalkSpeed at/above which the run animation plays

local AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 6,
}

type ZombieRecord = {
	trove: Trove.Trove,
	controller: Controller,
}

local ZombieService = {}

local template: Model? = nil
local zombiesFolder: Folder? = nil
local alive: { [Model]: ZombieRecord } = {}
local aliveCount = 0
local killListener: ((position: Vector3, killer: Player?) -> ())? = nil
local playerDamageHandler: ((humanoid: Humanoid, amount: number) -> ())? = nil

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
	return model:FindFirstChildOfClass("Humanoid")
end

local function getRoot(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function findNearestTarget(fromPos: Vector3): (BasePart?, Humanoid?)
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestDist = math.huge

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		if PlayerState.isDowned(player) then
			continue -- zombies ignore downed players (they go for whoever's still up)
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
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

local function createTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local source = models and models:FindFirstChild("Zombie")
	if not source or not source:IsA("Model") then
		warn("[ZombieService] ReplicatedStorage.Assets.Models.Zombie not found")
		return nil
	end

	local model = source:Clone()
	model.Name = "Zombie"

	local root = getRoot(model)
	if root then
		model.PrimaryPart = root
	end

	-- Keep the themed art; only assign the collision group (zombies don't collide
	-- with each other — the mobile-perf win).
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = Constants.CollisionGroups.Zombies
		end
	end

	local humanoid = getHumanoid(model)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- ZombieController.Collapse owns the death (immediate + readable), not the default
		-- gravity flop — so the kill never reads as a ~0.2s ambiguous delay.
		humanoid.BreakJointsOnDeath = false
	end

	model.Parent = ServerStorage
	return model
end

-- ---- AI -------------------------------------------------------------------

local function runAi(model: Model, humanoid: Humanoid, root: BasePart, path: Path, controller: Controller)
	-- Stagger so the horde doesn't recompute paths on the same frame.
	task.wait(math.random() * ZombieConfig.REPATH_INTERVAL)

	local lastAttack = 0

	while model.Parent and humanoid.Health > 0 do
		local targetRoot, targetHum = findNearestTarget(root.Position)

		if targetRoot and targetHum then
			local dist = (targetRoot.Position - root.Position).Magnitude

			if dist <= ZombieConfig.ATTACK_RANGE then
				humanoid:Move(Vector3.zero)
				controller:Attack()
				local now = os.clock()
				if now - lastAttack >= ZombieConfig.ATTACK_COOLDOWN then
					lastAttack = now
					if playerDamageHandler then
						playerDamageHandler(targetHum, ZombieConfig.CONTACT_DAMAGE)
					else
						targetHum:TakeDamage(ZombieConfig.CONTACT_DAMAGE)
					end
				end
			else
				if humanoid.WalkSpeed >= RUN_ANIM_THRESHOLD then
					controller:Run()
				else
					controller:Walk()
				end

				local ok = pcall(function()
					path:ComputeAsync(root.Position, targetRoot.Position)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					local waypoints = path:GetWaypoints()
					local nextPoint = waypoints[2] or waypoints[1]
					if nextPoint then
						humanoid:MoveTo(nextPoint.Position)
					end
				else
					humanoid:MoveTo(targetRoot.Position)
				end
			end
		end

		task.wait(ZombieConfig.REPATH_INTERVAL)
	end
end

-- ---- lifecycle ------------------------------------------------------------

local function onZombieDied(model: Model)
	local record = alive[model]
	if not record then
		return
	end
	alive[model] = nil
	aliveCount -= 1
	CollectionService:RemoveTag(model, Constants.Tags.Zombie)
	record.trove:Clean() -- disconnects path/Died and destroys the controller
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
	if template then
		print("[ZombieService] Initialized")
	else
		warn("[ZombieService] Initialized without a template")
	end
end

function ZombieService.spawn(round: number): Model?
	local tmpl = template
	if not tmpl then
		warn("[ZombieService] spawn before init / missing template")
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

	local controller = ZombieController.new(model)
	local trove = Trove.new()
	local path = PathfindingService:CreatePath(AGENT_PARAMS)
	trove:Add(path)
	trove:Connect(humanoid.Died, function()
		onZombieDied(model)
	end)
	trove:Add(function()
		controller:Destroy()
	end)

	alive[model] = { trove = trove, controller = controller }
	aliveCount += 1

	task.spawn(runAi, model, humanoid, root, path, controller)
	return model
end

function ZombieService.damageZombie(model: Model, amount: number, killer: Player?)
	local humanoid = getHumanoid(model)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if CombatModifiers.isInstaKill() then
		amount = humanoid.MaxHealth -- Insta-Kill power-up: any hit is lethal
	end
	humanoid:TakeDamage(amount)

	if killer then
		local mult = CombatModifiers.getPointsMultiplier() -- Double Points power-up
		SessionService.addPoints(killer, ZombieConfig.POINTS_PER_HIT * mult)
		if humanoid.Health <= 0 then
			SessionService.addPoints(killer, ZombieConfig.POINTS_PER_KILL * mult)
			SessionService.addKill(killer)
		end
	end

	if humanoid.Health <= 0 and killListener then
		local root = getRoot(model)
		killListener(if root then root.Position else Vector3.zero, killer)
	end
end

-- AoE blast (grenades / Ray Gun ground shots): blow the legs off (→ crawl) and
-- damage every living zombie within `radius` of `position`. The leg gore comes from
-- the impact zone, not a health threshold. Returns how many were hit (HUD marker).
function ZombieService.explode(position: Vector3, radius: number, damage: number, killer: Player?): number
	local count = 0
	for model, record in alive do
		local root = getRoot(model)
		local humanoid = getHumanoid(model)
		if root and humanoid and humanoid.Health > 0 and (root.Position - position).Magnitude <= radius then
			record.controller:DetachLegs()
			ZombieService.damageZombie(model, damage, killer)
			count += 1
		end
	end
	return count
end

-- Register a single listener fired when a zombie dies (position, killer?). Lets
-- PowerUpService roll drops without ZombieService having to depend on it.
function ZombieService.setKillListener(fn: (position: Vector3, killer: Player?) -> ())
	killListener = fn
end

-- Route zombie melee through this (DownService) so a fatal hit downs the player instead
-- of killing them. Falls back to direct TakeDamage if unset.
function ZombieService.setPlayerDamageHandler(fn: (humanoid: Humanoid, amount: number) -> ())
	playerDamageHandler = fn
end

-- Kill every alive zombie at once (Nuke power-up). Bypasses points + the kill listener;
-- the caller awards the flat nuke bonus. Snapshots keys first (death mutates `alive`).
function ZombieService.nukeKill()
	local models: { Model } = {}
	for model in alive do
		table.insert(models, model)
	end
	for _, model in models do
		local humanoid = getHumanoid(model)
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(humanoid.MaxHealth)
		end
	end
end

function ZombieService.getAliveCount(): number
	return aliveCount
end

function ZombieService.despawnAll()
	for model, record in alive do
		record.trove:Clean()
		CollectionService:RemoveTag(model, Constants.Tags.Zombie)
		model:Destroy()
	end
	table.clear(alive)
	aliveCount = 0
end

return ZombieService
