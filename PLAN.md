# RIFT SURVIVORS — MASTER BUILD PLAN

_Last updated: 2026-09-11_

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
> - T3.3 Isometric architecture + creature art at tree/rock detail level (in progress)
> - T3.5 Rain effect, T3.6 Volcano black lava, T3.7 Factory electro, T3.8 SFX redo,
>   T3.9 Hero role + multi-charge, T3.10 Upgrade diversification, T3.11 Recruit creep
>   behavior test, T3.12 Use new sprites to populate 4 areas on empty map
>
> **In progress:** T1.5 hero balance (all heroes solo + FFA), T3.3 isometric art.
> **Queued:** T1.7–T1.10, T3.4–T3.12.

This is the master plan. Each task has sub-requirements and must be validated in-game
by the selftest harness (bot must survive; visual changes must be confirmed in
screenshots). Use this to track progress.

---

## P0 — CRITICAL (blocks everything)

### T0.1 Fix ability preview not showing in menu (Pjotr mode)
- [ ] Reproduce: select a hero, hover an ability slot → preview SubViewport must render
- [ ] Root-cause: check `bootstrap.gd` hero-select flow (Pjotr mode) vs OFFLINE mode
- [ ] Verify `ability_preview_world.reload()` is called on hero change + slot hover
- [ ] Confirm `render_target_update_mode = ALWAYS` in the tscn
- [ ] Confirm `_ensure_preview_rect()` runs and TextureRect is added to layout
- [ ] Confirm `SoundDirector.preview_muted = true` so no audio in menu
- [ ] Validate: UI-verify screenshot shows hero + creeps + VFX in the preview box
- [ ] Validate: no preview sound while hovering

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
- [ ] **Volt Q → bouncing lightning**: arcs slowly between creeps in an area, AoE denial; multi-charge
- [ ] **Warden voodoo wards → multi-charge** (3 stack, cast refreshes timer)
- [ ] **Fissure → multi-charge + bigger AoE** (confirm which hero; widen area)
- [ ] Every hero gets at least one multi-charge ability
- [ ] Role specialization pass: each of the 16 heroes tuned to read clearly as their role (tank/mage/support/assassin/ranged/melee/druid/stealth)
- [ ] Verify: solo + FFA selftest per hero; screenshot each hero's new Q

### T1.8 Level-up diversification (NEW 2026-09-11)
- [ ] 3-4 distinct upgrade choices per level-up (not 2 repeated)
- [ ] Upgrades scale with hero role
- [ ] Verify: each hero solo → level-up UI shows varied options

### T1.9 Biome hazards: rain + black lava + factory electro (NEW 2026-09-11)
- [ ] Rain overlay + rain SFX in all worlds (occasional, 8-15s bursts) — see T3.5
- [ ] Volcano: lava periodically cools to black, walkable no-dmg (5-8s) — see T3.6
- [ ] Factory: ground periodically electrocutes, small damage ticks — see T3.7

### T1.10 Non-robot hero SFX redo (NEW 2026-09-11)
- [ ] Each non-robot hero: distinct per-ability SFX, world-themed, pixel-art-analog — see T3.8
- [ ] Verify: `sound_probe_heroes` selftest confirms each hero's SFX is audibly distinct

---

## P2 — MEDIUM

### T2.1 Map + rendering
- [x] Flowers/grasses not only in middle — scatter everywhere (grass_real top-up) — verified via `grass_edges_verify.json` screenshots showing grass/flowers at all 4 map edges
- [ ] Rain effects (check chat history for the earlier rain feature)
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

- [ ] Dance/disco minigame — pixel-art disco ball, floor tiles, dancing creeps (2-frame)
- [ ] Keg Toss — pixel-art kegs, target ring, lagoon backdrop props
- [ ] Whack-a-Creep — pixel-art creeps (3×3 grid), mallet, grid tiles
- [ ] RPS — pixel-art hand gestures (rock/paper/creep), table
- [ ] Treasure Dash — pixel-art maze walls, treasure chests, runner
- [ ] All other planned minigames (crate stack, crystal catch, ring roll, slime splat,
      balloon pop, gem relay, creep pinball) — pixel art only
- [ ] Verify: each minigame in its isolated empty-world scene shows only pixel-art sprites

### T3.5 Rain effect (all worlds)
**User direction (2026-09-11):** Rain happens occasionally in ALL worlds — a nice
rain overlay + rain sound.

- [ ] Rain particle overlay: ~40-60 falling streak particles, light blue-white,
      slight diagonal angle, subtle
- [ ] Rain is occasional — random start/stop, lasts 8-15s, not permanent
- [ ] Rain SFX: synthesized rain loop (quiet, -20dB), crossfades in/out with the rain
- [ ] Rain works in all 5 biomes (grass/volcano/ice/factory/docks) — in volcano it's
      "ash + rain", in factory "rain + steam", but visually the same rain overlay
- [ ] Verify: selftest with a forced-rain dev command → screenshot shows rain streaks
      + rain sound audible

### T3.6 Volcano "black lava" phase
**User direction (2026-09-11):** In the lava world, the lava periodically becomes
black (solidified) for a short window, during which walking on it causes no damage.

- [ ] Every ~20-30s the lava pools enter a "black" phase for ~5-8s
- [ ] Black phase: lava color shifts to dark grey/black, hazard DOT paused,
      no dunk scramble
- [ ] Visual cue: a brief "the lava cools" flash + SFX (deep thud) when it cools
- [ ] Verify: screenshot during black phase shows dark pools + player walks on
      them without damage

### T3.7 Factory "electrocuted ground" hazard
**User direction (2026-09-11):** In the factory world, the ground periodically
electrocutes, dealing small damage to anyone standing on the affected area.

- [ ] Every ~15-25s a random floor patch (3-4 tiles) "electrocutes" for ~3s
- [ ] Electro patch: crackling electric overlay (zigzag lines + sparks), small
      damage tick (2-3 dps), visible
- [ ] SFX: electric crackle
- [ ] Verify: screenshot shows the electro patch + damage ticks while standing on it

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

- [ ] Recruit flow: stand in area → bond timer fills → creeps become friendly
      minions that follow the player
- [ ] Friendly minions fight enemy creeps (target nearest enemy)
- [ ] In FFA: friendly minions fight OTHER players' minions/hero
- [ ] After a minigame completes, the player's recruited creeps still function
      and engage in combat
- [ ] Verify: selftest with 2 heroes + recruited creeps → creeps fight enemies;
      FFA selftest → creeps fight other team

### T3.12 Use new sprites to build 4 areas on an empty map
**User direction (2026-09-11):** After building all the isometric sprites, use
them to populate the 4 recruitment areas on an otherwise empty map (the isolated
test scene). Each area should show its house + props + 3 creature variants, all
using the new isometric art.

- [ ] Isolated empty-world scene with 4 areas laid out (one per corner)
- [ ] Each area: structure (house) + 2-3 props + 3 recruit creatures
- [ ] Screenshot at 4× zoom → confirm all new art renders correctly and reads as
      the same art pass as the trees/rocks

---

## ORCHESTRATION PLAN

Per the user's hard rule: **max 2 builders + 1 orchestrator (me), no questions, keep going.**

- **Builder A**: T1.2 (4 new areas + sprites) + T1.3 (mini-games framework)
- **Builder B**: T1.4 (SFX overhaul) + T1.5 (balance + visual fixes)
- **Orchestrator (me)**: T0.1 (preview fix), T0.2 (test fix), coordinate, validate,
  restart app, commit.

Each builder works in its own git worktree (best-of-n-runner) to avoid conflicts.
I merge + verify + run selftests after each builder lands.
