# Architecture

## Product targets

- Windows and macOS clients first.
- Android and iOS clients later, using the same simulation and backend.
- One Linux headless dedicated server export from the same Godot project.
- One to four players; every run must remain enjoyable solo.

## Runtime split

```text
Godot shared gameplay and data
├── desktop presentation + mouse/controller input
├── mobile presentation + touch input
└── headless authoritative simulation

Clients
├── platform adapter (guest / Steam / Apple / Google)
├── neutral player_id and server-side entitlements
└── ENet/UDP connection

Backend
├── account and entitlement API
├── PostgreSQL
└── match-server allocator → Docker game-server processes
```

Steam, Apple and Google identities must be links to an internal player account. They must never become the canonical database key. Store SDK calls stay behind platform adapters, so gameplay code does not know which store launched it.

## Authority rules

The dedicated server will own:

- Player health, enemy health and deaths.
- Enemy spawning and movement.
- Damage, cooldowns and chains from the Arc Staff.
- XP, levels, gold, drops and upgrade choices.
- Run timer, bosses and win/loss state.

Clients send input intentions: movement direction, aim direction, button state and upgrade choice. A client must not tell the server that it dealt damage, collected gold or completed a level.

## Current phase-1 boundary

The lobby, dynamic network players, input messages and authoritative snapshots now form a complete small multiplayer loop. Players, enemies, health, Arc Staff damage, XP and upgrade validation are server-owned. The client currently interpolates authoritative positions without prediction. This deliberately prioritizes correctness before latency masking and bandwidth optimization.

## Command-line modes

```bash
# Normal local test
godot --path .

# Listen-server foundation
godot --path . -- --host --port=27015

# Client foundation
godot --path . -- --join=127.0.0.1 --port=27015

# Dedicated server foundation
godot --headless --path . -- --server --port=27015
```

The double dash separates Godot's arguments from project arguments.
