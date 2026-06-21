--!strict
--[[
	ZombieController.luau
	Per-zombie visual/state controller: animation playback (walk/run/crawl/attack/
	remove-planks), and health-driven gore (head detaches < 15% HP, legs detach
	< 40% HP and the zombie switches to crawling). Ragdolled parts pop off and clean
	up after a delay.

	Ported from the in-place prototype with two fixes:
	  - No yields at require time (SE-8): assets are resolved inside methods.
	  - Resilient animations: a real uploaded Animation is used if present; otherwise
	    the KeyframeSequence is registered for Studio-only preview. Everything is
	    pcall-guarded so a missing/unuploaded animation never breaks the zombie.

	Drive it from the server AI (ZombieService): :Walk()/:Run() while moving,
	:Attack() on a melee hit. Health changes trigger detachment automatically.

	NOTE: KeyframeSequenceProvider IDs are temporary and Studio-only. For animations
	to play in a published game, upload the 6 KeyframeSequences and reference them as
	Animation objects (with AnimationId) under ReplicatedStorage.Assets.Animations.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local LEGS_DETACH_THRESHOLD = 0.40
local PART_CLEANUP_DELAY = 5

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

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animFolder = assets and assets:FindFirstChild("Animations")
	if not animFolder then
		return
	end

	for stateName, animName in ANIM_NAMES do
		local asset = animFolder:FindFirstChild(animName)
		if asset then
			local animation = resolveAnimation(asset)
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
		local percent = health / math.max(humanoid.MaxHealth, 1)

		if percent < HEAD_DETACH_THRESHOLD and not self.HeadDetached then
			self:DetachHead()
		end
		if percent < LEGS_DETACH_THRESHOLD and not self.LegsDetached then
			self:DetachLegs()
		end
		if health <= 0 then
			self:SetState(STATE.DEAD)
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
	for _, track in self.Animations do
		if track.IsPlaying then
			track:Stop()
		end
	end
	table.clear(self.Animations)
end

return {
	ZombieController = ZombieController,
	STATE = STATE,
}
