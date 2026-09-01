--!strict

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
	_spawn: SpawnLocation,
}

export type ArenaService = typeof(setmetatable({} :: InternalArenaService, ArenaService))

local function requireChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	assert(child ~= nil, string.format("[ArenaService] Missing static arena node %s.%s", parent:GetFullName(), name))
	assert(child:IsA(className), string.format(
		"[ArenaService] %s must be a %s, got %s",
		child:GetFullName(),
		className,
		child.ClassName
	))
	return child
end

function ArenaService.new(): ArenaService
	local arenaInstance = Workspace:WaitForChild(Config.Arena.ModelName, 10)
	assert(arenaInstance ~= nil and arenaInstance:IsA("Model"), string.format(
		"[ArenaService] Static Workspace model %q is required. Build it in Studio before running.",
		Config.Arena.ModelName
	))

	local root = arenaInstance :: Model
	local geometry = requireChild(root, "Geometry", "Folder") :: Folder
	local projectiles = requireChild(root, "Projectiles", "Folder") :: Folder
	local bossModel = requireChild(root, Config.Enemy.Name, "Model") :: Model
	local bossCore = requireChild(bossModel, "Core", "BasePart") :: BasePart
	local spawn = requireChild(geometry, "ShowcaseSpawn", "SpawnLocation") :: SpawnLocation

	for _, staleProjectile in ipairs(projectiles:GetChildren()) do
		staleProjectile:Destroy()
	end

	return setmetatable({
		_root = root,
		_geometry = geometry,
		_projectiles = projectiles,
		_bossModel = bossModel,
		_bossCore = bossCore,
		_spawn = spawn,
	} :: InternalArenaService, ArenaService)
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
	local heightAttribute = self._spawn:GetAttribute("CharacterSpawnHeight")
	local yawAttribute = self._spawn:GetAttribute("CharacterSpawnYawDegrees")
	local height = if typeof(heightAttribute) == "number" then heightAttribute else 4.5
	local yawDegrees = if typeof(yawAttribute) == "number" then yawAttribute else 180

	return self._spawn.CFrame
		* CFrame.new(0, height, 0)
		* CFrame.Angles(0, math.rad(yawDegrees), 0)
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
