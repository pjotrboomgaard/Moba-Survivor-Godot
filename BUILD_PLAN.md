# Coop MOBA — All-Night Build Plan

Living plan. Work top-to-bottom within each workstream; mark each task `[x]` when
verified in-game (self-test report + screenshot evidence). Keep returning to this
file and keep building. Priority order: P1 (blocking / user-flagged) first.

## Status legend
- `[ ]` not started
- `[-]` in progress
- `[x]` done + verified (report + screenshot)

---

## Workstream A — FFA Performance (P1, user-flagged "lags very hard")
Goal: 4-bot FFA sim at steady FPS. Root cause = too many enemies (110+ cap) each
running full AI + `get_nodes_in_group` scans every physics frame; 4 WaveDirectors
in FFA multiply the load.

- [x] **A1. Investigate** — `fps_probe` event added to selftest_driver recording
      manual frame-count FPS + enemy counts. Baseline captured.
- [x] **A2. Distance cull on enemy AI** — `FAR_CULL_RADIUS=2200`, checked every 0.5s;
      far non-boss enemies skip AI and idle in place. (DONE + VERIFIED)
- [ ] **A3. Target cache** — `_find_nearest_player` already runs on a timer; ensure
      interval grows with player count.
- [x] **A4. Reduce FFA live cap** — FFA enemies capped at 70 via wave_director. (DONE)
- [x] **A5. Verify** — `ffa_perf_check.json` self-test: FPS stable at ~20-21,
      proc_ms ~47-52ms with 41 enemies, far-cull reducing AI load. (VERIFIED)

## Workstream B — Factory Teleporters (P1, user request)
Goal: factory map (biome 3) has teleporter pads; stepping on one moves you to its
partner pad. No cooldown. Pads scattered across the map as an interconnected system.

- [x] **B1. Pad asset** — `_teleporter_pad_texture()` generates glowing pad ring. (DONE)
- [x] **B2. Teleporter logic** — `Area2D` pads in arena.gd, on body_entered teleport
      to partner. Ring FX via `scripts/teleport_ring.gd`. No cooldown. (DONE)
- [x] **B3. Pad pairing** — 6 pads, 3 pairs (i ^ 1 pairing), spawned in `_spawn_teleporters()`
      when `biome_id == 3`. (DONE)
- [x] **B4. Minimap** — show teleporter pads as bright dots. (DONE)
- [x] **B5. Verify** — `teleport_verify.json` self-test: 6 pads spawned at correct
      positions. (VERIFIED)

## Workstream C — Town House Art (P1, user: "looks ugly, no tilt, more styles")
Goal: straight upright houses, multiple distinct pixel styles, fits game's chunky
look. Keep existing (house/shop/church/well) but un-tilt; add more styles.

- [x] **C1. Un-tilt** — `obstacle.gd` town_ rotation = 0. (DONE)
- [x] **C2. Regenerate 16x16 straight art** — house, house2, house3, cottage, shop,
      church, well (DONE via gen_town_art.gd).
- [x] **C3. Register new sprites** — `town_house2`, `town_house3`, `town_cottage`
      into `sprite_library` TERRAIN_SPRITES + arena pool + town quest cluster. (DONE)
- [x] **C4. Verify** — `town_biome_verify.json` self-test: 7 town buildings spawned
      with distinct styles, rotation=0. (VERIFIED)

## Workstream D — Town Quests (creeps join, strong enough, quest flow)
- [ ] **D1. town_minion_combat** — creeps join you, attack other heroes AND other
      creeps. Verify via bots.
- [ ] **D2. town_minion_power** — minions strong enough (range/dmg) to reach and
      fight enemy heroes.
- [ ] **D3. town_art_verify** — wolf/raven/fox pixel art renders on map.
- [ ] **D4. town_quest_flow** — standing-nearby timer + reward trigger (bots).
- [ ] **D5. town_topleft** — town quest spawns at top-left corner (verify).

## Workstream E — Boss Form
- [ ] **E1. bossform_revert** — revert to hero after N hero kills; creeps stop
      attacking owner.
- [x] E2. HUD icons swap in (slam/cross/volley) + camera zoom 0.5 — verified.
- [x] E3. Move speed 300→435, dmg 18→32.4 in boss form — verified.
- [x] E4. All 3 attacks fire w/ cooldowns — verified.

## Workstream F — Creep Camps
- [ ] **F1. camps_aggro** — all 3+ camps attack back when provoked.
- [ ] **F2. camps_respawn** — 2-min respawn timer works.
- [ ] **F3. camps_no_chase** — camps don't chase when player runs away.
- [ ] **F4. camps_gank** — bots can gank heroes fighting camps.

