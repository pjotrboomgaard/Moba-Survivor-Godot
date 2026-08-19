# Co-op MOBA Survivor

Production-oriented Godot project for a one-to-four-player cooperative action survivor. The playable slice is deliberately small, but it now uses the same authoritative multiplayer direction intended for Windows, macOS, future mobile clients and Linux dedicated servers.

## Current playable slice

- WASD movement in a bounded arena.
- Two game modes: the original Classic run and Pjotr mode.
- Fourteen enemy types, including fliers, exploders and two bosses.
- Four playable roles, each strong and weak against different enemies.
- Hand-authored pixel art for every hero, enemy, projectile and pickup.
- XP drops, levels and three upgrade choices.
- Gold from every kill and a shop that opens once every ten waves.
- Health, death and restart.

## Game modes

**Classic** is the original run, preserved exactly: the Arclight and its Arc Staff, endless Grunts on the old 1.4 second rhythm, no waves, no bosses, no gold, no shop and no class picker. **Pjotr mode** unlocks the four heroes, the full enemy roster, themed waves, bosses and the shop. Pick the mode at the top of the start screen, or launch straight into one with `-- --classic` / `-- --pjotr`.

## Roles

Co-op action roguelites settle on four archetypes, and a party running one of each reaches deeper content than one that stacks damage. The classes follow that split.

| Class | Role | Weapon | HP | Speed | Damage | Interval | Identity |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Arclight | Damage | Arc Staff | 100 | 300 | 18 | 0.70s | Glass cannon, chains between packed enemies |
| Bulwark | Tank | Aegis Hammer | 220 | 230 | 30 | 0.95s | 30% damage reduction, pulls enemy aggro, cone slam |
| Warden | Support | Verdant Censer | 140 | 285 | 11 | 0.55s | Heals allies in a 220 aura and grants +15% damage |
| Frostbinder | Control | Rime Lance | 130 | 270 | 12 | 0.80s | Bursts slow every enemy hit by 45% for 2.5s |

Support and Control deal deliberately low damage. Their value is enabling the damage roles, not personal output. Choose the role in the start screen; the choice is saved to the local profile and sent to the server on join.

### Every hero counters something

Each hero deals one damage type and each enemy resists or takes extra from it, so a party wants coverage rather than four copies of the best damage dealer.

| Target | Arclight (lightning) | Bulwark (impact) | Warden (nature) | Frostbinder (frost) |
| --- | --- | --- | --- | --- |
| Swarmling | **×1.6** | ×1.4 | ×1.0 | ×1.0 |
| Brute | ×0.6 | **×1.5** | ×1.0 | ×0.8 |
| Sentinel | ×0.45 | **×1.6** | ×1.0 | ×0.8 |
| Stalker | ×1.0 | ×0.7 | ×1.0 | **×1.7** |
| Charger | ×1.0 | ×0.85 | ×1.0 | **×1.5** |
| Hexer | ×1.1 | ×1.0 | **×1.8** | ×1.0 |
| Summoner | ×1.0 | ×1.0 | **×1.6** | ×1.0 |
| Drifter | **×1.3** | ×0.4 | ×1.0 | ×1.2 |
| Bomber | **×1.4** | ×0.5 | ×1.0 | ×1.3 |

A Bulwark cannot meaningfully hit anything airborne, and an Arclight alone will stall against Sentinels.

## Enemies and waves

Thirteen enemy types unlock as the run goes on, so pressure grows in variety as well as in numbers.

| Enemy | Behaviour | HP | Speed | Damage | Gold | Debuts in |
| --- | --- | --- | --- | --- | --- | --- |
| Grunt | Melee baseline | 26 | 100 | 6 | 3 | 1 |
| Swarmling | Fast and fragile | 12 | 165 | 4 | 1 | 2 |
| Spitter | Keeps range and shoots | 24 | 85 | 7 per shot | 4 | 4 |
| Drifter | Flies over everything | 20 | 135 | 7 | 4 | 6 |
| Brute | Slow and heavy | 130 | 62 | 18 | 12 | 8 |
| Stalker | Flanker, ignores taunt | 26 | 205 | 10 | 6 | 9 |
| Bomber | Flies in and detonates | 16 | 150 | 22 in a 105 blast | 5 | 11 |
| Hexer | Heals nearby enemies | 60 | 95 | none | 10 | 12 |
| Sentinel | Armoured wall | 100 | 70 | 12 | 10 | 13 |
| Splitter | Breaks into 3 Swarmlings | 45 | 95 | 8 | 7 | 15 |
| Charger | Telegraphs, then dashes | 55 | 85 → 430 | 16 | 8 | 17 |
| Summoner | Hangs back and spawns swarms | 70 | 80 | none | 12 | 19 |
| **Ravager** | Boss, summons swarms | 1400 | 58 | 30 | 120 | 10 |
| **Stormcaller** | Boss, flying 5-shot barrage | 1100 | 95 | 12 per bolt | 140 | 20 |

Enemies steer away from each other, so a wave arrives as a spread front instead of one overlapping blob. Every new type gets its own debut wave where only two of them show up, announced on screen, so you meet each enemy alone before you ever face a crowd of them.

### Wave themes

Waves 1 to 20 are hand-written, each with its own name and composition. From wave 21 the director improvises using the same building blocks.

