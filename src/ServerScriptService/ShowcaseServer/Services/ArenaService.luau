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

type RubbleData = {
	position: Vector3,
	size: Vector3,
	rotation: Vector3,
}

export type ArenaService = typeof(setmetatable({} :: InternalArenaService, ArenaService))

local STONE_LIGHT = Color3.fromRGB(151, 137, 111)
local STONE_MID = Color3.fromRGB(116, 106, 89)
local STONE_DARK = Color3.fromRGB(72, 68, 60)
local STONE_WARM = Color3.fromRGB(128, 105, 75)
local MORTAR = Color3.fromRGB(61, 58, 52)
local IRON = Color3.fromRGB(48, 45, 41)
local IRON_EDGE = Color3.fromRGB(78, 71, 61)
local BRONZE = Color3.fromRGB(132, 91, 47)
local BANNER_RED = Color3.fromRGB(102, 42, 34)
local EMBER = Color3.fromRGB(238, 119, 42)
local EMBER_HOT = Color3.fromRGB(255, 201, 93)

local function shade(color: Color3, amount: number): Color3
	return Color3.new(
		math.clamp(color.R + amount, 0, 1),
		math.clamp(color.G + amount, 0, 1),
		math.clamp(color.B + amount, 0, 1)
	)
end

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

local function makeWedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): WedgePart
	local part = Instance.new("WedgePart")
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

local function makeVerticalCylinder(
	name: string,
	height: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local cylinder = makePart(
		name,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		parent
	)
	cylinder.Shape = Enum.PartType.Cylinder
	return cylinder
end

local function makeDecorative(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, color: Color3, thickness: number, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = instance
end

local function configureLighting()
	Lighting.ClockTime = 17.35
	Lighting.Brightness = 2.15
	Lighting.ExposureCompensation = 0.05
	Lighting.Ambient = Color3.fromRGB(99, 82, 67)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 100, 80)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 202, 139)
	Lighting.ColorShift_Bottom = Color3.fromRGB(91, 77, 68)
	Lighting.EnvironmentDiffuseScale = 0.48
	Lighting.EnvironmentSpecularScale = 0.38
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	Lighting.GeographicLatitude = 34
	Lighting.FogColor = Color3.fromRGB(186, 147, 105)
	Lighting.FogStart = 180
	Lighting.FogEnd = 520

	for _, effectName in ipairs({ "ShowcaseAtmosphere", "ShowcaseColorGrade", "ShowcaseSunRays" }) do
		local oldEffect = Lighting:FindFirstChild(effectName)
		if oldEffect ~= nil then
			oldEffect:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ShowcaseAtmosphere"
	atmosphere.Color = Color3.fromRGB(205, 174, 137)
	atmosphere.Decay = Color3.fromRGB(102, 86, 79)
	atmosphere.Density = 0.2
	atmosphere.Offset = 0.08
	atmosphere.Glare = 0.08
	atmosphere.Haze = 1.25
	atmosphere.Parent = Lighting

	local colorGrade = Instance.new("ColorCorrectionEffect")
	colorGrade.Name = "ShowcaseColorGrade"
	colorGrade.Brightness = -0.015
	colorGrade.Contrast = 0.075
	colorGrade.Saturation = -0.08
	colorGrade.TintColor = Color3.fromRGB(255, 226, 190)
	colorGrade.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "ShowcaseSunRays"
	sunRays.Intensity = 0.035
	sunRays.Spread = 0.68
	sunRays.Parent = Lighting
end

