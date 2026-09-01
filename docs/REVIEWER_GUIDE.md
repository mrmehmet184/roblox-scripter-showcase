# Reviewer Guide

This repository is intentionally scoped for a fast technical review.

## Run the showcase

1. Install Rojo and the Roblox Studio Rojo plugin.
2. Open a blank Roblox Studio place.
3. Run `rojo serve` from the repository root.
4. Connect the Studio plugin to `default.project.json`.
5. Press Play.

The arena, boss, networking surface, match lifecycle, and interface are generated at runtime. No external assets are required.

## Suggested code-review order

1. `CombatService.luau` — untrusted request validation, cooldowns, range, aim-cone checks, line of sight, and server hit resolution.
2. `ProjectileService.luau` — server-owned homing movement, segment collision, parry consumption, reflection, lifetime, and damage.
3. `EnemyService.luau` — target selection, attack scheduling, telegraphs, explicit boss states, and sequence interruption.
4. `MatchService.luau` — waiting, countdown, active, results, cleanup, and reset ownership.
5. `StateMachine.luau` — allowed transitions and observable state changes.
6. `UIController.luau` — responsive telemetry and cross-platform presentation.

## In-game checks

- The client sends intent rather than damage or target decisions.
- Invalid or excessive requests are rejected and shown in telemetry.
- Projectiles are simulated and resolved by the server.
- Parry timing is owned by the server and consumed once.
- Reflected projectiles use a separate server damage path.
- Boss and match states are visible in the interface.
- The simulation resets cleanly after the result state.

Additional design details are available in `ARCHITECTURE.md` and `SECURITY.md`.
