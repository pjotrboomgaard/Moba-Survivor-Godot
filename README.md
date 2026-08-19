# Co-op MOBA Survivor

Production-oriented Godot project for a one-to-four-player cooperative action survivor. The playable slice is deliberately small, but it now uses the same authoritative multiplayer direction intended for Windows, macOS, future mobile clients and Linux dedicated servers.

## Current playable slice

- WASD movement in a bounded arena.
- Enemy spawning, pursuit and contact damage.
- Cursor-directed Arc Staff with a cyan primary bolt and purple chains.
- XP drops, levels and structured offence/survival/utility choices.
- Arc Staff tech including extra chains, chain range and Split Current.
- Critical hits, regeneration, lifesteal and XP pickup upgrades.
- Floating damage, critical-hit, healing and XP numbers.
- Live Arc Staff stat panel and escalating enemy silhouettes.
- Health, death and restart.
- Placeholder vector graphics only.

## Phase-1 network slice

- One Godot project for clients and the headless server.
- In-game Solo, Host and Join menu plus dedicated-server startup mode.
- ENet/UDP transport with dynamic players and a four-player total limit.
- Server-authoritative movement, enemy simulation, damage, health and XP.
- Twenty world snapshots and thirty client input messages per second by default.
- Server-validated level-up choices.
- Platform-neutral player profile scaffold.
- Shared input service ready for keyboard, controller and touch adapters.
- Compatibility renderer for broad desktop and mobile support.
- Docker definition for the exported Linux server.

See [docs/PHASE_1.md](docs/PHASE_1.md) for the two-instance test and honest limitations, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the long-term design.

## Run in Godot

1. Install the current stable Godot 4 release.
2. Import this folder through `project.godot`.
3. Press F6/F5 and choose Solo, Host or Join.
4. Move with WASD and hold the left mouse button to aim and cast the Arc Staff.

Gameplay test controls:

- `Esc`: open the run menu.
- `F1`: toggle developer tools in a debug build.
- Dev tools can add XP, add five levels without opening pickers, spawn an elite
  and toggle invulnerability. Online commands are validated by the server.

Command-line development modes:

```bash
godot --path .
godot --path . -- --host
godot --path . -- --join=127.0.0.1
godot --headless --path . -- --server
```

## Validate without opening the editor

```bash
./tests/validate_project.sh
```

This checks the project layout and all `res://` file references. A full GDScript parse and runtime check still requires Godot.

## Next checkpoint

The next gameplay checkpoint deepens the Arc Staff into mutually exclusive
Chain Lightning and Storm Caller branches, then adds the first wave director
and boss. Networking work continues in parallel with reconnect handling and
the first hosted dedicated-server deployment.