local function createBossHealthDisplay(head: BasePart)
	local healthBillboard = Instance.new("BillboardGui")
	healthBillboard.Name = "HealthBillboard"
	healthBillboard.AlwaysOnTop = true
	healthBillboard.LightInfluence = 0.15
	healthBillboard.MaxDistance = 220
	healthBillboard.Size = UDim2.fromOffset(270, 50)
	healthBillboard.StudsOffsetWorldSpace = Vector3.new(0, 3.25, 0)
	healthBillboard.Parent = head

	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "Container"
	healthFrame.BackgroundColor3 = Color3.fromRGB(35, 29, 24)
	healthFrame.BackgroundTransparency = 0.08
	healthFrame.BorderSizePixel = 0
	healthFrame.Size = UDim2.fromScale(1, 1)
	healthFrame.Parent = healthBillboard
	addCorner(healthFrame, 3)
	addStroke(healthFrame, BRONZE, 1.5, 0.15)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = Config.Enemy.Name
	nameLabel.TextColor3 = Color3.fromRGB(229, 216, 193)
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Position = UDim2.fromOffset(10, 5)
	nameLabel.Size = UDim2.new(1, -20, 0, 18)
	nameLabel.Parent = healthFrame

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.GothamMedium
	healthText.Text = string.format("%d / %d", Config.Enemy.MaximumHealth, Config.Enemy.MaximumHealth)
	healthText.TextColor3 = Color3.fromRGB(184, 167, 142)
	healthText.TextSize = 11
	healthText.TextXAlignment = Enum.TextXAlignment.Right
	healthText.Position = UDim2.fromOffset(10, 5)
	healthText.Size = UDim2.new(1, -20, 0, 18)
	healthText.Parent = healthFrame

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.BackgroundColor3 = Color3.fromRGB(62, 53, 44)
	barBackground.BorderSizePixel = 0
	barBackground.Position = UDim2.fromOffset(10, 32)
	barBackground.Size = UDim2.new(1, -20, 0, 7)
	barBackground.Parent = healthFrame
	addCorner(barBackground, 2)

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.BackgroundColor3 = Color3.fromRGB(156, 55, 42)
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.Parent = barBackground
	addCorner(barFill, 2)
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

	local leftFoot = makePart(
		"LeftFoot",
		Vector3.new(2.45, 1.4, 3.15),
		baseCFrame * CFrame.new(-1.55, -3.9, 0.25),
		STONE_DARK,
		Enum.Material.Granite,
		model
	)
	leftFoot.CanCollide = false
	local rightFoot = makePart(
		"RightFoot",
		Vector3.new(2.45, 1.4, 3.15),
		baseCFrame * CFrame.new(1.55, -3.9, 0.25),
		STONE_DARK,
		Enum.Material.Granite,
		model
	)
	rightFoot.CanCollide = false

	for _, xOffset in ipairs({ -1.55, 1.55 }) do
		local sideName = if xOffset < 0 then "Left" else "Right"
		local shin = makePart(
			sideName .. "Shin",
			Vector3.new(1.85, 2.9, 2.15),
			baseCFrame * CFrame.new(xOffset, -2.45, 0),
			shade(STONE_MID, if xOffset < 0 then -0.025 else 0.015),
			Enum.Material.Slate,
			model
		)
		shin.CanCollide = false

		local greave = makePart(
			sideName .. "Greave",
			Vector3.new(2.05, 2.15, 0.38),
			baseCFrame * CFrame.new(xOffset, -2.35, 1.25),
			IRON,
			Enum.Material.Metal,
			model
		)
		greave.CanCollide = false

		local knee = makePart(
			sideName .. "KneeGuard",
			Vector3.new(2.15, 1.05, 2.45),
			baseCFrame * CFrame.new(xOffset, -1.15, 0.12),
			IRON_EDGE,
			Enum.Material.Metal,
			model
		)
		knee.Shape = Enum.PartType.Ball
		knee.CanCollide = false
	end

	local lowerBody = makePart(
		"LowerBody",
		Vector3.new(4.9, 1.65, 3.5),
		baseCFrame * CFrame.new(0, -0.6, 0),
		STONE_DARK,
		Enum.Material.Granite,
		model
	)
	lowerBody.CanCollide = false

	local belt = makePart(
		"IronBelt",
		Vector3.new(5.25, 0.55, 3.75),
		baseCFrame * CFrame.new(0, 0.05, 0),
		IRON,
		Enum.Material.Metal,
		model
	)
	belt.CanCollide = false

	local torso = makePart(
		"Torso",
		Vector3.new(5.25, 3.6, 3.75),
		baseCFrame * CFrame.new(0, 1.35, 0),
		STONE_MID,
		Enum.Material.Slate,
		model
	)
	torso.CanCollide = false

	local chestPlate = makePart(
		"ChestPlate",
		Vector3.new(4.65, 2.65, 0.48),
		baseCFrame * CFrame.new(0, 1.48, 2.04),
		IRON,
		Enum.Material.Metal,
		model
	)
	chestPlate.CanCollide = false

	local chestRidge = makePart(
		"ChestRidge",
		Vector3.new(0.42, 3.0, 0.28),
		baseCFrame * CFrame.new(0, 1.5, 2.4),
		IRON_EDGE,
		Enum.Material.Metal,
		model
	)
	chestRidge.CanCollide = false

	local core = makePart(
		"Core",
		Vector3.new(0.34, 1.5, 1.5),
		baseCFrame * CFrame.new(0, 1.28, 2.58) * CFrame.Angles(0, math.rad(90), 0),
		BRONZE,
		Enum.Material.Metal,
		model
	)
	core.Shape = Enum.PartType.Cylinder
	core.CanCollide = false

	local coreInset = makePart(
		"CoreInset",
		Vector3.new(0.18, 0.76, 0.76),
		baseCFrame * CFrame.new(0, 1.28, 2.77) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(194, 111, 47),
		Enum.Material.Neon,
		model
	)
	coreInset.Shape = Enum.PartType.Cylinder
	coreInset.CanCollide = false
	coreInset.CastShadow = false

	for _, xOffset in ipairs({ -3.3, 3.3 }) do
		local sideName = if xOffset < 0 then "Left" else "Right"
		local shoulder = makePart(
			sideName .. "Shoulder",
			Vector3.new(2.3, 2.05, 3.0),
			baseCFrame * CFrame.new(xOffset, 2.15, 0),
			IRON_EDGE,
			Enum.Material.Metal,
			model
		)
		shoulder.CanCollide = false

		local shoulderStone = makePart(
			sideName .. "ShoulderStone",
			Vector3.new(1.75, 1.4, 2.35),
			baseCFrame * CFrame.new(xOffset, 2.08, 0),
			STONE_DARK,
			Enum.Material.Granite,
			model
		)
		shoulderStone.CanCollide = false

		local arm = makePart(
			sideName .. "Arm",
			Vector3.new(1.85, 3.65, 2.05),
			baseCFrame * CFrame.new(xOffset, -0.25, 0),
			shade(STONE_MID, if xOffset < 0 then -0.035 else 0),
			Enum.Material.Slate,
			model
		)
		arm.CanCollide = false

		local bracer = makePart(
			sideName .. "Bracer",
			Vector3.new(2.05, 1.45, 2.3),
			baseCFrame * CFrame.new(xOffset, -1.2, 0.08),
			IRON,
			Enum.Material.Metal,
			model
		)
		bracer.CanCollide = false
	end

	local neck = makePart(
		"NeckGuard",
		Vector3.new(3.45, 0.7, 3.1),
		baseCFrame * CFrame.new(0, 3.38, 0),
		IRON,
		Enum.Material.Metal,
		model
	)
	neck.CanCollide = false

	local head = makePart(
		"Head",
		Vector3.new(3.2, 2.25, 2.75),
		baseCFrame * CFrame.new(0, 4.35, 0),
		STONE_DARK,
		Enum.Material.Granite,
		model
	)
	head.CanCollide = false

	local helmet = makePart(
		"Helmet",
		Vector3.new(3.55, 1.3, 3.05),
		baseCFrame * CFrame.new(0, 4.88, -0.02),
		IRON,
		Enum.Material.Metal,
		model
	)
	helmet.CanCollide = false

	local facePlate = makePart(
		"FacePlate",
		Vector3.new(2.65, 1.55, 0.32),
		baseCFrame * CFrame.new(0, 4.18, 1.53),
		IRON_EDGE,
		Enum.Material.Metal,
		model
	)
	facePlate.CanCollide = false

	local visor = makePart(
		"Visor",
		Vector3.new(1.85, 0.16, 0.12),
		baseCFrame * CFrame.new(0, 4.48, 1.73),
		Color3.fromRGB(214, 96, 42),
		Enum.Material.Neon,
		model
	)
	visor.CanCollide = false
	visor.CastShadow = false

	local crest = makeWedge(
		"BrokenCrest",
		Vector3.new(0.42, 1.35, 2.25),
		baseCFrame * CFrame.new(0, 5.72, -0.15) * CFrame.Angles(0, math.rad(90), 0),
		IRON_EDGE,
		Enum.Material.Metal,
		model
	)
	crest.CanCollide = false

	createBossHealthDisplay(head)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("RestingTransparency", descendant.Transparency)
		end
	end

	return model, core
