--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("Config"))

local UIController = {}
UIController.__index = UIController

type InternalUIController = {
	_gui: ScreenGui,
	_scale: UIScale,
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
	_abilityToken: number,
	_connections: { RBXScriptConnection },
}

export type UIController = typeof(setmetatable({} :: InternalUIController, UIController))

local function newInstance(className: string, properties: { [string]: any }): Instance
	local instance = Instance.new(className)
	for key, value in pairs(properties) do
		(instance :: any)[key] = value
	end
	return instance
end

local function round(guiObject: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
end

local function stroke(guiObject: GuiObject, color: Color3, transparency: number)
	local outline = Instance.new("UIStroke")
	outline.Color = color
	outline.Transparency = transparency
	outline.Thickness = 1
	outline.Parent = guiObject
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	return newInstance("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = Config.Palette.Text,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = position,
		Size = size,
		Parent = parent,
	}) :: TextLabel
end

local function card(parent: Instance, name: string, position: UDim2, size: UDim2, anchorPoint: Vector2?): Frame
	local frame = newInstance("Frame", {
		Name = name,
		BackgroundColor3 = Config.Palette.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		AnchorPoint = anchorPoint or Vector2.zero,
		Parent = parent,
	}) :: Frame
	round(frame, 10)
	stroke(frame, Color3.fromRGB(78, 91, 112), 0.58)
	return frame
end

local function formatTime(seconds: number): string
	local safe = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(safe / 60), safe % 60)
end

