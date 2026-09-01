--!strict

local Config = {
	Version = "1.2.0",

	Brand = {
		Creator = "mehmet184",
		Title = "The Broken Court",
		Subtitle = "Defeat the warden before the last bell",
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
		Name = "WARDEN OF ASH",
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
		Background = Color3.fromRGB(22, 18, 14),
		Panel = Color3.fromRGB(42, 34, 27),
		PanelAlt = Color3.fromRGB(61, 49, 37),
		Text = Color3.fromRGB(239, 225, 195),
		MutedText = Color3.fromRGB(169, 151, 122),
		Accent = Color3.fromRGB(117, 143, 102),
		Warning = Color3.fromRGB(211, 150, 62),
		Danger = Color3.fromRGB(151, 53, 40),
		Info = Color3.fromRGB(116, 132, 137),
	},
}

return table.freeze(Config)
