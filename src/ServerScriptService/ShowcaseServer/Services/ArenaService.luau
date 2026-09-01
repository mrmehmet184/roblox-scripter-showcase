--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("Config"))

local ArenaService = {}
ArenaService.__index = ArenaService

type InternalArenaService = {
	_root: Model,
	_geometry: Folder,
	_projectiles: Folder,
	_bossModel: Model,
	_bossCore: BasePart,
	_spawnLocation: SpawnLocation,
}

export type ArenaService = typeof(setmetatable({} :: InternalArenaService, ArenaService))

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.CastShadow = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, color: Color3, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = 1
	stroke.Parent = instance
end

local function createFloatingLabel(parent: BasePart, heading: string, body: string, accent: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EngineeringLabel"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 180
	billboard.Size = UDim2.fromOffset(250, 76)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Config.Palette.Panel
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard
	addCorner(frame, 10)
	addStroke(frame, accent, 0.35)

	local strip = Instance.new("Frame")
	strip.BackgroundColor3 = accent
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(0, 4, 1, -16)
	strip.Position = UDim2.fromOffset(8, 8)
	strip.Parent = frame
	addCorner(strip, 3)

	local headingLabel = Instance.new("TextLabel")
	headingLabel.BackgroundTransparency = 1
	headingLabel.Font = Enum.Font.GothamBold
	headingLabel.Text = heading
	headingLabel.TextColor3 = Config.Palette.Text
	headingLabel.TextSize = 15
	headingLabel.TextXAlignment = Enum.TextXAlignment.Left
	headingLabel.Position = UDim2.fromOffset(24, 10)
	headingLabel.Size = UDim2.new(1, -34, 0, 22)
	headingLabel.Parent = frame

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.Text = body
	bodyLabel.TextColor3 = Config.Palette.MutedText
	bodyLabel.TextSize = 12
	bodyLabel.TextWrapped = true
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.Position = UDim2.fromOffset(24, 33)
	bodyLabel.Size = UDim2.new(1, -34, 0, 34)
	bodyLabel.Parent = frame
end

local function createBoss(parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = Config.Enemy.Name
	model:SetAttribute("ShowcaseEnemy", true)
	model:SetAttribute("Health", Config.Enemy.MaximumHealth)
	model:SetAttribute("MaximumHealth", Config.Enemy.MaximumHealth)
	model.Parent = parent

	local baseCFrame = Config.Arena.BossCFrame

	local hitbox = makePart(
		"Hitbox",
		Vector3.new(7, 10, 6),
		baseCFrame,
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic,
		model
	)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CastShadow = false
	model.PrimaryPart = hitbox

	local lowerBody = makePart(
		"LowerBody",
		Vector3.new(5.5, 3.2, 4.3),
		baseCFrame * CFrame.new(0, -1.7, 0),
		Color3.fromRGB(41, 48, 61),
		Enum.Material.Metal,
		model
	)
	lowerBody.CanCollide = false

	local torso = makePart(
		"Torso",
		Vector3.new(6.2, 4.2, 4.8),
		baseCFrame * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(54, 64, 81),
		Enum.Material.Metal,
		model
	)
	torso.CanCollide = false

	local head = makePart(
		"Head",
		Vector3.new(4.3, 2.2, 3.5),
		baseCFrame * CFrame.new(0, 4.8, 0),
		Color3.fromRGB(31, 37, 48),
		Enum.Material.Metal,
		model
	)
	head.CanCollide = false

	local visor = makePart(
		"Visor",
		Vector3.new(3.4, 0.65, 0.18),
		baseCFrame * CFrame.new(0, 4.9, 1.82),
		Config.Palette.Danger,
		Enum.Material.Neon,
		model
	)
	visor.CanCollide = false
	visor.CastShadow = false

	local core = makePart(
		"Core",
		Vector3.new(1.45, 1.45, 0.35),
		baseCFrame * CFrame.new(0, 1.5, 2.55),
		Config.Palette.Info,
		Enum.Material.Neon,
		model
	)
	core.Shape = Enum.PartType.Cylinder
	core.CFrame *= CFrame.Angles(0, math.rad(90), 0)
	core.CanCollide = false
	core.CastShadow = false

	for _, xOffset in ipairs({ -4.25, 4.25 }) do
		local shoulder = makePart(
			if xOffset < 0 then "LeftShoulder" else "RightShoulder",
			Vector3.new(2.2, 2.2, 2.5),
			baseCFrame * CFrame.new(xOffset, 2.1, 0),
			Color3.fromRGB(70, 82, 102),
			Enum.Material.Metal,
			model
		)
		shoulder.Shape = Enum.PartType.Ball
		shoulder.CanCollide = false

		local arm = makePart(
			if xOffset < 0 then "LeftArm" else "RightArm",
			Vector3.new(1.7, 4.8, 1.9),
			baseCFrame * CFrame.new(xOffset, -0.9, 0),
			Color3.fromRGB(46, 55, 70),
			Enum.Material.Metal,
			model
		)
		arm.CanCollide = false
	end

	local healthBillboard = Instance.new("BillboardGui")
	healthBillboard.Name = "HealthBillboard"
	healthBillboard.AlwaysOnTop = true
	healthBillboard.LightInfluence = 0
	healthBillboard.MaxDistance = 220
	healthBillboard.Size = UDim2.fromOffset(320, 58)
	healthBillboard.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
	healthBillboard.Parent = head

	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "Container"
	healthFrame.BackgroundColor3 = Config.Palette.Background
	healthFrame.BackgroundTransparency = 0.1
	healthFrame.BorderSizePixel = 0
	healthFrame.Size = UDim2.fromScale(1, 1)
	healthFrame.Parent = healthBillboard
	addCorner(healthFrame, 9)
	addStroke(healthFrame, Config.Palette.Danger, 0.35)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = Config.Enemy.Name
	nameLabel.TextColor3 = Config.Palette.Text
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.fromOffset(12, 5)
	nameLabel.Size = UDim2.new(1, -24, 0, 20)
	nameLabel.Parent = healthFrame

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamMedium
	healthText.Text = string.format("%d / %d", Config.Enemy.MaximumHealth, Config.Enemy.MaximumHealth)
	healthText.TextColor3 = Config.Palette.MutedText
	healthText.TextSize = 12
	healthText.TextXAlignment = Enum.TextXAlignment.Right
	healthText.Position = UDim2.fromOffset(12, 5)
	healthText.Size = UDim2.new(1, -24, 0, 20)
	healthText.Parent = healthFrame

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.BackgroundColor3 = Color3.fromRGB(46, 51, 62)
	barBackground.BorderSizePixel = 0
	barBackground.Position = UDim2.fromOffset(12, 34)
	barBackground.Size = UDim2.new(1, -24, 0, 10)
	barBackground.Parent = healthFrame
	addCorner(barBackground, 5)

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.BackgroundColor3 = Config.Palette.Danger
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = barBackground
	addCorner(barFill, 5)

	return model, core
end

function ArenaService.new(): ArenaService
	if Config.Arena.RemoveDefaultBaseplate then
		local defaultBaseplate = Workspace:FindFirstChild("Baseplate")
		if defaultBaseplate ~= nil and defaultBaseplate:IsA("BasePart") then
			defaultBaseplate:Destroy()
		end

		local defaultSpawn = Workspace:FindFirstChild("SpawnLocation")
		if defaultSpawn ~= nil and defaultSpawn:IsA("SpawnLocation") then
			defaultSpawn:Destroy()
		end
	end

	local oldArena = Workspace:FindFirstChild(Config.Arena.ModelName)
	if oldArena then
		oldArena:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = Config.Arena.ModelName
	root.Parent = Workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = root

	local projectiles = Instance.new("Folder")
	projectiles.Name = "Projectiles"
	projectiles.Parent = root

	local self = setmetatable({
		_root = root,
		_geometry = geometry,
		_projectiles = projectiles,
		_bossModel = nil :: any,
		_bossCore = nil :: any,
		_spawnLocation = nil :: any,
	}, ArenaService)

	self:_buildEnvironment()
	return self
end

function ArenaService:_buildEnvironment()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(54, 61, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 34, 45)
	Lighting.FogColor = Color3.fromRGB(9, 12, 17)
	Lighting.FogEnd = 420

	local floorSize = Config.Arena.FloorSize
	makePart(
		"MainFloor",
		Vector3.new(floorSize, 1, floorSize),
		CFrame.new(0, 0, 0),
		Color3.fromRGB(22, 27, 35),
		Enum.Material.Metal,
		self._geometry
	)

	makePart(
		"InnerFloor",
		Vector3.new(100, 0.2, 112),
		CFrame.new(0, 0.61, 0),
		Color3.fromRGB(29, 36, 47),
		Enum.Material.SmoothPlastic,
		self._geometry
	)

	for offset = -48, 48, 8 do
		local lineX = makePart(
			"GridX",
			Vector3.new(0.06, 0.03, 112),
			CFrame.new(offset, 0.73, 0),
			Color3.fromRGB(52, 65, 82),
			Enum.Material.Neon,
			self._geometry
		)
		lineX.CanCollide = false
		lineX.CastShadow = false

		local lineZ = makePart(
			"GridZ",
			Vector3.new(100, 0.03, 0.06),
			CFrame.new(0, 0.73, offset),
			Color3.fromRGB(52, 65, 82),
			Enum.Material.Neon,
			self._geometry
		)
		lineZ.CanCollide = false
		lineZ.CastShadow = false
	end

	for _, wallData in ipairs({
		{ Vector3.new(floorSize, 8, 2), CFrame.new(0, 4, -floorSize / 2), Vector3.new(0, 0, 1) },
		{ Vector3.new(floorSize, 8, 2), CFrame.new(0, 4, floorSize / 2), Vector3.new(0, 0, -1) },
		{ Vector3.new(2, 8, floorSize), CFrame.new(-floorSize / 2, 4, 0), Vector3.new(1, 0, 0) },
		{ Vector3.new(2, 8, floorSize), CFrame.new(floorSize / 2, 4, 0), Vector3.new(-1, 0, 0) },
	}) do
		local wall = makePart(
			"Boundary",
			wallData[1] :: Vector3,
			wallData[2] :: CFrame,
			Color3.fromRGB(25, 31, 40),
			Enum.Material.Metal,
			self._geometry
		)
		wall:SetAttribute("InwardNormal", wallData[3])
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ShowcaseSpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = true
	spawnLocation.Neutral = true
	spawnLocation.Enabled = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.new(Config.Arena.SpawnCFrame.Position - Vector3.new(0, 4.5, 0))
	spawnLocation.Color = Config.Palette.Accent
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Transparency = 0.3
	spawnLocation.Parent = self._geometry
	self._spawnLocation = spawnLocation

	local bossPlatform = makePart(
		"BossPlatform",
		Vector3.new(28, 1.2, 24),
		CFrame.new(Config.Arena.BossCFrame.Position - Vector3.new(0, 5, 0)),
		Color3.fromRGB(35, 41, 54),
		Enum.Material.Metal,
		self._geometry
	)
	bossPlatform:SetAttribute("BossPlatform", true)

	local bossModel, bossCore = createBoss(self._root)
	self._bossModel = bossModel
	self._bossCore = bossCore

	local labels = {
		{
			position = Vector3.new(-32, 1.4, 30),
			heading = "SERVER AUTHORITY",
			body = "Client sends intent. Server validates state, range, cooldown and line of sight.",
			accent = Config.Palette.Accent,
		},
		{
			position = Vector3.new(0, 1.4, 30),
			heading = "STATE MACHINE",
			body = "Match and boss behavior use explicit, observable state transitions.",
			accent = Config.Palette.Info,
		},
		{
			position = Vector3.new(32, 1.4, 30),
			heading = "PARRY / REFLECT",
			body = "Projectile collision, parry windows and reflected damage are decided on the server.",
			accent = Config.Palette.Warning,
		},
	}

	for _, labelData in ipairs(labels) do
		local pedestal = makePart(
			"EngineeringPedestal",
			Vector3.new(5, 1.4, 5),
			CFrame.new(labelData.position),
			Color3.fromRGB(34, 41, 53),
			Enum.Material.Metal,
			self._geometry
		)
		createFloatingLabel(pedestal, labelData.heading, labelData.body, labelData.accent)
	end
end

function ArenaService:GetRoot(): Model
	return self._root
end

function ArenaService:GetProjectileFolder(): Folder
	return self._projectiles
end

function ArenaService:GetBossModel(): Model
	return self._bossModel
end

function ArenaService:GetBossPosition(): Vector3
	return self._bossModel:GetPivot().Position
end

function ArenaService:GetBossOrigin(): Vector3
	return self._bossCore.Position + Vector3.new(0, 0.4, 0)
end

function ArenaService:GetSpawnCFrame(): CFrame
	return Config.Arena.SpawnCFrame
end

function ArenaService:PlaceCharacter(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.CFrame = self:GetSpawnCFrame()
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

function ArenaService:UpdateBossHealth(health: number, maximumHealth: number)
	self._bossModel:SetAttribute("Health", health)
	self._bossModel:SetAttribute("MaximumHealth", maximumHealth)

	local head = self._bossModel:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local healthBillboard = head:FindFirstChild("HealthBillboard")
	if not healthBillboard or not healthBillboard:IsA("BillboardGui") then
		return
	end

	local container = healthBillboard:FindFirstChild("Container")
	if not container or not container:IsA("Frame") then
		return
	end

	local healthText = container:FindFirstChild("HealthText")
	if healthText and healthText:IsA("TextLabel") then
		healthText.Text = string.format("%d / %d", math.max(0, math.floor(health)), maximumHealth)
	end

	local barBackground = container:FindFirstChild("BarBackground")
	if barBackground and barBackground:IsA("Frame") then
		local barFill = barBackground:FindFirstChild("BarFill")
		if barFill and barFill:IsA("Frame") then
			barFill.Size = UDim2.fromScale(math.clamp(health / maximumHealth, 0, 1), 1)
		end
	end
end

function ArenaService:SetBossEnabled(enabled: boolean)
	for _, descendant in ipairs(self._bossModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "Hitbox" then
			descendant.Transparency = if enabled then 0 else 0.55
		end
	end
end

return ArenaService
