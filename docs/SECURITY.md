# Security Model

## Trust boundary

Everything received from `ActionRequest.OnServerEvent` is treated as untrusted.

The only supported client requests are:

```text
Attack { direction: Vector3 }
Parry
```

The HUD calls the first action **Strike**; the network protocol deliberately retains the narrow `Attack` action name.

The attack request does not contain a target, damage value, range, hit position, boss reference, or success flag.

## Validation layers

### 1. Action allowlist

Unknown action names and non-string action identifiers are rejected.

### 2. Global rate limit

All action requests share a server-side fixed-window rate limit. This is separate from gameplay cooldowns.

### 3. Match context

Combat requests are accepted only during the `Active` match state.

### 4. Character context

Both actions require a living Humanoid and HumanoidRootPart. Attack validation additionally requires a Head to establish the server-owned strike origin.

### 5. Payload validation

For attacks, the server checks the payload table, direction Vector3, finite values, and an expected magnitude range before normalization. Parry does not consume a payload.

### 6. Per-action cooldown

Attack and parry timing are tracked with `os.clock()` on the server.

### 7. Server-owned hit resolution

The server uses its own character origin, configured range, configured cone, server-known boss position, and a Workspace raycast.

### 8. Server-owned parry timing and proximity

The parry window is stored only in `CombatService`. At collision time, the server verifies both the active window and the distance between the character root and the projectile collision point. A successful window is consumed once.

### 9. World obstruction

Projectile movement checks each server simulation segment with `Workspace:Raycast`. Player characters, the projectile folder, and the boss model are excluded because those targets are resolved through explicit server collision paths.

## Intentionally excluded patterns

This showcase does not include:

- Client-provided target Instances
- Client-provided damage
- Client-authoritative projectile movement
- Client-confirmed hits
- Generic remotes that mutate arbitrary DataModel paths
- Dynamic `require()` based on client data
- Remote relays that blindly broadcast client payloads
