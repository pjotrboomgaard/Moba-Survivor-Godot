# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Run the project (F5/F6 in-editor, or headless):

```bash
godot --path .                                  # normal local run
godot --path . -- --host                        # listen server
godot --path . -- --join=127.0.0.1               # client
godot --headless --path . -- --server            # dedicated server
godot --path . -- --classic                      # force Classic mode
godot --path . -- --pjotr --start-wave=10        # force Pjotr mode, skip to wave 10
```

Validate without opening the editor (checks project layout and all `res://` references):

```bash
./tests/validate_project.sh
```

Run the headless smoke test (fires every weapon at real enemies; asserts chains, cones, auras,
slows, taunt, projectiles, damage, flight, explosions, splitting, summoning, charging,
separation, wave archetypes, boss placement and the classic spawn rhythm):

```bash
godot --headless --path . --import                       # required after adding/renaming any class_name script
godot --headless --path . res://tests/class_smoke_test.tscn
```

Import must run first whenever a script's `class_name` was added or renamed — Godot only
registers global class names during an import pass, and the test scene fails to parse otherwise.
The smoke test exits non-zero and prints the failing assertion on a regression.

Regenerate pixel art (hand-authored character grids in `tools/sprite_art.gd`, baked to PNG):

```bash
godot --headless --path . res://tools/sprite_forge.tscn
```

The forge refuses to write if a grid isn't square or uses an out-of-palette colour, and writes
`assets/sprites/_contact_sheet.png` for reviewing the whole set at once.

## Architecture

**Engine**: Godot 4.7, GL compatibility renderer (desktop + mobile reach). Entry point is
`scenes/bootstrap/bootstrap.tscn`.

**Two game modes share one codebase**: Classic (the original run — Arclight only, endless
Grunts, no waves/bosses/gold/shop) and Pjotr mode (four classes, full enemy roster, themed
waves, bosses, shop). Mode is picked at the start screen or via `--classic`/`--pjotr`. Code
branches on mode rather than being two separate projects — check for mode gating before adding
features that shouldn't leak into Classic.

**Server-authoritative multiplayer**: one Godot project produces both the client and the
headless dedicated server. The server owns player/enemy health, spawning and movement, damage,
cooldowns, XP/levels/gold/drops, and win/loss state. Clients only ever send input intentions
(movement direction, aim direction, buttons, upgrade choice) — never outcomes. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full authority split and
[docs/PHASE_1.md](docs/PHASE_1.md) for the current networking boundary and its limitations.
Clients currently interpolate authoritative snapshots with no prediction/reconciliation yet.

**Autoloads** (`autoload/`, registered in `project.godot`) are the cross-cutting services:
`GameRuntime`, `SteamService`, `NetworkService`, `PlayerProfile`, `InputService`, `AudioService`.
Transport is ENet/UDP by default; when Steam is running, `SteamService`
(`addons/godotsteam`, GodotSteam GDExtension) swaps in `SteamMultiplayerPeer` for the same
`multiplayer.multiplayer_peer` slot, giving NAT-free P2P via Steam lobbies/overlay invites.
Steam is transport only today — it does not own player identity; `PlayerProfile` still does.

**Gameplay code** lives in `scripts/` (one script per concept: `enemy.gd`/`enemy_type.gd`,
`player.gd`/`player_class.gd`, `wave_director.gd`, `shop_catalog.gd`/`shop_stand.gd`,
`health_component.gd`, etc.) with matching scenes under `scenes/` (`arena/`, `enemy/`,
`player/`, `projectile/`, `xp/`, `ui/`). `wave_director.gd` drives wave composition from a
budget (`4 + wave × 1.5`, +45% per extra player) using archetypes (Advance, Swarm, Air Assault,
Snipers, Ambush, Elite Guard, Boss) plus modifiers (Enraged, Armoured, Fragile Horde) rather than
per-wave hardcoding beyond the hand-authored waves 1–20.

**Physics layers** (`project.godot`): World, Players, Enemies, Projectiles — keep collision
masks aligned with this when adding new bodies.

**Backend direction** (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)): account/entitlement
API + PostgreSQL + a match-server allocator spinning up Docker game-server processes
(`infra/docker/`). Platform identities (Steam/Apple/Google) must link to an internal player
account and never become the canonical DB key.

## Godot-specific gotchas

- After adding or renaming a script with `class_name`, run `godot --headless --path . --import`
  before running tests — global class names only register during an import pass.
- Sprites fall back silently to the original vector drawing if a PNG is missing from
  `assets/sprites/`, so a broken sprite forge run fails quietly rather than crashing.
- `steam_appid.txt` holds Valve's public "Spacewar" test App ID (`480`) for development; a real
  release needs the studio's own Steamworks App ID there instead.
