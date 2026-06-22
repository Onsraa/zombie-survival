--!strict
--[[
	ZombieController.luau
	Per-zombie visual/state controller: animation playback (walk/run/crawl/attack/
	remove-planks), and gore: the head detaches near death (< 15% HP); the legs are
	blown off by explosions (ZombieService.explode -> :DetachLegs()), switching the
	zombie to crawling. Ragdolled parts pop off and clean up after a delay.

	Ported from the in-place prototype with two fixes:
	  - No yields at require time (SE-8): assets are resolved inside methods.
	  - Resilient animations: a real uploaded Animation is used if present; otherwise
	    the KeyframeSequence is registered for Studio-only preview. Everything is
	    pcall-guarded so a missing/unuploaded animation never breaks the zombie.

	Drive it from the server AI (ZombieService): :Walk()/:Run() while moving,
	:Attack() on a melee hit. The head detaches automatically near death; legs detach
	on explosion via :DetachLegs().

	ANIMATIONS: playback prefers uploaded AnimationIds from Config/ZombieAnimations; any
	id left blank falls back to the committed KeyframeSequence via KeyframeSequenceProvider
	(Studio preview only — won't play in a published game until the id is filled).
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieAnimations = require(ReplicatedStorage.Shared.Config.ZombieAnimations)

local STATE = {
	IDLE = "Idle",
	WALKING = "Walking",
	RUNNING = "Running",
	CRAWLING = "Crawling",
	ATTACK_STANDING = "AttackStanding",
	ATTACK_CRAWLING = "AttackCrawling",
	REMOVE_PLANKS = "RemovePlanks",
	DEAD = "Dead",
}

local HEAD_DETACH_THRESHOLD = 0.15
local PART_CLEANUP_DELAY = 5
local DEATH_SHOVE = 14 -- impulse so a ragdolled corpse visibly drops (the no-death-anim case)
-- The R6 rig joints to loosen for a death ragdoll (cosmetic welds are left intact).
-- "Root" is this rig's root joint; "RootJoint" is the stock-R6 name — cover both.
local R6_JOINT_NAMES = {
	Root = true,
	RootJoint = true,
	Neck = true,
	["Left Shoulder"] = true,
	["Right Shoulder"] = true,
	["Left Hip"] = true,
	["Right Hip"] = true,
}

local ZombieController = {}
ZombieController.__index = ZombieController

export type ZombieController = typeof(setmetatable(
	{} :: {
		Model: Model,
		Humanoid: Humanoid?,
		HumanoidRootPart: BasePart?,
		Head: BasePart?,
		LeftLeg: BasePart?,
		RightLeg: BasePart?,
		CurrentState: string,
		IsCrawling: boolean,
		HeadDetached: boolean,
		LegsDetached: boolean,
		Attacking: boolean,
		RemovingPlanks: boolean,
		Animations: { [string]: AnimationTrack },
		CurrentAnimationTrack: AnimationTrack?,
		NeckMotor: Motor6D?,
		LeftHipMotor: Motor6D?,
		RightHipMotor: Motor6D?,
		_connection: RBXScriptConnection?,
	},
	ZombieController
))

-- Map of state -> KeyframeSequence/Animation name under Assets.Animations.
local ANIM_NAMES = {
	[STATE.WALKING] = "ZombieWalk",
	[STATE.RUNNING] = "ZombieRun",
	[STATE.CRAWLING] = "ZombieCrawl",
	[STATE.ATTACK_STANDING] = "ZombieAttackStanding",
	[STATE.ATTACK_CRAWLING] = "ZombieAttackCrawling",
	[STATE.REMOVE_PLANKS] = "ZombieRemovePlanks",
	[STATE.DEAD] = "ZombieDeath",
}

-- Playback speed per animated state (defaults to 1.0).
local SPEED_BY_STATE = {
	[STATE.WALKING] = 0.8,
	[STATE.RUNNING] = 1.2,
	[STATE.CRAWLING] = 0.6,
	[STATE.REMOVE_PLANKS] = 0.8,
}

-- Turn an Animation/KeyframeSequence asset into something LoadAnimation accepts.
-- Returns nil if it cannot be made playable (caller skips it).
local function resolveAnimation(asset: Instance): Animation?
	if asset:IsA("Animation") then
		return asset
	end
	if asset:IsA("KeyframeSequence") then
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(asset)
		end)
		if ok and typeof(id) == "string" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			return animation
		end
	end
	return nil
end

-- Build a playable Animation for a clip name: prefer the uploaded AnimationId from
-- Config/ZombieAnimations; fall back to the committed KeyframeSequence (Studio preview).
local function buildAnimation(animName: string, animFolder: Instance?): Animation?
	local id = ZombieAnimations[animName]
	if type(id) == "string" and id ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animation
	end
	local asset = animFolder and animFolder:FindFirstChild(animName)
	if asset then
		return resolveAnimation(asset)
	end
	return nil
end

function ZombieController.new(zombieModel: Model): ZombieController
	local self = setmetatable({}, ZombieController) :: ZombieController
	self.Model = zombieModel
	self.Humanoid = zombieModel:FindFirstChildOfClass("Humanoid")
	self.HumanoidRootPart = zombieModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	self.Head = zombieModel:FindFirstChild("Head") :: BasePart?
	self.LeftLeg = zombieModel:FindFirstChild("LeftLeg") :: BasePart?
	self.RightLeg = zombieModel:FindFirstChild("RightLeg") :: BasePart?

	self.CurrentState = STATE.IDLE
	self.IsCrawling = false
	self.HeadDetached = false
	self.LegsDetached = false
	self.Attacking = false
	self.RemovingPlanks = false
	self.Animations = {}
	self.CurrentAnimationTrack = nil

	self:LoadAnimations()
	self:SetupDetachableParts()
	self:SetupDamageDetection()

	return self
end

function ZombieController.LoadAnimations(self: ZombieController)
	local humanoid = self.Humanoid
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- animFolder may be nil — uploaded AnimationIds (from config) don't need it; the
	-- KeyframeSequence fallback inside buildAnimation does.
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animFolder = assets and assets:FindFirstChild("Animations")

	for stateName, animName in ANIM_NAMES do
		local animation = buildAnimation(animName, animFolder)
		if animation then
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				self.Animations[stateName] = track
			end
		end
	end
end

function ZombieController.SetupDetachableParts(self: ZombieController)
	self.NeckMotor = self.Head and self.Head:FindFirstChild("Neck") :: Motor6D?
	self.LeftHipMotor = self.LeftLeg and self.LeftLeg:FindFirstChild("Left Hip") :: Motor6D?
	self.RightHipMotor = self.RightLeg and self.RightLeg:FindFirstChild("Right Hip") :: Motor6D?
end

function ZombieController.SetupDamageDetection(self: ZombieController)
	local humanoid = self.Humanoid
	if not humanoid then
		return
	end

	self._connection = humanoid.HealthChanged:Connect(function(health: number)
		-- Head pops near death. Legs come off only from explosions (ZombieService.explode),
		-- so a crawling zombie always means "took a blast", never just "low HP".
		if health / math.max(humanoid.MaxHealth, 1) < HEAD_DETACH_THRESHOLD and not self.HeadDetached then
			self:DetachHead()
		end
		if health <= 0 then
			self:Collapse()
		end
	end)
end

local function detachPart(part: BasePart, velocity: Vector3, motor: Motor6D?)
	if motor then
		motor.Part0 = nil
		motor.Part1 = nil
		motor.Enabled = false
	end
	part.CanCollide = true
	part.Anchored = false
	part.AssemblyLinearVelocity = velocity
end

function ZombieController.DetachHead(self: ZombieController)
	local head = self.Head
	if not head or self.HeadDetached then
		return
	end
	self.HeadDetached = true

	local root = self.HumanoidRootPart
	local pop = if root
		then (root.CFrame.UpVector + Vector3.new(math.random(-50, 50) / 100, 0, math.random(-50, 50) / 100)) * 15
		else Vector3.new(0, 15, 0)
	detachPart(head, pop, self.NeckMotor)
	head.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))

	task.delay(PART_CLEANUP_DELAY, function()
		if head.Parent then
			head.Parent = nil
		end
	end)
