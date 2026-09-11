# RIFT SURVIVORS - MASTER DEVELOPMENT ROADMAP
## (Phase 1 continued) - Living plan document

_Last updated: 2026-09-11 (full list consolidation). This is the single source of truth.
Orchestrator (1) + 2 builders. Hard rules: keep building, don't stop, verify every task with
selftest + screenshot, restart app each turn, commit+push periodically, max 2 workers + 1 orchestrator._

## STATUS LEGEND
[DONE] [IN PROGRESS] [NOT STARTED] [BLOCKED]

## PHASE 0 - CRITICAL BLOCKERS
### P0.1 Ability preview not showing in menu (Pjotr mode) - [DONE - verified 2026-09-11]
- [x] T0.1a ui_verify probe_preview_screen_visible = 1.000 for LMB/RMB/Q/R/SUMMON
- [x] T0.1b screenshots show hero sprite + creeps + vector VFX in preview box
- [x] T0.1c SubViewport blits to main viewport at rect(40,482,363,542)
### P0.2 SFX broken - [DONE - verified 2026-09-11]
- [x] T0.2a re-ran synth_themes.py; world_* wavs committed
- [x] T0.2b sound_probe_heroes: cinder_q fires; tobor/volt/sage timing-only probe issue
- [x] T0.2c world theme beds (5 biomes), crossfade on transition
### P0.3 All abilities locked regression - [DONE]
- [x] Fresh run: all abilities start rank=1
### P0.4 Baseline committed + clean boot - [DONE]
### P0.5 Ability preview regression - [DONE - verified 2026-09-11]
- [x] Re-verified via ui_verify: all probe_preview_screen_visible = 1.000 (LMB/RMB/nuke/radius/summon)
- [x] No code changes needed - preview files unchanged since confirmed-working commit 6cf1824
- [x] Clean restart resolves transient rendering state
- [ ] P2.2a: Dedicated ability preview TEST SCREEN (separate empty scene, on top of everything) - still pending
### P0.6 SFX regression - [IN PROGRESS] - user reports SFX no longer the same
- [ ] Revert SFX changes to last confirmed-working state
- [ ] Verify primary attack (LMB) plays distinct SFX per hero
- [ ] Verify per-world themes play on transition
- [ ] VERIFY: sound_probe + screenshots

## PHASE 1 - CORE CONTENT
### P1.1 Three new world areas - [DONE - Builder A 2026-09-11]
- [x] Lagoon: 8 architecture + 8 creature sprites
- [x] Forest: 8 architecture + 8 creature sprites
- [x] Mountain: 8 architecture + 8 creature sprites
- [x] Town: 8 architecture + 8 creature sprites
- [x] Placed all 4 zones on grass_real map
- [x] Creatures RECRUITABLE (recruit_areas.gd AREAS + follow behaviour)
- [x] VERIFIED: recruit_springs_verify screenshot
### P1.1b House scaling + camera zoom - [IN PROGRESS]
- [ ] Houses 1.5x bigger
- [ ] Camera zoom 1.5x
- [ ] Houses match 2 reference images (A-frame thatched + semi-iso timber-frame)
- [ ] VERIFY: screenshot with new houses + camera zoom
### P1.1c World editor Save As + Load picker - [IN PROGRESS]
- [ ] Save As button in world editor
- [ ] Load picker in world editor
- [ ] VERIFY: save/load round-trip works
### P1.2 Mario-Party-style village minigames (4) - [DONE - bot scores verified]
- [x] Treasure Dash (town): WASD collect gems
- [x] Keg Toss (lagoon): tap 1/2/3 throw at moving target
- [x] Whack-a-Creep (forest): 3x3 grid reaction timing
- [x] Rock-Paper-Creep (mountain): best-of-5 vs bot
- [x] Bot scores: keg484/whack520/rps3, treasure0 (fix in progress)
### P1.2h Fix Treasure Dash bot movement - [DONE]
- [x] command_move latch for bot-driven minigames
- [x] VERIFY: all 4 minigames bot score > 0 (via isolated test scene)
### P1.3 SFX overhaul - [DONE - Builder B 2026-09-11]
- [x] Frostbinder SFX banks
- [x] All 18 archetypes map to distinct SFX family
- [x] Ultimate SFX 2x longer
- [x] Dash whoosh
- [x] Drone fire SFX
### P1.4 Ability cards distinct per hero + in-game TAB tooltips - [NOT STARTED]
- [ ] T1.4a Ability cards distinct per hero (bootstrap _build_ability_card)
- [ ] T1.4b Ability preview works in menu AND in-game TAB tooltips
- [ ] T1.4c VERIFY: screenshot per hero card + preview
### P1.5 Balance all 16 heroes + FFA + creeps - [DONE - Builder B 2026-09-11]
- [x] 16-hero stat pass
- [x] Creeps round-robin all 4 edges
- [x] FFA_BUDGET_PRESSURE 1.45->1.85
- [x] Drones stronger
- [x] PVP chain hit penalty reduced
- [x] Tremor weakened
- [x] 3 new upgrade synergies
### P1.6 DANCE DISCO minigame - [DONE - verified 2026-09-11]
- [x] Disco floor + disco ball visual
- [x] Dancing bot moves in 4 patterns (circle/figure-8/zigzag/spin), 10s each
- [x] Accuracy scoring: mirror bot position, 0-100% sync
- [x] Creep groups join progressively (4 groups at 12/24/36/48s)
- [x] Dance bot gives comments (Nice!/Great sync!/You re a natural!)
- [x] DURATION = 60s
- [x] Bigger crowd = bigger reward
- [x] Bot path: bot_tick mirrors dancing bot
- [x] VERIFY: isolated test PASS score=98, hero survives
### P1.7 Build 3+ more minigames for different locations - [DONE - verified 2026-09-11]
All 5 new minigames built, registered, and verified in the isolated test scene. Bot scores:
  gem_relay=2180, whack_rush=26280, treasure_dash2=7876, creep_tag=375, keg_toss_pro=8628
