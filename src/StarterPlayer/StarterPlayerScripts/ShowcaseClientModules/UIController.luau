--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIController = {}
UIController.__index = UIController

local COLORS = {
	White = Color3.fromRGB(245, 245, 245),
	Muted = Color3.fromRGB(170, 170, 170),
	Red = Color3.fromRGB(185, 28, 35),
}

type InternalUIController = {
	_gui: ScreenGui,
	_matchState: TextLabel,
	_matchTimer: TextLabel,
	_bossState: TextLabel,
	_bossTarget: TextLabel,
	_bossHealthText: TextLabel,
	_bossHealthFill: Frame,
	_acceptedValue: TextLabel,
	_rejectedValue: TextLabel,
	_lastEvent: TextLabel,
	_notification: Frame,
	_notificationText: TextLabel,
	_damageOverlay: Frame,
	_parryFill: Frame,
	_parryStatus: TextLabel,
	_notificationId: number,
	_notificationTween: Tween?,
	_damageTween: Tween?,
	_abilityToken: number,
	_lastResult: string?,
	_connections: { RBXScriptConnection },
}

export type UIController = typeof(setmetatable({} :: InternalUIController, UIController))

local function requireChild(parent: Instance, name: string, className: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(child ~= nil, string.format("[UIController] Missing %s.%s", parent:GetFullName(), name))
	assert(child:IsA(className), string.format(
		"[UIController] %s must be a %s, got %s",
		child:GetFullName(),
		className,
		child.ClassName
	))
	return child
end

local function formatTime(seconds: number): string
	local wholeSeconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(wholeSeconds / 60), wholeSeconds % 60)
end

local function humanize(value: string): string
	local spaced = value:gsub("_", " "):gsub("(%l)(%u)", "%1 %2")
	return string.upper(spaced)
end

local function formatCombatEvent(value: string): string
	if value == "" then
		return "AWAITING INPUT"
	end
	return humanize(value)
end

local function formatNotification(value: string): string
	return string.upper(value)
end

local function hudTone(color: Color3?): Color3
	if color ~= nil and color.R > color.G * 1.12 and color.R > color.B * 1.12 then
		return COLORS.Red
	end
	return COLORS.White
end

function UIController.new(): UIController
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = requireChild(playerGui, "MainUI", "ScreenGui") :: ScreenGui
	local root = requireChild(gui, "Root", "Frame") :: Frame
	local mainPanel = requireChild(root, "MainPanel", "Frame") :: Frame
	local bossPanel = requireChild(mainPanel, "BossPanel", "Frame") :: Frame
	local roundPanel = requireChild(mainPanel, "RoundPanel", "Frame") :: Frame
	local combatRecord = requireChild(root, "CombatRecord", "Frame") :: Frame
	local combatHints = requireChild(root, "CombatHints", "Frame") :: Frame
	local parryTile = requireChild(combatHints, "ParryTile", "Frame") :: Frame
	local notification = requireChild(root, "Notification", "Frame") :: Frame

	local healthTrack = requireChild(bossPanel, "HealthTrack", "Frame") :: Frame
	local parryTrack = requireChild(parryTile, "ParryTrack", "Frame") :: Frame

	gui.Enabled = true

	return setmetatable({
		_gui = gui,
		_matchState = requireChild(roundPanel, "MatchState", "TextLabel") :: TextLabel,
		_matchTimer = requireChild(roundPanel, "MatchTimer", "TextLabel") :: TextLabel,
		_bossState = requireChild(bossPanel, "BossState", "TextLabel") :: TextLabel,
		_bossTarget = requireChild(bossPanel, "BossTarget", "TextLabel") :: TextLabel,
		_bossHealthText = requireChild(bossPanel, "HealthText", "TextLabel") :: TextLabel,
		_bossHealthFill = requireChild(healthTrack, "HealthFill", "Frame") :: Frame,
		_acceptedValue = requireChild(combatRecord, "AcceptedValue", "TextLabel") :: TextLabel,
		_rejectedValue = requireChild(combatRecord, "RejectedValue", "TextLabel") :: TextLabel,
		_lastEvent = requireChild(combatRecord, "LastEvent", "TextLabel") :: TextLabel,
		_notification = notification,
		_notificationText = requireChild(notification, "Text", "TextLabel") :: TextLabel,
		_damageOverlay = requireChild(root, "DamageOverlay", "Frame") :: Frame,
		_parryFill = requireChild(parryTrack, "ParryFill", "Frame") :: Frame,
		_parryStatus = requireChild(parryTile, "ParryStatus", "TextLabel") :: TextLabel,
		_notificationId = 0,
		_notificationTween = nil,
		_damageTween = nil,
		_abilityToken = 0,
		_lastResult = nil,
		_connections = {},
	} :: InternalUIController, UIController)
end

function UIController:SetMatch(snapshot: { [string]: any })
	local state = if typeof(snapshot.state) == "string" then snapshot.state else "Unknown"
	local timeRemaining = if typeof(snapshot.timeRemaining) == "number" then snapshot.timeRemaining else 0
	local result = if typeof(snapshot.result) == "string" then snapshot.result else nil

	if state == "Active" then
		self._matchState.Text = "FIGHT"
	elseif state == "Countdown" then
		self._matchState.Text = "PREPARE"
	elseif state == "Waiting" then
		self._matchState.Text = "WAITING"
	elseif state == "Results" then
		self._matchState.Text = if result == "SYSTEM VERIFIED" then "VICTORY" else "ROUND OVER"
	else
		self._matchState.Text = humanize(state)
	end

	self._matchTimer.Text = formatTime(timeRemaining)

	if state == "Results" and result ~= nil and result ~= self._lastResult then
		self._lastResult = result
		self:Notify(result, if result == "SYSTEM VERIFIED" then COLORS.White else COLORS.Red, 2.5)
	elseif state ~= "Results" then
		self._lastResult = nil
	end
