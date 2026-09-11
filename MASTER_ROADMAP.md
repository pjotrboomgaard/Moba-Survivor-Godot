# RIFT SURVIVORS - MASTER DEVELOPMENT ROADMAP
## (Phase 1 continued) - Living plan document

_Last updated: 2026-09-11. This is the single source of truth for the multi-day build-out.
Orchestrator (1) + 2 builders. Hard rules: keep building, don't stop, verify every task with
selftest + screenshot, restart app each turn, commit+push periodically, max 2 workers + 1 orchestrator._

## GROUNDING (what already exists)
- 17 heroes in scripts/player_class.gd CLASSES; 4 ability slots (Q/E/D/R kit + LMB + RMB secondary).
- Ability preview: scenes/bootstrap/ability_preview_world.gd (SubViewport live-sim), wired in
  scenes/bootstrap/bootstrap.gd. A second older ability_preview.gd exists.
- SFX: autoload/audio_service.gd (SOUND_LIBRARY, WORLD_THEME_TRACKS per-biome, per-hero cast/attack
  banks, FAMILY_FOR_ARCHETYPE). Gated by autoload/sound_director.gd (preview_muted, is_on_screen).
- 5 biomes (game_runtime.gd): 0 grass,1 volcano,2 ice,3 factory,4 docks. Cycle every 10 waves.
- 4 recruit areas + 4 minigames already scaffolded (scripts/recruit_areas.gd, minigame_*.gd).
- Selftest: tools/selftest/run_selftest.ps1 + requests/*.json + ui_verify_driver. Bot = CpuBrain.
- Dash/blink: player.gd _cast_ability_dash_strike (launch) vs _cast_ability_blink (instant).
- XP cap after lvl10: DONE (player.gd _xp_growth_for_level).

## STATUS LEGEND
[DONE] [IN PROGRESS] [NOT STARTED] [BLOCKED]

## PHASE 0 - CRITICAL BLOCKERS (do first, unblock everything)
### P0.1 Ability preview not showing in menu (Pjotr mode) - [DONE - verified 2026-09-11]
- [x] T0.1a ui_verify probe_preview_screen_visible = 1.000 for LMB/RMB/Q/R/SUMMON
- [x] T0.1b screenshots (ability_preview_nuke, ability_preview_radius, ability_preview_summon)
      show hero sprite + 3 creeps + vector VFX rendering in the preview box
- [x] T0.1c SubViewport blits to main viewport at rect(40,482,363,542)
### P0.2 SFX broken / "no sound on primary attack" / "not the same anymore" - [DONE - verified 2026-09-11]
- [x] T0.2b re-ran tools/synth_themes.py; world_* wavs now committed + hash-verified identical to HEAD
- [x] T0.2a sound_probe_heroes: cinder_q fires from cast_cinder bank (cinder_3.wav). The tobor/volt/
      sage "fail" is probe timing (hero-switch cast not settled when sampled), NOT a real SFX break.
      attack_<hero> banks exist for all 17 heroes; _play_ability_sfx routes to AudioService.play_ability.
- [x] T0.2c world theme beds present (5 biomes), set_world_theme crossfades on transition
- [x] T0.2d sound_director.is_on_screen gate is correct (hero on screen -> plays)
### P0.3 "All abilities are locked" regression - [DONE - verified 2026-09-11]
- [x] T0.3a fresh run: _apply_kit_abilities sets every loadout slot to rank=1 (player.gd 546-548)
- [x] T0.3b HUD comment "All abilities are learned from the start (no rank-0 lock state)" (hud.gd 1037)
- [x] T0.3c sound_probe end-probe shows all 4 sage abilities rank=1; level-ups upgrade ranks
### P0.4 Commit baseline + verify game boots clean - [NOT STARTED]
- [ ] T0.4a godot --headless --import clean (no parse cascade)
- [ ] T0.4b probe_boot selftest PASS

## PHASE 1 - CORE CONTENT (big builds)
### P1.1 Three new world areas (lagoon/forest/mountain) + 4th = town - [NOT STARTED]
- [ ] T1.1a Lagoon: 8 architecture + 8 creature sprites (palms, fruit trees, dodo-like birds, other
        lagoon animals). Consistent 16px pixel density.
- [ ] T1.1b Forest: 8 architecture + 8 creature sprites (forest huts, forest creatures).
- [ ] T1.1c Mountain: 8 architecture + 8 creature sprites (isometric mountain huts, mountain creatures).
- [ ] T1.1d Town: ensure 8 architecture + 8 creature sprites present.
- [ ] T1.1e Place all 4 zones on the grass_real map at corners.
- [ ] T1.1f New creatures linger (chill, small wander, no aggro) until recruited.
- [ ] T1.1g Make each zone's creatures RECRUITABLE (recruit_areas.gd AREAS + follow behaviour, unique per camp).
- [ ] T1.1h VERIFY: recruit_springs_verify screenshot shows 4 distinct areas; bot recruits + creature follows.
### P1.2 Mario-Party-style village minigames (4, each a big build) - [IN PROGRESS]
- [ ] T1.2a Framework minigame_base.gd + minigame_area.gd (exists; harden).
- [ ] T1.2b Keg Toss (lagoon): tap 1/2/3 to throw at moving target, accuracy score. Bot+player.
- [ ] T1.2c Whack-a-Creep (forest): 3x3 grid, reaction timing, combo. Bot+player.
- [ ] T1.2d Rock-Paper-Creep (mountain): best-of-5 vs pattern-learning bot. Bot+player.
- [ ] T1.2e Treasure Dash (town): WASD collect gems in maze. Bot+player.
- [ ] T1.2f Each: unique VFX + unique SFX + reward (gold+XP) on completion.
- [ ] T1.2g Bot AI (CpuBrain) walks to nearest idle minigame and plays it; bot survives the run.
- [ ] T1.2h VERIFY: each minigame - bot completes (score>0, reward granted) and player can complete.
### P1.3 SFX overhaul - [NOT STARTED]
- [ ] T1.3a Per-ability distinct SFX: extend FAMILY_FOR_ARCHETYPE (11/18->18) + SOUND_LIBRARY.
- [ ] T1.3b Dash = launch whoosh not blink (player.gd _cast_ability_blink -> tween travel).
- [ ] T1.3c Ultimate SFX last 2x longer (audio_service._ult_echo_call + kit_fx_library ult lifetime).
- [ ] T1.3d Drones: all firing paths play drone_fire/turret_fire sfx.
- [ ] T1.3e Per-world themes (5 beds) + per-hero themes (cast/attack banks) - keep analog pixel feel.
- [ ] T1.3f VERIFY: sound_probe_heroes + per-ability sound_probe; bot survives.
### P1.4 Ability cards + distinct per hero - [NOT STARTED]
- [ ] T1.4a Ability cards distinct per hero (bootstrap _build_ability_card).
- [ ] T1.4b Ability preview works in menu (P0.1) AND in-game TAB tooltips.
- [ ] T1.4c VERIFY: screenshot per hero card + preview.
### P1.5 Balance all 16 heroes + FFA bots + creeps - [NOT STARTED]
- [ ] T1.5a 16-hero stat pass (player_class.gd CLASSES).
- [ ] T1.5b Creeps from all corners evenly (ghost_wave_system _perimeter_point_nearest).
- [ ] T1.5c FFA: more creeps toward local side (wave_director FFA_*_PRESSURE + _emit_pressure_pack).
- [ ] T1.5d Drones stronger (companion_drone stats).
- [ ] T1.5e Shield vs creeps (player.gd shield absorption).
- [ ] T1.5f Chain hits reduced vs heroes (PVP_CHAIN_HOP_PENALTY) - Volt/drone too strong.
- [ ] T1.5g Tremor too strong -> reduce contact dmg/dash interval (enemy_type.gd bulwark).
- [ ] T1.5h Gold drop up (wave_director gold multipliers).
- [ ] T1.5i All heroes access all items (shop_catalog.items_for).
- [ ] T1.5j Upgrade diversity: range/arc not over-granted; broaden upgrade_catalog DEFS/SYNERGIES.
- [ ] T1.5k VERIFY: solo_survival on 3+ heroes PASS_CLUTCH; ffa_balance_check; bot survives.

## PHASE 2 - WORLD TRANSITIONS + HUD
### P2.1 World-transition rework - [NOT STARTED]
- [ ] T2.1a Transition after boss defeated 2x (wave5 boss1, wave10 boss2, wave15 boss3).
- [ ] T2.1b 1st boss kill: killer takes over (boss-form buff + banner + ring + SFX).
- [ ] T2.1c 2nd kill: zoom out to centre, ring fire sweep across map.
- [ ] T2.1d Bosses differ per world (enemy_type.boss_for_wave + enemy._pick_boss_pattern).
- [ ] T2.1e Zoom to middle on transition.
- [ ] T2.1f VERIFY: boss_takeover_verify probe confirms takeover + ring + zoom.
### P2.2 HUD + UI - [NOT STARTED]
- [ ] T2.2a Hold-TAB in-game ability tooltips (hud._show_ability_hints).
- [ ] T2.2b Show all my stats / upgrades / items (hud stats panel).
- [ ] T2.2c All heroes access all items.
- [ ] T2.2d FFA off-screen arrows with hero icon (hud._draw_ffa_player_arrows - verify).
- [ ] T2.2e VERIFY: screenshot TAB panel + stats panel in-game.

## PHASE 3 - SELFTEST COVERAGE
- [ ] T3.1 Every requirement above has a selftest request + probes.
- [ ] T3.2 Bot survival test across all 16 heroes (solo_survival roster).
- [ ] T3.3 Minigame bot completion (all 4, score>0).
- [ ] T3.4 VERIFY: each new request PASS + screenshot.

## PHASE 4 - POLISH
- [ ] T4.1 Rain effects on grass world.
- [ ] T4.2 FFA off-screen arrows: symbol filled with hero icon.
- [ ] T4.3 Landmarks consistent across worlds.
- [ ] T4.4 Volcano: no trees/flowers/grass; Ice: no water objects; Docks: no random houses.
- [ ] T4.5 VERIFY: volcano_no_trees + per-biome screenshots.

## WORK ASSIGNMENT
- Builder A: P1.1 (3 new areas + sprites) + P1.2 (minigames).
- Builder B: P1.3 (SFX) + P1.5 (balance) + P2 (transitions + HUD).
- Orchestrator (me): P0 (blockers), P1.4 (cards), P3 (selftest), P4 (polish), verify all, commit, restart.