--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("Config"))

local UIController = {}
UIController.__index = UIController

local COLORS = {
	Charcoal = Color3.fromRGB(28, 25, 21),
	CharcoalDeep = Color3.fromRGB(17, 15, 13),
	Stone = Color3.fromRGB(65, 59, 50),
	Iron = Color3.fromRGB(101, 94, 82),
	IronDark = Color3.fromRGB(55, 51, 45),
	Parchment = Color3.fromRGB(232, 216, 180),
	ParchmentMuted = Color3.fromRGB(173, 157, 128),
	Ember = Color3.fromRGB(193, 132, 58),
	EmberLight = Color3.fromRGB(226, 169, 85),
	Blood = Color3.fromRGB(142, 48, 38),
	BloodDark = Color3.fromRGB(77, 25, 22),
	BloodLight = Color3.fromRGB(194, 74, 55),
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

local function stroke(guiObject: GuiObject, color: Color3, transparency: number, thickness: number?)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Color = color
	outline.Transparency = transparency
	outline.Thickness = thickness or 1
	outline.Parent = guiObject
end

local function gradient(guiObject: GuiObject, topColor: Color3, bottomColor: Color3, rotation: number?)
	local wash = Instance.new("UIGradient")
	wash.Color = ColorSequence.new(topColor, bottomColor)
	wash.Rotation = rotation or 90
	wash.Parent = guiObject
end

local function constrain(guiObject: GuiObject, minimum: Vector2, maximum: Vector2)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minimum
	constraint.MaxSize = maximum
	constraint.Parent = guiObject
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	return newInstance("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = text,
		TextColor3 = COLORS.Parchment,
		TextSize = textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = position,
		Size = size,
		Parent = parent,
	}) :: TextLabel
end

local function addRivet(parent: GuiObject, position: UDim2)
	local rivet = newInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COLORS.Iron,
		BorderSizePixel = 0,
		Position = position,
		Rotation = 45,
		Size = UDim2.fromOffset(5, 5),
		Parent = parent,
	}) :: Frame
	stroke(rivet, COLORS.CharcoalDeep, 0.25)
end

local function addRule(parent: Instance, position: UDim2, size: UDim2, transparency: number?)
	newInstance("Frame", {
		BackgroundColor3 = COLORS.Iron,
		BackgroundTransparency = transparency or 0.35,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	})
end

local function panel(parent: Instance, name: string, position: UDim2, size: UDim2, anchorPoint: Vector2?): Frame
	local frame = newInstance("Frame", {
		Name = name,
		AnchorPoint = anchorPoint or Vector2.zero,
		BackgroundColor3 = COLORS.Stone,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	}) :: Frame
	round(frame, 3)
	stroke(frame, COLORS.Iron, 0.12)
	gradient(frame, COLORS.Stone, COLORS.Charcoal)
	return frame
end

local function formatTime(seconds: number): string
	local safe = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(safe / 60), safe % 60)
end

local function humanize(value: string): string
	local words = string.gsub(value, "(%l)(%u)", "%1 %2")
	words = string.gsub(words, "[_%-]", " ")
	return string.upper(words)
end