end

function ZombieController.DetachLegs(self: ZombieController)
	if self.LegsDetached then
		return
	end
	self.LegsDetached = true

	if self.LeftLeg then
		detachPart(
			self.LeftLeg,
			Vector3.new(math.random(-30, 30) / 10, 5, math.random(-30, 30) / 10),
			self.LeftHipMotor
		)
	end
	if self.RightLeg then
		detachPart(
			self.RightLeg,
			Vector3.new(math.random(-30, 30) / 10, 5, math.random(-30, 30) / 10),
			self.RightHipMotor
		)
	end

	local left, right = self.LeftLeg, self.RightLeg
	task.delay(PART_CLEANUP_DELAY, function()
		if left and left.Parent then
			left.Parent = nil
		end
		if right and right.Parent then
			right.Parent = nil
		end
	end)

	self.IsCrawling = true
	self:SetState(STATE.CRAWLING)
end

-- Make death explicit the instant the killing shot lands. Prefer a collapse animation
-- (a clean "fall to the floor"); fall back to a scripted ragdoll so the kill always reads
-- clearly instead of the default BreakJointsOnDeath gravity flop (the ~0.2s ambiguity).
function ZombieController.Collapse(self: ZombieController)
	if self.CurrentState == STATE.DEAD then
		return
	end
	self.CurrentState = STATE.DEAD
	self.Attacking = false
	self.RemovingPlanks = false

	if self.CurrentAnimationTrack and self.CurrentAnimationTrack.IsPlaying then
		self.CurrentAnimationTrack:Stop()
	end

	local deathTrack = self.Animations[STATE.DEAD]
	if deathTrack then
		deathTrack.Priority = Enum.AnimationPriority.Action
		deathTrack:Play()
		self.CurrentAnimationTrack = deathTrack
	else
		self:Ragdoll()
	end
