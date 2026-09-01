--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ShowcaseShared")
local Config = require(Shared:WaitForChild("Config"))
local StateMachine = require(Shared:WaitForChild("StateMachine"))
local Types = require(ReplicatedStorage.ShowcaseShared.Types)

type MatchSnapshot = Types.MatchSnapshot

local MatchService = {}
MatchService.__index = MatchService

type InternalMatchService = {
	_remotes: any,
	_arena: any,
	_enemyService: any?,
	_machine: any,
	_running: boolean,
	_timeRemaining: number,
	_result: string?,
	_bossDefeated: boolean,
	_winnerUserId: number,
	_playerAddedConnection: RBXScriptConnection,
	_playerRemovingConnection: RBXScriptConnection,
	_characterConnections: { [Player]: RBXScriptConnection },
}

export type MatchService = typeof(setmetatable({} :: InternalMatchService, MatchService))

local TRANSITIONS = {
	Waiting = { Countdown = true },
	Countdown = { Active = true, Waiting = true },
	Active = { Results = true, Waiting = true },
	Results = { Countdown = true, Waiting = true },
}

function MatchService.new(remotes: any, arena: any): MatchService
	local machine = StateMachine.new("Waiting", TRANSITIONS)

	local self = setmetatable({
		_remotes = remotes,
		_arena = arena,
		_enemyService = nil,
		_machine = machine,
		_running = false,
		_timeRemaining = 0,
		_result = nil,
		_bossDefeated = false,
		_winnerUserId = 0,
		_playerAddedConnection = nil :: any,
		_playerRemovingConnection = nil :: any,
		_characterConnections = {},
	}, MatchService)

	machine:Connect(function()
		self:_broadcastSnapshot()
	end)

	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self:_bindPlayer(player)
	end)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		local connection = self._characterConnections[player]
		if connection ~= nil then
			connection:Disconnect()
			self._characterConnections[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end

	return self
end

function MatchService:SetEnemyService(enemyService: any)
	self._enemyService = enemyService
end

function MatchService:_bindPlayer(player: Player)
	local oldConnection = self._characterConnections[player]
	if oldConnection ~= nil then
		oldConnection:Disconnect()
	end

	self._characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		task.spawn(function()
			self:_configureCharacter(character)
		end)
	end)

	if player.Character ~= nil then
		task.spawn(function()
			self:_configureCharacter(player.Character :: Model)
		end)
	end
end

function MatchService:_configureCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)

	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = 18
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end

	if rootPart and rootPart:IsA("BasePart") then
		task.wait()
		self._arena:PlaceCharacter(character)
	end
end

function MatchService:_transition(nextState: string)
	if not self._machine:Transition(nextState) then
		self._machine:Force(nextState)
	end
end

function MatchService:_broadcastSnapshot()
	self._remotes.StateUpdate:FireAllClients({
		kind = "Match",
		state = self._machine:GetState(),
		timeRemaining = self._timeRemaining,
		result = self._result,
		winnerUserId = self._winnerUserId,
	})
end

function MatchService:_prepareRound()
	self._bossDefeated = false
	self._winnerUserId = 0
	self._result = nil

	local enemyService = self._enemyService
	if enemyService ~= nil then
		enemyService:Reset()
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil

		if character == nil or humanoid == nil or humanoid.Health <= 0 then
			task.spawn(function()
				local ok, message = pcall(function()
					player:LoadCharacterAsync()
				end)
				if not ok then
					warn(string.format("[MatchService] failed to reload %s: %s", player.Name, tostring(message)))
				end
			end)
		else
			humanoid.Health = humanoid.MaxHealth
			self._arena:PlaceCharacter(character)
		end
	end
end

function MatchService:_runCountdown(): boolean
	self:_transition("Countdown")
	self._result = nil

	for remaining = Config.Match.CountdownDuration, 1, -1 do
		if #Players:GetPlayers() == 0 then
			self:_transition("Waiting")
			return false
		end

		self._timeRemaining = remaining
		self:_broadcastSnapshot()
		task.wait(1)
	end

	return #Players:GetPlayers() > 0
end

function MatchService:_runActiveRound(): boolean
	self:_transition("Active")
	self._timeRemaining = Config.Match.ActiveDuration
	self:_broadcastSnapshot()

	local enemyService = self._enemyService
	if enemyService ~= nil then
		enemyService:SetActive(true)
	end

	for remaining = Config.Match.ActiveDuration, 0, -1 do
		if #Players:GetPlayers() == 0 then
			if enemyService ~= nil then
				enemyService:SetActive(false)
			end
			self:_transition("Waiting")
			return false
		end

		self._timeRemaining = remaining
		self:_broadcastSnapshot()

		if self._bossDefeated then
			break
		end

		if remaining > 0 then
			task.wait(1)
		end
	end

	if enemyService ~= nil then
		enemyService:SetActive(false)
	end

	self._result = if self._bossDefeated then "SYSTEM VERIFIED" else "TIME EXPIRED"
	return true
end

function MatchService:_runResults()
	self:_transition("Results")

	for remaining = Config.Match.ResultsDuration, 1, -1 do
		if #Players:GetPlayers() == 0 then
			self:_transition("Waiting")
			return
		end

		self._timeRemaining = remaining
		self:_broadcastSnapshot()
		task.wait(1)
	end
end

function MatchService:_runLoop()
	while self._running do
		if #Players:GetPlayers() == 0 then
			self._timeRemaining = 0
			self._result = nil
			self:_transition("Waiting")
			self:_broadcastSnapshot()
			task.wait(1)
			continue
		end

		self:_prepareRound()
		if not self:_runCountdown() then
			continue
		end

		if not self:_runActiveRound() then
			continue
		end

		self:_runResults()
	end
end

function MatchService:Start()
	if self._running then
		return
	end

	self._running = true
	task.spawn(function()
		self:_runLoop()
	end)
end

function MatchService:IsActive(): boolean
	return self._machine:GetState() == "Active"
end

function MatchService:OnBossDefeated(player: Player?)
	if not self:IsActive() or self._bossDefeated then
		return
	end

	self._bossDefeated = true
	self._winnerUserId = if player ~= nil then player.UserId else 0
	self._result = "SYSTEM VERIFIED"
	self:_broadcastSnapshot()
end

function MatchService:GetSnapshot(): MatchSnapshot
	return {
		state = self._machine:GetState(),
		timeRemaining = self._timeRemaining,
		result = self._result,
		winnerUserId = self._winnerUserId,
	}
end

function MatchService:Destroy()
	self._running = false
	self._playerAddedConnection:Disconnect()
	self._playerRemovingConnection:Disconnect()

	for _, connection in pairs(self._characterConnections) do
		connection:Disconnect()
	end
	table.clear(self._characterConnections)
end

return MatchService