end

local function createBoundary(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	inwardNormal: Vector3
)
	local boundary = makePart(
		"Boundary",
		size,
		cframe,
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic,
		parent
	)
	boundary.Transparency = 1
	boundary.CastShadow = false
	boundary:SetAttribute("InwardNormal", inwardNormal)
end

local function createWallSegment(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	variation: number
)
	local wall = makePart(name, size, cframe, shade(STONE_MID, variation), Enum.Material.Limestone, parent)
	wall:SetAttribute("Architecture", "RuinedWall")

	local footing = makePart(
		name .. "Footing",
		Vector3.new(size.X + 0.7, 0.65, size.Z + 0.55),
		cframe * CFrame.new(0, -size.Y / 2 + 0.15, 0),
		shade(STONE_DARK, variation * 0.5),
		Enum.Material.Slate,
		parent
	)
	footing.CanTouch = false

	local cap = makePart(
		name .. "Cap",
		Vector3.new(size.X + 0.45, 0.45, size.Z + 0.35),
		cframe * CFrame.new(0, size.Y / 2 + 0.08, 0),
		shade(STONE_LIGHT, variation * 0.45),
		Enum.Material.Limestone,
		parent
	)
	cap.CanTouch = false
end

local function createStoneArch(
	parent: Instance,
	name: string,
	groundCFrame: CFrame,
	openingWidth: number,
	pillarHeight: number,
	depth: number
)
	local pillarWidth = 2.8
	local pillarOffset = openingWidth / 2 + pillarWidth / 2
	for _, side in ipairs({ -1, 1 }) do
		local variation = if side < 0 then -0.025 else 0.012
		createWallSegment(
			parent,
			name .. (if side < 0 then "LeftPier" else "RightPier"),
			Vector3.new(pillarWidth, pillarHeight, depth),
			groundCFrame * CFrame.new(side * pillarOffset, pillarHeight / 2, 0),
			variation
		)

		local buttress = makePart(
			name .. "Buttress",
			Vector3.new(2.1, pillarHeight * 0.68, depth + 1.6),
			groundCFrame * CFrame.new(side * (pillarOffset + 2.15), pillarHeight * 0.34, 0.45),
			STONE_DARK,
			Enum.Material.Slate,
			parent
		)
		buttress.CFrame *= CFrame.Angles(0, 0, math.rad(-side * 2.5))
	end

	local radius = openingWidth / 2 + 0.45
	for index, angle in ipairs({ -75, -50, -25, 0, 25, 50, 75 }) do
		local radians = math.rad(angle)
		local x = math.sin(radians) * radius
		local y = pillarHeight + math.cos(radians) * radius
		local block = makePart(
			name .. "ArchStone" .. tostring(index),
			Vector3.new(if angle == 0 then 3.35 else 3.0, if angle == 0 then 2.65 else 2.35, depth + 0.25),
			groundCFrame * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(-angle)),
			shade(STONE_LIGHT, ((index % 3) - 1) * 0.025),
			Enum.Material.Limestone,
			parent
		)
		block:SetAttribute("Architecture", "ArchStone")
	end