end

function UIController:SetBoss(snapshot: { [string]: any })
	local state = if typeof(snapshot.state) == "string" then snapshot.state else "Unknown"
	local health = if typeof(snapshot.health) == "number" then snapshot.health else 0
	local maximumHealth = if typeof(snapshot.maximumHealth) == "number" and snapshot.maximumHealth > 0
		then snapshot.maximumHealth
		else Config.Enemy.MaximumHealth
	local targetName = if typeof(snapshot.targetName) == "string" then snapshot.targetName else "NONE"

	self._bossState.Text = humanize(state)
	self._bossTarget.Text = if string.upper(targetName) == "NONE"
		then "NO TARGET"
		else "FACING " .. string.upper(targetName)
	self._bossHealthText.Text = string.format(
		"%d / %d",
		math.max(0, math.floor(health)),
		math.floor(maximumHealth)
	)

	TweenService:Create(
		self._bossHealthFill,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(math.clamp(health / maximumHealth, 0, 1), 1) }
	):Play()
end

function UIController:SetTelemetry(snapshot: { [string]: any })
	self._acceptedValue.Text = tostring(math.floor(
		if typeof(snapshot.accepted) == "number" then snapshot.accepted else 0
	))
	self._rejectedValue.Text = tostring(math.floor(
		if typeof(snapshot.rejected) == "number" then snapshot.rejected else 0
	))
	self._lastEvent.Text = formatCombatEvent(
		if typeof(snapshot.lastEvent) == "string" then snapshot.lastEvent else "Awaiting input"
	)
end

function UIController:StartParryCooldown(duration: number)
	if duration <= 0 then
		return
	end

	self._abilityToken += 1
	local token = self._abilityToken

	task.spawn(function()
		local startedAt = os.clock()
		while token == self._abilityToken do
			local remaining = math.max(0, duration - (os.clock() - startedAt))
			self._parryFill.Size = UDim2.fromScale(math.clamp(remaining / duration, 0, 1), 1)
			self._parryStatus.Text = if remaining > 0
				then string.format("RECOVERING %.1fs", remaining)
				else "PARRY READY"
			self._parryStatus.TextColor3 = if remaining > 0 then COLORS.Muted else COLORS.White

			if remaining <= 0 then
				break
			end
			task.wait(0.05)
		end

		if token == self._abilityToken then
			self._parryFill.Size = UDim2.fromScale(0, 1)
			self._parryStatus.Text = "PARRY READY"
			self._parryStatus.TextColor3 = COLORS.White
		end
	end)
end

function UIController:Notify(message: string, color: Color3?, duration: number?)
	self._notificationId += 1
	local id = self._notificationId

	if self._notificationTween ~= nil then
		self._notificationTween:Cancel()
		self._notificationTween = nil
	end

	self._notificationText.Text = formatNotification(message)
	self._notificationText.TextColor3 = hudTone(color)
	self._notificationText.TextTransparency = 0
	self._notification.BackgroundTransparency = 0.08
	self._notification.Visible = true

	task.delay(duration or 1.4, function()
		if id ~= self._notificationId then
			return
		end

		local tween = TweenService:Create(
			self._notification,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		self._notificationTween = tween
		tween:Play()
		tween.Completed:Once(function()
			if id == self._notificationId then
				self._notification.Visible = false
				self._notificationTween = nil
			end
		end)
	end)
end

function UIController:FlashDamage()
	if self._damageTween ~= nil then
		self._damageTween:Cancel()
	end

	self._damageOverlay.BackgroundTransparency = 0.82
	local tween = TweenService:Create(
		self._damageOverlay,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	self._damageTween = tween
	tween:Play()
	tween.Completed:Once(function()
		if self._damageTween == tween then
			self._damageTween = nil
		end
	end)
end

function UIController:HandleState(payload: { [string]: any })
	if payload.kind == "Match" then
		self:SetMatch(payload)
	elseif payload.kind == "Boss" then
		self:SetBoss(payload)
	elseif payload.kind == "Telemetry" then
		self:SetTelemetry(payload)
	elseif payload.kind == "Ability"
		and payload.ability == "Parry"
		and typeof(payload.cooldown) == "number"
	then
		self:StartParryCooldown(payload.cooldown)
	end
end

function UIController:ApplySnapshot(snapshot: { [string]: any })
	if typeof(snapshot.match) == "table" then
		self:SetMatch(snapshot.match)
	end
	if typeof(snapshot.boss) == "table" then
		self:SetBoss(snapshot.boss)
	end
	if typeof(snapshot.telemetry) == "table" then
		self:SetTelemetry(snapshot.telemetry)
	end
end

function UIController:Destroy()
	self._abilityToken += 1
	self._notificationId += 1

	if self._notificationTween ~= nil then
		self._notificationTween:Cancel()
	end
	if self._damageTween ~= nil then
		self._damageTween:Cancel()
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._gui.Enabled = false
end

return UIController
