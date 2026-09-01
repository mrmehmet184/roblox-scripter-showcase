# The Broken Court — Roblox Scripting Showcase

**Created by [mehmet184](https://www.roblox.com/users/361890644/profile)**

A focused Roblox/Luau boss encounter built for technical review. Fight the **Warden of Ash** in a fully runtime-generated ruined court while the project demonstrates server-authoritative combat, projectile parrying and reflection, explicit state machines, remote validation, rate limiting, and a touch-aware gameplay HUD.

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
- Fully runtime-generated ruined medieval court and detailed stone-and-iron boss
- Sunset lighting, atmosphere, fog, color grading, and restrained combat effects
- Desktop, gamepad, and touch input support
- Replicated accepted/rejected request counters for technical inspection (hidden in the default HUD)

## Current presentation

The showcase now uses a cohesive worn-stone, iron, parchment, and ember visual language instead of a generic neon dashboard. `ArenaService` builds the uneven court floor, central seal, ruined walls and arches, columns, banners, braziers, rubble, boundaries, spawn point, and Warden model entirely from Roblox primitives. The client adds a compact boss/match HUD, a touch-aware control layout, parry cooldown feedback, impact shards, guard effects, slam markers, damage feedback, and camera response.

## Controls

| Input | Action |
|---|---|
| Left Mouse / `F` / Right Trigger | Strike |
| `Q` / Left Trigger | Parry and reflect |
| Movement keys / thumbstick | Move |

The player-facing **Strike** label maps to the validated `Attack` network action.

## Security model

The client sends action intent and an aim direction. It does not choose targets, damage, hit results, boss health, projectile outcomes, parry success, or match results.

The server validates:

- Action names and required attack fields/types
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
5. [`ArenaService.luau`](src/ServerScriptService/ShowcaseServer/Services/ArenaService.luau) — runtime court, Warden, lighting, and stable gameplay references
6. [`StateMachine.luau`](src/ReplicatedStorage/ShowcaseShared/StateMachine.luau) — reusable transition primitive
7. [`UIController.luau`](src/StarterPlayer/StarterPlayerScripts/ShowcaseClientModules/UIController.luau) — touch-aware gameplay HUD and cooldown feedback
8. [`EffectsController.luau`](src/StarterPlayer/StarterPlayerScripts/ShowcaseClientModules/EffectsController.luau) — local combat feedback and effect cleanup

## Documentation

- [`docs/REVIEWER_GUIDE.md`](docs/REVIEWER_GUIDE.md)
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/SECURITY.md`](docs/SECURITY.md)

## Rights

Copyright © 2026 mehmet184. All rights reserved. This repository is publicly viewable for portfolio review, recruitment evaluation, and technical demonstration. Redistribution, resale, or commercial reuse is not permitted without written permission.