end

local function createColumn(
	parent: Instance,
	name: string,
	position: Vector3,
	height: number,
	yaw: number,
	broken: boolean
)
	local base = makePart(
		name .. "Base",
		Vector3.new(4.3, 0.75, 4.3),
		CFrame.new(position + Vector3.new(0, 0.38, 0)) * CFrame.Angles(0, math.rad(yaw), 0),
		STONE_DARK,
		Enum.Material.Slate,
		parent
	)
	base:SetAttribute("Architecture", "Column")

	local plinth = makePart(
		name .. "Plinth",
		Vector3.new(3.55, 0.65, 3.55),
		CFrame.new(position + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, math.rad(yaw + 3), 0),
		STONE_LIGHT,
		Enum.Material.Limestone,
		parent
	)
	plinth:SetAttribute("Architecture", "Column")

	local shaftHeight = math.max(2.5, height - 2.1)
	local lean = if broken then 2.8 else 0.5
	local shaft = makePart(
		name .. "Shaft",
		Vector3.new(2.65, shaftHeight, 2.65),
		CFrame.new(position + Vector3.new(0, 1.35 + shaftHeight / 2, 0))
			* CFrame.Angles(math.rad(if broken then -1.2 else 0), math.rad(yaw), math.rad(lean)),
		shade(STONE_MID, if broken then -0.02 else 0.02),
		Enum.Material.Limestone,
		parent
	)
	shaft:SetAttribute("Architecture", "Column")

	if not broken then
		local capital = makePart(
			name .. "Capital",
			Vector3.new(3.65, 0.75, 3.65),
			CFrame.new(position + Vector3.new(0, height - 0.4, 0)) * CFrame.Angles(0, math.rad(yaw - 2), 0),
			STONE_LIGHT,
			Enum.Material.Limestone,
			parent
		)
		capital:SetAttribute("Architecture", "Column")
	else
		local brokenTop = makeWedge(
			name .. "BrokenTop",
			Vector3.new(2.75, 1.15, 2.75),
			CFrame.new(position + Vector3.new(0, height - 0.35, 0)) * CFrame.Angles(0, math.rad(yaw + 30), 0),
			STONE_MID,
			Enum.Material.Limestone,
			parent
		)
		brokenTop:SetAttribute("Architecture", "Column")
	end
end

