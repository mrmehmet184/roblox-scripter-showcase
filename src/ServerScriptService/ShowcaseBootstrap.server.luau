--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("ShowcaseShared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(ReplicatedStorage.ShowcaseShared.Types)

type FullSnapshot = Types.FullSnapshot

local ServerFolder = ServerScriptService:WaitForChild("ShowcaseServer")
local Services = ServerFolder:WaitForChild("Services")

local RemoteService = require(Services:WaitForChild("RemoteService"))
local RateLimiter = require(Services:WaitForChild("RateLimiter"))
local ArenaService = require(Services:WaitForChild("ArenaService"))
local MatchService = require(Services:WaitForChild("MatchService"))
local CombatService = require(Services:WaitForChild("CombatService"))
local ProjectileService = require(Services:WaitForChild("ProjectileService"))
local EnemyService = require(Services:WaitForChild("EnemyService"))

local remotes = RemoteService.Create()
local rateLimiter = RateLimiter.new()
local arenaService = ArenaService.new()
local matchService = MatchService.new(remotes, arenaService)
local combatService = CombatService.new(remotes, rateLimiter, matchService)
local projectileService = ProjectileService.new(remotes, arenaService, combatService)
local enemyService = EnemyService.new(
	remotes,
	arenaService,
	projectileService,
	combatService,
	matchService
)

combatService:SetEnemyService(enemyService)
projectileService:SetEnemyService(enemyService)
matchService:SetEnemyService(enemyService)

remotes.Snapshot.OnServerInvoke = function(player: Player): FullSnapshot
	return {
		match = matchService:GetSnapshot(),
		boss = enemyService:GetSnapshot(),
		telemetry = combatService:GetTelemetry(player),
		version = Config.Version,
	}
end

Workspace:SetAttribute("ScripterShowcaseVersion", Config.Version)
matchService:Start()

print(string.format(
	"[Scripter Showcase] %s v%s is running with server-authoritative combat.",
	Config.Brand.Creator,
	Config.Version
))

game:BindToClose(function()
	matchService:Destroy()
	enemyService:Destroy()
	projectileService:Destroy()
	combatService:Destroy()
	rateLimiter:Destroy()
end)