function UIController.new(): UIController
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local oldGui = playerGui:FindFirstChild("ScripterShowcaseUI")
	if oldGui then
		oldGui:Destroy()
	end

	local gui = newInstance("ScreenGui", {
		Name = "ScripterShowcaseUI",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}) :: ScreenGui

	local root = newInstance("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}) :: Frame

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local brand = card(root, "Brand", UDim2.fromOffset(22, 22), UDim2.fromOffset(360, 86))
	local accent = newInstance("Frame", {
		BackgroundColor3 = Config.Palette.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(4, 62),
		Parent = brand,
	}) :: Frame
	round(accent, 3)
	local creator = label(brand, string.upper(Config.Brand.Creator), UDim2.fromOffset(28, 13), UDim2.new(1, -40, 0, 31), 25)
	creator.Font = Enum.Font.GothamBlack
	local subtitle = label(brand, "SERVER-AUTHORITATIVE LUAU SHOWCASE", UDim2.fromOffset(29, 47), UDim2.new(1, -42, 0, 22), 11)
	subtitle.TextColor3 = Config.Palette.MutedText

	local match = card(root, "Match", UDim2.fromOffset(22, 120), UDim2.fromOffset(360, 50))
	local matchState = label(match, "WAITING", UDim2.fromOffset(16, 0), UDim2.new(1, -112, 1, 0), 13)
	matchState.Font = Enum.Font.GothamBold
	local matchTimer = label(match, "00:00", UDim2.new(1, -98, 0, 0), UDim2.fromOffset(82, 50), 15)
	matchTimer.Font = Enum.Font.RobotoMono
	matchTimer.TextColor3 = Config.Palette.MutedText
	matchTimer.TextXAlignment = Enum.TextXAlignment.Right

	local boss = card(root, "Boss", UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(520, 90), Vector2.new(0.5, 0))
	local bossTitle = label(boss, Config.Enemy.Name, UDim2.fromOffset(16, 8), UDim2.new(0.55, 0, 0, 24), 17)
	bossTitle.Font = Enum.Font.GothamBlack
	local bossHealthText = label(boss, string.format("%d / %d", Config.Enemy.MaximumHealth, Config.Enemy.MaximumHealth), UDim2.new(0.55, 0, 0, 8), UDim2.new(0.45, -16, 0, 24), 12)
	bossHealthText.Font = Enum.Font.RobotoMono
	bossHealthText.TextColor3 = Config.Palette.MutedText
	bossHealthText.TextXAlignment = Enum.TextXAlignment.Right
	local bar = newInstance("Frame", {
		BackgroundColor3 = Color3.fromRGB(47, 54, 67),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(16, 37),
		Size = UDim2.new(1, -32, 0, 12),
		Parent = boss,
	}) :: Frame
	round(bar, 6)
	local bossHealthFill = newInstance("Frame", {
		BackgroundColor3 = Config.Palette.Danger,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = bar,
	}) :: Frame
	round(bossHealthFill, 6)
	local bossState = label(boss, "STATE // DORMANT", UDim2.fromOffset(16, 57), UDim2.new(0.55, 0, 0, 22), 11)
	bossState.Font = Enum.Font.GothamBold
	bossState.TextColor3 = Config.Palette.Warning
	local bossTarget = label(boss, "TARGET // NONE", UDim2.new(0.55, 0, 0, 57), UDim2.new(0.45, -16, 0, 22), 11)
	bossTarget.TextColor3 = Config.Palette.MutedText
	bossTarget.TextXAlignment = Enum.TextXAlignment.Right

	local telemetry = card(root, "Telemetry", UDim2.new(1, -22, 0, 22), UDim2.fromOffset(306, 210), Vector2.new(1, 0))
	local telemetryTitle = label(telemetry, "SERVER VALIDATION", UDim2.fromOffset(15, 10), UDim2.new(1, -30, 0, 26), 17)
	telemetryTitle.Font = Enum.Font.GothamBlack
	local gate = label(telemetry, "REMOTE INPUT GATED BY SERVER", UDim2.fromOffset(15, 39), UDim2.new(1, -30, 0, 22), 10)
	gate.Font = Enum.Font.GothamBold
	gate.TextColor3 = Config.Palette.Accent
	local acceptedCaption = label(telemetry, "ACCEPTED", UDim2.fromOffset(15, 73), UDim2.fromOffset(125, 18), 10)
	acceptedCaption.TextColor3 = Config.Palette.MutedText
	local rejectedCaption = label(telemetry, "REJECTED", UDim2.fromOffset(162, 73), UDim2.fromOffset(125, 18), 10)
	rejectedCaption.TextColor3 = Config.Palette.MutedText
	local acceptedValue = label(telemetry, "0", UDim2.fromOffset(15, 91), UDim2.fromOffset(125, 34), 25)
	acceptedValue.Font = Enum.Font.RobotoMono
	acceptedValue.TextColor3 = Config.Palette.Accent
	local rejectedValue = label(telemetry, "0", UDim2.fromOffset(162, 91), UDim2.fromOffset(125, 34), 25)
	rejectedValue.Font = Enum.Font.RobotoMono
	rejectedValue.TextColor3 = Config.Palette.Danger
	local lastEventCaption = label(telemetry, "LAST EVENT", UDim2.fromOffset(15, 137), UDim2.new(1, -30, 0, 18), 10)
	lastEventCaption.TextColor3 = Config.Palette.MutedText
	local lastEvent = label(telemetry, "AWAITING INPUT", UDim2.fromOffset(15, 156), UDim2.new(1, -30, 0, 38), 11)
	lastEvent.Font = Enum.Font.RobotoMono
	lastEvent.TextWrapped = true
	lastEvent.TextYAlignment = Enum.TextYAlignment.Top

	local controls = card(root, "Controls", UDim2.new(0.5, 0, 1, -22), UDim2.fromOffset(540, 76), Vector2.new(0.5, 1))
	local attackText = label(controls, "LMB / F   ATTACK", UDim2.fromOffset(18, 8), UDim2.new(0.5, -24, 0, 25), 13)
	attackText.Font = Enum.Font.GothamBold
	local attackInfo = label(controls, "Validated range, cone and line of sight", UDim2.fromOffset(18, 35), UDim2.new(0.5, -24, 0, 28), 10)
	attackInfo.TextColor3 = Config.Palette.MutedText
	local parryText = label(controls, "Q   PARRY / REFLECT", UDim2.new(0.5, 7, 0, 8), UDim2.new(0.5, -25, 0, 25), 13)
	parryText.Font = Enum.Font.GothamBold
	parryText.TextColor3 = Config.Palette.Warning
	local parryStatus = label(controls, "READY // SERVER TIMED WINDOW", UDim2.new(0.5, 7, 0, 35), UDim2.new(0.5, -25, 0, 28), 10)
	parryStatus.TextColor3 = Config.Palette.MutedText
	local parryFill = newInstance("Frame", {
		BackgroundColor3 = Config.Palette.Warning,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.5, 0, 0, 0),
		Parent = controls,
	}) :: Frame

	local notification = card(root, "Notification", UDim2.new(0.5, 0, 0.28, 0), UDim2.fromOffset(470, 54), Vector2.new(0.5, 0.5))
	notification.Visible = false
	local notificationText = label(notification, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 15)
	notificationText.Font = Enum.Font.GothamBlack
	notificationText.TextXAlignment = Enum.TextXAlignment.Center

	local damageOverlay = newInstance("Frame", {
		BackgroundColor3 = Config.Palette.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	}) :: Frame

	local self = setmetatable({
		_gui = gui,
		_scale = scale,
		_matchState = matchState,
		_matchTimer = matchTimer,
		_bossState = bossState,
		_bossTarget = bossTarget,
		_bossHealthText = bossHealthText,
		_bossHealthFill = bossHealthFill,
		_acceptedValue = acceptedValue,
		_rejectedValue = rejectedValue,
		_lastEvent = lastEvent,
		_notification = notification,
		_notificationText = notificationText,
		_damageOverlay = damageOverlay,
		_parryFill = parryFill,
		_parryStatus = parryStatus,
		_notificationId = 0,
		_abilityToken = 0,
		_connections = {},
	}, UIController)

	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			self._scale.Scale = math.clamp(math.min(viewport.X / 1600, viewport.Y / 900), 0.65, 1)
		end
	end

	table.insert(self._connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale))
	local camera = Workspace.CurrentCamera
	if camera then
		table.insert(self._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
	end
	updateScale()

	return self
end

function UIController:SetMatch(snapshot: { [string]: any })
	local state = if typeof(snapshot.state) == "string" then snapshot.state else "Unknown"
	local timeRemaining = if typeof(snapshot.timeRemaining) == "number" then snapshot.timeRemaining else 0
	local result = if typeof(snapshot.result) == "string" then snapshot.result else nil
	self._matchState.Text = if state == "Active" then "LIVE SERVER SIMULATION" elseif state == "Countdown" then "ROUND INITIALIZING" else string.upper(state)
	self._matchTimer.Text = formatTime(timeRemaining)
	if state == "Results" and result then
		self:Notify(result, if result == "SYSTEM VERIFIED" then Config.Palette.Accent else Config.Palette.Warning, 2.5)
	end
end

function UIController:SetBoss(snapshot: { [string]: any })
	local state = if typeof(snapshot.state) == "string" then snapshot.state else "Unknown"
	local health = if typeof(snapshot.health) == "number" then snapshot.health else 0
	local maximumHealth = if typeof(snapshot.maximumHealth) == "number" and snapshot.maximumHealth > 0 then snapshot.maximumHealth else Config.Enemy.MaximumHealth
	local targetName = if typeof(snapshot.targetName) == "string" then snapshot.targetName else "NONE"
	self._bossState.Text = "STATE // " .. string.upper(state)
	self._bossTarget.Text = "TARGET // " .. string.upper(targetName)
	self._bossHealthText.Text = string.format("%d / %d", math.max(0, math.floor(health)), math.floor(maximumHealth))
	TweenService:Create(self._bossHealthFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(health / maximumHealth, 0, 1), 1),
	}):Play()