local function createBrazier(parent: Instance, name: string, position: Vector3)
	local base = makePart(
		name .. "Base",
		Vector3.new(3.2, 0.55, 3.2),
		CFrame.new(position + Vector3.new(0, 0.48, 0)),
		STONE_DARK,
		Enum.Material.Slate,
		parent
	)
	base:SetAttribute("Landmark", "Brazier")

	makePart(
		name .. "Pedestal",
		Vector3.new(1.7, 2.35, 1.7),
		CFrame.new(position + Vector3.new(0, 1.7, 0)),
		STONE_MID,
		Enum.Material.Limestone,
		parent
	)

	local bowl = makeVerticalCylinder(
		name .. "IronBowl",
		0.48,
		3.25,
		CFrame.new(position + Vector3.new(0, 3.0, 0)),
		IRON,
		Enum.Material.Metal,
		parent
	)
	bowl:SetAttribute("Landmark", "Brazier")

	local coals = makeVerticalCylinder(
		name .. "Coals",
		0.18,
		2.35,
		CFrame.new(position + Vector3.new(0, 3.3, 0)),
		Color3.fromRGB(70, 30, 21),
		Enum.Material.Slate,
		parent
	)
	makeDecorative(coals)

	local flame = makePart(
		name .. "Flame",
		Vector3.new(0.9, 1.65, 0.9),
		CFrame.new(position + Vector3.new(0.15, 4.05, 0)),
		EMBER,
		Enum.Material.Neon,
		parent
	)
	flame.Shape = Enum.PartType.Ball
	flame.Transparency = 0.08
	flame.CastShadow = false
	makeDecorative(flame)

	local flameCore = makePart(
		name .. "FlameCore",
		Vector3.new(0.42, 1.1, 0.42),
		CFrame.new(position + Vector3.new(-0.14, 3.95, 0.08)),
		EMBER_HOT,
		Enum.Material.Neon,
		parent
	)
	flameCore.Shape = Enum.PartType.Ball
	flameCore.CastShadow = false
	makeDecorative(flameCore)

	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = Color3.fromRGB(255, 151, 72)
	light.Brightness = 2.2
	light.Range = 18
	light.Shadows = false
	light.Parent = flame
end

local function createBanner(parent: Instance, name: string, cframe: CFrame)
	local cloth = makePart(
		name,
		Vector3.new(5.2, 7.1, 0.18),
		cframe,
		BANNER_RED,
		Enum.Material.Fabric,
		parent
	)
	makeDecorative(cloth)

	local lowerLeft = makePart(
		name .. "TailLeft",
		Vector3.new(2.45, 1.65, 0.18),
		cframe * CFrame.new(-1.35, -4.32, 0),
		shade(BANNER_RED, -0.025),
		Enum.Material.Fabric,
		parent
	)
	makeDecorative(lowerLeft)

	local lowerRight = makePart(
		name .. "TailRight",
		Vector3.new(2.45, 1.15, 0.18),
		cframe * CFrame.new(1.35, -4.07, 0),
		shade(BANNER_RED, 0.015),
		Enum.Material.Fabric,
		parent
	)
	makeDecorative(lowerRight)

	local emblem = makePart(
		name .. "Emblem",
		Vector3.new(1.45, 1.45, 0.08),
		cframe * CFrame.new(0, 0.25, 0.14) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(181, 127, 62),
		Enum.Material.Fabric,
		parent
	)
	makeDecorative(emblem)

	local rod = makePart(
		name .. "Rod",
		Vector3.new(6.25, 0.18, 0.18),
		cframe * CFrame.new(0, 3.72, 0),
		IRON,
		Enum.Material.Metal,
		parent
	)
	makeDecorative(rod)
end

