--!strict

local Config = {
	Version = "1.1.0",

	Brand = {
		Creator = "mehmet184",
		Title = "Scripter Showcase",
		Subtitle = "Server-authoritative Roblox gameplay engineering",
	},

	Match = {
		CountdownDuration = 5,
		ActiveDuration = 150,
		ResultsDuration = 8,
	},

	Combat = {
		AttackCooldown = 0.45,
		AttackRange = 14,
		AttackDamage = 28,
		AttackConeDot = 0.42,
		ParryWindow = 0.5,
		ParryRadius = 6.5,
		ParryCooldown = 1.25,
		MaximumDirectionMagnitude = 1.5,
		MinimumDirectionMagnitude = 0.5,
	},

	Enemy = {
		Name = "SENTINEL-01",
		MaximumHealth = 900,
		ProjectileCount = 5,
		ProjectileTelegraphDuration = 0.8,
		ProjectileLaunchInterval = 0.34,
		GroundSlamRadius = 18,
		GroundSlamDamage = 30,
		GroundSlamTelegraphDuration = 1.15,
		RecoveryDuration = 1.25,
		TargetRange = 180,
	},

	Projectile = {
		Speed = 52,
		ReflectedSpeedMultiplier = 1.22,
		HomingStrength = 4.5,
		HitRadius = 3,
		Lifetime = 7,
		PlayerDamage = 18,
		ReflectedDamage = 150,
	},

	Networking = {
		MaximumActionsPerSecond = 18,
		ActionWindowSeconds = 1,
	},

	Arena = {
		ModelName = "ScripterShowcaseArena",
		FloorSize = 140,
		SpawnCFrame = CFrame.new(0, 5, 42) * CFrame.Angles(0, math.rad(180), 0),
		BossCFrame = CFrame.new(0, 5, -22),
		RemoveDefaultBaseplate = true,
	},

	Palette = {
		Background = Color3.fromRGB(12, 15, 20),
		Panel = Color3.fromRGB(21, 26, 34),
		PanelAlt = Color3.fromRGB(28, 34, 44),
		Text = Color3.fromRGB(240, 244, 252),
		MutedText = Color3.fromRGB(151, 164, 184),
		Accent = Color3.fromRGB(59, 214, 134),
		Warning = Color3.fromRGB(255, 190, 72),
		Danger = Color3.fromRGB(255, 82, 104),
		Info = Color3.fromRGB(80, 155, 255),
	},
}

return table.freeze(Config)