end

function UIController:SetTelemetry(snapshot: { [string]: any })
	self._acceptedValue.Text = tostring(math.floor(if typeof(snapshot.accepted) == "number" then snapshot.accepted else 0))
	self._rejectedValue.Text = tostring(math.floor(if typeof(snapshot.rejected) == "number" then snapshot.rejected else 0))
	self._lastEvent.Text = string.upper(if typeof(snapshot.lastEvent) == "string" then snapshot.lastEvent else "AWAITING INPUT")
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
			self._parryFill.Size = UDim2.new(0.5, 0, math.clamp(remaining / duration, 0, 1), 0)
			self._parryStatus.Text = if remaining > 0 then string.format("COOLDOWN // %.1fs", remaining) else "READY // SERVER TIMED WINDOW"
			if remaining <= 0 then
				break
			end
			task.wait(0.05)
		end
		if token == self._abilityToken then
			self._parryFill.Size = UDim2.new(0.5, 0, 0, 0)
		end
	end)
end

function UIController:Notify(text: string, color: Color3?, duration: number?)
	self._notificationId += 1
	local id = self._notificationId
	self._notificationText.Text = string.upper(text)
	self._notificationText.TextColor3 = color or Config.Palette.Text
	self._notification.Visible = true
	self._notification.BackgroundTransparency = 0.02
	task.delay(duration or 1.4, function()
		if id ~= self._notificationId then
			return
		end
		local tween = TweenService:Create(self._notification, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			if id == self._notificationId then
				self._notification.Visible = false
			end
		end)
	end)
end

function UIController:FlashDamage()
	self._damageOverlay.BackgroundTransparency = 0.76
	TweenService:Create(self._damageOverlay, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
end

function UIController:HandleState(payload: { [string]: any })
	if payload.kind == "Match" then
		self:SetMatch(payload)
	elseif payload.kind == "Boss" then
		self:SetBoss(payload)
	elseif payload.kind == "Telemetry" then
		self:SetTelemetry(payload)
	elseif payload.kind == "Ability" and payload.ability == "Parry" and typeof(payload.cooldown) == "number" then
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
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._gui:Destroy()
end

return UIController
