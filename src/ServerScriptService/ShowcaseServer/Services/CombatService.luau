--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("ShowcaseShared")
local Config = require(Shared:WaitForChild("Config"))
local Janitor = require(Shared:WaitForChild("Janitor"))
local MathUtil = require(Shared:WaitForChild("MathUtil"))
local Types = require(ReplicatedStorage.ShowcaseShared.Types)

type TelemetrySnapshot = Types.TelemetrySnapshot

local CombatService = {}
CombatService.__index = CombatService

type PlayerCombatState = {
	lastAttackAt: number,
	parryUntil: number,
	parryCooldownUntil: number,
}

type PlayerTelemetry = {
	accepted: number,
	rejected: number,
	lastEvent: string,
}

type InternalCombatService = {
	_remotes: any,
	_rateLimiter: any,
	_matchService: any,
	_enemyService: any?,
	_playerStates: { [Player]: PlayerCombatState },
	_telemetry: { [Player]: PlayerTelemetry },
	_janitor: any,
}

export type CombatService = typeof(setmetatable({} :: InternalCombatService, CombatService))

local function getCharacterState(player: Player): (Model?, Humanoid?, BasePart?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")

	if humanoid == nil or humanoid.Health <= 0 then
		return character, humanoid, nil, nil
	end

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return character, humanoid, nil, nil
	end

	if head == nil or not head:IsA("BasePart") then
		return character, humanoid, rootPart, nil
	end

	return character, humanoid, rootPart, head
end

function CombatService.new(remotes: any, rateLimiter: any, matchService: any): CombatService
	local self = setmetatable({
		_remotes = remotes,
		_rateLimiter = rateLimiter,
		_matchService = matchService,
		_enemyService = nil,
		_playerStates = {},
		_telemetry = {},
		_janitor = Janitor.new(),
	}, CombatService)

	self._janitor:Add(remotes.ActionRequest.OnServerEvent:Connect(function(player: Player, actionName: any, payload: any)
		self:_onActionRequest(player, actionName, payload)
	end))

	self._janitor:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._playerStates[player] = nil
		self._telemetry[player] = nil
		self._rateLimiter:Forget(player)
	end))

	return self
end

function CombatService:SetEnemyService(enemyService: any)
	self._enemyService = enemyService
end

function CombatService:_getPlayerState(player: Player): PlayerCombatState
	local state = self._playerStates[player]
	if state == nil then
		state = {
			lastAttackAt = -math.huge,
			parryUntil = -math.huge,
			parryCooldownUntil = -math.huge,
		}
		self._playerStates[player] = state
	end

	return state
end

function CombatService:_getTelemetry(player: Player): PlayerTelemetry
	local telemetry = self._telemetry[player]
	if telemetry == nil then
		telemetry = {
			accepted = 0,
			rejected = 0,
			lastEvent = "Awaiting input",
		}
		self._telemetry[player] = telemetry
	end

	return telemetry
end

function CombatService:_pushTelemetry(player: Player)
	local telemetry = self:_getTelemetry(player)
	self._remotes.StateUpdate:FireClient(player, {
		kind = "Telemetry",
		accepted = telemetry.accepted,
		rejected = telemetry.rejected,
		lastEvent = telemetry.lastEvent,
	})
end

function CombatService:_accept(player: Player, eventName: string)
	local telemetry = self:_getTelemetry(player)
	telemetry.accepted += 1
	telemetry.lastEvent = string.format("ACCEPTED // %s", eventName)
	self:_pushTelemetry(player)
end

function CombatService:_reject(player: Player, reason: string)
	local telemetry = self:_getTelemetry(player)
	telemetry.rejected += 1
	telemetry.lastEvent = string.format("REJECTED // %s", reason)
	self:_pushTelemetry(player)
end

function CombatService:_onActionRequest(player: Player, actionName: any, payload: any)
	if typeof(actionName) ~= "string" then
		self:_reject(player, "invalid action type")
		return
	end

	if not self._rateLimiter:Allow(
		player,
		"ActionRequest",
		Config.Networking.MaximumActionsPerSecond,
		Config.Networking.ActionWindowSeconds
	) then
		self:_reject(player, "rate limit")
		return
	end

	if actionName == "Attack" then
		self:_handleAttack(player, payload)
	elseif actionName == "Parry" then
		self:_handleParry(player)
	else
		self:_reject(player, "unknown action")
	end
end