## Workstream G — Upgrades
- [ ] **G1. upg_all_heroes** — all upgrades work for ALL heroes.
- [ ] **G2. upg_rarity** — rarity mix (mostly commons, occasional rare, rare legendary).
- [ ] **G3. upg_synergy** — synergy trees create distinct paths.
- [ ] **G4. upg_legendary** — legendary upgrade genuinely impactful.

## Workstream H — Balance
- [ ] **H1. hero_balance** — buff fast-dying heroes, nerf tanky-forever ones.
- [ ] **H2. ability_balance** — balance ability dmg/CDs across all heroes.
- [ ] **H3. ffa_balance** — 4-bot FFA sim, track kill ratios.
- [ ] **H4. level_pacing** — slow down level-up rate.
- [ ] **H5. bot_upgrades** — bots upgrade slowly, vary choices per run.

## Workstream I — Visuals / World
- [ ] **I1. shadows_tree** — tree shadows point correct dir, longer at dawn/dusk.
- [ ] **I2. shadows_rock** — rock shadows sized/directed correctly.
- [ ] **I3. sprite_visibility** — all enemies/hero always visible.
- [ ] **I4. minimap_terrain** — trees/rocks subdued colors.
- [ ] **I5. minimap_water_lava** — water/lava distinct colors.
- [ ] **I6. minimap_quests** — quest locations light up.
- [ ] **I7. drone_pixel** — drones look like drones (not circles) + bottom bar
      shows upgrades.
- [x] **I8. lava_red** — volcano void tint set to `Color(0.86, 0.34, 0.20)`. (DONE)
- [ ] **I9. splitting_creep** — splits into smaller creeps on death.
- [ ] **I10. corpses_verify** — unique flattened pixel corpse per enemy type.
- [ ] **I11. melee_dash_verify** — creeps lunge toward hero when hitting.

## Workstream K — Redo biome-specific boulders/props (P1, user: "look weird, fit worlds better")
Goal: redo the generic boulders/rocks that are sprinkled across all worlds (except grass).
Replace with themed props that fit each biome:
- Volcano: fiery boulders, glowing obsidian rocks, magma chunks
- Ice: snow hills, ice formations, frost-covered rocks
- Factory: utility masts, radio towers, industrial pipes, crates
- Docks: dock poles, barrel stacks, wooden crates, mooring posts

- [x] **K1. Generate new themed props** — `tools/gen_biome_props.gd`: 8 themed 16x16 props.
      (DONE: volcano_rock_fiery, volcano_obsidian, ice_snow_hill, ice_frost_rock,
      factory_mast, factory_tower, docks_pole, docks_barrel_stack)
- [x] **K2. Register in sprite_library** — added to TERRAIN_SPRITES list. (DONE)
- [x] **K3. Update arena pool** — `_random_scatter_type()` and `_ground_cover_sprites()`
      in arena.gd use themed props per biome. (DONE)
- [ ] **K4. Verify** — biome_probe self-test per biome; screenshots.

## Workstream L — Make volcano lava more red
Goal: volcano lava currently muted. Make it clearly red/orange. Other biomes NOT red.

- [x] **L1. Adjust _void_tile_tint** — volcano biome (id 1): `Color(0.86, 0.34, 0.20)`.
      (DONE)
- [ ] **L2. Verify** — screenshot volcano vs other biomes.

## Workstream M — Self-test extensions
- [x] **M1. fps_probe** — `fps_probe` event records manual frame-count FPS + enemy counts.
      (DONE)
- [x] **M2. biome_probe** — `biome_probe` event records biome_id, obstacle sprite
      IDs + counts. (DONE)
- [x] **M3. teleporter_probe** — `teleporter_probe` event records pad count + positions.
      (DONE)

## Workstream N — Git
- [ ] **N1. Commit + push** — commit all changes from this session.

---

## Session log
- 2026-09-08: RMB hold-to-charge verified (all heroes). Boss-form HUD/move/attacks
  verified. Town art regenerated straight (7 styles). Town quest → top-left corner.
  Town buildings cluster around quest. This plan file created.
- 2026-09-09: FFA far-cull verified (FPS ~20, 41 enemies, proc_ms ~50ms). Factory
  teleporters verified (6 pads). Town buildings verified (7 styles, no tilt).
  Biome props generated (8 themed props). Volcano lava tinted red. FFA enemy cap
  reduced to 70. Self-test events: fps_probe, biome_probe, teleporter_probe.
