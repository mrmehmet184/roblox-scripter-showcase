--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("Config"))
local MathUtil = require(ReplicatedStorage:WaitForChild("ShowcaseShared"):WaitForChild("MathUtil"))

local EffectsController = {}
EffectsController.__index = EffectsController

local random = Random.new()

type InternalEffectsController = {
	_ui: any,
	_localPlayer: Player,
	_shakeToken: number,
	_destroyed: boolean,
	_activeGuards: { [BasePart]: boolean },
}

export type EffectsController = typeof(setmetatable({} :: InternalEffectsController, EffectsController))

local function makePart(
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Parent = Workspace
	return part
end

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function getLocalHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function EffectsController.new(uiController: any): EffectsController
	return setmetatable({
		_ui = uiController,
		_localPlayer = Players.LocalPlayer,
		_shakeToken = 0,
		_destroyed = false,
		_activeGuards = {},
	}, EffectsController)
end

function EffectsController:_burst(position: Vector3, color: Color3, maximumSize: number)
	local ring = makePart(
		"LocalImpactRing",
		position + Vector3.new(0, 0.08, 0),
		Vector3.new(0.08, 0.8, 0.8),
		color,
		Enum.Material.SmoothPlastic
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.72

	TweenService:Create(
		ring,
		TweenInfo.new(0.34, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.08, maximumSize, maximumSize),
			Transparency = 1,
		}
	):Play()
	Debris:AddItem(ring, 0.4)

	local travel = math.clamp(maximumSize * 0.42, 1.2, 7)
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2 + random:NextNumber(-0.22, 0.22)
		local direction = Vector3.new(math.cos(angle), random:NextNumber(0.28, 0.72), math.sin(angle)).Unit
		local shardColor = color:Lerp(Color3.fromRGB(94, 76, 57), 0.48)
		local shard = makePart(
			"LocalImpactShard",
			position + Vector3.new(0, 0.35, 0),
			Vector3.new(random:NextNumber(0.12, 0.24), random:NextNumber(0.12, 0.32), random:NextNumber(0.12, 0.24)),
			shardColor,
			Enum.Material.Slate
		)
		shard.Transparency = 0.08
		local destination = position + direction * random:NextNumber(travel * 0.55, travel)
		TweenService:Create(
			shard,
			TweenInfo.new(random:NextNumber(0.28, 0.46), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				CFrame = CFrame.new(destination) * CFrame.Angles(
					random:NextNumber(-2.5, 2.5),
					random:NextNumber(-2.5, 2.5),
					random:NextNumber(-2.5, 2.5)
				),
				Transparency = 1,
				Size = shard.Size * 0.45,
			}
		):Play()
		Debris:AddItem(shard, 0.52)
	end
end

function EffectsController:_showDamageNumber(position: Vector3, amount: number, color: Color3, prefix: string?)
	local anchor = makePart("DamageNumberAnchor", position, Vector3.one * 0.1, color, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1

	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Antique
	label.Text = string.format("%s%d", prefix or "-", math.floor(amount))
	label.TextColor3 = color
	label.TextSize = 25
	label.TextStrokeColor3 = Config.Palette.Background
	label.TextStrokeTransparency = 0.42
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	TweenService:Create(
		billboard,
		TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0) }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.42),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()

	Debris:AddItem(anchor, 0.75)
end

function EffectsController:_attackTrace(payload: { [string]: any })
	if typeof(payload.origin) ~= "Vector3" or typeof(payload.direction) ~= "Vector3" then
		return
	end

	local range = if typeof(payload.range) == "number" then math.clamp(payload.range, 1, 30) else 12
	local direction = MathUtil.SafeUnit(payload.direction, Vector3.new(0, 0, -1))
	local midpoint = payload.origin + direction * (range * 0.5)
	local color = if payload.userId == self._localPlayer.UserId then Color3.fromRGB(223, 210, 172) else Config.Palette.MutedText
	local trace = makePart("LocalAttackTrace", midpoint, Vector3.new(0.09, 0.48, range), color, Enum.Material.SmoothPlastic)
	trace.CFrame = CFrame.lookAt(midpoint, midpoint + direction)
	trace.Transparency = 0.58

	TweenService:Create(
		trace,
		TweenInfo.new(0.13, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = Vector3.new(0.02, 0.08, range * 1.03) }
	):Play()
	Debris:AddItem(trace, 0.2)

	if payload.hit == true and typeof(payload.hitPosition) == "Vector3" then
		self:_burst(payload.hitPosition, Config.Palette.Accent, 3.2)
	end
