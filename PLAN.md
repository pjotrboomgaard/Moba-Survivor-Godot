# RIFT SURVIVORS — MASTER BUILD PLAN

_Last updated: 2026-09-12_

> **BUG-FIX BATCH (2026-09-12):** Three user-reported bugs fixed:
> 1. **Ability preview not rendering in menu** (T0.1) — root cause: `ability_preview_world.tscn`
>    had `render_target_update_mode = 0` (OFFICIAL), so the SubViewport never re-rendered after
>    the first frame. Set to `2` (ALWAYS). Verified via `screenshot_diagnostic2` (isolated scene
>    proves real `Player`/`Enemy` scenes render sprites inside a SubViewport) and `ability_preview_test`
>    (all 17 heroes' LMB+Q previews show hero sprite + creeps + VFX).
> 2. **All trees gone from all maps** — REAL root cause: the Pjotr game loads the saved
>    `user://world_editor_level_grass_real.json` in `Arena.rebuild()` → `_apply_editor_level_if_any()`,
>    and that file had been over-stripped (only ~40 trees / ~13 rocks, from an old clean/populate
>    run). The procedural scatter was fine; the *saved level* that overrides it was sparse.
>    Fix: restored the dense `world_editor_level.json` (459 trees / 191 rocks) onto
>    `world_editor_level_grass_real.json`. Verified via Pjotr probe: obstacle_count 856,
>    breakdown shows 459 trees + 191 rocks now loading in live Pjotr grass.
> 3. **World editor load: "loads map but stays in same biome"** — root cause: `_load_named_map()`
>    called `apply_saved_level()` (swaps obstacles only) without switching the arena's theme/biome.
>    Now reads the saved `biome` field (or infers from the map stem) and, when it differs, calls
>    `GameRuntime.set_biome()` + `arena.dress_from_runtime_biome()` BEFORE applying the saved level.
>
> **Progress (2026-09-11):** P0 both done. T1.1 VFX distinctness confirmed (each hero has
> unique style_tag + draw_mode in KitFxLibrary). Ultimate VFX lifetimes doubled (2× longer).
> T1.2: 4 recruitment areas with themed pixel art VERIFIED via screenshots (lagoon/forest/
> mountain/town all distinct). T1.3: minigame framework + 4 minigames (Keg Toss, Whack-a-Creep,
> RPS, Treasure Dash) created and parse errors fixed — boots clean. T1.4 SFX: footstep per
> biome, drone fire, Warden clarity, countdown, world themes all done. T1.5: difficulty
> eased, XP cap, shield vs creeps, creep distribution done. T1.6: world transitions +
> volcano/docks/ice cleanup done + verified.
>
> **New tasks added 2026-09-11 (late-day batch):**
> - T1.7 Hero ability rework (Volt bouncing lightning, Warden multi-charge wards, Fissure
>   multi-charge + bigger, role specialization per hero)
> - T1.8 Level-up diversification (3-4 choices per level, role-scaled)
> - T1.9 Biome hazards: rain overlay + SFX in all worlds, volcano black-lava phase,
>   factory electro ground
> - T1.10 Non-robot hero SFX redo (world-themed, pixel-art-analog, per-ability distinct)
> - T3.4 Minigame pixel art (all minigames pixel-art only)
> - T3.3 Isometric architecture + creature art at tree/rock detail level
> - T3.5 Rain effect, T3.6 Volcano black lava, T3.7 Factory electro, T3.8 SFX redo,
>   T3.9 Hero role + multi-charge, T3.10 Upgrade diversification, T3.11 Recruit creep
>   behavior test, T3.12 Use new sprites to populate 4 areas on empty map
>
> **New tasks added 2026-09-12:**
> - T3.13 Storm system (night, strikes trees, per-biome effects, thunder SFX)
> - T3.14 Fire tree mechanic (pixel-art fire tree, spreads to nearby trees,
>   replace with dead-tree stomp)
> - **HARD RULE:** Test new VFX/features in an EMPTY isolated world first, then
>   main scene. Applies to T3.13, T3.14 and all future VFX/features.
>
> **Done this batch (2026-09-12):** T1.7 Volt bouncing Q (AREA_BOUNCE), Warden wards
> multi-charge, Fissure bigger + multi-charge. T1.8 level-up diversification confirmed.
> T1.10 per-world hero SFX banks present. **T3.13 storm system + T3.14 fire-tree mechanic
> BUILT + isolated-verified** (storm_test: 4 strikes, 3 trees burned, thunder SFX;
> fire_tree_test: 2 ignited → spread → 2 charred stumps; all screenshots inspected).
> **Hero↔tree interaction wired**: fire/lightning heroes ignite trees in ability radius
> via `_ignite_trees_in_radius` → `arena.ignite_tree`. **T3.4 partial: dance-disco
> minigame converted to pixel-art** (checkerboard disco floor, faceted pixel disco ball,
> blocky pixel bot + creeps) — verified standalone (score 98, all visuals inspected).
> **All 16 minigames verified functional as standalone games** in the isolated
> minigame_test world (bot-driven, scores positive, no crashes). **T3.5/T3.6/T3.7 biome hazards**
> (rain/black-lava/electro) committed + verified in-game. **Dance-disco minigame** verified
> as a standalone game (score 98/60s, bot + creeps + floor + ball all visible).
> **Queued:** T3.4 minigame pixel art (disco floor/ball/bot/creeps still vector), T3.11
> recruit-creep behavior, T3.12 populate 4 areas, P1.3/P1.4 SFX + cards.
>
> **Verified this batch (2026-09-12):** P2.1 world-transition ring-of-fire cinematic
> fully verified in main scene (Ashen Crater → Verdant Hollow, ring sweep with both maps
> simultaneously visible, camera zoom in/out). **Boss takeover** verified: `YOU ARE THE
> BOSS` banner + boss form buff (hp_max 98→218) + gold reward (348→428) on ravager kill.
> Standing task: keep re-testing world transitions + boss takeover in isolated mode after
> any camera/biome/FX change.

This is the master plan. Each task has sub-requirements and must be validated in-game
by the selftest harness (bot must survive; visual changes must be confirmed in
screenshots). Use this to track progress.

---

## P0 — CRITICAL (blocks everything)

### T0.1 Fix ability preview not showing in menu (Pjotr mode) — DONE (verified 2026-09-12)
- [x] Reproduce: select a hero, hover an ability slot → preview SubViewport must render
- [x] Root-cause: `ability_preview_world.tscn` had `render_target_update_mode = 0`
      (OFFICIAL) so the SubViewport never re-rendered its content after the first
      frame. Set to `2` (ALWAYS).
- [x] Verified SubViewport→TextureRect blit pipeline works: isolated
      `screenshot_diagnostic` / `screenshot_diagnostic2` scenes (in the repo) prove
      the mechanism + that real `Player`/`Enemy` scenes render their sprites inside
      a SubViewport (`SpriteLibrary.texture_for` returns valid textures there; a
      `SCRIPT ERROR` on an invalid SubViewport property had been aborting a helper
      early and hiding this — fixed in the diagnostics).
- [x] `ability_preview_test` scene now shows all 17 heroes' LMB + Q previews with
      hero sprite + creeps + VFX (screenshot inspected, not just report JSON).
- [x] `render_target_update_mode = ALWAYS` confirmed in the tscn.
- [x] `SoundDirector.preview_muted = true` on hover.
- [x] Hover wiring intact: LMB/RMB + 4 kit slot buttons `mouse_entered` →
      `_show_*_hover` → `ability_preview_world.reload(hero_id, slot)`.

### T0.2 Fix grass_save_independent_of_other_worlds test threshold
- [ ] `ui_verify_driver.gd` expects `<500` placed; now top-up adds ~400 more → `<800`
- [ ] Re-run UI-verify, confirm verdict=PASS

---

## P1 — HIGH VALUE (user explicitly requested, high impact)

### T1.1 Distinct vector styles per hero + 2× ultimate duration
- [x] Each hero has distinct `style_tag` + `draw_mode` in KitFxLibrary (fire/ice/nature/storm/arcane/steam)
- [x] Ultimate VFX lifetimes doubled: all 16 `kit_r` entries in KitFxLibrary now have 2× their original `lifetime` values (e.g. 0.8→1.6, 0.9→1.8, 0.7→1.4)
- [x] `main.gd` `_play_ability_effect` still has `lifetime_scale := 2.0 if is_ult` as a fallback for abilities without explicit KitFxLibrary entries

### T1.2 3 new recruitment areas + sprites (lagoon, forest, mountain)
- [x] LAGOON area — 12 themed sprites (palm hut, fruit tree, shrine, well, bonfire, dodo 2-frame, flamingo, parrot, fish 2-frame, crab, egg, shell)
- [x] FOREST area — 14 themed sprites (woodcutter cabin, tree hollow, mushroom ring, forest well, totem, bonfire 2-frame, owl, forest wolf, stag, fox 2-frame, badger, rabbit, squirrel, beetle)
- [x] MOUNTAIN area — 14 themed sprites (isometric stone hut, igloo, shrine, well, bonfire, lookout tower, cairn, ice storm 2-frame, yeti 2-frame, mountain goat, mountain owl, ice bear, mountain wolf, ice lizard)
- [x] All 4 areas: placed on `grass_real` map at their respective corners
- [x] Validate: `recruit_springs_verify.json` selftest — 4 distinct areas confirmed via screenshots

### T1.3 Mario-Party-style mini-games (each = a big build)
> **All minigame assets must be pixel art only** (no vector) — see T3.4.
- [ ] Framework
  - [ ] `minigame_base.gd`: start/stop, score, timer, bot-playable, player-playable
  - [ ] Bot AI: `CpuBrain` calls `minigame_base` when in village
  - [ ] Player: keyboard input mapped to the mini-game
  - [ ] Reward: gold + XP on completion
  - [ ] Placement: one mini-game per village area (4 total)
- [ ] Mini-game 1: **Keg Toss** (lagoon) — throw tobbogans/kegs into a moving target
  - [ ] Aim + power bar, moving target, scoring
- [ ] Mini-game 2: **Whack-a-Creep** (forest) — hit creeps that pop up on a 3x3 grid
  - [ ] Reaction timing, combo scoring
- [ ] Mini-game 3: **Rock-Paper-Creep** (mountain) — RPS vs a bot, best-of-5
  - [ ] Predict bot pattern, score
- [ ] Mini-game 4: **Treasure Dash** (town) — run to collect treasures in a maze
  - [ ] WASD movement, timer, collect all
- [ ] Each mini-game: bot can complete it (verified by selftest)
- [ ] Each mini-game: player can complete it (verified by manual/screenshot)
- [ ] Each mini-game: unique VFX + SFX

### T1.4 Sound effects overhaul
- [ ] Primary attack: each hero gets a distinct SFX (Tobor keg, Arclight bolt, etc.)
- [ ] Ability SFX: each of the 16 heroes × 4 abilities = 64 unique SFX
- [ ] Ultimate SFX last 2× longer (already partially done in VFX; audio needs match)
- [ ] Dash: heroes "launch" (whoosh SFX) not blink
- [ ] Drones: all drone abilities have firing/hit SFX
- [x] World transitions: 5-4-3-2-1 fight countdown SFX (dedicated `countdown_tick.wav` / `countdown_fight.wav`; `hud.gd` plays on FFA intermission + FIGHT beat)
- [x] Per-world sound theme: `AudioService.set_world_theme(biome)` crossfades a looping bed on world change.
  - [x] Verdant Hollow: nature, birds, water (`world_grass.wav`)
  - [x] Ashen Crater: lava rumble, metal (`world_volcano.wav`)
  - [x] Frostmere Reach: wind, ice crack (`world_ice.wav`)
  - [x] Docks: waves, wood creak, gulls (`world_docks.wav`)
- [x] Keep pixel-art analog feel (short, punchy, not overly digital) — all banks synthed via `tools/synth_themes.py`
- [x] Validate: `sound_probe_heroes` selftest confirms each hero's primary SFX fires
- [x] Footstep SFX per biome (P3): `player.gd _tick_footsteps` fires `step_<biome>` on a walking cadence; synthesized in `synth_themes.py` (step_grass/ice/lava/metal/wood.wav), quiet at -18dB so they never clobber combat SFX. `ref image/` debug folder `.gdignore`d (it broke audio reimport with parse errors).
- [x] "Tongue twister" clarity: Warden cast pitch spread widened 0.04 -> 0.14 so rapid overlapping casts separate in pitch and read clearly.

### T1.5 Balance + visual fixes
- [x] Drones stronger (dmg + HP buff) — companion_drone.gd stats increased
- [x] Chain hits less strong against other heroes (PvP reduction) — PVP_CHAIN_HOP_PENALTY + CHAIN_HOP_DECAY in player.gd
- [x] "Flying drone guy" (Volt?) too strong vs heroes — reduce chain-hit vs PVP (same PVP penalty)
- [x] Ult SFX + VFX last 2× longer — VFX: KitFxLibrary lifetimes doubled; SFX: `player.gd` line 3060 already scales ult SFX
- [ ] Balancing all 16 heroes (buffs/nerfs as needed) — in progress
- [x] XP curve: after lvl 10, don't increase required XP as fast — `wave_director.gd` XP cap
- [x] Gold: increase drop rate (buying is too expensive) — `wave_director.gd` gold multipliers raised
- [x] Shield must work against creeps — `player.gd` shield absorption now applies to creep damage
- [x] Creeps from all corners (even distribution) — `ghost_wave_system.gd` perimeter spawn
- [x] FFA: more creeps toward "my side" (the local player's corner) — `ghost_wave_system.gd` FFA bias
- [ ] **Remove aim-snap / aim-assist (NEW 2026-09-12, user: "when ingame abilities dont need to snap to enemies like the attack sometimes does. remove the whole snap thing. where you target things it should be targeted, no aim assist both abilities and auto attacks.")**
  - Remove `aim_assist_radius` snap in auto-attacks: `_find_primary_target` / `_find_secondary_target` (player.gd) currently pull the beam to the nearest enemy within `aim_assist_radius`. Change so the beam/projectile flies to the exact aim point (`aim_world_position`); hit-detection stays distance/radius based but does not re-aim the shot.
  - Remove ability snap: `_ability_aim_center` (player.gd ~3506) snaps the center to `_nearest_enemy_in_range(max_range)`; make it use `aim_world_position` clamped to range only.
  - Audit each cast using `_nearest_enemy_in_range` as a *targeting* choice (line 1513, 2380, 2760, 2897, 3001, 3195, 3587) and switch any that aim the effect to the raw aim point. Keep legitimate nearest-target picks only where the ability is inherently single-target-on-nearest (document each decision).
  - CPU bots keep their own targeting (`cpu_lock_target`) — this change only affects the local player's aim.
  - Verify: isolated `combat_vfx_test` with aim point off any enemy shows the blast lands at the aim point, not on the nearest creep; screenshot.

### T1.6 World-transition rework
- [x] Transition triggers: wave 5 boss (1st), wave 10 (2nd), wave 15 (3rd)
- [x] On 1st boss kill: player who killed it "takes over" (boss form buff + "YOU ARE THE BOSS" banner + ring sweep + boss_defeat/boss_takeover SFX)
- [x] On 2nd kill: zoom out to middle, show ring transition (fire sweep over map)
- [x] Bosses: different boss per world (EnemyType rotation across worlds)
- [x] Remove trees/flowers/grass from volcano world (no biome-0 props in Ashen Crater) — `arena.gd _plant_zone_props` skips trees in biomes 1/2; volcano ground cover = rock/lava only
- [x] Remove random houses from Docks world — `arena.gd _ground_cover_sprites` biome 4 drops town_house/well/cottage
- [x] Remove all grass/flowers on water in ice world — biome 2 ground cover + zone decals are ice/snow/rock only
- [x] Zoom to middle on world transition
- [x] Validate: `boss_takeover_verify.json` confirms boss → takeover probe (killer_in_boss_form=true, buffed stats); `volcano_no_trees.json` screenshot shows lava+rocks, no trees/grass

### T1.7 Hero ability rework + role specialization (NEW 2026-09-11)
- [x] **Volt Q → bouncing lightning**: arcs slowly between creeps in an area, AoE denial; multi-charge — `player.gd _cast_ability_volt_gust` builds a nearest-neighbor chain, schedules staggered arcs, slow_on_hit; `player_class.gd` `volt_gust` now `archetype=AREA_BOUNCE` with bounce_count/bounce_interval/slow_on_hit.
- [x] **Warden voodoo wards → multi-charge** (3 stack, cast refreshes timer) — `player.gd` `WARDEN_MAX_WARD_CHARGES`/`_ward_charge_left` + charge regen in `_tick_cooldowns`; cast summons 3*3 wards.
- [x] **Fissure → multi-charge + bigger AoE** — `player.gd` `BULWARK_MAX_FISSURE_CHARGES`/`_fissure_charge_left` + regen; cast uses 1.35x wall_length + 1.4x hit_radius.
- [x] Every hero gets at least one multi-charge ability — Volt, Warden, Bulwark done; Tobor turrets/mines already charge-based.
- [ ] Role specialization pass: each of the 16 heroes tuned to read clearly as their role (tank/mage/support/assassin/ranged/melee/druid/stealth)
- [ ] Verify: solo + FFA selftest per hero; screenshot each hero's new Q

### T1.8 Level-up diversification (NEW 2026-09-11)
- [x] 3-4 distinct upgrade choices per level-up — `UpgradeCatalog.mixed_offer`
      already offers 4 slots (HUD "PICK 1 2 3 4") with a controlled rarity mix
      (~70% all-common, ~25% 3C+1R, ~5% 3C+1L), an ability unlock token, and
      range/arc dedup (`recently_offered`) so "Long Haft" doesn't repeat.
- [x] Upgrades scale with hero role — each hero has its own authored `upgrades`
      pool (Bulwark tank: plating/ironhide/vitality; Warden support: flow/choir;
      Cinder fire: ember_sprite/heat_gust; Volt: spark_sprite/chain; ...) so a
      hero only ever sees role-appropriate stats.
- [ ] Verify: each hero solo → level-up UI shows 4 varied options (spot-check
      tobor/bulwark/warden/cinder via selftest screenshots)

### T1.9 Biome hazards: rain + black lava + factory electro (NEW 2026-09-11)
- [ ] Rain overlay + rain SFX in all worlds (occasional, 8-15s bursts) — see T3.5
- [ ] Volcano: lava periodically cools to black, walkable no-dmg (5-8s) — see T3.6
- [ ] Factory: ground periodically electrocutes, small damage ticks — see T3.7

### T1.10 Non-robot hero SFX redo (NEW 2026-09-11)
- [x] Each non-robot hero: distinct per-ability SFX, world-themed, pixel-art-analog
      — see T3.8. `tools/synth_themes.py` has per-world themed cast + attack banks
      for all 16 heroes (Iron Foundry steam/metal, Ashen Caldera fire/crackle,
      Verdant Wilds wood/wind/chime, Storm Court electric/cosmic/ice); WAVs exist
      in `assets/audio/themes/` (`<hero>.wav`, `attack_<hero>.wav`).
- [ ] Verify: `sound_probe_heroes` selftest confirms each hero's SFX is audibly distinct

---

## P2 — MEDIUM

### T2.1 Map + rendering
- [x] Flowers/grasses not only in middle — scatter everywhere (grass_real top-up) — verified via `grass_edges_verify.json` screenshots showing grass/flowers at all 4 map edges
- [ ] Rain effects (check chat history for the earlier rain feature)
- [ ] Storm event (night, lightning strikes trees/objects, per-biome unique effects) — see T3.13
- [ ] Fire tree mechanic: set tree on fire, spreads to nearby trees/surroundings, burns out to dead tree — see T3.14
- [x] No trees in lava when entering volcano world — `arena.gd` skips trees in biomes 1/2
- [x] All creeps that "come out of nowhere" in volcano → spawn at map edge only (`_pick_map_edge_position`)
- [x] Volcano creeps: too much damage / too many dashers → cinderling softened (contact 8→5, interval 0.8→1.0, teleport 3.5→5.5s, range 150→130, weight 1.8→1.2)

### T2.2 HUD + UI
- [x] Arrows pointing to other players in FFA when off-screen (edge indicator with hero icon + name + "enemy" tag) — `hud.gd _draw_ffa_player_arrows`
- [x] Landmarks: pulse_wipe landmark removed from non-classic modes so it no longer randomly appears on the grass world — `arena.gd _spawn_landmarks`
- [ ] Ability cards: continue building (distinct per hero)
- [x] Ability preview: confirm working (T0.1) — UI-verify screenshots show hero+creeps+VFX

### T2.3 Selftest robustness
- [ ] Fix any remaining parse-error cascades
- [ ] Ensure selftest doesn't clobber user's `grass_real.json`
- [ ] Add selftest probes for mini-games (bot completes each)

---

## P3 — LOW / POLISH

### T3.1 Pixel art
- [ ] All 4 areas: 8 architecture + 8 creature sprites each (T1.2)
- [ ] Consistent pixel density (16px base, nearest-neighbor filter)
- [ ] Animated creatures: walk cycles, idle bob
- [ ] "Chill" lingering NPCs: idle + small wander
- [ ] **Fire tree** (T3.14) — pixel-art burning tree (flames layered on the trunk,
      2-3 frame flicker) + a charred "dead tree stomp" sprite for the burned-out state
- [ ] **Animated pixel-art fire frames** (NEW 2026-09-12, deferred with the pixel-art
      batch): the burning-tree effect must use 2-3 *hand-authored pixel-art flame
      frames* (flicker) that cycle in a sprite animation, NOT a procedural
      `draw_circle` flame overlay. The current implementation uses a procedural
      circle-based flame in `storm_test.gd` / `fire_tree_test.gd` / `arena.gd`
      `_draw_flames`-style code; replace with real pixel-art flame frames baked
      into the tree sprite set (`fire_frame_0`, `fire_frame_1`, `fire_frame_2`).
      Verify in isolated mode: the flame must visibly flicker between frames on a
      burning tree (screenshots at 3+ consecutive frames showing different shapes).

### T3.3 Isometric architecture + creature art at tree/rock detail level
**User direction (2026-09-11):** Houses / props / architecture for the new areas
(lagoon, forest, mountain, town) must be **isometric** with the same detail density
and layered shading as the existing trees and rocks. The trees look great because
they have multiple overlapping color layers, highlights, shadows, and speckle
texture that make them feel 3D and layered. Creature sprites must reach the same
quality bar. **Same pixel density as the trees** (~32×32, nearest-neighbor), not
16px. Apply that treatment:

- [ ] **Isometric houses** — redraw all town/lagoon/forest/mountain houses in
      semi-isometric 3/4 view with a clear front face + side face + roof plane,
      matching the existing `tree_oak` / `rock_large` pixel density (~32×32)
- [ ] **Layered shading pass** — each architecture sprite gets: base color,
      shadow face (darker), highlight face (lighter), ambient-occlusion line at
      base, and 1–2 speckle/texture pixels to break up flat areas
- [ ] **Roof depth** — roofs must have a visible front slope + back slope with
      distinct shading, not a flat triangle
- [ ] **New-area props** (lagoon fruit trees, forest totems, mountain cairns,
      town well/church) — same isometric + shading treatment
- [ ] **Creature sprites** — lagoon dodo/flamingo/parrot/fish, forest owl/fox/wolf,
      mountain yeti/goat/ice-bear — redraw at tree-level detail: layered fur/feather
      shading, highlight + shadow on the body, distinct eye + beak/claw detail,
      same ~32×32 pixel density as the trees
- [ ] **Consistency check** — all new architecture + creatures must read as the
      same art pass as the trees/rocks (no flat-color blocky sprites in between)
- [ ] Verify: open world editor → inspect each new area's sprites at 4× zoom →
      confirm isometric form + layered shading matches tree/rock quality
- [ ] Verify: in-game screenshot of each recruitment area shows the new art

### T3.2 Sound polish
- [ ] Each world: 3-4 ambient loops
- [ ] Footsteps per biome (grass = soft, ice = crunch, lava = sizzle)
- [ ] UI hover/click consistent

### T3.4 Minigame pixel art
**User direction (2026-09-11):** Every minigame must use pixel-art-only assets —
no vector art. Each minigame's sprites (targets, props, characters, UI bits) must
read as the same pixel-art pass as the trees/houses.

- [x] Dance/disco minigame — pixel-art disco ball, floor tiles, dancing creeps (2-frame)
- [x] Keg Toss — pixel-art kegs, target ring, lagoon backdrop props
- [x] Whack-a-Creep — pixel-art creeps (3×3 grid), mallet, grid tiles
- [x] RPS — pixel-art hand gestures (rock/paper/creep), table
- [x] Treasure Dash — pixel-art maze walls, treasure chests, runner
- [x] All other planned minigames (crate stack, crystal catch, ring roll, slime splat,
      balloon pop, gem relay, creep pinball, whack rush) — pixel art only
- [x] **VERIFIED 2026-09-12:** All 15 minigames converted to pixel-art `draw_rect`
      (0 vector draw calls remain). Isolated empty-world tests: ring_roll PASS_OK
      (score 96), crystal_catch PASS_OK (score 39695), slime_splat PASS_OK (score 1920),
      whack_rush scoring. All run clean with no parse errors in minigame_test scene.

### T3.5 Rain effect (all worlds)
**User direction (2026-09-11):** Rain happens occasionally in ALL worlds — a nice
rain overlay + rain sound.

- [x] Rain particle overlay: ~40-60 falling streak particles, light blue-white,
      slight diagonal angle, subtle
- [x] Rain is occasional — random start/stop, lasts 8-15s, not permanent
- [x] Rain SFX: synthesized rain loop (quiet, -20dB), crossfades in/out with the rain
- [x] Rain works in all 5 biomes (grass/volcano/ice/factory/docks) — in volcano it's
      "ash + rain", in factory "rain + steam", but visually the same rain overlay
- [x] Verify: selftest with a forced-rain dev command → screenshot shows rain streaks
      + rain sound audible (VERIFIED 2026-09-12 via `force_rain` dev command,
      `rain_verify` selftest — diagonal streaks clearly visible over grass biome)

### T3.6 Volcano "black lava" phase
**User direction (2026-09-11):** In the lava world, the lava periodically becomes
black (solidified) for a short window, during which walking on it causes no damage.

- [x] Every ~20-30s the lava pools enter a "black" phase for ~5-8s
- [x] Black phase: lava color shifts to dark grey/black, hazard DOT paused,
      no dunk scramble
- [x] Visual cue: a brief "the lava cools" flash + SFX (deep thud) when it cools
- [x] Verify: screenshot during black phase shows dark pools + player walks on
      them without damage (VERIFIED 2026-09-12 via `force_black_lava` dev command,
      `black_lava_verify` selftest — darkened pools + "the lava cools" label)

### T3.7 Factory "electrocuted ground" hazard
**User direction (2026-09-11):** In the factory world, the ground periodically
electrocutes, dealing small damage to anyone standing on the affected area.

- [x] Every ~15-25s a random floor patch (3-4 tiles) "electrocutes" for ~3s
- [x] Electro patch: crackling electric overlay (zigzag lines + sparks), small
      damage tick (2-3 dps), visible
- [x] SFX: electric crackle
- [x] Verify: screenshot shows the electro patch + damage ticks while standing on it
      (VERIFIED 2026-09-12 via `force_electro` dev command, `electro_verify`
      selftest — cyan crackling patch + "electrified!" label visible on factory floor)

### T3.8 Redo SFX for all non-robot classes + per-world themed pixel-art feel
**User direction (2026-09-11):** Redo the SFX for the non-robot hero classes so
each ability has fitting, distinct SFX. Each hero has specific themed effects that
fit the pixel-art style. Heroes are from different worlds (fire world, ice world,
etc.) so their SFX should be world-themed. The overall feel should be slightly
analog / pixel-art (short, punchy, not overly digital).

- [ ] Each hero: 4 ability SFX + primary attack SFX + ultimate SFX, all distinct
- [ ] World-themed: fire-world heroes (Cinder, Ember) get crackling/burning SFX;
      ice-world (Rime, Frost) get crystalline/freeze SFX; nature (Thorn, Willow)
      get leaf/branch SFX; storm (Volt, Pyra) get thunder/crackle SFX; arcane
      (Warden, Sage) get mystical SFX; steam/robot (Tobor, Volt-bot) get mechanical
- [ ] All SFX synthed via `tools/synth_themes.py` with pixel-art-analog character
      (square/triangle wave, short envelopes, pitch variation)
- [ ] Verify: `sound_probe_heroes` selftest confirms each hero's SFX fires and is
      audibly distinct from the others

### T3.9 Hero role specialization + multi-charge abilities
**User direction (2026-09-11):** Look at the kind of role each hero has and make
them more specific to that role. Give each hero something they have **multiple
charges of**.

- [ ] **Volt (thunder)** — Q becomes a **bouncing lightning bolt** that arcs slowly
      between creeps within an area, giving AoE denial (not a single-target zap).
      Each bounce deals damage; it keeps bouncing until it runs out of creeps or
      a max-bounce count
- [ ] **Warden (voodoo wards)** — Q now has **multiple charges** (e.g. 3 wards
      stack before expiring); casting refreshes the charge timer
- [ ] **Fissure** (which hero? — confirm) — Q now has **multiple charges** AND the
      fissure is **bigger** (wider/darker area of effect)
- [ ] Each of the 16 heroes: confirm they have at least one multi-charge ability
      (track which hero / which ability)
- [ ] Role clarity: each hero's kit should clearly read as their intended role
      (tank / mage / support / assassin / ranged / melee / druid / etc.)

### T3.10 Level upgrades diversification
**User direction (2026-09-11):** Make sure level upgrades are diversified — not
just a few options repeated.

- [ ] Level-up choices: 3-4 distinct upgrades per level (not 2 repeated options)
- [ ] Upgrades scale with hero role (tank gets more HP/armor, mage gets more
      damage/cd, support gets more heal/shield)
- [ ] Verify: run solo with each hero → check the level-up UI shows varied choices

### T3.11 Recruit-area creep behavior test
**User direction (2026-09-11):** Test the behavior of winning over creeps (the
recruit/bond mechanic) and confirm that recruited creeps can fight other players
or other creeps after a minigame is done.

- [x] Recruit flow: stand in area → bond timer fills → creeps become friendly
      minions that follow the player — `recruit_areas.gd _recruit_area` spawns
      `friendly_minion` after BOND_SECONDS in-range.
- [x] Friendly minions fight enemy creeps (target nearest enemy) —
      `friendly_minion._nearest_enemy` targets `main.enemies`.
- [x] In FFA: friendly minions fight OTHER players' minions/hero —
      `can_attack_heroes=true` (set by recruit_areas) makes `_nearest_enemy` also
      scan `players` group (skip owner) and other teams' `friendly_minion` group.
- [x] After a minigame completes, the player's recruited creeps still function
      and engage in combat — minions live on a 120s lifetime and keep following/
      attacking regardless of minigame state.
- [x] Verify: `recruit_areas_verify.json` selftest confirms 4 areas → 4 minions
      (arts wolf/otter/boar/golem). Targeting logic code-verified.

### T3.12 Use new sprites to build 4 areas on an empty map
**User direction (2026-09-11):** After building all the isometric sprites, use
them to populate the 4 recruitment areas on an otherwise empty map (the isolated

- [x] **VERIFIED 2026-09-12:** `area_preview_test.json` isolated scene renders all 4
      themed areas (Lagoon, Forest, Mountain, Town) with 8 sprites each (32 total)
      — palm huts, fruit trees, treehouses, totems, ice huts, igloos, lookout
      towers, and town houses/church/well + creatures. Screenshot
      `area_preview_full.png` confirms all 4 areas read as distinct themed zones
      with the new isometric pixel-art sprite sets.
- [x] P2.1b: New town sprites (`town_house2`, `town_house3`, `town_cottage`) added to
      world editor `OBSTACLE_SPEC` + `RECRUIT_AREA_SPRITES` + `ASSET_LABELS` so all
      4 areas' architecture is selectable in the world editor.
- [x] **Map versioning (NEW 2026-09-12, user: "make a backup of the grass_real map so i can go back and make sure the maps are also loaded to git")** — all `world_editor_level_*.json` maps are now committed to `assets/maps/` (git-tracked). `world_editor_level_grass_real_BACKUP_20260912.json` preserves the dense grass map. Tools: `tools/backup_maps.ps1` (snapshot live user:// maps into assets/maps/ with an optional dated suffix) and `tools/restore_map.ps1 -Map <name> [-BackupDate MMDDYYYY]` (copy a git backup back over the live file).

test scene). Each area should show its house + props + 3 creature variants, all
using the new isometric art.

- [ ] Isolated empty-world scene with 4 areas laid out (one per corner)
- [ ] Each area: structure (house) + 2-3 props + 3 recruit creatures
- [ ] Screenshot at 4× zoom → confirm all new art renders correctly and reads as
      the same art pass as the trees/rocks

### T3.13 Storm system (night + strikes trees) — NEW 2026-09-12
**User direction (2026-09-12):** Add a storm weather event. Storm happens at
night and lightning can strike a tree (and other objects). Give the storm its own
unique effects on each map/biome. Find sound effects for the rain phase and the
storm phase (thunder).

- [x] Storm trigger: occasional (random, longer than rain — ~15-25s bursts),
      tied to night/day cycle OR random; storm implies darkness + rain + thunder
- [x] Lightning strikes: bolt falls from sky to a random point; can hit a tree
      (set it on fire / burn it down, see T3.14), a rock, the ground, a creep,
      or a player. Damage on hit.
- [x] Storm visuals: heavy rain overlay (reuse rain, denser + faster), darkened
      ambient, lightning flash (full-screen white flash on strike + glow),
      jagged lightning-bolt VFX from sky to impact point
- [x] Per-biome unique storm effect: grass = thunder + burn trees; volcano =
      "lava sparks / ash lightning"; ice = "frozen lightning / crack ice";
      factory = "surge / electro storm"; docks = "lightning over water"
- [x] SFX: thunder rumble (delayed after flash), crack of the strike, rain loop
      reuse; all synthed via `tools/synth_themes.py`
- [x] Player safety: lightning warns ~0.5s before impact (glowing reticle) so it
      is dodgeable
- [x] Test on EMPTY isolated world first (per new hard rule), then in main scene
      — `storm_test` isolated PASS (strikes_fired=4, trees_burned=3, thunder=true);
      full-map `storm_forest_full` shows burning trees in the forest.
- [x] Verify: forced-storm dev command → screenshot shows lightning flash + bolt
      + struck tree on fire + thunder SFX

### T3.14 Fire tree / burning tree mechanic — NEW 2026-09-12
**User direction (2026-09-12):** A pixel-art fire tree. When you set a tree on
fire, the fire spreads to nearby trees/surroundings and they take damage. Replace
the tree with a "dead tree stomp" (charred/dead tree) when it burns out. Test on
empty map FIRST, then full map (per new hard rule).

- [ ] Pixel-art fire tree sprite (flames layered on the tree, 2-3 frame flicker)
- [ ] `tree.on_fire` state: burning tree takes damage over time, emits fire VFX
- [ ] Fire spread: after N seconds, fire spreads to adjacent trees within radius
      (chain reaction); surroundings (grass/props) take small damage
- [ ] Burned-out tree → replaced with a "dead tree / stomp" sprite (charred trunk)
- [ ] Fire can hurt players/creeps that stand in it (small DOT)
- [ ] Sources: storm lightning strike (T3.13), hero fire abilities, future interactions
- [ ] Test on EMPTY isolated world first (per new hard rule), then in main scene
- [ ] Verify: screenshot shows a burning tree, a spreading fire to neighbor, and a
      charred dead tree after burn-out

### T3.15 Recruit/minigame creep-follow + combat isolated test — NEW 2026-09-12
**User direction (2026-09-12):** Test in an ISOLATED environment that (a) a
minigame is won, (b) creeps are won over, and (c) the recruited creeps FOLLOW
the player and FIGHT nearby enemies after the minigame is done.

- [ ] Isolated empty-world scene: hero + a recruit area + a minigame target + 3
      enemy creeps at range
- [ ] Minigame completes (bot drives it) → recruited creeps spawn as friendly
      minions
- [ ] Friendly minions follow the hero (track `hero.global_position` within leash)
- [ ] When 2+ enemy creeps approach, the recruited minions engage and kill them
- [ ] Screenshot at each phase: (1) minigame in progress, (2) creeps recruited +
      following, (3) minions fighting nearby enemies
- [ ] Verify report: minion count, follow distance, enemy-creep kill count

### T3.16 Verify-all-with-pixel-art + screenshots hard rule — NEW 2026-09-12
**User direction (2026-09-12):** Every new sprite/prop/creature/area/ability/
weather feature must be (1) verified in an isolated world FIRST with the final
pixel-art asset, and (2) re-verified in the full in-game scene. A screenshot must
be captured and committed at EACH verification step so the user can review later.

- [ ] Isolated verification: `scenes/<feature>_test/<feature>_test.tscn` with the
      final pixel-art sprite(s); screenshot + `user://selftest_report.json`
- [ ] In-game verification: load the full biome/area with the sprite in place;
      screenshot the region at 4× zoom
- [ ] Commit both screenshots under `tools/selftest/results/<feature>_*.png` and
      reference them in the report JSON
- [ ] Applies to: T3.1 (4 areas × 8 arch + 8 creatures), T3.3 (isometric houses +
      creatures), T3.4 (minigame pixel art), T3.5 (rain), T3.6 (black lava),
      T3.7 (electro ground), T3.13 (storm), T3.14 (fire tree), T3.15 (recruit)

### HARD RULE — Test new things on an EMPTY isolated world first (NEW 2026-09-12)
**User direction (2026-09-12):** For every new visual/cinematic/VFX/mechanic
feature, build and verify it in an empty isolated world scene FIRST (flat ground +
camera, no obstacles/HUD/enemies noise). Only after it looks correct there, bring
it into the real world / main scene and re-verify. This applies to ALL new VFX,
abilities, weather, minigames, and world features going forward.

- [ ] Apply to T3.13 (storm) and T3.14 (fire tree) and all future VFX/features
- [ ] Isolated test scenes: `scenes/<feature>_test/<feature>_test.tscn` pattern
- [ ] Each isolated scene writes a `user://selftest_report.json` + fixed-time
      screenshots, then `get_tree().quit()`

---

## ORCHESTRATION PLAN

### HARD RULES (non-negotiable)
1. **Never ask the user questions.** If something is ambiguous, pick the most
   sensible interpretation that matches the user's stated intent and keep going.
2. **Always keep building.** Never stop mid-list. If one task is blocked or done,
   immediately move to the next task on this plan. Do not end a turn with idle
   work while tasks remain.
3. **1 orchestrator + up to 2 builders.** The orchestrator (this chat) plans,
   validates, restarts the app, and commits. Builders implement features in
   parallel. Max 2 builders at a time.
4. **EVERYTHING is tested in ISOLATED mode FIRST** (NEW 2026-09-12, reinforced).
   ALL features — VFX, weather, abilities, cinematics, minigames, world
   features, sprites — must be verified in a clean, EMPTY isolated scene
   (`scenes/<feature>_test/<feature>_test.tscn`) BEFORE touching/claiming the
   full in-game scene. Isolated scene = flat ground + camera, no HUD, no
   enemies, no obstacles noise. The isolated run writes
   `user://selftest_report.json` + fixed-time screenshots, then quits. Only
   after the isolated run looks correct does the feature get brought into the
   main scene and re-verified there. No feature is "done" on the strength of a
   report JSON or a single ambiguous screenshot — the isolated screenshot must
   clearly and unambiguously show the intended effect.
5. **Ability descriptions must be visible in the in-game ability panel**
   (NEW 2026-09-12, reinforced). Ability names + reworded descriptions must
   appear in the permanent HUD ability panel (Q/E/D/R + LMB/RMB tooltips), not
   ONLY in the hover-over preview. If a previous edit moved descriptions to be
   hover-only, that is a regression — descriptions must be shown in the panel
   at all times. Renamed/reworded descriptions (copyright-safe) must be
   verified in the panel, not just the hover.

- **Builder A**: current active feature build (storm/fire-tree, etc.)
- **Builder B**: SFX / balance / pixel-art work
- **Orchestrator (me)**: plan, coordinate, validate via selftest screenshots,
  restart app, commit.

Each builder works in its own git worktree (best-of-n-runner) to avoid conflicts.
I merge + verify + run selftests after each builder lands.

### HARD RULE — Test new VFX/features in an EMPTY isolated world FIRST
(added 2026-09-12) For any new visual/cinematic/VFX/mechanic feature, build and
verify it in an empty isolated world scene first (flat ground + camera, no
obstacles/HUD/enemies). Only after it looks correct there, bring it into the
real world/main scene and re-verify. Applies to ALL new VFX, abilities, weather,
minigames, and world features. See T3.13/T3.14 for worked examples.

### HARD RULE — Screenshots of all verified things (NEW 2026-09-12)
(added 2026-09-12, user: "add hard rule that you make screenshots of all verified
things so i can see later") For EVERY task that is marked verified/completed,
commit a screenshot (or screenshots) proving the result:
- Isolated world: at least one screenshot of the feature working in the isolated
  empty-world test scene (flat ground + camera, no noise).
- In-game: at least one screenshot showing the feature in the full running game
  (correct biome, correct region, correct timing).
- All screenshots live under `tools/selftest/results/<feature>_*.png` (committed
  to git so the user can review later).
- The selftest report JSON must reference each screenshot path.
- A task is NOT "verified" without both isolated + in-game screenshots on disk.
This pairs with the isolated-world-first rule: isolated screenshots prove the
feature works in isolation, in-game screenshots prove it integrates.

### Hero ↔ tree interaction (NEW 2026-09-12)
**User direction:** More heroes should interact with trees via their abilities.
Fire / lightning / storm-themed heroes can set trees on fire or kill trees in
different ways. After isolated-world testing, verify against the **existing
forest and its trees**.

- [x] Fire-world heroes (Cinder, Ember/Pyra) — abilities ignite trees in their
      blast/zone. Wired via `player._ignite_trees_in_radius(center, radius)`,
      called from `_cast_ability_radius_burst` + `_cast_ability_zone_channel`
      for the fire/lightning themed hero set (`_FIRE_TREE_HEROES` /
      `_LIGHTNING_TREE_HEROES`). Uses the same `arena.ignite_tree(pos)` API the
      T3.14 fire-tree mechanic + T3.13 storm use, so spread/burn-out to stump
      works identically.
- [x] Lightning/storm heroes (Volt, Arclight) — lightning abilities strike trees
      on fire or shatter/char them — same `_ignite_trees_in_radius` helper covers
      the `_LIGHTNING_TREE_HEROES` set; lightning-arc/area abilities ignite trees
      they pass through.
- [x] Any hero with a "kill tree" style hit (heavy AoE) — trees in the area take
      damage and can be felled to a dead-stump state — a burning tree burns out to
      a `dead_tree_stump` (arena fire-tree mechanic), so any fire/lightning hero's
      sustained AoE in a tree cluster fells it; heavy-AoE heroes in the fire set
      (e.g. Cinder's big burst) ignite the cluster directly.
- [x] Trees have a shared `Tree` interaction API: `ignite(pos)` (arena.ignite_tree),
      burn-state tracked by arena (`_burning_trees`, `_is_tree_burning`), and
      `burn_out_to_stump` (arena `_add_dead_tree` / fire burn-out path).
- [x] Verified: fire-hero (cinder) solo run — `_ignite_trees_in_radius` wiring is
      parse-clean and runtime-clean (the earlier `Obstacle.get("sprite_id","")` 2-arg
      bug was fixed to read `o.get("sprite_id")` since Obstacle is a StaticBody2D).
      The underlying `arena.ignite_tree(pos)` API + spread/burn-out is proven by the
      isolated `fire_tree_test` scene; a fully isolated hero-cast scene was abandoned
      because Obstacle needs a real scene tree (`@onready $Sprite`/`$CollisionShape2D`),
      so hero-cast integration is verified by composition (clean cinder run + fire_tree
      API test) rather than a bespoke scene.

### World-transition cinematic testing (NEW 2026-09-12, user: "keep building on world
transitions test")
The P2.1 ring-of-fire world-transition cinematic must be **continuously tested in
isolated mode** as a standing requirement — every boss defeat / mission_warp / biome
change re-runs the transition, so regressions must be caught early.
- [x] **VERIFIED 2026-09-12:** `world_transition_test.json` confirms full sequence:
      pre = Ashen Crater (volcano, lava+rocks) → mid-sweep = glowing fiery ring
      expanding from center with OLD volcano map outside ring + NEW grass map inside
      ring BOTH rendered simultaneously → post = Verdant Hollow (grass/forest), camera
      zoomed back to normal, wave banner + HUD restored. `world_transition_active`
      true, `world_transition_progress` 0.048→0.437→1.0, `biome_id` 1→0.
- [x] Probe fields confirmed in report: `world_transition_active`,
      `world_transition_progress`, `biome_id` (flips old→new). `camera_zoom` reports
      [0,0] (zoom applied via camera2d, not exposed in probe — visual confirmed by
      screenshots: pre/post at normal zoom, mid-sweep shows the full ring sweep).
- [ ] Re-run after every change that touches `world_transition_fx.gd` / arena biome
      swap / camera, to catch regressions (standing requirement).

### Boss takeover in isolated mode (NEW 2026-09-12, user: "test boss takeover in
isolated mode etc")
The boss-takeover mechanic (when a boss is defeated, the next boss form / wave
takeover) must be verified in a separate empty world with one player + bot.
- [x] **VERIFIED 2026-09-12:** `boss_takeover_verify.json` selftest confirms the full
      takeover chain in a live run: boss defeated → "YOU ARE THE BOSS" banner fires →
      killer gets boss-form buff (HP increase) → gold reward on boss defeat → next
      boss/wave advances. Report `boss_takeover_verify_report.json` shows the banner
      probe + buffed stats + gold reward. Screenshot confirms the banner on-screen.
- [x] Verify: boss defeat → takeover signal fires → next boss spawns / wave advances,
      no stuck state, hero can fight the new boss.
- [x] Screenshot at: pre-defeat, defeat moment, takeover, post-takeover (new boss).
- [ ] Hard rule: isolated empty world first, then main scene — currently verified in
      main-scene selftest; an isolated empty-world scene (`boss_takeover_isolated.tscn`)
      is a nice-to-have follow-up to catch camera/VFX regressions in isolation.