local function formatCombatEvent(value: string): string
	local upper = string.upper(value)
	local acceptedPrefix = "ACCEPTED // "
	local rejectedPrefix = "REJECTED // "

	if string.sub(upper, 1, #acceptedPrefix) == acceptedPrefix then
		local action = humanize(string.sub(value, #acceptedPrefix + 1))
		if action == "ATTACK" then
			return "STRIKE COMMITTED"
		elseif action == "PARRY" then
			return "GUARD RAISED"
		end
		return action .. " COMMITTED"
	elseif string.sub(upper, 1, #rejectedPrefix) == rejectedPrefix then
		return "BLOCKED: " .. humanize(string.sub(value, #rejectedPrefix + 1))
	elseif upper == "AWAITING INPUT" then
		return "AWAITING COMBAT"
	end

	local cleaned = string.gsub(upper, " // ", ": ")
	return cleaned
end

local function formatNotification(value: string): string
	local upper = string.upper(value)

	if string.find(upper, "SYSTEM VERIFIED", 1, true) then
		return if string.find(upper, "BOSS DEFEATED", 1, true) then "BOSS DEFEATED" else "VICTORY"
	elseif string.find(upper, "SHOWCASE ONLINE", 1, true) then
		return "ENTER THE ARENA"
	elseif string.find(upper, "PARRY CONFIRMED", 1, true) then
		return "PERFECT PARRY"
	elseif string.find(upper, "GROUND SLAM", 1, true) then
		return "GROUND SLAM - MOVE!"
	elseif string.sub(upper, 1, 10) == "DAMAGE // " then
		return "HIT: " .. humanize(string.sub(value, 11))
	elseif string.sub(upper, 1, 8) == "BOSS // " then
		return humanize(string.sub(value, 9))
	elseif upper == "TIME EXPIRED" then
		return "TIME'S UP"
	elseif upper == "SNAPSHOT UNAVAILABLE" then
		return "ARENA STATUS UNAVAILABLE"
	end

	local cleaned = string.gsub(upper, " // ", " - ")
	return cleaned
end

local function warmTone(color: Color3?): Color3
	if color == nil then
		return COLORS.Parchment
	elseif color == Config.Palette.Danger then
		return COLORS.BloodLight
	elseif color == Config.Palette.Warning then
		return COLORS.EmberLight
	elseif color == Config.Palette.Accent then
		return COLORS.EmberLight
	end
	return color
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
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}) :: Frame

	local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- A small hanging round plaque keeps match information readable without becoming a dashboard.
	local match = panel(root, "Round", UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(148, 40), Vector2.new(0.5, 0))
	match.ZIndex = 6
	addRivet(match, UDim2.new(0, 9, 0.5, 0))
	addRivet(match, UDim2.new(1, -9, 0.5, 0))
	local matchState = label(match, "WAITING", UDim2.fromOffset(19, 3), UDim2.new(1, -38, 0, 13), 10)
	matchState.Font = Enum.Font.SourceSansBold
	matchState.TextColor3 = COLORS.ParchmentMuted
	matchState.TextXAlignment = Enum.TextXAlignment.Center
	matchState.TextTruncate = Enum.TextTruncate.AtEnd
	matchState.ZIndex = 7
	local matchTimer = label(match, "00:00", UDim2.fromOffset(19, 13), UDim2.new(1, -38, 0, 24), 20)
	matchTimer.Font = Enum.Font.Antique
	matchTimer.TextColor3 = COLORS.Parchment
	matchTimer.TextXAlignment = Enum.TextXAlignment.Center
	matchTimer.TextStrokeColor3 = COLORS.CharcoalDeep
	matchTimer.TextStrokeTransparency = 0.55
	matchTimer.ZIndex = 7

	-- The boss health bar is the visual anchor: solid iron, worn stone, and a restrained blood-red fill.
	local boss = panel(root, "Boss", UDim2.new(0.5, 0, 0, 62), UDim2.new(0.56, 0, 0, 86), Vector2.new(0.5, 0))
	constrain(boss, Vector2.new(300, 86), Vector2.new(650, 86))
	addRivet(boss, UDim2.fromOffset(10, 10))
	addRivet(boss, UDim2.new(1, -10, 0, 10))
	addRivet(boss, UDim2.new(0, 10, 1, -10))
	addRivet(boss, UDim2.new(1, -10, 1, -10))
	addRule(boss, UDim2.fromOffset(20, 29), UDim2.new(1, -40, 0, 1), 0.48)

	local leftBracket = newInstance("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = COLORS.IronDark,
		BorderSizePixel = 0,
		Position = UDim2.new(0, -2, 0.5, 0),
		Rotation = 45,
		Size = UDim2.fromOffset(15, 15),
		Parent = boss,
	}) :: Frame
	stroke(leftBracket, COLORS.Iron, 0.18)
	local rightBracket = newInstance("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = COLORS.IronDark,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 2, 0.5, 0),
		Rotation = 45,
		Size = UDim2.fromOffset(15, 15),
		Parent = boss,
	}) :: Frame
	stroke(rightBracket, COLORS.Iron, 0.18)

	local bossTitle = label(boss, humanize(Config.Enemy.Name), UDim2.fromOffset(46, 4), UDim2.new(1, -92, 0, 24), 18)
	bossTitle.Font = Enum.Font.Antique
	bossTitle.TextColor3 = COLORS.Parchment
	bossTitle.TextXAlignment = Enum.TextXAlignment.Center
	bossTitle.TextStrokeColor3 = COLORS.CharcoalDeep
	bossTitle.TextStrokeTransparency = 0.62

	local healthTrack = newInstance("Frame", {
		BackgroundColor3 = COLORS.CharcoalDeep,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(20, 34),
		Size = UDim2.new(1, -40, 0, 19),
		Parent = boss,
	}) :: Frame
	round(healthTrack, 2)
	stroke(healthTrack, COLORS.IronDark, 0.02)

	local bossHealthFill = newInstance("Frame", {
		BackgroundColor3 = COLORS.Blood,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = healthTrack,
	}) :: Frame
	gradient(bossHealthFill, COLORS.BloodLight, COLORS.BloodDark)
	newInstance("Frame", {
		BackgroundColor3 = COLORS.Parchment,
		BackgroundTransparency = 0.79,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = bossHealthFill,
	})

	for index = 1, 3 do
		newInstance("Frame", {
			BackgroundColor3 = COLORS.CharcoalDeep,
			BackgroundTransparency = 0.43,
			BorderSizePixel = 0,
			Position = UDim2.new(index / 4, 0, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			ZIndex = 4,
			Parent = healthTrack,
		})
	end

	local bossHealthText = label(boss, string.format("%d / %d", Config.Enemy.MaximumHealth, Config.Enemy.MaximumHealth), UDim2.fromOffset(20, 34), UDim2.new(1, -40, 0, 19), 12)
	bossHealthText.Font = Enum.Font.SourceSansBold
	bossHealthText.TextColor3 = COLORS.Parchment
	bossHealthText.TextXAlignment = Enum.TextXAlignment.Center
	bossHealthText.TextStrokeColor3 = COLORS.CharcoalDeep
	bossHealthText.TextStrokeTransparency = 0.15
	bossHealthText.ZIndex = 5

	local bossState = label(boss, "DORMANT", UDim2.fromOffset(20, 58), UDim2.new(0.5, -24, 0, 18), 11)
	bossState.Font = Enum.Font.SourceSansBold
	bossState.TextColor3 = COLORS.EmberLight
	local bossTarget = label(boss, "NO TARGET", UDim2.new(0.5, 4, 0, 58), UDim2.new(0.5, -24, 0, 18), 11)
	bossTarget.Font = Enum.Font.SourceSans
	bossTarget.TextColor3 = COLORS.ParchmentMuted
	bossTarget.TextTruncate = Enum.TextTruncate.AtEnd
	bossTarget.TextXAlignment = Enum.TextXAlignment.Right

	-- Telemetry survives as a quiet combat record instead of a developer-facing validation panel.
	local telemetry = panel(root, "CombatRecord", UDim2.fromOffset(18, 150), UDim2.fromOffset(292, 70))
	telemetry.Visible = false
	addRivet(telemetry, UDim2.fromOffset(9, 9))
	addRule(telemetry, UDim2.fromOffset(194, 9), UDim2.fromOffset(1, 52), 0.52)
	local telemetryTitle = label(telemetry, "ARENA RECORD", UDim2.fromOffset(19, 5), UDim2.fromOffset(164, 18), 10)
	telemetryTitle.Font = Enum.Font.SourceSansBold
	telemetryTitle.TextColor3 = COLORS.ParchmentMuted
	local lastEvent = label(telemetry, "AWAITING COMBAT", UDim2.fromOffset(12, 23), UDim2.fromOffset(172, 38), 13)
	lastEvent.Font = Enum.Font.SourceSansSemibold
	lastEvent.TextColor3 = COLORS.Parchment
	lastEvent.TextWrapped = true
	lastEvent.TextYAlignment = Enum.TextYAlignment.Center
	local acceptedCaption = label(telemetry, "COMMITTED", UDim2.fromOffset(205, 7), UDim2.fromOffset(54, 16), 9)
	acceptedCaption.Font = Enum.Font.SourceSansBold
	acceptedCaption.TextColor3 = COLORS.ParchmentMuted
	local acceptedValue = label(telemetry, "0", UDim2.fromOffset(260, 4), UDim2.fromOffset(20, 20), 15)
	acceptedValue.Font = Enum.Font.Antique
	acceptedValue.TextColor3 = COLORS.EmberLight
	acceptedValue.TextXAlignment = Enum.TextXAlignment.Right
	local rejectedCaption = label(telemetry, "BLOCKED", UDim2.fromOffset(205, 39), UDim2.fromOffset(54, 16), 9)
	rejectedCaption.Font = Enum.Font.SourceSansBold
	rejectedCaption.TextColor3 = COLORS.ParchmentMuted
	local rejectedValue = label(telemetry, "0", UDim2.fromOffset(260, 36), UDim2.fromOffset(20, 20), 15)
	rejectedValue.Font = Enum.Font.Antique
	rejectedValue.TextColor3 = COLORS.BloodLight
	rejectedValue.TextXAlignment = Enum.TextXAlignment.Right

	-- Keyboard hints live at the bottom; touch devices get the same cooldown readout below the boss bar.
	local controlPosition = if isTouchOnly then UDim2.new(0.5, 0, 0, 142) else UDim2.new(0.5, 0, 1, -18)
	local controlAnchor = if isTouchOnly then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	local controlSize = if isTouchOnly then UDim2.fromOffset(230, 38) else UDim2.new(0.62, 0, 0, 52)
	local controls = panel(root, "CombatHints", controlPosition, controlSize, controlAnchor)
	if not isTouchOnly then
		constrain(controls, Vector2.new(300, 52), Vector2.new(430, 52))
	end
	controls.BackgroundTransparency = 0.08
	addRule(controls, UDim2.new(0.5, 0, 0, 8), UDim2.new(0, 1, 1, -16), 0.42)

	local attackKey = label(controls, if isTouchOnly then "TAP" else "F / LMB", UDim2.fromOffset(12, 7), UDim2.fromOffset(if isTouchOnly then 36 else 62, 27), if isTouchOnly then 9 else 10)
	attackKey.Font = Enum.Font.SourceSansBold
	attackKey.TextColor3 = COLORS.CharcoalDeep
	attackKey.TextXAlignment = Enum.TextXAlignment.Center
	attackKey.BackgroundColor3 = COLORS.ParchmentMuted
	attackKey.BackgroundTransparency = 0.04
	round(attackKey, 2)
	stroke(attackKey, COLORS.Iron, 0.22)
	local attackText = label(controls, "STRIKE", UDim2.fromOffset(if isTouchOnly then 55 else 84, 7), UDim2.new(0.5, if isTouchOnly then -58 else -87, 0, 27), 13)
	attackText.Font = Enum.Font.SourceSansBold
	attackText.TextColor3 = COLORS.Parchment
	attackText.TextYAlignment = Enum.TextYAlignment.Center

	local parryKey = label(controls, if isTouchOnly then "TAP" else "Q", UDim2.new(0.5, 12, 0, 7), UDim2.fromOffset(if isTouchOnly then 36 else 28, 27), if isTouchOnly then 9 else 11)
	parryKey.Font = Enum.Font.SourceSansBold
	parryKey.TextColor3 = COLORS.CharcoalDeep
	parryKey.TextXAlignment = Enum.TextXAlignment.Center
	parryKey.BackgroundColor3 = COLORS.EmberLight
	parryKey.BackgroundTransparency = 0.04
	round(parryKey, 2)
	stroke(parryKey, COLORS.Iron, 0.15)
	local parryStatus = label(controls, "PARRY READY", UDim2.new(0.5, if isTouchOnly then 55 else 49, 0, 4), UDim2.new(0.5, if isTouchOnly then -60 else -61, 0, 19), if isTouchOnly then 10 else 12)
	parryStatus.Font = Enum.Font.SourceSansBold
	parryStatus.TextColor3 = COLORS.EmberLight
	parryStatus.TextTruncate = Enum.TextTruncate.AtEnd
	parryStatus.TextYAlignment = Enum.TextYAlignment.Center

	local parryTrack = newInstance("Frame", {
		BackgroundColor3 = COLORS.CharcoalDeep,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0.5, if isTouchOnly then 55 else 49, 1, -11),
		Size = UDim2.new(0.5, if isTouchOnly then -67 else -61, 0, 3),
		Parent = controls,
	}) :: Frame
	round(parryTrack, 1)
	local parryFill = newInstance("Frame", {
		BackgroundColor3 = COLORS.Ember,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = parryTrack,
	}) :: Frame
	gradient(parryFill, COLORS.EmberLight, COLORS.Ember, 0)

	local notification = panel(root, "Notification", UDim2.new(0.5, 0, 0.24, 0), UDim2.new(0.32, 0, 0, 42), Vector2.new(0.5, 0.5))
	constrain(notification, Vector2.new(220, 42), Vector2.new(360, 42))
	notification.Visible = false
	notification.ZIndex = 20
	local notificationText = label(notification, "", UDim2.fromOffset(18, 0), UDim2.new(1, -36, 1, 0), 16)
	notificationText.Font = Enum.Font.Antique
	notificationText.TextXAlignment = Enum.TextXAlignment.Center
	notificationText.TextStrokeColor3 = COLORS.CharcoalDeep
	notificationText.TextStrokeTransparency = 0.55
	notificationText.ZIndex = 21

	local damageOverlay = newInstance("Frame", {
		BackgroundColor3 = COLORS.Blood,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	}) :: Frame

	local self = setmetatable({
		_gui = gui,
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
		_notificationTween = nil,
		_damageTween = nil,
		_abilityToken = 0,
		_connections = {},
	} :: InternalUIController, UIController)

	return self
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
	if state == "Results" and result then
		self:Notify(result, if result == "SYSTEM VERIFIED" then COLORS.EmberLight else COLORS.ParchmentMuted, 2.5)
	end
end

function UIController:SetBoss(snapshot: { [string]: any })
	local state = if typeof(snapshot.state) == "string" then snapshot.state else "Unknown"
	local health = if typeof(snapshot.health) == "number" then snapshot.health else 0
	local maximumHealth = if typeof(snapshot.maximumHealth) == "number" and snapshot.maximumHealth > 0 then snapshot.maximumHealth else Config.Enemy.MaximumHealth
	local targetName = if typeof(snapshot.targetName) == "string" then snapshot.targetName else "NONE"

	self._bossState.Text = humanize(state)
	self._bossTarget.Text = if string.upper(targetName) == "NONE" then "NO TARGET" else "FACING " .. string.upper(targetName)
	self._bossHealthText.Text = string.format("%d / %d", math.max(0, math.floor(health)), math.floor(maximumHealth))
	TweenService:Create(self._bossHealthFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(math.clamp(health / maximumHealth, 0, 1), 1),
	}):Play()
end

function UIController:SetTelemetry(snapshot: { [string]: any })
	self._acceptedValue.Text = tostring(math.floor(if typeof(snapshot.accepted) == "number" then snapshot.accepted else 0))
	self._rejectedValue.Text = tostring(math.floor(if typeof(snapshot.rejected) == "number" then snapshot.rejected else 0))
	self._lastEvent.Text = formatCombatEvent(if typeof(snapshot.lastEvent) == "string" then snapshot.lastEvent else "Awaiting input")
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
			self._parryStatus.Text = if remaining > 0 then string.format("RECOVERING %.1fs", remaining) else "PARRY READY"
			self._parryStatus.TextColor3 = if remaining > 0 then COLORS.ParchmentMuted else COLORS.EmberLight
			if remaining <= 0 then
				break
			end
			task.wait(0.05)
		end
		if token == self._abilityToken then
			self._parryFill.Size = UDim2.fromScale(0, 1)
			self._parryStatus.Text = "PARRY READY"
			self._parryStatus.TextColor3 = COLORS.EmberLight
		end
	end)
end

function UIController:Notify(text: string, color: Color3?, duration: number?)
	self._notificationId += 1
	local id = self._notificationId

	if self._notificationTween then
		self._notificationTween:Cancel()
		self._notificationTween = nil
	end

	self._notificationText.Text = formatNotification(text)
	self._notificationText.TextColor3 = warmTone(color)
	self._notificationText.TextTransparency = 0
	self._notification.Visible = true
	self._notification.BackgroundTransparency = 0.38

	task.delay(duration or 1.4, function()
		if id ~= self._notificationId then
			return
		end

		local tween = TweenService:Create(self._notification, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
		})
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
	if self._damageTween then
		self._damageTween:Cancel()
	end

	self._damageOverlay.BackgroundTransparency = 0.83
	local tween = TweenService:Create(self._damageOverlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	})
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
	self._notificationId += 1
	if self._notificationTween then
		self._notificationTween:Cancel()
	end
	if self._damageTween then
		self._damageTween:Cancel()
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._gui:Destroy()
end

return UIController