local function buildFloor(parent: Instance)
	local floorSize = Config.Arena.FloorSize
	makePart(
		"MainFloor",
		Vector3.new(floorSize, 2, floorSize),
		CFrame.new(0, -1, 0),
		Color3.fromRGB(68, 61, 49),
		Enum.Material.Rock,
		parent
	)

	makePart(
		"CourtyardFoundation",
		Vector3.new(118, 0.38, 118),
		CFrame.new(0, 0.01, 0),
		MORTAR,
		Enum.Material.Cobblestone,
		parent
	)

	for row = -6, 6 do
		local rowOffset = if row % 2 == 0 then 0 else 5.2
		for column = -5, 5 do
			local x = column * 10.35 + rowOffset
			local z = row * 8.35
			local signature = (row * 37 + column * 23 + 301) % 29
			if math.abs(x) < 56 and signature ~= 0 and signature ~= 13 then
				local width = 9.8 - (signature % 4) * 0.18
				local depth = 7.85 - (signature % 3) * 0.16
				local rotation = ((signature % 5) - 2) * 0.65
				local heightOffset = ((signature % 4) - 1) * 0.012
				local paver = makePart(
					"WornPaver",
					Vector3.new(width, 0.2, depth),
					CFrame.new(x, 0.28 + heightOffset, z) * CFrame.Angles(0, math.rad(rotation), 0),
					shade(STONE_WARM, ((signature % 7) - 3) * 0.012),
					if signature % 5 == 0 then Enum.Material.Slate else Enum.Material.Limestone,
					parent
				)
				makeDecorative(paver)
			end
		end
	end

	for index, z in ipairs({ 35, 27, 19, 11, 3, -5, -13 }) do
		local direction = if index % 2 == 0 then -1 else 1
		local pathStone = makePart(
			"ProcessionalStone",
			Vector3.new(12.5 - (index % 3) * 0.55, 0.24, 6.6),
			CFrame.new(direction * 0.32, 0.42, z) * CFrame.Angles(0, math.rad(direction * (index % 3) * 0.8), 0),
			shade(STONE_LIGHT, -0.035 - index * 0.004),
			Enum.Material.Limestone,
			parent
		)
		makeDecorative(pathStone)
	end

	local sealOuter = makeVerticalCylinder(
		"CourtyardSealOuter",
		0.2,
		17,
		CFrame.new(0, 0.43, 3),
		STONE_DARK,
		Enum.Material.Slate,
		parent
	)
	makeDecorative(sealOuter)
	local sealInner = makeVerticalCylinder(
		"CourtyardSealInner",
		0.22,
		13.8,
		CFrame.new(0, 0.55, 3),
		STONE_WARM,
		Enum.Material.Limestone,
		parent
	)
	makeDecorative(sealInner)
	local sealHeart = makeVerticalCylinder(
		"CourtyardSealHeart",
		0.23,
		4.2,
		CFrame.new(0, 0.67, 3),
		BRONZE,
		Enum.Material.Metal,
		parent
	)
	makeDecorative(sealHeart)

	for index, crackData in ipairs({
		{ Vector3.new(-12, 0.52, 17), Vector3.new(9, 0.05, 0.22), -18 },
		{ Vector3.new(13, 0.52, 8), Vector3.new(7, 0.05, 0.18), 27 },
		{ Vector3.new(-18, 0.52, -9), Vector3.new(8.5, 0.05, 0.2), 12 },
		{ Vector3.new(19, 0.52, -20), Vector3.new(6, 0.05, 0.18), -31 },
		{ Vector3.new(-6, 0.7, 1), Vector3.new(5, 0.05, 0.16), 48 },
	}) do
		local crack = makePart(
			"StoneCrack" .. tostring(index),
			crackData[2] :: Vector3,
			CFrame.new(crackData[1] :: Vector3) * CFrame.Angles(0, math.rad(crackData[3] :: number), 0),
			Color3.fromRGB(47, 43, 37),
			Enum.Material.Slate,
			parent
		)
		makeDecorative(crack)
	end
end

local function buildArchitecture(parent: Instance)
	local floorSize = Config.Arena.FloorSize
	createBoundary(parent, Vector3.new(floorSize, 18, 2), CFrame.new(0, 9, -floorSize / 2), Vector3.new(0, 0, 1))
	createBoundary(parent, Vector3.new(floorSize, 18, 2), CFrame.new(0, 9, floorSize / 2), Vector3.new(0, 0, -1))
	createBoundary(parent, Vector3.new(2, 18, floorSize), CFrame.new(-floorSize / 2, 9, 0), Vector3.new(1, 0, 0))
	createBoundary(parent, Vector3.new(2, 18, floorSize), CFrame.new(floorSize / 2, 9, 0), Vector3.new(-1, 0, 0))

	local northSegments = {
		{ -53, 12, 9.5 },
		{ -40, 12, 12 },
		{ -27, 12, 8 },
		{ 27, 12, 10.5 },
		{ 40, 12, 7.5 },
		{ 53, 12, 11.5 },
	}
	for index, segment in ipairs(northSegments) do
		local x = segment[1]
		local width = segment[2]
		local height = segment[3]
		createWallSegment(
			parent,
			"NorthRuin" .. tostring(index),
			Vector3.new(width, height, 4),
			CFrame.new(x, height / 2, -63),
			((index % 4) - 2) * 0.018
		)
	end

	createStoneArch(parent, "WardenGate", CFrame.new(0, 0, -62.8), 12, 10, 4.6)
	createBanner(parent, "LeftWardenBanner", CFrame.new(-22.5, 9.4, -60.7))
	createBanner(parent, "RightWardenBanner", CFrame.new(22.5, 9.1, -60.7))

	local southSegments = {
		{ -52, 16, 7 },
		{ -34, 17, 9.5 },
		{ -18, 13, 6.5 },
		{ 19, 14, 8 },
		{ 35, 16, 6.5 },
		{ 52, 16, 9 },
	}
	for index, segment in ipairs(southSegments) do
		local x = segment[1]
		local width = segment[2]
		local height = segment[3]
		createWallSegment(
			parent,
			"SouthRuin" .. tostring(index),
			Vector3.new(width, height, 3.6),
			CFrame.new(x, height / 2, 63.5),
			((index % 3) - 1) * 0.02
		)
	end
	-- Keep the player entrance open so the third-person camera never sits inside a decorative arch.

	local sideZ = { -50, -36, -20, -4, 12, 28, 45, 57 }
	for index, z in ipairs(sideZ) do
		if index ~= 3 then
			local westHeight = 6.5 + ((index * 3) % 6)
			createWallSegment(
				parent,
				"WestRuin" .. tostring(index),
				Vector3.new(13.5, westHeight, 3.8),
				CFrame.new(-63.2, westHeight / 2, z) * CFrame.Angles(0, math.rad(90), 0),
				((index % 4) - 2) * 0.018
			)
		end

		if index ~= 2 then
			local eastHeight = 7.5 + ((index * 5) % 5)
			createWallSegment(
				parent,
				"EastRuin" .. tostring(index),
				Vector3.new(13.5, eastHeight, 3.8),
				CFrame.new(63.2, eastHeight / 2, z) * CFrame.Angles(0, math.rad(90), 0),
				((index % 3) - 1) * 0.02
			)
		end
	end

	createStoneArch(
		parent,
		"EastProcessionalArch",
		CFrame.new(63, 0, -36) * CFrame.Angles(0, math.rad(90), 0),
		8,
		7.5,
		4
	)

	createColumn(parent, "WestColumnA", Vector3.new(-51, 0, -43), 10.5, -4, false)
	createColumn(parent, "WestColumnB", Vector3.new(-52, 0, -19), 6.4, 8, true)
	createColumn(parent, "WestColumnC", Vector3.new(-53, 0, 22), 8.1, -11, true)
	createColumn(parent, "WestColumnD", Vector3.new(-51, 0, 45), 10, 3, false)
	createColumn(parent, "EastColumnA", Vector3.new(51, 0, -46), 11, 2, false)
	createColumn(parent, "EastColumnB", Vector3.new(52, 0, -16), 10.5, -2, false)
	createColumn(parent, "EastColumnC", Vector3.new(51, 0, 16), 7.2, 7, true)
	createColumn(parent, "EastColumnD", Vector3.new(52, 0, 43), 10.8, -4, false)
