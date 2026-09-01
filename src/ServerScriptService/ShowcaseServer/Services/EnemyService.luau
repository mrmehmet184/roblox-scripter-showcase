--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ShowcaseShared")
local Config = require(Shared:WaitForChild("Config"))
local MathUtil = require(Shared:WaitForChild("MathUtil"))
local StateMachine = require(Shared:WaitForChild("StateMachine"))
local Types = require(ReplicatedStorage.ShowcaseShared.Types)

type BossSnapshot = Types.BossSnapshot

local EnemyService = {}
EnemyService.__index = EnemyService

type InternalEnemyService = {
	_remotes: any,
	_arena: any,
	_projectileService: any,
	_combatService: any,
	_matchService: any,
	_model: Model,
	_machine: any,
	_health: number,
	_maximumHealth: number,
	_active: boolean,
	_alive: boolean,
	_running: boolean,
	_attackIndex: number,
	_sequenceId: number,
	_currentTarget: Player?,
}

export type EnemyService = typeof(setmetatable({} :: InternalEnemyService, EnemyService))

local TRANSITIONS = {
	Dormant = { Acquiring = true, Defeated = true },
	Acquiring = { Telegraph = true, Dormant = true, Defeated = true },
	Telegraph = { ProjectileVolley = true, GroundSlam = true, Dormant = true, Defeated = true },
	ProjectileVolley = { Recovery = true, Dormant = true, Defeated = true },
	GroundSlam = { Recovery = true, Dormant = true, Defeated = true },
	Recovery = { Acquiring = true, Dormant = true, Defeated = true },
	Defeated = { Dormant = true },
}

local function getAliveRoot(player: Player): BasePart?
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

function EnemyService.new(
	remotes: any,
	arena: any,
	projectileService: any,
	combatService: any,
	matchService: any
): EnemyService
	local machine = StateMachine.new("Dormant", TRANSITIONS)

	local self = setmetatable({
		_remotes = remotes,
		_arena = arena,
		_projectileService = projectileService,
		_combatService = combatService,
		_matchService = matchService,
		_model = arena:GetBossModel(),
		_machine = machine,
		_health = Config.Enemy.MaximumHealth,
		_maximumHealth = Config.Enemy.MaximumHealth,
		_active = false,
		_alive = true,
		_running = true,
		_attackIndex = 0,
		_sequenceId = 0,
		_currentTarget = nil,
	}, EnemyService)

	machine:Connect(function()
		self:_broadcastSnapshot()
	end)

	self:_updateHealthPresentation()
	self:_broadcastSnapshot()

	task.spawn(function()
		self:_runBehaviorLoop()
	end)

	return self
end

function EnemyService:_isSequenceValid(sequenceId: number): boolean
	return self._running and self._active and self._alive and self._sequenceId == sequenceId
end

function EnemyService:_selectTarget(): Player?
	local bossPosition = self:GetPosition()
	local bestTarget: Player? = nil
	local bestDistance = Config.Enemy.TargetRange

	for _, player in ipairs(Players:GetPlayers()) do
		local rootPart = getAliveRoot(player)
		if rootPart ~= nil then
			local distance = (rootPart.Position - bossPosition).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestTarget = player
			end
		end
	end

	return bestTarget
end

function EnemyService:_transition(nextState: string)
	if not self._machine:Transition(nextState) then
		self._machine:Force(nextState)
	end
end

function EnemyService:_runBehaviorLoop()
	while self._running do
		if not self._active or not self._alive then
			task.wait(0.15)
			continue
		end

		self:_transition("Acquiring")
		local target = self:_selectTarget()
		self._currentTarget = target
		self:_broadcastSnapshot()

		if target == nil then
			task.wait(0.3)
			continue
		end

		local sequenceId = self._sequenceId
		self._attackIndex += 1

		if self._attackIndex % 2 == 1 then
			self:_performProjectileVolley(target, sequenceId)
		else
			self:_performGroundSlam(sequenceId)
		end

		if self:_isSequenceValid(sequenceId) then
			self:_transition("Recovery")
			task.wait(Config.Enemy.RecoveryDuration)
		end
	end
end

function EnemyService:_performProjectileVolley(initialTarget: Player, sequenceId: number)
	self:_transition("Telegraph")
	self._remotes.Effect:FireAllClients({
		type = "BossTelegraph",
		attack = "PROJECTILE VOLLEY",
		duration = Config.Enemy.ProjectileTelegraphDuration,
		position = self:GetPosition(),
	})

	task.wait(Config.Enemy.ProjectileTelegraphDuration)
	if not self:_isSequenceValid(sequenceId) then
		return
	end

	self:_transition("ProjectileVolley")
	local target = initialTarget

	for projectileIndex = 1, Config.Enemy.ProjectileCount do
		if not self:_isSequenceValid(sequenceId) then
			return
		end

		if getAliveRoot(target) == nil then
			local replacement = self:_selectTarget()
			if replacement == nil then
				return
			end
			target = replacement
			self._currentTarget = target
			self:_broadcastSnapshot()
		end

		local horizontalOffset = (projectileIndex - (Config.Enemy.ProjectileCount + 1) / 2) * 0.45
		local origin = self._arena:GetBossOrigin() + Vector3.new(horizontalOffset, 0, 0)
		self._projectileService:Launch(target, origin)
		task.wait(Config.Enemy.ProjectileLaunchInterval)
	end