function CombatService:_handleAttack(player: Player, payload: any)
	if not self._matchService:IsActive() then
		self:_reject(player, "match inactive")
		return
	end

	local character, _, rootPart, head = getCharacterState(player)
	if character == nil or rootPart == nil or head == nil then
		self:_reject(player, "character unavailable")
		return
	end

	if typeof(payload) ~= "table" then
		self:_reject(player, "invalid payload")
		return
	end

	local rawDirection = payload.direction
	if typeof(rawDirection) ~= "Vector3" then
		self:_reject(player, "direction missing")
		return
	end

	if not MathUtil.IsFiniteVector3(rawDirection) then
		self:_reject(player, "non-finite direction")
		return
	end

	local magnitude = rawDirection.Magnitude
	if magnitude < Config.Combat.MinimumDirectionMagnitude or magnitude > Config.Combat.MaximumDirectionMagnitude then
		self:_reject(player, "direction magnitude")
		return
	end

	local state = self:_getPlayerState(player)
	local now = os.clock()
	if now - state.lastAttackAt < Config.Combat.AttackCooldown then
		self:_reject(player, "attack cooldown")
		return
	end
	state.lastAttackAt = now

	local direction = rawDirection.Unit
	local origin = head.Position
	local hitPosition = origin + direction * Config.Combat.AttackRange
	local hitEnemy = false

	local enemyService = self._enemyService
	if enemyService ~= nil and enemyService:IsAlive() then
		local bossPosition = enemyService:GetPosition()
		local offset = bossPosition - origin
		local distance = offset.Magnitude

		if distance <= Config.Combat.AttackRange then
			local towardBoss = MathUtil.SafeUnit(offset, direction)
			if direction:Dot(towardBoss) >= Config.Combat.AttackConeDot then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = { character }
				raycastParams.IgnoreWater = true

				local result = Workspace:Raycast(origin, offset, raycastParams)
				local bossModel = enemyService:GetModel()
				if result == nil or result.Instance:IsDescendantOf(bossModel) then
					hitEnemy = true
					hitPosition = bossPosition
					enemyService:TakeDamage(Config.Combat.AttackDamage, player, "Melee")
				end
			end
		end
	end

	self._remotes.Effect:FireAllClients({
		type = "Attack",
		userId = player.UserId,
		origin = origin,
		direction = direction,
		range = Config.Combat.AttackRange,
		hit = hitEnemy,
		hitPosition = hitPosition,
	})

	self:_accept(player, if hitEnemy then "melee hit" else "melee swing")
end

function CombatService:_handleParry(player: Player)
	if not self._matchService:IsActive() then
		self:_reject(player, "match inactive")
		return
	end

	local _, _, rootPart = getCharacterState(player)
	if rootPart == nil then
		self:_reject(player, "character unavailable")
		return
	end

	local state = self:_getPlayerState(player)
	local now = os.clock()
	if now < state.parryCooldownUntil then
		self:_reject(player, "parry cooldown")
		return
	end

	state.parryUntil = now + Config.Combat.ParryWindow
	state.parryCooldownUntil = now + Config.Combat.ParryCooldown

	self._remotes.Effect:FireAllClients({
		type = "ParryWindow",
		userId = player.UserId,
		position = rootPart.Position,
		duration = Config.Combat.ParryWindow,
	})

	self._remotes.StateUpdate:FireClient(player, {
		kind = "Ability",
		ability = "Parry",
		cooldown = Config.Combat.ParryCooldown,
	})

	self:_accept(player, "parry window")
end

function CombatService:TryConsumeParry(player: Player, projectilePosition: Vector3): boolean
	local state = self:_getPlayerState(player)
	if os.clock() > state.parryUntil then
		return false
	end

	local _, _, rootPart = getCharacterState(player)
	if rootPart == nil or (rootPart.Position - projectilePosition).Magnitude > Config.Combat.ParryRadius then
		return false
	end

	state.parryUntil = -math.huge
	self._remotes.Effect:FireAllClients({
		type = "ParrySuccess",
		userId = player.UserId,
		position = projectilePosition,
	})
	self:_accept(player, "projectile reflected")
	return true
end

function CombatService:DamagePlayer(player: Player, amount: number, source: string): boolean
	if amount <= 0 or not MathUtil.IsFiniteNumber(amount) then
		return false
	end

	local _, humanoid, rootPart = getCharacterState(player)
	if humanoid == nil or rootPart == nil then
		return false
	end

	local finalAmount = math.clamp(amount, 0, humanoid.MaxHealth)
	humanoid:TakeDamage(finalAmount)
	self._remotes.Effect:FireAllClients({
		type = "PlayerDamaged",
		userId = player.UserId,
		position = rootPart.Position,
		amount = finalAmount,
		source = source,
	})
	return true
end

function CombatService:GetTelemetry(player: Player): TelemetrySnapshot
	local telemetry = self:_getTelemetry(player)
	return {
		accepted = telemetry.accepted,
		rejected = telemetry.rejected,
		lastEvent = telemetry.lastEvent,
	}
end

function CombatService:Destroy()
	self._janitor:Destroy()
	table.clear(self._playerStates)
	table.clear(self._telemetry)
end

return CombatService
