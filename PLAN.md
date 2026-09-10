# RIFT SURVIVORS — MASTER BUILD PLAN

_Last updated: 2026-09-10_

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

### T1.1 Revert to last-known-good ability VFX state (before "unique vectors" change)
- [ ] `git log --oneline` for `scripts/main.gd` + `scenes/bootstrap/ability_preview_world.gd`
- [ ] Identify commit just before the "unique vectors" refactor
- [ ] Revert `main.gd` VFX spawning to that state (keep the dedup + ult-2x changes if present)
- [ ] Ensure each hero's abilities have *distinct* vector styles (BOLT/BLAST/BURST/ARC/WAVE/TELEPORT)
- [ ] Validate: kit_dry selftest per hero; screenshot confirms VFX renders

### T1.2 3 new recruitment areas + sprites (lagoon, forest, mountain)
- [ ] LAGOON area
  - [ ] 8 architecture sprites: palm huts, dock stilt, lagoon shrine, fruit tree,
       reed shelter, tide pool, coral platform, lagoon well
  - [ ] 8 creature sprites: dodo (walking), tropical bird (animated), parrot,
       iguana, turtle, crab, jellyfish (floating), seagull
  - [ ] Recruit behavior: lagoon creatures are fast/cheap, swarm from water edge
  - [ ] Pixel art: same density as existing (16px base, `town_*` style)
  - [ ] `recruit_areas.gd`: register lagoon corner (BL) with theme + accent color
- [ ] FOREST area
  - [ ] 8 architecture sprites: woodcutter cabin, root hut, mushroom ring, lantern
       post, stone circle, campfire (animated), hanging bed, tree hollow
  - [ ] 8 creature sprites: wolf (existing), boar (existing), owl, fox, badger,
       deer, hedgehog, mushroom golem
  - [ ] Recruit behavior: forest creatures are tanky/slow, defend the camp
  - [ ] `recruit_areas.gd`: register forest corner (TR)
- [ ] MOUNTAIN area
  - [ ] 8 architecture sprites: isometric stone huts, cliff dwelling, mine cart,
       avalanche gate, wind chime, ice cave mouth, lookout tower, prayer flags
  - [ ] 8 creature sprites: yeti, mountain goat, snow leopard, raven, stone
       golem, ice wisp, cave bat, avalanche spirit
  - [ ] Recruit behavior: mountain creatures are high-damage/low HP, ranged
  - [ ] `recruit_areas.gd`: register mountain corner (BR)
- [ ] All 4 areas: spawn lingering NPCs that idle/move a bit ("chill" behavior)
- [ ] All 4 areas: placed on the `grass_real` map at their respective corners
- [ ] Validate: selftest recruits from each area; screenshot shows themed NPCs

### T1.3 Mario-Party-style mini-games (each = a big build)
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
- [ ] World transitions: 5-4-3-2-1 fight countdown SFX
- [ ] Per-world sound theme:
  - [ ] Verdant Hollow: nature, birds, water
  - [ ] Ashen Crater: lava rumble, metal
  - [ ] Frostmere Reach: wind, ice crack
  - [ ] Docks: waves, wood creak, gulls
- [ ] Keep pixel-art analog feel (short, punchy, not overly digital)
- [ ] Validate: `sound_probe` selftest confirms each hero's primary SFX fires

### T1.5 Balance + visual fixes
- [ ] Drones stronger (dmg + HP buff)
- [ ] Chain hits less strong against other heroes (PvP reduction)
- [ ] "Flying drone guy" (Volt?) too strong vs heroes — reduce chain-hit vs PVP
- [ ] Ult SFX + VFX last 2× longer (VFX done; audio T1.4)
- [ ] Balancing all 16 heroes (buffs/nerfs as needed)
- [ ] XP curve: after lvl 10, don't increase required XP as fast
- [ ] Gold: increase drop rate (buying is too expensive)
- [ ] Shield must work against creeps (currently dies with shield up)
- [ ] Creeps from all corners (even distribution)
- [ ] FFA: more creeps toward "my side" (the local player's corner)

### T1.6 World-transition rework
- [ ] Transition triggers: wave 5 boss (1st), wave 10 (2nd), wave 15 (3rd)
- [ ] On 1st boss kill: player who killed it "takes over" (special buff/role?)
- [ ] On 2nd kill: zoom out to middle, show ring transition (old world = outside ring,
       new world = inside ring, like fire sweeping the map)
- [ ] Bosses: different boss per world
- [ ] Remove trees/flowers/grass from volcano world (no biome-0 props in Ashen Crater)
- [ ] Remove random houses from Docks world
- [ ] Remove all objects on water in ice world
- [ ] Zoom to middle on world transition
- [ ] Validate: selftest confirms boss → transition → new world

---

## P2 — MEDIUM

### T2.1 Map + rendering
- [ ] Flowers/grasses not only in middle — scatter everywhere (grass_real top-up)
- [ ] Rain effects (check chat history for the earlier rain feature)
- [ ] No trees in lava when entering volcano world
- [ ] All creeps that "come out of nowhere" in volcano → spawn at map edge only
- [ ] Volcano creeps: too much damage / too many dashers → reduce

### T2.2 HUD + UI
- [ ] Arrows pointing to other players in FFA when off-screen (edge indicator with
       hero icon filled symbol)
- [ ] Landmarks: all 4 landmarks work consistently (some currently don't trigger)
- [ ] Ability cards: continue building (distinct per hero)
- [ ] Ability preview: confirm working (T0.1)

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

### T3.2 Sound polish
- [ ] Each world: 3-4 ambient loops
- [ ] Footsteps per biome (grass = soft, ice = crunch, lava = sizzle)
- [ ] UI hover/click consistent

---

## ORCHESTRATION PLAN

Per the user's hard rule: **max 2 builders + 1 orchestrator (me), no questions, keep going.**

- **Builder A**: T1.2 (4 new areas + sprites) + T1.3 (mini-games framework)
- **Builder B**: T1.4 (SFX overhaul) + T1.5 (balance + visual fixes)
- **Orchestrator (me)**: T0.1 (preview fix), T0.2 (test fix), coordinate, validate,
  restart app, commit.

Each builder works in its own git worktree (best-of-n-runner) to avoid conflicts.
I merge + verify + run selftests after each builder lands.