end

function EnemyService:_performGroundSlam(sequenceId: number)
	local bossPosition = self:GetPosition()
	self:_transition("Telegraph")
	self._remotes.Effect:FireAllClients({
		type = "SlamTelegraph",
		position = Vector3.new(bossPosition.X, 0.8, bossPosition.Z),
		radius = Config.Enemy.GroundSlamRadius,
		duration = Config.Enemy.GroundSlamTelegraphDuration,
	})

	task.wait(Config.Enemy.GroundSlamTelegraphDuration)
	if not self:_isSequenceValid(sequenceId) then
		return
	end

	self:_transition("GroundSlam")

	for _, player in ipairs(Players:GetPlayers()) do
		local rootPart = getAliveRoot(player)
		if rootPart ~= nil then
			local horizontalOffset = Vector3.new(
				rootPart.Position.X - bossPosition.X,
				0,
				rootPart.Position.Z - bossPosition.Z
			)

			if horizontalOffset.Magnitude <= Config.Enemy.GroundSlamRadius then
				self._combatService:DamagePlayer(player, Config.Enemy.GroundSlamDamage, "GroundSlam")

				local pushDirection = if horizontalOffset.Magnitude > 0.01
					then horizontalOffset.Unit
					else Vector3.new(0, 0, 1)
				rootPart.AssemblyLinearVelocity = pushDirection * 34 + Vector3.new(0, 18, 0)
			end
		end
	end

	self._remotes.Effect:FireAllClients({
		type = "SlamImpact",
		position = Vector3.new(bossPosition.X, 0.8, bossPosition.Z),
		radius = Config.Enemy.GroundSlamRadius,
	})

	task.wait(0.22)
end

function EnemyService:_updateHealthPresentation()
	self._arena:UpdateBossHealth(self._health, self._maximumHealth)
end

function EnemyService:_broadcastSnapshot()
	local targetName: string? = nil
	if self._currentTarget ~= nil and self._currentTarget.Parent ~= nil then
		targetName = self._currentTarget.Name
	end

	self._remotes.StateUpdate:FireAllClients({
		kind = "Boss",
		name = Config.Enemy.Name,
		state = self._machine:GetState(),
		health = self._health,
		maximumHealth = self._maximumHealth,
		targetName = targetName,
		alive = self._alive,
	})
end

function EnemyService:Reset()
	self._sequenceId += 1
	self._active = false
	self._alive = true
	self._health = self._maximumHealth
	self._attackIndex = 0
	self._currentTarget = nil
	self._projectileService:Clear()
	self._machine:Force("Dormant")
	self._arena:SetBossEnabled(true)
	self:_updateHealthPresentation()
	self:_broadcastSnapshot()
end

function EnemyService:SetActive(active: boolean)
	if self._active == active then
		return
	end

	self._sequenceId += 1
	self._active = active and self._alive

	if self._active then
		self:_transition("Acquiring")
	else
		self._currentTarget = nil
		self._projectileService:Clear()
		if self._alive then
			self._machine:Force("Dormant")
		end
	end

	self:_broadcastSnapshot()
end

function EnemyService:TakeDamage(amount: number, sourcePlayer: Player?, source: string): boolean
	if not self._active or not self._alive then
		return false
	end

	if amount <= 0 or not MathUtil.IsFiniteNumber(amount) then
		return false
	end

	local finalAmount = math.clamp(amount, 0, 500)
	self._health = math.max(0, self._health - finalAmount)
	self:_updateHealthPresentation()
	self:_broadcastSnapshot()

	self._remotes.Effect:FireAllClients({
		type = "BossDamaged",
		position = self:GetPosition() + Vector3.new(0, 3.5, 0),
		amount = finalAmount,
		source = source,
		sourceUserId = if sourcePlayer ~= nil then sourcePlayer.UserId else 0,
	})

	if self._health <= 0 then
		self:_defeat(sourcePlayer)
	end

	return true
end

function EnemyService:_defeat(sourcePlayer: Player?)
	if not self._alive then
		return
	end

	self._sequenceId += 1
	self._active = false
	self._alive = false
	self._currentTarget = nil
	self._projectileService:Clear()
	self._machine:Force("Defeated")
	self._arena:SetBossEnabled(false)
	self:_broadcastSnapshot()

	self._remotes.Effect:FireAllClients({
		type = "BossDefeated",
		position = self:GetPosition(),
		userId = if sourcePlayer ~= nil then sourcePlayer.UserId else 0,
	})

	self._matchService:OnBossDefeated(sourcePlayer)
end

function EnemyService:GetPosition(): Vector3
	return self._model:GetPivot().Position
end

function EnemyService:GetModel(): Model
	return self._model
end

function EnemyService:IsAlive(): boolean
	return self._alive
end

function EnemyService:GetSnapshot(): BossSnapshot
	local targetName: string? = nil
	if self._currentTarget ~= nil and self._currentTarget.Parent ~= nil then
		targetName = self._currentTarget.Name
	end

	return {
		name = Config.Enemy.Name,
		state = self._machine:GetState(),
		health = self._health,
		maximumHealth = self._maximumHealth,
		targetName = targetName,
		alive = self._alive,
	}
end

function EnemyService:Destroy()
	self._running = false
	self._active = false
	self._sequenceId += 1
	self._projectileService:Clear()
end

return EnemyService
