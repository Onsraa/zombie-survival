--!strict
--[[
	BuyStation.luau
	A shared interactive pedestal: a Part + ProximityPrompt + floating label. Server-
	authoritative — on trigger it re-checks the buyer is actually at the pedestal
	(anti-exploit; a client could otherwise fire the prompt from anywhere), then calls
	onActivate(player). Used by WallBuy / MysteryBox / Pack-a-Punch so the pedestal +
	prompt + proximity plumbing lives in one place.

	Public API:
		BuyStation.create(config) -> BasePart
]]

local BuyStation = {}

export type StationConfig = {
	name: string,
	position: Vector3,
	objectText: string,
	actionText: string,
	labelText: string?,
	color: Color3?,
	onActivate: (player: Player) -> (),
	activationDistance: number?,
	validateDistance: number?,
}

local DEFAULT_SIZE = Vector3.new(4, 4, 1)
local DEFAULT_COLOR = Color3.fromRGB(80, 80, 90)
local DEFAULT_ACTIVATION = 10 -- ProximityPrompt range
local DEFAULT_VALIDATE = 16 -- server anti-exploit re-check (> activation, with margin)

local function makeLabel(text: string, parent: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8, 2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 226, 150)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

function BuyStation.create(config: StationConfig): BasePart
	local part = Instance.new("Part")
	part.Name = config.name
	part.Anchored = true
	part.Size = DEFAULT_SIZE
	part.Position = config.position
	part.Color = config.color or DEFAULT_COLOR
	part.Material = Enum.Material.Metal

	local validateDistance = config.validateDistance or DEFAULT_VALIDATE
	local onActivate = config.onActivate

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = config.objectText
	prompt.ActionText = config.actionText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = config.activationDistance or DEFAULT_ACTIVATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player: Player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		-- Anti-exploit: the player must actually be at the pedestal.
		if (root.Position - part.Position).Magnitude > validateDistance then
			return
		end
		onActivate(player)
	end)

	if config.labelText then
		makeLabel(config.labelText, part)
	end
	return part
end

return BuyStation