end

local function buildLandmarksAndDebris(parent: Instance)
	createBrazier(parent, "BossBrazierLeft", Vector3.new(-15, 0, -24))
	createBrazier(parent, "BossBrazierRight", Vector3.new(15, 0, -24))
	createBrazier(parent, "CourtyardBrazierWest", Vector3.new(-35, 0, 22))
	createBrazier(parent, "CourtyardBrazierEast", Vector3.new(35, 0, 22))

	local rubble: { RubbleData } = {
		{ position = Vector3.new(-56, 1.0, -14), size = Vector3.new(5.8, 1.7, 2.5), rotation = Vector3.new(12, 23, 6) },
		{ position = Vector3.new(-51, 0.65, -9), size = Vector3.new(3.0, 1.2, 2.4), rotation = Vector3.new(-8, 51, 17) },
		{ position = Vector3.new(-48, 0.55, 27), size = Vector3.new(2.7, 1.0, 3.5), rotation = Vector3.new(13, -19, 8) },
		{ position = Vector3.new(-57, 0.55, 34), size = Vector3.new(3.8, 1.0, 2.0), rotation = Vector3.new(-7, 34, -12) },
		{ position = Vector3.new(54, 0.8, 10), size = Vector3.new(4.4, 1.4, 2.2), rotation = Vector3.new(8, -31, 13) },
		{ position = Vector3.new(48, 0.5, 18), size = Vector3.new(2.4, 0.9, 2.8), rotation = Vector3.new(17, 11, -8) },
		{ position = Vector3.new(44, 0.55, -48), size = Vector3.new(3.3, 1.0, 2.0), rotation = Vector3.new(-12, 64, 9) },
		{ position = Vector3.new(-37, 0.55, -51), size = Vector3.new(3.6, 1.1, 2.5), rotation = Vector3.new(7, 38, -14) },
		{ position = Vector3.new(26, 0.5, 51), size = Vector3.new(2.9, 0.85, 2.1), rotation = Vector3.new(11, -46, 8) },
		{ position = Vector3.new(-30, 0.48, 52), size = Vector3.new(2.4, 0.8, 3.2), rotation = Vector3.new(-9, 27, 12) },
	}

	for index, item in ipairs(rubble) do
		local rubblePart = makePart(
			"Rubble" .. tostring(index),
			item.size,
			CFrame.new(item.position)
				* CFrame.Angles(
					math.rad(item.rotation.X),
					math.rad(item.rotation.Y),
					math.rad(item.rotation.Z)
				),
			shade(STONE_MID, ((index % 5) - 2) * 0.018),
			if index % 3 == 0 then Enum.Material.Slate else Enum.Material.Limestone,
			parent
		)
		makeDecorative(rubblePart)
	end

	for index, data in ipairs({
		{ Vector3.new(-54, 1.25, -4), 6.2, 2.4, 18 },
		{ Vector3.new(-49, 1.05, -0.5), 4.8, 2.2, 26 },
		{ Vector3.new(52, 1.0, 31), 5.4, 2.1, -21 },
	}) do
		local segment = makePart(
			"FallenColumn" .. tostring(index),
			Vector3.new(data[2] :: number, data[3] :: number, data[3] :: number),
			CFrame.new(data[1] :: Vector3) * CFrame.Angles(0, math.rad(data[4] :: number), math.rad(4)),
			STONE_LIGHT,
			Enum.Material.Limestone,
			parent
		)
		segment.Shape = Enum.PartType.Cylinder
		makeDecorative(segment)
	end
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
	if oldArena ~= nil then
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
	configureLighting()
	buildFloor(self._geometry)
	buildArchitecture(self._geometry)
	buildLandmarksAndDebris(self._geometry)

	local spawnDais = makePart(
		"SpawnDais",
		Vector3.new(17, 0.52, 12),
		CFrame.new(Config.Arena.SpawnCFrame.Position - Vector3.new(0, 4.72, 0)),
		STONE_LIGHT,
		Enum.Material.Limestone,
		self._geometry
	)
	spawnDais:SetAttribute("Landmark", "PlayerEntry")

	local spawnStep = makePart(
		"SpawnStep",
		Vector3.new(14, 0.28, 4),
		CFrame.new(0, 0.28, Config.Arena.SpawnCFrame.Position.Z - 7.3),
		STONE_MID,
		Enum.Material.Limestone,
		self._geometry
	)
	spawnStep:SetAttribute("Landmark", "PlayerEntry")

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ShowcaseSpawn"
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.CanQuery = false
	spawnLocation.CanTouch = false
	spawnLocation.Neutral = true
	spawnLocation.Enabled = true
	spawnLocation.Duration = 0
	spawnLocation.Size = Vector3.new(10, 0.4, 8)
	spawnLocation.CFrame = CFrame.new(Config.Arena.SpawnCFrame.Position - Vector3.new(0, 4.5, 0))
	spawnLocation.Transparency = 1
	spawnLocation.CastShadow = false
	spawnLocation.Parent = self._geometry
	self._spawnLocation = spawnLocation

	local bossGroundPosition = Config.Arena.BossCFrame.Position - Vector3.new(0, 4.62, 0)
	local bossPlatform = makeVerticalCylinder(
		"BossPlatform",
		0.58,
		25,
		CFrame.new(bossGroundPosition),
		STONE_DARK,
		Enum.Material.Slate,
		self._geometry
	)
	bossPlatform:SetAttribute("BossPlatform", true)

	local bossPlatformInset = makeVerticalCylinder(
		"BossPlatformInset",
		0.24,
		20.5,
		CFrame.new(bossGroundPosition + Vector3.new(0, 0.38, 0)),
		STONE_WARM,
		Enum.Material.Limestone,
		self._geometry
	)
	makeDecorative(bossPlatformInset)

	local bossSpawn = makePart(
		"BossSpawn",
		Vector3.new(1, 1, 1),
		Config.Arena.BossCFrame,
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic,
		self._geometry
	)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn.CastShadow = false
	bossSpawn:SetAttribute("BossSpawn", true)

	local bossModel, bossCore = createBoss(self._root)
	self._bossModel = bossModel
	self._bossCore = bossCore
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
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		rootPart.CFrame = self:GetSpawnCFrame()
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