end

function EffectsController:_showParryShield(userId: number, duration: number)
	if self._destroyed then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end

	local character = player.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local shield = makePart(
		"LocalParryGuard",
		rootPart.Position,
		Vector3.new(0.5, 1, 0.12),
		Config.Palette.Warning,
		Enum.Material.Metal
	)
	shield.Transparency = 0.58
	shield.CFrame = rootPart.CFrame * CFrame.new(0, 0.5, -2.1)

	local guardGlow = Instance.new("Highlight")
	guardGlow.Name = "GuardGlow"
	guardGlow.Adornee = shield
	guardGlow.DepthMode = Enum.HighlightDepthMode.Occluded
	guardGlow.FillColor = Config.Palette.Warning
	guardGlow.FillTransparency = 0.62
	guardGlow.OutlineColor = Color3.fromRGB(244, 205, 120)
	guardGlow.OutlineTransparency = 0.28
	guardGlow.Parent = shield
	self._activeGuards[shield] = true

	TweenService:Create(
		shield,
		TweenInfo.new(math.min(duration, 0.18), Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = Vector3.new(5.2, 5.8, 0.16), Transparency = 0.72 }
	):Play()

	task.spawn(function()
		local startedAt = os.clock()
		while not self._destroyed and shield.Parent ~= nil and os.clock() - startedAt < duration do
			local currentCharacter = player.Character
			local currentRoot = if currentCharacter ~= nil then currentCharacter:FindFirstChild("HumanoidRootPart") else nil
			if currentRoot and currentRoot:IsA("BasePart") then
				shield.CFrame = currentRoot.CFrame * CFrame.new(0, 0.5, -2.1)
			end
			RunService.RenderStepped:Wait()
		end

		if shield.Parent ~= nil then
			local tween = TweenService:Create(
				shield,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = Vector3.new(6.4, 6.8, 0.08), Transparency = 1 }
			)
			tween:Play()
			tween.Completed:Wait()
			shield:Destroy()
		end
		self._activeGuards[shield] = nil
	end)
end

