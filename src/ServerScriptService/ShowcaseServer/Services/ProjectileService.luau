--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("Config"))
local MathUtil = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("MathUtil"))

local ProjectileService = {}
ProjectileService.__index = ProjectileService

type ProjectileRecord = {
	id: number,
	part: Part,
	position: Vector3,
	velocity: Vector3,
	createdAt: number,
	target: Player?,
	reflector: Player?,
	reflected: boolean,
}

type InternalProjectileService = {
	_remotes: any,
	_arena: any,
	_combatService: any,
	_enemyService: any?,
	_projectiles: { [number]: ProjectileRecord },
	_nextId: number,
	_heartbeatConnection: RBXScriptConnection,
}

export type ProjectileService = typeof(setmetatable({} :: InternalProjectileService, ProjectileService))

local function getAliveRoot(player: Player?): BasePart?
	if player == nil then
		return nil
	end

	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function createProjectilePart(parent: Instance, id: number, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = string.format("Projectile_%d", id)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.35, 1.35, 1.35)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(58, 30, 24)
	part.CFrame = CFrame.new(position)
	part.Parent = parent

	local ember = Instance.new("Highlight")
	ember.Name = "Ember"
	ember.Adornee = part
	ember.DepthMode = Enum.HighlightDepthMode.Occluded
	ember.FillColor = Config.Palette.Danger
	ember.FillTransparency = 0.42
	ember.OutlineTransparency = 1
	ember.Parent = part

	local frontAttachment = Instance.new("Attachment")
	frontAttachment.Name = "Front"
	frontAttachment.Position = Vector3.new(0, 0, 0.38)
	frontAttachment.Parent = part

	local backAttachment = Instance.new("Attachment")
	backAttachment.Name = "Back"
	backAttachment.Position = Vector3.new(0, 0, -0.38)
	backAttachment.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Attachment0 = frontAttachment
	trail.Attachment1 = backAttachment
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Palette.Danger),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(205, 105, 49)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 48, 34)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 0.35
	trail.Lifetime = 0.32
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = Color3.fromRGB(214, 98, 48)
	light.Brightness = 1.45
	light.Range = 9
	light.Shadows = false
	light.Parent = part

	return part
end

function ProjectileService.new(remotes: any, arena: any, combatService: any): ProjectileService
	local self = setmetatable({
		_remotes = remotes,
		_arena = arena,
		_combatService = combatService,
		_enemyService = nil,
		_projectiles = {},
		_nextId = 0,
		_heartbeatConnection = nil :: any,
	}, ProjectileService)

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_step(deltaTime)
	end)

	return self
end

function ProjectileService:SetEnemyService(enemyService: any)
	self._enemyService = enemyService
end

function ProjectileService:Launch(target: Player, origin: Vector3): boolean
	local targetRoot = getAliveRoot(target)
	if targetRoot == nil then
		return false
	end

	self._nextId += 1
	local projectileId = self._nextId
	local direction = MathUtil.SafeUnit(targetRoot.Position - origin, Vector3.new(0, 0, 1))
	local part = createProjectilePart(self._arena:GetProjectileFolder(), projectileId, origin)

	self._projectiles[projectileId] = {
		id = projectileId,
		part = part,
		position = origin,
		velocity = direction * Config.Projectile.Speed,
		createdAt = os.clock(),
		target = target,
		reflector = nil,
		reflected = false,
	}

	self._remotes.Effect:FireAllClients({
		type = "ProjectileLaunched",
		projectileId = projectileId,
		position = origin,
		targetUserId = target.UserId,
	})

	return true
end

function ProjectileService:_remove(projectileId: number)
	local record = self._projectiles[projectileId]
	if record == nil then
		return
	end

	self._projectiles[projectileId] = nil
	if record.part.Parent ~= nil then
		record.part:Destroy()
	end
end

function ProjectileService:_reflect(record: ProjectileRecord, player: Player, atPosition: Vector3)
	local enemyService = self._enemyService
	if enemyService == nil or not enemyService:IsAlive() then
		self:_remove(record.id)
		return
	end

	record.reflected = true
	record.reflector = player
	record.target = nil
	record.position = atPosition
	record.velocity = MathUtil.SafeUnit(enemyService:GetPosition() - atPosition, Vector3.new(0, 0, -1))
		* Config.Projectile.Speed
		* Config.Projectile.ReflectedSpeedMultiplier

	record.part.Color = Color3.fromRGB(76, 58, 30)
	local trail = record.part:FindFirstChild("Trail")
	if trail and trail:IsA("Trail") then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Palette.Warning),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(236, 190, 96)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 68, 38)),
		})
	end

	local light = record.part:FindFirstChild("Glow")
	if light and light:IsA("PointLight") then
		light.Color = Color3.fromRGB(238, 181, 78)
	end

	local ember = record.part:FindFirstChild("Ember")
	if ember and ember:IsA("Highlight") then
		ember.FillColor = Config.Palette.Warning
	end

	self._remotes.Effect:FireAllClients({
		type = "ProjectileReflected",
		projectileId = record.id,
		userId = player.UserId,
		position = atPosition,
	})