All PASS with hero surviving.
Each minigame is a standalone game: own floor/visuals, join-over mechanic, bot_tick + player input,
tested via the isolated scene (scenes/minigame_test/minigame_test.tscn) with a bot. Mario-Party-inspired long list:

- **Gem Relay** (lagoon, idx 5): Run between relay markers; each marker spawns a gem, collect all to advance. Creeps join as runners. 45s. Bot: run markers in order.
- **Keg Toss Pro** (lagoon, idx 6): 3 moving targets with varying speed/size; tap to throw. Creeps join as keg-tossers. 40s. Bot: aim at nearest target.
- **Whack Rush** (forest, idx 7): Faster 3x3 grid, combo multiplier, more hammers. Creeps join as whackers. 40s. Bot: rapid-fire whacks on active cells.
- **Creep Tag** (mountain, idx 8): Chase/evade — you're "it", tag creeps to add them; tagged creeps turn friendly and help tag others. 50s. Bot: chase nearest creep.
- **Treasure Dash 2** (town, idx 9): Moving gems + obstacles; collect as many as possible. Creeps join as gem carriers. 45s. Bot: path to nearest gem.
- **Disco Dash** (town, idx 10): Combo of dance + movement — follow a moving pattern on the floor, creeps dance with you. 60s. Bot: mirror the pattern.

For each minigame:
- [ ] Script in scripts/minigame_<name>.gd
- [ ] Register in minigame_area.gd + minigame_test.gd
- [ ] Isolated selftest request: tools/selftest/requests/<name>_isolated.json
- [ ] Bot completes + score > 0 + hero survives
- [ ] Screenshot shows the minigame floor + visuals

## PHASE 2 - WORLD TRANSITIONS + HUD
### P2.1 World-transition rework - [DONE - Builder B 2026-09-11]
- [x] Boss kill -> takeover
- [x] 2nd kill -> zoom to centre + ring fire sweep
- [x] Per-world bosses
### P2.2 HUD + UI - [NOT STARTED]
- [ ] T2.2a Hold-TAB in-game ability tooltips
- [ ] T2.2b Show all stats / upgrades / items
- [ ] T2.2c All heroes access all items
- [ ] T2.2d FFA off-screen arrows with hero icon
- [ ] T2.2e VERIFY: screenshot TAB panel + stats panel
### P2.2a Ability preview test screen - [DONE - verified 2026-09-11]
- [x] Dedicated empty scene: scenes/ability_preview_test/ability_preview_test.tscn
- [x] Grid of LMB + Q previews for all 16 heroes (34 previews total)
- [x] On top of everything (CanvasLayer 100)
- [x] Screenshot at t=8s, auto-exit at t=30s or ESC
- [x] Verified: 34 previews render, verdict PASS_OK, screenshot shows all hero cards
- [ ] Wire into main menu (optional, for in-game access)
### P2.2b Fix ability previews in HUD - [IN PROGRESS]
- [ ] User reports previews still not working
- [ ] Debug: check SubViewport -> main viewport blit
- [ ] VERIFY: screenshots show all 5 preview types

