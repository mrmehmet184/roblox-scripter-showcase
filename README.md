# Roblox Scripting Showcase

**Created by [mehmet184](https://www.roblox.com/users/361890644/profile)**

A focused Roblox/Luau gameplay showcase built for technical review. The project demonstrates server-authoritative combat, projectile parrying and reflection, configurable boss behavior, explicit state machines, remote validation, rate limiting, and a responsive telemetry interface.

> **Playable demo:** The Roblox experience link will be added after publishing and live testing.

## Systems demonstrated

- Typed Luau with `--!strict`
- Server-authoritative melee combat
- Cooldown, range, aim-cone, and line-of-sight validation
- Per-player remote rate limiting
- Server-simulated homing projectiles
- Timed parry windows and projectile reflection
- Configurable boss targeting and attack scheduling
- Match and enemy state machines
- Runtime-generated arena and boss model
- Desktop, gamepad, and touch input support
- Live accepted/rejected request telemetry

## Controls

| Input | Action |
|---|---|
| Left Mouse / `F` / Right Trigger | Attack |
| `Q` / Left Trigger | Parry and reflect |
| Movement keys / thumbstick | Move |

## Security model

The client sends action intent and an aim direction. It does not choose targets, damage, hit results, boss health, projectile outcomes, parry success, or match results.

The server validates:

- Action names and payload shapes
- Finite numeric values
- Match and character state
- Request rate and action cooldowns
- Attack range and aim cone
- Line of sight
- Projectile movement and collision
- Parry timing and reflected damage

## Project structure

```text
src/
├── ReplicatedStorage/
│   └── ShowcaseShared/
│       ├── Config.luau
│       ├── Janitor.luau
│       ├── MathUtil.luau
│       ├── StateMachine.luau
│       └── Types.luau
├── ServerScriptService/
│   ├── ShowcaseBootstrap.server.luau
│   └── ShowcaseServer/
│       └── Services/
│           ├── ArenaService.luau
│           ├── CombatService.luau
│           ├── EnemyService.luau
│           ├── MatchService.luau
│           ├── ProjectileService.luau
│           ├── RateLimiter.luau
│           └── RemoteService.luau
└── StarterPlayer/
    └── StarterPlayerScripts/
        ├── ShowcaseClient.client.luau
        └── ShowcaseClientModules/
            ├── EffectsController.luau
            ├── InputController.luau
            └── UIController.luau
```

## Run in Roblox Studio

1. Install [Rojo](https://rojo.space/) and the Roblox Studio Rojo plugin.
2. Clone or download this repository.
3. Open a blank place in Roblox Studio.
4. Run the following command in the repository root:

```bash
rojo serve
```

5. Connect the Studio plugin to `default.project.json`.
6. Press **Play**.

The server generates the arena, boss, remotes, round lifecycle, and gameplay environment at runtime. No external models, animations, sounds, or asset IDs are required.

## Recommended review path

1. [`CombatService.luau`](src/ServerScriptService/ShowcaseServer/Services/CombatService.luau) — request validation and server hit resolution
2. [`ProjectileService.luau`](src/ServerScriptService/ShowcaseServer/Services/ProjectileService.luau) — homing movement, collision, parry, and reflection
3. [`EnemyService.luau`](src/ServerScriptService/ShowcaseServer/Services/EnemyService.luau) — targeting, telegraphs, and attack sequencing
4. [`MatchService.luau`](src/ServerScriptService/ShowcaseServer/Services/MatchService.luau) — round lifecycle and reset ownership
5. [`StateMachine.luau`](src/ReplicatedStorage/ShowcaseShared/StateMachine.luau) — reusable transition primitive
6. [`UIController.luau`](src/StarterPlayer/StarterPlayerScripts/ShowcaseClientModules/UIController.luau) — responsive telemetry UI

## Documentation

- [`docs/REVIEWER_GUIDE.md`](docs/REVIEWER_GUIDE.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/SECURITY.md`](docs/SECURITY.md)

## Rights

Copyright © 2026 mehmet184. All rights reserved. This repository is publicly viewable for portfolio review, recruitment evaluation, and technical demonstration. Redistribution, resale, or commercial reuse is not permitted without written permission.