function EffectsController:_showSlamTelegraph(position: Vector3, radius: number, duration: number)
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "LocalSlamWarning"
	markerFolder.Parent = Workspace

	local disc = makePart(
		"LocalSlamTelegraph",
		position + Vector3.new(0, 0.06, 0),
		Vector3.new(0.12, 2, 2),
		Config.Palette.Danger,
		Enum.Material.SmoothPlastic
	)
	disc.Parent = markerFolder
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(disc.Position) * CFrame.Angles(0, 0, math.rad(90))
	disc.Transparency = 0.86

	TweenService:Create(
		disc,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{
			Size = Vector3.new(0.12, radius * 2, radius * 2),
			Transparency = 0.76,
		}
	):Play()

	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2
		local markerPosition = position + Vector3.new(math.cos(angle) * radius, 0.12, math.sin(angle) * radius)
		local marker = makePart(
			"WarningStone",
			markerPosition,
			Vector3.new(0.48, 0.1, 2.3),
			Color3.fromRGB(173, 64, 43),
			Enum.Material.SmoothPlastic
		)
		marker.Parent = markerFolder
		marker.CFrame = CFrame.lookAt(markerPosition, Vector3.new(position.X, markerPosition.Y, position.Z))
		marker.Transparency = 0.32
		TweenService:Create(
			marker,
			TweenInfo.new(math.max(0.08, duration / 4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
			{ Transparency = 0.74 }
		):Play()
	end

	Debris:AddItem(markerFolder, duration + 0.08)
end

function EffectsController:_showSlamImpact(position: Vector3, radius: number)
	local disc = makePart(
		"LocalSlamImpact",
		position + Vector3.new(0, 0.08, 0),
		Vector3.new(0.18, radius * 0.3, radius * 0.3),
		Color3.fromRGB(119, 76, 49),
		Enum.Material.Slate
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	disc.Transparency = 0.48

	TweenService:Create(
		disc,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.18, radius * 2.25, radius * 2.25),
			Transparency = 1,
		}
	):Play()
	Debris:AddItem(disc, 0.38)
	self:_burst(position + Vector3.new(0, 0.8, 0), Color3.fromRGB(152, 95, 55), 8)
	self:_shakeCamera(0.3, 0.42)
end

function EffectsController:_shakeCamera(strength: number, duration: number)
	self._shakeToken += 1
	local token = self._shakeToken

	task.spawn(function()
		local startedAt = os.clock()
		while not self._destroyed and token == self._shakeToken do
			local elapsed = os.clock() - startedAt
			if elapsed >= duration then
				break
			end

			local humanoid = getLocalHumanoid(self._localPlayer)
			if humanoid ~= nil then
				local fade = 1 - elapsed / duration
				humanoid.CameraOffset = Vector3.new(
					(math.random() - 0.5) * 2,
					(math.random() - 0.5) * 2,
					0
				) * strength * fade
			end

			RunService.RenderStepped:Wait()
		end

		if token == self._shakeToken then
			local humanoid = getLocalHumanoid(self._localPlayer)
			if humanoid ~= nil then
				humanoid.CameraOffset = Vector3.zero
			end
		end
	end)
end

function EffectsController:Handle(payload: { [string]: any })
	local effectType = payload.type
	if typeof(effectType) ~= "string" then
		return
	end

	if effectType == "Attack" then
		self:_attackTrace(payload)
	elseif effectType == "ParryWindow" then
		if typeof(payload.userId) == "number" and typeof(payload.duration) == "number" then
			self:_showParryShield(payload.userId, math.clamp(payload.duration, 0.05, 2))
		end
	elseif effectType == "ParrySuccess" then
		if typeof(payload.position) == "Vector3" then
			self:_burst(payload.position, Config.Palette.Warning, 7)
		end
		if payload.userId == self._localPlayer.UserId then
			self._ui:Notify("Perfect parry!", Config.Palette.Warning, 1.35)
		end
	elseif effectType == "ProjectileReflected" then
		if typeof(payload.position) == "Vector3" then
			self:_burst(payload.position, Config.Palette.Warning, 4.5)
		end
	elseif effectType == "ProjectileBlocked" then
		if typeof(payload.position) == "Vector3" then
			self:_burst(payload.position, Config.Palette.MutedText, 2.8)
		end
	elseif effectType == "ReflectedProjectileHit" then
		if typeof(payload.position) == "Vector3" and typeof(payload.amount) == "number" then
			self:_burst(payload.position, Config.Palette.Warning, 8)
			self:_shakeCamera(0.18, 0.24)
		end
	elseif effectType == "BossDamaged" then
		if typeof(payload.position) == "Vector3" and typeof(payload.amount) == "number" then
			local damageColor = if payload.source == "ReflectedProjectile" then Config.Palette.Warning else Config.Palette.Accent
			self:_showDamageNumber(payload.position, payload.amount, damageColor)
		end
	elseif effectType == "BossTelegraph" then
		local attack = if typeof(payload.attack) == "string" then payload.attack else "INCOMING ATTACK"
		local warning = if attack == "PROJECTILE VOLLEY" then "Incoming volley!" elseif attack == "GROUND SLAM" then "The Warden raises its hammer!" else "The Warden is attacking!"
		self._ui:Notify(warning, Config.Palette.Danger, 1.05)
	elseif effectType == "SlamTelegraph" then
		if typeof(payload.position) == "Vector3" and typeof(payload.radius) == "number" and typeof(payload.duration) == "number" then
			self:_showSlamTelegraph(
				payload.position,
				math.clamp(payload.radius, 1, 60),
				math.clamp(payload.duration, 0.1, 5)
			)
			self._ui:Notify("Move out of the marked ground!", Config.Palette.Danger, payload.duration)
		end
	elseif effectType == "SlamImpact" then
		if typeof(payload.position) == "Vector3" and typeof(payload.radius) == "number" then
			self:_showSlamImpact(payload.position, math.clamp(payload.radius, 1, 60))
		end
	elseif effectType == "PlayerDamaged" then
		if payload.userId == self._localPlayer.UserId then
			self._ui:FlashDamage()
			self._ui:Notify("You were hit.", Config.Palette.Danger, 0.72)
			self:_shakeCamera(0.12, 0.18)
		end
	elseif effectType == "BossDefeated" then
		if typeof(payload.position) == "Vector3" then
			self:_burst(payload.position, Config.Palette.Accent, 18)
		end
		self._ui:Notify("The Warden has fallen.", Config.Palette.Accent, 3)
		self:_shakeCamera(0.22, 0.5)
	end
end

function EffectsController:Destroy()
	self._destroyed = true
	self._shakeToken += 1
	for guard in pairs(self._activeGuards) do
		if guard.Parent ~= nil then
			guard:Destroy()
		end
	end
	table.clear(self._activeGuards)
	local humanoid = getLocalHumanoid(self._localPlayer)
	if humanoid ~= nil then
		humanoid.CameraOffset = Vector3.zero
	end
end

return EffectsController