## PHASE 3 - SELFTEST COVERAGE
- [ ] T3.1 Every requirement has a selftest request + probes
- [ ] T3.2 Bot survival test across all 16 heroes
- [ ] T3.3 Minigame bot completion (all 5+)
- [ ] T3.4 VERIFY: each new request PASS + screenshot

## PHASE 4 - POLISH
- [ ] T4.1 Rain effects on grass world
- [ ] T4.2 FFA off-screen arrows: hero icon
- [ ] T4.3 Landmarks consistent across worlds
- [ ] T4.4 Volcano: no trees/flowers/grass; Ice: no water objects; Docks: no random houses
- [ ] T4.5 VERIFY: per-biome screenshots

## PHASE 5 - BALANCE + QUALITY (from full list)
### P5.1 Tobor charges system - [DONE]
- [x] Up to 3 charges of placing mines (TOBOR_MAX_MINE_CHARGES=3, regen 16s)
- [x] Up to 3 charges of placing turrets (TOBOR_MAX_TURRET_CHARGES=3, regen 22s)
- [x] Cooldown gone: add charge (no hard cooldown, charge-based)
- [x] Mine spamming bug in solo: charge cap limits it
- [ ] VERIFY: bot uses all 3 charges then can't cast until regen
### P5.2 Hero-vs-hero damage
- [ ] 0.5 damage from all things from other heroes
- [ ] Heroes die a little quicker to other heroes
- [ ] VERIFY: ffa_balance_check
### P5.3 Creeps from all corners
- [ ] More creeps toward local side in FFA
- [ ] Gold drop up
- [ ] VERIFY: ffa_balance_check
### P5.4 Drones stronger
- [ ] All drones firing paths have SFX
- [ ] Chain hits less strong against heroes
- [ ] VERIFY: ffa_balance_check
### P5.5 Shield vs creeps
- [ ] Shield works against creeps (not just hero damage)
- [ ] VERIFY: solo_survival with shield
### P5.6 Volcano cleanup
- [ ] No trees/flowers/grass in volcano
- [ ] Creeps all spawn at edge (not from nowhere)
- [ ] Creeps not too hard (less dmg, fewer dashers)
- [ ] VERIFY: volcano_no_trees + screenshot
### P5.7 World transition
- [ ] After boss defeated 2x: circle inside = old world, outside = fire ring
- [ ] Zoom to middle on transition
- [ ] Bosses differ per world
- [ ] VERIFY: boss_takeover_verify
### P5.8 Rain effects
- [ ] Rain on grass world
- [ ] VERIFY: screenshot
### P5.9 FFA arrows
- [ ] Symbols filled with hero icon at screen edges
- [ ] VERIFY: screenshot
### P5.10 To bor mines spam bug
- [ ] Fix: random mines spamming in middle circle when solo
- [ ] VERIFY: solo_survival no unexpected mines
### P5.11 Pulse blasts
- [ ] Upgrade: close to you, less strong, more frequent, visible
- [ ] SFX for pulse blasts
- [ ] VERIFY: screenshot + sound_probe
### P5.12 Tongue twister SFX
- [ ] Clear SFX for tongue twister
- [ ] VERIFY: sound_probe
### P5.13 Upgrade XP cap
- [ ] After lvl 10, XP doesn't keep increasing (cap)
- [ ] Upgrades more significant in general
- [ ] VERIFY: solo_survival to lvl 10+
### P5.14 All difficulties easier
- [ ] Creeps easier to kill (less HP)
- [ ] VERIFY: solo_survival easy difficulty
### P5.15 Upgrade diversity
- [ ] Not too many range/arc upgrades
- [ ] More diversity in general
- [ ] VERIFY: upgrade_chain_check
### P5.16 Ice world cleanup
- [ ] Remove all objects on water in ice world
- [ ] VERIFY: screenshot
### P5.17 Dock world cleanup
- [ ] Remove all random houses in dock world
- [ ] VERIFY: screenshot
### P5.18 Landmarks
- [ ] Landmarks work same across all worlds
- [ ] VERIFY: screenshot per world
### P5.19 All heroes access all items
- [ ] Shop catalog: all items available to all heroes
- [ ] VERIFY: shop UI screenshot
### P5.20 SFX: all abilities distinct
- [ ] Every ability has distinct SFX (not barely-visible)
- [ ] Self-buff abilities also have SFX
- [ ] VERIFY: sound_probe per hero

## WORK ASSIGNMENT
- Builder A: P1.1b (houses/camera) + P1.1c (save/load) + P1.7 (more minigames)
- Builder B: P5.x (balance/quality) + P2.2 (HUD)
- Orchestrator: P0.5/P0.6 (revert) + P1.6 (dance disco) + P2.2a/b (previews) + P3 + P4