end

-- Loosen the six R6 joints so the body goes limp at once, with a shove so it drops
-- visibly. Cosmetic welds (eyes/mouth/hands) are left intact.
function ZombieController.Ragdoll(self: ZombieController)
	for _, descendant in self.Model:GetDescendants() do
		if descendant:IsA("Motor6D") and R6_JOINT_NAMES[descendant.Name] then
			descendant.Enabled = false
		end
	end
	local torso = self.Model:FindFirstChild("Torso") :: BasePart?
	if torso then
		local back = if self.HumanoidRootPart then -self.HumanoidRootPart.CFrame.LookVector else Vector3.zero
		torso.AssemblyLinearVelocity = back * DEATH_SHOVE + Vector3.new(0, -DEATH_SHOVE * 0.3, 0)
	end
end

function ZombieController.SetState(self: ZombieController, newState: string)
	if self.CurrentState == STATE.DEAD then
		return
	end
	if self.CurrentState == newState then
		return
	end
	if self.LegsDetached and (newState == STATE.WALKING or newState == STATE.RUNNING) then
		newState = STATE.CRAWLING
	end
	self.CurrentState = newState
	self:PlayAnimationForState(newState)
end

function ZombieController.PlayAnimationForState(self: ZombieController, state: string)
	if self.CurrentAnimationTrack and self.CurrentAnimationTrack.IsPlaying then
		self.CurrentAnimationTrack:Stop()
	end

	local track = self.Animations[state]
	if not track then
		return
	end

	track:AdjustSpeed(SPEED_BY_STATE[state] or 1.0)
	track:Play()
	self.CurrentAnimationTrack = track

	if not track.Looped then
		track.Stopped:Once(function()
			if self.Attacking then
				self.Attacking = false
				self:SetState(if self.LegsDetached then STATE.CRAWLING else STATE.WALKING)
			elseif self.RemovingPlanks then
				self.RemovingPlanks = false
				self:SetState(if self.LegsDetached then STATE.CRAWLING else STATE.WALKING)
			end
		end)
	end
end

function ZombieController.Walk(self: ZombieController)
	if self.Attacking or self.RemovingPlanks then
		return
	end
	self:SetState(if self.LegsDetached then STATE.CRAWLING else STATE.WALKING)
end

function ZombieController.Run(self: ZombieController)
	if self.Attacking or self.RemovingPlanks then
		return
	end
	self:SetState(if self.LegsDetached then STATE.CRAWLING else STATE.RUNNING)
end

function ZombieController.Attack(self: ZombieController)
	if self.Attacking or self.RemovingPlanks then
		return
	end
	self.Attacking = true
	self:SetState(if self.LegsDetached then STATE.ATTACK_CRAWLING else STATE.ATTACK_STANDING)
end

function ZombieController.RemovePlanks(self: ZombieController)
	if self.Attacking or self.RemovingPlanks then
		return
	end
	self.RemovingPlanks = true
	self:SetState(STATE.REMOVE_PLANKS)
end

function ZombieController.ForceDetachHead(self: ZombieController)
	self:DetachHead()
end

function ZombieController.ForceDetachLegs(self: ZombieController)
	self:DetachLegs()
end

function ZombieController.GetState(self: ZombieController): string
	return self.CurrentState
end

function ZombieController.Destroy(self: ZombieController)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	for state, track in self.Animations do
		-- Leave the death track playing through the corpse linger; stop everything else.
		if state ~= STATE.DEAD and track.IsPlaying then
			track:Stop()
		end
	end
	table.clear(self.Animations)
end

return {
	ZombieController = ZombieController,
	STATE = STATE,
}
