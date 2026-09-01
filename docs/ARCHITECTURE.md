# Architecture Notes

## Design goals

The showcase is optimized for five things:

1. A reviewer can understand it quickly.
2. Gameplay decisions remain server-authoritative.
3. Systems are separated by responsibility.
4. Round and enemy behavior are explicit rather than hidden in long loops.
5. The project runs without external assets or dependencies.

## Client responsibilities

The client may:

- Capture input
- Calculate an aim direction from the current camera
- Request an attack or parry
- Render UI and temporary visual effects
- Display replicated match and boss state
- Display replicated telemetry counters for technical inspection; the combat record is hidden in the default HUD

The client may not decide:

- Which target was hit
- Whether a request is valid
- Damage values
- Boss health
- Projectile collision
- Whether a parry succeeded
- Match results

## Server services

### RemoteService

Creates the fixed networking surface. There are no remotes that accept arbitrary Instance paths, arbitrary target Instances, or arbitrary damage values.

### RateLimiter

Applies a shared per-player fixed-window limit to combat requests. Per-action gameplay cooldowns remain separate from the global network limit.

### MatchService

Owns the lifecycle:

```text
Waiting -> Countdown -> Active -> Results
```

It prepares characters, starts and stops the enemy, resolves the round, and automatically resets the simulation.

### CombatService

Treats client input as untrusted intent. It validates the action allowlist, required attack fields and types, finite vectors, match state, character state, remote rate, action cooldown, range, aim cone, and line of sight.

### EnemyService

Owns boss health, target selection, attack sequencing, telegraphs, state transitions, interruption, reset, and defeat.

### ProjectileService

Owns projectile creation, homing movement, world-geometry raycasts, segment-based proximity collision, parry overlap, reflection, boss collision, damage, lifetime, and cleanup.

### ArenaService

Generates the complete presentation environment at runtime: worn court tiles, architectural ruins, landmarks, boundaries, spawn geometry, the Warden model and health billboard, and the lighting/post-processing stack. It exposes stable boss, spawn, arena-root, and projectile-folder references to the other services.

## Client presentation

- `InputController` converts keyboard, mouse, gamepad, and touch input into narrow attack/parry intent messages.
- `UIController` renders the match timer, boss health/state/target, a touch-aware control layout, parry cooldown, and themed notifications.
- `EffectsController` renders local-only attack traces, parry guards, projectile/reflection feedback, slam warnings and impacts, debris bursts, damage numbers, and camera response. Teardown stops tracked guards and camera work; short-lived effects self-clean through `Debris`.

## Shared primitives

- `StateMachine` provides explicit allowed transitions and observable state changes.
- `Janitor` owns client and server connection/controller cleanup.
- `MathUtil` centralizes finite-number checks, safe vector normalization, and segment collision helpers.
- `Types` defines the replicated match, boss, telemetry, and full snapshot contracts.

## Dependency flow

```text
Bootstrap
├── RemoteService
├── RateLimiter
├── ArenaService
├── MatchService
├── CombatService
├── ProjectileService
└── EnemyService
```

Circular gameplay relationships are resolved through dependency injection after construction instead of requiring services from each other.

## Failure behavior

- Malformed attack payloads are rejected and counted.
- Excessive requests are rate-limited.
- Missing characters or dead Humanoids cannot act.
- Projectiles self-remove if their target disappears or world geometry blocks their movement segment.
- Attack sequences are invalidated through sequence IDs when a round stops or resets.
- All runtime projectiles are cleared between rounds and during shutdown.