end

function ProjectileService:_createWorldRaycastParams(): RaycastParams
	local excluded: { Instance } = { self._arena:GetProjectileFolder() }

	local enemyService = self._enemyService
	if enemyService ~= nil then
		table.insert(excluded, enemyService:GetModel())
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil then
			table.insert(excluded, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	return params
end

function ProjectileService:_step(deltaTime: number)
	local now = os.clock()
	local stepDelta = math.min(deltaTime, 0.1)
	local removeIds: { number } = {}
	local worldRaycastParams = self:_createWorldRaycastParams()

	for projectileId, record in pairs(self._projectiles) do
		if now - record.createdAt >= Config.Projectile.Lifetime then
			table.insert(removeIds, projectileId)
			continue
		end

		local targetPosition: Vector3?
		if record.reflected then
			local enemyService = self._enemyService
			if enemyService ~= nil and enemyService:IsAlive() then
				targetPosition = enemyService:GetPosition()
			end
		else
			local targetRoot = getAliveRoot(record.target)
			if targetRoot ~= nil then
				targetPosition = targetRoot.Position + Vector3.new(0, 1.6, 0)
			end
		end

		if targetPosition == nil then
			table.insert(removeIds, projectileId)
			continue
		end

		local desiredDirection = MathUtil.SafeUnit(targetPosition - record.position, record.velocity.Unit)
		local desiredSpeed = Config.Projectile.Speed
		if record.reflected then
			desiredSpeed *= Config.Projectile.ReflectedSpeedMultiplier
		end

		local desiredVelocity = desiredDirection * desiredSpeed
		local homingAlpha = math.clamp(Config.Projectile.HomingStrength * stepDelta, 0, 1)
		record.velocity = record.velocity:Lerp(desiredVelocity, homingAlpha)

		local oldPosition = record.position
		local newPosition = oldPosition + record.velocity * stepDelta
		local worldHit = Workspace:Raycast(oldPosition, newPosition - oldPosition, worldRaycastParams)
		if worldHit ~= nil then
			record.position = worldHit.Position
			record.part.CFrame = CFrame.new(worldHit.Position)
			self._remotes.Effect:FireAllClients({
				type = "ProjectileBlocked",
				position = worldHit.Position,
			})
			table.insert(removeIds, projectileId)
			continue
		end

		record.position = newPosition
		local facing = MathUtil.SafeUnit(record.velocity, Vector3.new(0, 0, -1))
		record.part.CFrame = CFrame.lookAt(newPosition, newPosition + facing)

		if record.reflected then
			local enemyService = self._enemyService
			if enemyService ~= nil and enemyService:IsAlive() then
				local bossPosition = enemyService:GetPosition()
				local distance = MathUtil.DistancePointToSegment(bossPosition, oldPosition, newPosition)
				if distance <= Config.Projectile.HitRadius + 3 then
					enemyService:TakeDamage(
						Config.Projectile.ReflectedDamage,
						record.reflector,
						"ReflectedProjectile"
					)
					self._remotes.Effect:FireAllClients({
						type = "ReflectedProjectileHit",
						position = bossPosition,
						amount = Config.Projectile.ReflectedDamage,
					})
					table.insert(removeIds, projectileId)
				end
			end
		else
			local target = record.target
			local targetRoot = getAliveRoot(target)
			if target ~= nil and targetRoot ~= nil then
				local collisionPosition = targetRoot.Position + Vector3.new(0, 1.4, 0)
				local closestPosition = MathUtil.ClosestPointOnSegment(collisionPosition, oldPosition, newPosition)
				local distance = (collisionPosition - closestPosition).Magnitude
				if distance <= Config.Projectile.HitRadius then
					if self._combatService:TryConsumeParry(target, closestPosition) then
						self:_reflect(record, target, closestPosition)
					else
						self._combatService:DamagePlayer(target, Config.Projectile.PlayerDamage, "Projectile")
						table.insert(removeIds, projectileId)
					end
				end
			end
		end
	end

	for _, projectileId in ipairs(removeIds) do
		self:_remove(projectileId)
	end
end

function ProjectileService:Clear()
	local ids: { number } = {}
	for projectileId in pairs(self._projectiles) do
		table.insert(ids, projectileId)
	end

	for _, projectileId in ipairs(ids) do
		self:_remove(projectileId)
	end
end

function ProjectileService:Destroy()
	self._heartbeatConnection:Disconnect()
	self:Clear()
end

return ProjectileService
