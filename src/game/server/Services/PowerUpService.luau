--!strict
--[[
	PowerUpService.luau
	Classic power-up drops. On a zombie kill there is a small chance to spawn a floating
	pickup; the first player to touch it triggers a TEAM-WIDE effect:
		Max Ammo      — refill everyone's ammo (instant)
		Nuke          — kill all zombies + flat points to everyone (instant)
		Insta-Kill    — zombies die in one hit for a duration
		Double Points — 2x points for a duration
	Effects route through CombatModifiers (read by ZombieService) and the existing weapon/
	session services. A PowerUp remote drives the HUD banner. Server-authoritative.

	Public API:
		PowerUpService.init()   -- register the kill hook + remote (after ZombieService.init)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteHandler = require(script.Parent.Parent.RemoteHandler)
local CombatModifiers = require(script.Parent.CombatModifiers)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)
local ZombieService = require(script.Parent.ZombieService)
local BarrierService = require(script.Parent.BarrierService)

type PowerUp = {
	id: string,
	label: string,
	color: Color3,
	duration: number,
}

local DROP_CHANCE = 0.04 -- per kill
local MAX_ACTIVE_DROPS = 2
local PICKUP_LIFETIME = 25
local NUKE_POINTS = 400
local CARPENTER_POINTS = 200
local EFFECT_DURATION = 30

local POWERUPS: { PowerUp } = {
	{ id = "MaxAmmo", label = "MAX AMMO", color = Color3.fromRGB(80, 180, 255), duration = 0 },
	{ id = "Nuke", label = "NUKE", color = Color3.fromRGB(255, 130, 40), duration = 0 },
	{ id = "InstaKill", label = "INSTA-KILL", color = Color3.fromRGB(255, 60, 60), duration = EFFECT_DURATION },
	{ id = "DoublePoints", label = "DOUBLE POINTS", color = Color3.fromRGB(255, 215, 0), duration = EFFECT_DURATION },
	{ id = "Carpenter", label = "CARPENTER", color = Color3.fromRGB(150, 110, 60), duration = 0 },
}

local PowerUpService = {}

local dropsFolder: Folder? = nil
local activeDrops = 0
local instaKillToken = 0
local doublePointsToken = 0

local function ensureFolder(): Folder
	if dropsFolder and dropsFolder.Parent then
		return dropsFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "PowerUps"
	folder.Parent = Workspace
	dropsFolder = folder
	return folder
end

local function broadcast(powerup: PowerUp)
	RemoteHandler.fireAllClients(Remotes.Names.PowerUp, {
		label = powerup.label,
		r = math.floor(powerup.color.R * 255),
		g = math.floor(powerup.color.G * 255),
		b = math.floor(powerup.color.B * 255),
		duration = powerup.duration,
	})
end

local function applyEffect(powerup: PowerUp)
	broadcast(powerup)
	if powerup.id == "MaxAmmo" then
		for _, player in Players:GetPlayers() do
			WeaponService.refillAmmo(player)
		end
	elseif powerup.id == "Nuke" then
		ZombieService.nukeKill()
		for _, player in Players:GetPlayers() do
			SessionService.addPoints(player, NUKE_POINTS)
		end
	elseif powerup.id == "InstaKill" then
		CombatModifiers.setInstaKill(true)
		instaKillToken += 1
		local myToken = instaKillToken
		task.delay(powerup.duration, function()
			if myToken == instaKillToken then -- not superseded by a later pickup
				CombatModifiers.setInstaKill(false)
			end
		end)
	elseif powerup.id == "DoublePoints" then
		CombatModifiers.setPointsMultiplier(2)
		doublePointsToken += 1
		local myToken = doublePointsToken
		task.delay(powerup.duration, function()
			if myToken == doublePointsToken then
				CombatModifiers.setPointsMultiplier(1)
			end
		end)
	elseif powerup.id == "Carpenter" then
		BarrierService.repairAll()
		for _, player in Players:GetPlayers() do
			SessionService.addPoints(player, CARPENTER_POINTS)
		end
	end
end

local function spawnDrop(position: Vector3, powerup: PowerUp)
	local part = Instance.new("Part")
	part.Name = "PowerUp_" .. powerup.id
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position + Vector3.new(0, 2, 0)
	part.Material = Enum.Material.Neon
	part.Color = powerup.color
	part.Parent = ensureFolder()
	activeDrops += 1

	local taken = false
	local conn: RBXScriptConnection
	local function consume(byTouch: boolean)
		if taken then
			return
		end
		taken = true
		conn:Disconnect()
		activeDrops -= 1
		if byTouch then
			applyEffect(powerup)
		end
		part:Destroy()
	end

	conn = part.Touched:Connect(function(hit: BasePart)
		if Players:GetPlayerFromCharacter(hit.Parent) then
			consume(true)
		end
	end)

	task.delay(PICKUP_LIFETIME, function()
		consume(false) -- expire un-grabbed
	end)
end

local function onZombieKilled(position: Vector3, _killer: Player?)
	if activeDrops >= MAX_ACTIVE_DROPS or math.random() >= DROP_CHANCE then
		return
	end
	spawnDrop(position, POWERUPS[math.random(#POWERUPS)])
end

function PowerUpService.init()
	RemoteHandler.createRemote(Remotes.Names.PowerUp, "Event")
	ensureFolder()
	ZombieService.setKillListener(onZombieKilled)
	print("[PowerUpService] Initialized")
end

return PowerUpService
