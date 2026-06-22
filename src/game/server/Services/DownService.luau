--!strict
--[[
	DownService.luau
	Down & revive (the co-op core). When a zombie hit would kill a player they go DOWNED
	instead of dying: ragdolled (PlatformStand), frozen, can't shoot, bleeding out. A
	teammate holds a revive ProximityPrompt to bring them back. If everyone is down at once
	there's no one to revive → RoundService sees zero players "up" → game over. Solo, the
	Quick Revive perk grants one self-revive. Server-authoritative.

	Player damage is routed here from ZombieService (setPlayerDamageHandler); the "downed"
	flag lives in the PlayerState leaf so WeaponService/ZombieService read it without a cycle.

	Public API:
		DownService.init()             -- register the damage handler + lifecycle hooks
		DownService.countUpPlayers()   -- players alive and not downed (RoundService wipe check)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteHandler = require(script.Parent.Parent.RemoteHandler)
local PlayerState = require(script.Parent.PlayerState)
local PerkService = require(script.Parent.PerkService)
local ZombieService = require(script.Parent.ZombieService)

local BLEED_OUT_TIME = 30 -- seconds downed before dying
local REVIVE_HOLD = 5 -- seconds a teammate holds to revive
local REVIVE_DISTANCE = 9
local QUICK_REVIVE_DELAY = 5 -- solo self-revive delay (Quick Revive perk)
local DOWNED_HEALTH = 1

type DownRecord = {
	token: number,
	prompt: ProximityPrompt?,
}

local DownService = {}

local records: { [Player]: DownRecord } = {}
local tokenCounter = 0

local function broadcastDowned(player: Player, downed: boolean, bleedTime: number?)
	RemoteHandler.fireClient(Remotes.Names.Downed, player, { downed = downed, bleedTime = bleedTime })
end

local function clearRecord(player: Player)
	local rec = records[player]
	if rec then
		if rec.prompt then
			rec.prompt:Destroy()
		end
		records[player] = nil
	end
end

local function getHumanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function revive(player: Player)
	if not PlayerState.isDowned(player) then
		return
	end
	PlayerState.setDowned(player, false)
	tokenCounter += 1 -- invalidate the pending bleed-out
	clearRecord(player)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = Constants.WALK_SPEED
	end
	broadcastDowned(player, false)
end

local function bleedOut(player: Player)
	if not PlayerState.isDowned(player) then
		return
	end
	PlayerState.setDowned(player, false)
	clearRecord(player)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Health = 0 -- dies; respawns next round if the team survives
	end
	broadcastDowned(player, false)
end

local function countUpExcluding(excluded: Player?): number
	local n = 0
	for _, player in Players:GetPlayers() do
		if player ~= excluded then
			local humanoid = getHumanoid(player)
			if humanoid and humanoid.Health > 0 and not PlayerState.isDowned(player) then
				n += 1
			end
		end
	end
	return n
end

local function createRevivePrompt(player: Player, root: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = player.Name
	prompt.ActionText = "Revive"
	prompt.HoldDuration = REVIVE_HOLD
	prompt.MaxActivationDistance = REVIVE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(reviver: Player)
		if reviver == player or PlayerState.isDowned(reviver) then
			return -- no self-revive via prompt; a downed teammate can't revive
		end
		local rchar = reviver.Character
		local rroot = rchar and rchar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rroot and (rroot.Position - root.Position).Magnitude <= REVIVE_DISTANCE + 4 then
			revive(player)
		end
	end)
	return prompt
end

local function enterDowned(player: Player, humanoid: Humanoid)
	PlayerState.setDowned(player, true)
	humanoid.PlatformStand = true
	humanoid.WalkSpeed = 0
	humanoid.Health = DOWNED_HEALTH

	tokenCounter += 1
	local myToken = tokenCounter
	local root = humanoid.RootPart
	records[player] = { token = myToken, prompt = if root then createRevivePrompt(player, root) else nil }

	broadcastDowned(player, true, BLEED_OUT_TIME)

	-- Solo (no teammate up to revive) + Quick Revive => one self-revive.
	if countUpExcluding(player) == 0 and PerkService.hasPerk(player, "QuickRevive") then
		PerkService.removePerk(player, "QuickRevive")
		task.delay(QUICK_REVIVE_DELAY, function()
			local rec = records[player]
			if rec and rec.token == myToken then
				revive(player)
			end
		end)
		return
	end

	task.delay(BLEED_OUT_TIME, function()
		local rec = records[player]
		if rec and rec.token == myToken then
			bleedOut(player)
		end
	end)
end

-- Called by ZombieService when a zombie melees a player humanoid.
function DownService.damage(humanoid: Humanoid, amount: number)
	local char = humanoid.Parent
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player then
		humanoid:TakeDamage(amount) -- non-player fallback (shouldn't happen)
		return
	end
	if PlayerState.isDowned(player) then
		return -- already down; ignore further melee
	end
	if humanoid.Health - amount <= 0 then
		enterDowned(player, humanoid)
	else
		humanoid:TakeDamage(amount)
	end
end

function DownService.countUpPlayers(): number
	return countUpExcluding(nil)
end

function DownService.init()
	RemoteHandler.createRemote(Remotes.Names.Downed, "Event")
	ZombieService.setPlayerDamageHandler(DownService.damage)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			PlayerState.setDowned(player, false) -- fresh life is never downed
			clearRecord(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerState.setDowned(player, false)
		clearRecord(player)
	end)

	print("[DownService] Initialized")
end

return DownService
