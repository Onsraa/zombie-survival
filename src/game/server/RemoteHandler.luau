--!strict
--[[
	RemoteHandler.luau
	Centralized remote creation, validation, rate-limiting, and cooldown enforcement.
	Every client->server remote is registered here so the security layers (SE-5) are
	applied uniformly. Server->client remotes are created with createRemote and fired
	via fireClient / fireAllClients.

	register {
		Name, Type = "Event" | "Function",
		Handler  = function(player, ...) ... end,
		Validator? = function(player, ...) -> (boolean, string?),
		Cooldown? = seconds between fires,
		RateLimit? = max fires per Constants.REMOTE_WINDOW,
	}
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

export type RemoteConfig = {
	Name: string,
	Type: "Event" | "Function",
	Handler: (player: Player, ...any) -> ...any,
	Validator: ((player: Player, ...any) -> (boolean, string?))?,
	Cooldown: number?,
	RateLimit: number?,
}

local RemoteHandler = {}

local rateLimitData: { [Player]: { [string]: { number } } } = {}
local cooldownData: { [Player]: { [string]: number } } = {}
local violationCounts: { [Player]: number } = {}

local function getRemotesFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function checkRateLimit(player: Player, remoteName: string, maxRequests: number): boolean
	local now = os.clock()

	local playerRates = rateLimitData[player]
	if not playerRates then
		playerRates = {}
		rateLimitData[player] = playerRates
	end

	local windowStart = now - Constants.REMOTE_WINDOW
	local pruned: { number } = {}
	for _, ts in playerRates[remoteName] or {} do
		if ts > windowStart then
			table.insert(pruned, ts)
		end
	end

	if #pruned >= maxRequests then
		violationCounts[player] = (violationCounts[player] or 0) + 1
		warn(`[RemoteHandler] Rate limited {player.Name} on "{remoteName}" (#{violationCounts[player]})`)
		if violationCounts[player] >= Constants.REMOTE_KICK_THRESHOLD then
			task.defer(function()
				player:Kick("Too many requests. Please rejoin.")
			end)
		end
		playerRates[remoteName] = pruned
		return false
	end

	table.insert(pruned, now)
	playerRates[remoteName] = pruned
	return true
end

local function checkCooldown(player: Player, remoteName: string, cooldownSeconds: number): boolean
	local now = os.clock()
	local playerCooldowns = cooldownData[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldownData[player] = playerCooldowns
	end

	local lastUsed = playerCooldowns[remoteName]
	if lastUsed and (now - lastUsed) < cooldownSeconds then
		return false
	end

	playerCooldowns[remoteName] = now
	return true
end

-- Pass all security gates for a request. Returns true if the handler should run.
local function passesGates(player: Player, config: RemoteConfig, maxRate: number, cooldown: number, ...: any): boolean
	if not checkRateLimit(player, config.Name, maxRate) then
		return false
	end
	if cooldown > 0 and not checkCooldown(player, config.Name, cooldown) then
		return false
	end
	if config.Validator then
		local valid, reason = config.Validator(player, ...)
		if not valid then
			warn(`[RemoteHandler] Validation failed for {player.Name} on "{config.Name}": {reason or "unknown"}`)
			return false
		end
	end
	return true
end

function RemoteHandler.init()
	getRemotesFolder()
	print("[RemoteHandler] Initialized")
end

-- Create (or fetch) a remote instance by name without attaching a handler.
function RemoteHandler.createRemote(name: string, remoteType: "Event" | "Function"): Instance
	local folder = getRemotesFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end

	local remote: Instance = if remoteType == "Function"
		then Instance.new("RemoteFunction")
		else Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

-- Register a client->server remote with full security gating.
function RemoteHandler.register(config: RemoteConfig)
	local cooldown = config.Cooldown or 0
	local maxRate = config.RateLimit or Constants.MAX_REMOTE_RATE
	local remote = RemoteHandler.createRemote(config.Name, config.Type)

	if config.Type == "Event" then
		(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...: any)
			if passesGates(player, config, maxRate, cooldown, ...) then
				config.Handler(player, ...)
			end
		end)
	else
		(remote :: RemoteFunction).OnServerInvoke = function(player: Player, ...: any)
			if passesGates(player, config, maxRate, cooldown, ...) then
				return config.Handler(player, ...)
			end
			return nil
		end
	end

	print(`[RemoteHandler] Registered {config.Name} ({config.Type})`)
end

function RemoteHandler.fireClient(name: string, player: Player, ...: any)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, ...)
	end
end

function RemoteHandler.fireAllClients(name: string, ...: any)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

function RemoteHandler.cleanupPlayer(player: Player)
	rateLimitData[player] = nil
	cooldownData[player] = nil
	violationCounts[player] = nil
end

Players.PlayerRemoving:Connect(RemoteHandler.cleanupPlayer)

return RemoteHandler