| Wave | Theme | Wave | Theme |
| --- | --- | --- | --- |
| 1 | First Contact | 11 | Bombardment |
| 2 | Growing Numbers | 12 | Unholy Choir |
| 3 | The Swarm | 13 | Iron Line |
| 4 | Acid Rain | 14 | Ambush |
| 5 | Crossfire | 15 | Division |
| 6 | Wings | 16 | Skyfall |
| 7 | Air Assault | 17 | Stampede |
| 8 | The Wall | 18 | Night Terrors |
| 9 | Shadows | 19 | Dark Ritual |
| 10 | **The Ravager** | 20 | **The Stormcaller** |

Underneath the themes sit seven archetypes — Advance, Swarm, Air Assault, Snipers, Ambush, Elite Guard and Boss — plus modifiers that reshape a wave without new content: Enraged makes everything 18% faster, Armoured trades numbers for 25% more health, and Fragile Horde sends half again as many enemies at 70% health.

The director spends a budget of `4 + wave × 1.5`, scaled up by 45% per extra player. Enemy health grows 5% per wave while speed and damage stay fixed. A wave ends once it is cleared, followed by a fourteen second breather, or a thirty second one on the wave-ten boundaries where the shop opens.

## Gold and the shop

Every kill pays the whole party, so nobody races their team mates to a corpse. The shop only opens once every ten waves, in the long breather right after a boss, so gold piles up into a real spending spree instead of trickling away every wave. The wave counter warns you with `SHOP NEXT` during the wave before it. Prices climb with each copy you own.

The shop deliberately never sells the plain stat lines the level-up screen already sells — no raw damage, attack speed, movement speed, max health or mitigation. It sells MOBA-style mechanics instead, in the spirit of Thornmail, Satanic and Phase Boots:

| Item | Effect |
| --- | --- |
| Spiked Carapace | Reflects 25% of melee damage back at the attacker |
| Phase Boots | **Active (Space)**: sprint at +90% speed for 1.5s, 9s cooldown |
| Bloodfang | Heals you for 8% of the damage you deal |
| Regrowth Pendant | Regenerates 1.5 health per second |
| Rending Prism | Ignores 20% of enemy resistance against your damage type |
| Aegis Sigil | Once per wave, a lethal hit leaves you at 35% health instead |
| Ember Aura | Burns everything within 140 units for 6 damage per second |
| Frostbite Charm | Your hits slow enemies by 20% for a second |
| Lodestone | Pulls XP orbs in from 60% further away |

Phase Boots is the only active: hold Space and the HUD shows the cooldown next to your gold. Aegis Sigil recharges at the start of every wave. In a solo run the game pauses while the shop is open and resumes when you start the next wave; online the thirty second shopping break keeps running. The server validates every purchase.

## Pixel art

All art is hand-authored as character grids in `tools/sprite_art.gd` and baked into PNG files:

```bash
godot --headless --path . res://tools/sprite_forge.tscn
```

The forge refuses to write anything if a grid is not square or uses a colour outside its palette, and it also writes `assets/sprites/_contact_sheet.png` so the whole set can be reviewed at a glance. Textures use nearest-neighbour filtering so they stay crisp when scaled. If a sprite is missing the game silently falls back to its original vector drawing.

## Phase-1 network slice

- One Godot project for clients and the headless server.
- In-game Solo, Host and Join menu plus dedicated-server startup mode.
- Steam networking (GodotSteam GDExtension) when Steam is running: Host creates a friends-only
  Steam lobby and opens the Steam overlay invite dialog, so friends connect with no port
  forwarding — accepting an invite auto-joins, even from a cold launch. Falls back to the
  LAN/direct-IP flow below when Steam isn't detected.
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
3. Press F6/F5, pick a role, then choose Solo, Host or Join.
4. Move with WASD and hold the left mouse button to aim and use the weapon.

With Steam running, **Host** creates a Steam lobby and pops the Steam overlay invite dialog —
send it to a friend and their client auto-connects the moment they accept, no address to type
and no router configuration. `steam_appid.txt` currently holds `480`, Valve's public "Spacewar"
test App ID, for development; a real release needs the studio's own Steamworks App ID there
instead. Without Steam running, the menu falls back to the LAN / direct IP fields exactly as
before.

Command-line development modes:

```bash
godot --path .
godot --path . -- --host
godot --path . -- --join=127.0.0.1
godot --headless --path . -- --server
godot --path . -- --classic
godot --path . -- --pjotr --start-wave=10
```

`--start-wave=N` is a debug aid that jumps the wave director ahead, which is the quickest way to reach a boss wave without playing through a full run.

## Validate without opening the editor

```bash
./tests/validate_project.sh
```

This checks the project layout and all `res://` file references. A full GDScript parse and runtime check still requires Godot.

To verify the roles, enemy types and wave escalation actually behave, run the headless smoke test. It fires every weapon at real enemies and asserts the chain, cone, aura, slow, taunt, projectiles, damage counters, flight, explosions, splitting, summoning, charging, separation, wave archetypes, boss placement and the classic spawn rhythm all work:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/class_smoke_test.tscn
```

Run the import first after adding or renaming a script with a `class_name`. Godot only registers global class names during an import pass, and without it the test scene fails to parse.

It exits non-zero and prints the failing assertion when a role regresses.

## Next checkpoint

After the two-instance Mac test passes, the next checkpoint adds client prediction/reconciliation, reconnect handling, a production Linux export preset and the first hosted dedicated-server deployment. Content expansion waits until this networking path is stable.