function ArenaService:UpdateBossHealth(health: number, maximumHealth: number)
	self._bossModel:SetAttribute("Health", health)
	self._bossModel:SetAttribute("MaximumHealth", maximumHealth)

	local head = self._bossModel:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local healthBillboard = head:FindFirstChild("HealthBillboard")
	if healthBillboard == nil or not healthBillboard:IsA("BillboardGui") then
		return
	end

	local container = healthBillboard:FindFirstChild("Container")
	if container == nil or not container:IsA("Frame") then
		return
	end

	local healthText = container:FindFirstChild("HealthText")
	if healthText ~= nil and healthText:IsA("TextLabel") then
		healthText.Text = string.format("%d / %d", math.max(0, math.floor(health)), maximumHealth)
	end

	local barBackground = container:FindFirstChild("BarBackground")
	if barBackground ~= nil and barBackground:IsA("Frame") then
		local barFill = barBackground:FindFirstChild("BarFill")
		if barFill ~= nil and barFill:IsA("Frame") then
			barFill.Size = UDim2.fromScale(math.clamp(health / maximumHealth, 0, 1), 1)
		end
	end
end

function ArenaService:SetBossEnabled(enabled: boolean)
	for _, descendant in ipairs(self._bossModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "Hitbox" then
			local restingTransparency = descendant:GetAttribute("RestingTransparency")
			local visibleTransparency = if typeof(restingTransparency) == "number" then restingTransparency else 0
			descendant.Transparency = if enabled then visibleTransparency else math.max(visibleTransparency, 0.66)
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = enabled
		end
	end
end

return ArenaService
