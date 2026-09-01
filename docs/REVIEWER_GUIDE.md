# Reviewer Guide

This repository is intentionally scoped for a fast technical review.

## Run the showcase

1. Install Rojo and the Roblox Studio Rojo plugin.
2. Open a blank Roblox Studio place.
3. Run `rojo serve` from the repository root.
4. Connect the Studio plugin to `default.project.json`.
5. Press Play.

The Broken Court, Warden of Ash, networking surface, match lifecycle, interface, and combat effects are generated at runtime. No external assets are required.

## Suggested code-review order

1. `CombatService.luau` — untrusted request validation, cooldowns, range, aim-cone checks, line of sight, and server hit resolution.
2. `ProjectileService.luau` — server-owned homing movement, segment collision, parry consumption, reflection, lifetime, and damage.
3. `EnemyService.luau` — target selection, attack scheduling, telegraphs, explicit boss states, and sequence interruption.
4. `MatchService.luau` — waiting, countdown, active, results, cleanup, and reset ownership.
5. `ArenaService.luau` — runtime court construction, Warden model, lighting, boundaries, and stable service references.
6. `StateMachine.luau` — allowed transitions and observable state changes.
7. `UIController.luau` — compact touch-aware gameplay HUD and cooldown feedback.
8. `EffectsController.luau` — local-only combat feedback, camera response, and cleanup.

## In-game checks

- The client sends intent rather than damage or target decisions.
- Invalid or excessive requests are rejected and counted; the combat record is intentionally hidden in the default HUD.
- Projectiles are simulated and resolved by the server.
- Parry timing is owned by the server and consumed once.
- Reflected projectiles use a separate server damage path.
- The ruined court, Warden model, health billboard, sunset lighting, and compact desktop/touch HUD are generated without external assets.
- Strike/parry feedback includes thematic projectile colors, a guard effect, slam markers, impacts, and restrained camera response.
- Boss and match states are visible in the interface, while **Strike** maps to the server's `Attack` action.
- The simulation resets cleanly after the result state.

Additional design details are available in `ARCHITECTURE.md` and `SECURITY.md`.
