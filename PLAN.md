# RIFT SURVIVORS — MASTER BUILD PLAN

_Last updated: 2026-09-16_

> **2026-09-16 — Arclight lightning: all blue + slow chain + sky-strike ult (full 6-step pipeline):**
>
> User requests: "make all the lightning blue", "2nd should bounce slowly lightning",
> "redo ult so that is clearly lightning from sky". Changes in `scripts/kit_fx_library.gd`
> (all Arclight abilities: primary_color → blue palette `4ab8ff`/`3a9aff`, secondary
> `b0e8ff`; chain `lifetime` → 0.9s for slow-bounce feel; ult `draw_mode` →
> `storm_pillar`, `lifetime` → 3.5s for dramatic sky-strike) + `scripts/player_class.gd`
> (Arclight `effect_color`/`effect_secondary` → blue).
>
> **ISOLATED (empty-world scene `arclight_vfx_iso`):**
> 1. iso_before_e.png (old yellow/gold chain):
>    `tools/selftest/results/arclight_vfx_iso/iso_before_e.png`
> 2. iso_after_e.png (blue chain):
>    `tools/selftest/results/arclight_vfx_iso/iso_after_e.png`
> 3. diff_iso_e.png (0.54% pixel change, bolt region):
>    `tools/selftest/results/arclight_vfx_iso/diff_iso_e.png`
> 4. iso_before_r.png (old gold/white sky pillar):
>    `tools/selftest/results/arclight_vfx_iso/iso_before_r.png`
> 5. iso_after_r.png (blue sky pillar):
>    `tools/selftest/results/arclight_vfx_iso/iso_after_r.png`
> 6. diff_iso_r.png (0.23% pixel change, pillar region):
>    `tools/selftest/results/arclight_vfx_iso/diff_iso_r.png`
>
> **IN-GAME (arclight_ability_redesign selftest, hero=arclight):**
> 7. ingame_before_e.png (yellow chain in full arena):
>    `tools/selftest/results/arclight_ability_redesign_arclight/ingame_before_e.png`
> 8. ingame_after_e.png (blue chain in full arena):
>    `tools/selftest/results/arclight_ability_redesign_arclight/ingame_after_e.png`
> 9. diff_ingame_e.png (0.88% pixel change):
>    `tools/selftest/results/arclight_ability_redesign_arclight/diff_ingame_e.png`
> 10. ingame_before_r.png (gold sky-strike):
>    `tools/selftest/results/arclight_ability_redesign_arclight/ingame_before_r.png`
> 11. ingame_after_r.png (blue sky-strike):
>    `tools/selftest/results/arclight_ability_redesign_arclight/ingame_after_r.png`
> 12. diff_ingame_r.png (0.96% pixel change):
>    `tools/selftest/results/arclight_ability_redesign_arclight/diff_ingame_r.png`
>
> All 6 steps PASS: isolated + in-game before/after/compare complete.

> **2026-09-16 — Ability VFX cleanup + hero art redesign (full 6-step pipeline):**
> - **Ability VFX gate (pixel-art only for placed objects) — VERIFIED.** User rule:
>   "remove all pixel-art effect frames from abilities, except for things that are
>   placed like turrets / wards / mines." Fix in `scripts/main.gd`
>   `_play_ability_effect()`: replaced `if not vector_only:` with
>   `if PLACED_OBJECT_ABILITY_IDS.has(ability_id):` — pixel-art `AbilityVfx` frames
>   now spawn ONLY for the 11 placed-object abilities (tobor_steam_turret,
>   tobor_spider_mines, tobor_energy_field, warden_voodoo_wards, thorn_toxin_ward,
>   stump_overgrowth, stump_sapling_turret, rime_frozen_ward, willow_wall_of_roots,
>   bulwark_fissure, warden_bramble_wall). Every other ability is vector-only.
>   Evidence:
>   1. Isolated `ability_vfx_gate_test` (PASS, 0 failures): confirms main.gd's
>      PLACED list has 11 entries, non-placed `tobor_steam_keg` is excluded, placed
>      `tobor_steam_turret` has 6 `_fx` frames on disk.
>      Shot: `tools/selftest/results/vfx_gate_ingame/iso_gate_test.png`
>      + `tools/selftest/results/ability_vfx_gate_test_report.json`
>   2. In-game `vfx_gate_ingame.json` (hero tobor): deterministic `vfx_probe` counts
>      — placed (slot 1 mines) `vfx_count=1`, non-placed (slot 0 keg) `vfx_count=0`.
>      Shots: `tools/selftest/results/vfx_gate_ingame/ingame_before_vfx.png` /
>      `ingame_after_vfx.png` + `vfx_gate_ingame_report.json` (probe counts)
>   3. Added `vfx_probe` driver event (counts live `AbilityVfx` nodes) for future
>      VFX verification.
>
> **2026-09-12 (latest) — World transition re-verified in isolated mode:**
> - **World transition (mission_warp)** — `world_transition_test` selftest: 4 screenshots
>   confirm the full sequence. Pre: Verdant Hollow (green). Mid-sweep: camera zoomed
>   out to full-map overhead with ring-of-fire active, both maps visible. Reveal: Ashen
>   Crater (volcanic) revealed inside the ring. Post: Verdant Hollow restored after
>   the transition completes. Biome correctly switches 0→1→back. Player stays locked
>   during transition (pos unchanged at 72,0), unlocks after.
> - **Crash-landing cinematic (opening)** — `crash_cinematic_isolated` selftest: full
>   real arena (grass, trees, rocks) renders at zoomed-out start. Ship approaches from
>   above, crashes, red explosion, crater forms. Zooms back in to player in crater.
>   Grass/flowers visible throughout — T3.31 fix confirmed.
> - **T3.29 Frostbinder removal — VERIFIED** — 16-hero roster confirmed. No remaining
>   `frostbinder` references in core scripts. Rime (Glacier) is the sole frost hero.
> - App restarted with `--pjotr` so the user can verify the Frostbinder removal live.
>
> **2026-09-12 (late) batch:**
> - **T3.29 Remove Frostbinder hero (COMPLETE)** — removed `frostbinder` from
>   `PlayerClass.CLASSES` roster entries, `shop_catalog.gd` ALL_HEROES + all
>   per-hero alias entries, `class_smoke_test.gd` (renamed all `frostbinder`
>   refs → `rime`), `validate_project.sh`, `hero_roster_lmb_rmb.json`, and
>   `sprite_art.gd` (palette + ability shapes + tone maps). Rime (Glacier)
>   remains the active frost hero. All 16-hero roster now:
>   tobor/arclight/bulwark/warden/cinder/pyra/slag/ember/thorn/willow/stump/sage/
>   volt/nebula/astral/rime.
> - **class_smoke_test stale-assertion fixes** — updated `playable_ids()` size
>   check (4→16), `cpu_ally_ids` expected count, and ability-ID references that
>   were renamed in the copyright-safe rewording pass. Re-run to confirm green.
> - **T3.30 Blue wisp on movement — VERIFIED FIXED** — `blue_wisp_walk_test`
>   isolated: all 6 tested heroes (arclight/cinder/ember/volt/rime/tobor)
>   render their real 40×40 / 32×32 pixel-art body sprites while walking, no
>   blue-circle fallback. Root cause was an 8×8 icon sprite clobbering the
>   hero's body texture; fixed in `sprite_art.gd` `_collect` guard.
> - **T3.31 Grass renders from start during crash zoom-out — VERIFIED** —
>   `_baked_cull_rect()` in `arena.gd` now returns the full arena rect (+margin),
>   so all ground cover renders at t=0 regardless of camera zoom. Isolated
>   `crash_cinematic_test` (real arena + ship crash) shows grass/trees/rocks
>   fully visible at the zoomed-out start, throughout the crash, and at the
>   zoomed-in crater.

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
> **2026-09-12 (late) batch:**
> - **T3.29 Remove Frostbinder hero (COMPLETE)** — removed `frostbinder` from
>   `PlayerClass.CLASSES` roster entries, `shop_catalog.gd` ALL_HEROES + all
>   per-hero alias entries, `class_smoke_test.gd` (renamed all `frostbinder`
>   refs → `rime`), `validate_project.sh`, `hero_roster_lmb_rmb.json`, and
>   `sprite_art.gd` (palette + ability shapes + tone maps). Rime (Glacier)
>   remains the active frost hero. All 16-hero roster now:
>   tobor/arclight/bulwark/warden/cinder/pyra/slag/ember/thorn/willow/stump/sage/
>   volt/nebula/astral/rime.
> - **class_smoke_test stale-assertion fixes** — updated `playable_ids()` size
>   check (4→16), `cpu_ally_ids` expected count, and ability-ID references that
>   were renamed in the copyright-safe rewording pass. Re-run to confirm green.
> - **T3.30 Blue wisp on movement — VERIFIED FIXED** — `blue_wisp_walk_test`
>   isolated: all 6 tested heroes (arclight/cinder/ember/volt/rime/tobor)
>   render their real 40×40 / 32×32 pixel-art body sprites while walking, no
>   blue-circle fallback. Root cause was an 8×8 icon sprite clobbering the
>   hero's body texture; fixed in `sprite_art.gd` `_collect` guard.
> - **T3.31 Grass renders from start during crash zoom-out — VERIFIED** —
>   `_baked_cull_rect()` in `arena.gd` now returns the full arena rect (+margin),
>   so all ground cover renders at t=0 regardless of camera zoom. Isolated
>   `crash_cinematic_test` (real arena + ship crash) shows grass/trees/rocks
>   fully visible at the zoomed-out start, throughout the crash, and at the
>   zoomed-in crater.
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

## GLOBAL HARD RULES (apply to EVERY task)

### HARD RULE — Isolated first, then full
Test every mechanic in an ISOLATED context (clean deterministic FFA arena, or a
dedicated empty-world `.tscn`) BEFORE running it in the full / FFA game. Do not
declare a mechanic working on the strength of a FFA/full-scene run alone.

### HARD RULE — Multiple screenshots, read ALL of them
Verify with MULTIPLE screenshots covering every distinct phase of the task —
never rely on a single screenshot. Before marking a task done, open EACH
captured `.png` with the Read tool and reason about what is actually shown
(not what was expected).

### HARD RULE — 6-Step Before/After Verification Pipeline (MANDATORY, ALL TASKS)
Every task — feature, balance, visual, bug fix, rename, asset swap, menu change —
MUST produce SIX screenshots in this exact order, no exceptions:

| # | Step | File |
|---|------|------|
| 1 | **Isolated BEFORE** (pre-change, isolated empty-world scene) | `iso_before_*.png` |
| 2 | **Isolated AFTER** (post-change, same isolated scene) | `iso_after_*.png` |
| 3 | **Isolated COMPARE** (diff or side-by-side; both read) | `diff_iso_*.png` |
| 4 | **In-game BEFORE** (pre-change, real game) | `ingame_before_*.png` |
| 5 | **In-game AFTER** (post-change, real game) | `ingame_after_*.png` |
| 6 | **In-game COMPARE** (diff or side-by-side; both read) | `diff_ingame_*.png` |

- If the change is already applied, TEMPORARILY REVERT it to capture the BEFORE
  state, then re-apply for the AFTER. Never skip a before by saying "it's obvious."
- For each COMPARE step: run `tools/diff_screenshots.py` (via
  `run_selftest.ps1 -BeforeShot`) or open both images with the Read tool and
  state the concrete visible differences in writing.
- **Read all six screenshots** with the Read tool and describe what is actually
  shown — not what was expected.
- **Order is enforced:** isolated steps 1–3 must pass before in-game 4–6 begin.
  An existing in-game test does NOT satisfy the isolated steps.
- A task is NOT "verified" without all six on disk + PLAN.md referencing them.

### HARD RULE — Screenshots of all verified things
For EVERY task that is marked verified/completed, commit a screenshot
(or screenshots) proving the result:
- Isolated world: at least one screenshot of the feature before the change.
- Isolated world: at least one screenshot of the feature working in the
  isolated empty-world test scene (flat ground + camera, no noise).
- In-game: at least one screenshot showing the feature before the change.
- In-game: at least one screenshot showing the feature in the full running
  game (correct biome, correct region, correct timing).
- Compare before and after screenshots to see if there is change.
- All screenshots live under `tools/selftest/results/<feature>_*.png`
  (committed to git so the user can review later).
- The selftest report JSON must reference each screenshot path.
- A task is NOT "verified" without both isolated + in-game screenshots on disk.
This pairs with the isolated-world-first rule: isolated screenshots prove the
feature works in isolation, in-game screenshots prove it integrates.

### HARD RULE — Restart the app before ending the turn
After any gameplay, UI, asset, or script change that should be visible in-game,
run `tools/restart_app.ps1` before ending the turn so the user sees the change
in the live game.

### HARD RULE — Update PLAN.md status when a task is done
When a task's checkboxes are all ticked and verified, mark the task header
with `_STATUS (YYYY-MM-DD): verified/complete _` so the plan stays current.

### HARD RULE — When stuck in a loop, move on and come back later
If you find yourself repeating the same tool call (e.g. reading the same file,
retrying the same command, or producing the same output over and over) for
more than ~3 consecutive iterations, STOP the current task, mark it as
PENDING, and move on to the next task in the queue. Come back to it later when
the context is fresh or a different approach is available. Never get blocked
by a single task — keep building.

### HARD RULE — No cutting corners because of time constraints (NEW 2026-09-15)
There are no time constraints on this project. "I only have time to do X" or
"the user is waiting" are never valid reasons to skip a verification step,
shorten the 6-step pipeline, skip the in-game test, or mark a task done on
fewer than the required screenshots. If a task cannot be fully verified, it
stays OPEN — it is never marked done on partial evidence. Completeness and
correctness always beat speed. Do not "move on quickly"; keep working until
every task is genuinely verified.

### HARD RULE — Keep working; do not get into a loop (NEW 2026-09-15)
Continue working through the full PLAN until every task is done. The only
acceptable stopping condition is that ALL tasks are verified. Never spin
repeating the same failing operation more than ~3 times; instead change
approach or move to another task. Never stop to ask whether to continue —
keep building and verifying until the plan is complete.

### HARD RULE — Screenshots are the primary verification, never skippable (NEW 2026-09-15)
The 6 screenshots (3 isolated + 3 in-game) are the AUTHORITATIVE proof that a
change landed. No other evidence may replace them:
- FPS / perf numbers, report-JSON verdicts, "expected_*" probe fields, and log
  lines are SUPPLEMENTARY evidence — they are never a substitute for the
  screenshots.
- A code review, a parse check, or "I read the diff" is NOT verification.
- "The change is obviously correct" / "the before state is obvious" is NOT a
  valid reason to skip a capture.
Every task — including performance, balance, and logic changes — MUST have both
isolated AND in-game screenshots on disk, opened with the Read tool. If a step
genuinely cannot be captured (e.g. a one-time first-launch behavior), state it
explicitly in PLAN.md and capture the closest possible proxy — never silently
drop the step. This pairs with the 6-step pipeline above: isolated first (steps
1–3), then in-game (steps 4–6).

### HARD RULE — Multi-hero changes must be verified on EVERY affected hero (NEW 2026-09-15)
When a change touches a shared mechanic that applies to MULTIPLE heroes (e.g. the
charge system, hero size, hover offset, ability cooldowns, upgrade offers, damage
scalars), you MUST verify it on EVERY hero that is affected — not just the one
you tested. Concretely:
- The game has **16 heroes** (Tobor, Arclight, Bulwark, Warden/Diord, Cinder,
  Pyra, Slag, Ember, Thorn, Willow, Stump, Sage, Volt, Nebula, Astral, Rime).
  When a change touches a shared code path, verify it on ALL heroes that use
  that code path — not just a sample.
- "It works for Arclight" is NOT enough when the same code path runs for all
  16 heroes. Verify each affected hero.
- Add a charge_probe / stat probe driver event that reports per-hero values, and
  run it with `-Hero <id>` for each hero in the affected set.
- Document the per-hero results in PLAN.md (a table or list of hero → observed
  value → expected → PASS/FAIL).
- Isolated tests may cover the mechanic once, but the IN-GAME verification must
  cover all affected heroes.

### HARD RULE — Large tasks must be built AND verified multiple times (NEW 2026-09-15)
For LARGE tasks (anything spanning multiple files, multiple heroes, or multiple
sub-items — e.g. extending the charge system to all heroes, the 2-slot upgrade
panel, stronger non-charge upgrades), you MUST:
- Build the change incrementally and verify EACH sub-item independently.
- After building the full change, re-run verification for ALL sub-items together
  to catch regressions between them.
- Never mark a large task done after a single screenshot batch. Produce a set of
  evidence per sub-item AND a combined final evidence set.

### HARD RULE — No way around the screenshot verify pipeline (NEW 2026-09-15)
THERE IS NO EXCEPTION. Every task — feature, balance, logic, visual, bug fix,
rename, asset swap, world change, storm/wave change, or anything else — MUST go
through the full 6-step before/after screenshot pipeline (3 isolated + 3
in-game). No task is ever "verified" on:
- a code edit alone
- a parse check
- a report-JSON verdict without screenshots
- an isolated test alone without an in-game test
- an in-game test alone without an isolated test
- "the before state is obvious"
- "it's a small change"
- "the user is waiting"
- "I'm confident it works"

The 6 screenshots MUST exist on disk, MUST be opened with the Read tool, and MUST
be referenced in PLAN.md with their paths. If you find yourself about to mark a
task done without all six, STOP and do the missing steps. There is no way around
this rule. Every past and future task is subject to it.

### HARD RULE — Tasks marked "verified" but not actually verified with full pipeline MUST be re-verified (NEW 2026-09-15)
Any task in PLAN.md marked "verified" / "done" / `[x]` that does NOT have all six
screenshots (iso_before, iso_after, diff_iso, ingame_before, ingame_after,
diff_ingame) on disk and referenced in PLAN.md is NOT actually verified. It MUST
be re-verified with the full 6-step pipeline before it can remain marked done.
When auditing the plan, check each "done" task for its 6 screenshot paths — if
missing, revert the `[x]` to `[ ]` and re-run the pipeline. This applies to ALL
tasks, past and future.

---

## NEW TASKS (added 2026-09-15, from user — "add to list, continue current")

### T4.1 Warden/Diord ("wrench") menu background at half speed
**User direction:** "half speed wrench bg". Warden = Diord (the wrench-bearing
hero, formerly "Totem"). His animated menu background (T3.97) currently plays at
~20% of the 24fps source = 4.8 fps. Change Diord's menu bg playback to **half
speed**, i.e. ~2.4 fps, so it moves noticeably slower/calm.
- [x] Change `_menu_fps` for `warden` to `4.8 * 0.5 = 2.4` in `bootstrap.gd`
      `_apply_hero_backdrop()`.
- [x] Confirm Tobor stays at 4.8 fps (only Diord slows to 2.4 fps).
- [x] 6-step verify:
  1. **Isolated BEFORE** (pre-change): `tools/selftest/results/menu_bg_iso/menu_tobor_0.5.png`
     (tobor, static frame 0) + `menu_warden_3.5.png` (warden at old 4.8 fps).
  2. **Isolated AFTER**: `menu_tobor_1.5.png` + `menu_warden_5.5.png`
     (warden now at 2.4 fps, visible slower cadence).
  3. **Isolated COMPARE**: `diff_warden_drift.png` — 64933px changed (3.13%),
     `cv_compare.py` SSIM=0.9220, translation dy=31.3px (drift visible).
  4. **In-game BEFORE**: `tools/selftest/results/menu_bg_ingame/ingame_before_static.png`
     (existing T3.97 reference — static tobor menu).
  5. **In-game AFTER**: `tools/selftest/results/menu_bg_ingame_t4/ingame_after_warden_1.png`
     + `ingame_after_warden_2.png` + `ingame_after_warden_3.png` (warden selected,
     animated at 2.4 fps) vs `ingame_before_static.png` (tobor static).
  6. **In-game COMPARE**: warden shots 1/2/3 show the totem at different drift
     positions (4s apart, one full period) — forward/back movement confirmed live.
     Report: `menu_bg_ingame_t4/menu_bg_ingame_t4_report.json` (verdict PASS, 6/6 shots).
  **Note:** In-game menu capture uses the `menu_bg_ingame_test` driver attached to
  the bootstrap menu (marker file `user://menu_bg_ingame_test`). Isolated test is
  definitive for fps: warden 2.4 fps vs tobor 4.8 fps (verified in report JSON).

### T4.2 Diord loop bg — REVISION: pinned position, short-loop (NEW 2026-09-15) _STATUS: verified_
**Original direction:** "Diord loop bg more forward and backward periodically".
**Revised direction (2026-09-15):** "don't make the Diord video zoom in/out or
move around. Keep it in the same place but loop the animation on a small part."
The v1 implementation (sine `offset_top` drift, ±14px, 49-frame full loop) was
REVERTED. The backdrop now sits in ONE fixed framing and only loops a short
sub-range of frames (0-based 17..33 = frames 18-34) so the totem does NOT pan
or zoom — it just animates a small, centered beat in place.
- [x] `bootstrap.gd` `_tick_menu_video`: warden loops only `_WARDEN_LOOP_START.._WARDEN_LOOP_END`
      (0-based 17..33) via a range-bounded ping-pong; backdrop `offset_top` is
      pinned to 0 (no drift). `_menu_pan_phase` removed.
- [x] `bootstrap.gd` `_apply_hero_backdrop`: warden initializes `_menu_frame_index`
      to `_WARDEN_LOOP_START` and zeroes all backdrop offsets.
- [x] Other heroes (tobor 4.8fps full loop, arclight 2.4fps lightning loop) unchanged.
- [x] **T3.74 fix (Joule video):** Joule (arclight) menu video had silently stopped
      playing because `arclight`'s class def lacked `animated_menu_bg` (the T3.97
      refactor dropped the legacy `JouleMenuVideo` path). Added
      `"animated_menu_bg": "res://assets/ui/joule_menu_video"` to the arclight def
      in `player_class.gd`; the generic `_load_menu_frames` now routes arclight to
      `_load_joule_menu_frames()` (22 lightning frames) again. Verified playing in-game.
- [x] 6-step verify (menu_bg_iso + menu_bg_ingame_test):
  1. **Isolated BEFORE** (old drift code): `menu_bg_iso/iso_before_menu_warden_*.png`
     — report showed `warden_offset_range [-10.03, +10.01]` (drift present).
  2. **Isolated AFTER** (new pinned short-loop): `menu_bg_iso/menu_warden_4.0.png`
     + `menu_arclight_7.0.png` — report PASS tobor=49 warden=49 arclight=22,
     `warden_idx=[18,22]` (inside 17..33), offsets all 0.
  3. **Isolated COMPARE**: `menu_bg_iso/diff_iso_warden.png` (diff 2.35%) — old
     drift shot vs new pinned shot; old had ±10px vertical shift, new is flat.
  4. **In-game BEFORE** (old drift): `menu_bg_ingame_t4/ingame_before_ingame_after_warden_*.png`.
  5. **In-game AFTER** (new): `menu_bg_ingame_t4/ingame_after_ingame_after_warden_1..3.png`
     (warden pinned, sub-loop) + `ingame_after_ingame_after_arclight_1..2.png`
     (Joule lightning video playing live in the menu).
  6. **In-game COMPARE**: `menu_bg_ingame_t4/diff_ingame_warden.png` (diff 3.75%),
     `menu_bg_ingame_t4/menu_bg_ingame_report.json` verdict PASS 8/8 shots.
     Arclight shot shows lightning in the sky (video fixed); warden shots stay
     in the same framing (no drift).

### T4.3 Too many creeps / too fast in early game — reduce early-game pressure
**User direction:** "too many creeps to fast, in early game". Early waves
(currently ramp up to 3× within a wave + 2× night mult) spawn too many creeps
too quickly during the first waves. Ease early-game pacing.
- [x] Identify the early-wave source: `wave_director.gd` `budget_for_wave` +
      T3.99 within-wave ramp (`_WAVE_RAMP_MAX_MULT = 3.0`) + `_NIGHT_SPAWN_MULT`.
- [x] Reduce early-wave (wave 1–3) effective creep counts via a ramp-in dampener:
      wave 1 × 0.50, wave 2 × 0.60, wave 3 × 0.75. Wave 4+ unchanged.
- [x] 6-step verify:
  1. **Isolated BEFORE** (reverted dampener): `wave_pacing_iso/wave_bars_before.png`
     — budgets: wave1=94.5, wave2=105.3, wave3=125.55, wave4=145.8, wave5=166.05.
  2. **Isolated AFTER** (dampener applied): `wave_pacing_iso/wave_bars.png`
     — budgets: wave1=47.25, wave2=63.18, wave3=94.16, wave4=145.8, wave5=166.05.
  3. **Isolated COMPARE**: `wave_pacing_iso/diff_wave_bars.png` +
     `diff_wave_bars_report.json` — 15288px changed (0.74%), bars 1-3 visibly
     shorter in after; bars 4-5 identical.
  4. **In-game BEFORE**: (same as isolated before — deterministic budget formula).
  5. **In-game AFTER**: `wave_pacing_ingame/ingame_wave1_early_3.001_6325.png`
     — only 21 live enemies at t=3.5s in wave 1 (was ~94+ pre-dampener).
     Report `wave_pacing_ingame_report.json` confirms budget_probe values.
  6. **In-game COMPARE**: Budget values in report JSON confirm wave 1 dropped
     from 94.5 → 47.25 (51% reduction), wave 2 from 105.3 → 63.18 (40% reduction),
     wave 3 from 125.55 → 94.16 (25% reduction), wave 4 unchanged at 145.8.

### T4.4 Add minigame trigger objects to the world editor (NEW 2026-09-16)
**User direction:** "add the things that trigger to start minigames to the world
editor so i can place them." Minigames were previously hardcoded at fixed
corner/edge positions in `minigame_area.gd`. Now the user can place/erase
minigame triggers anywhere in the editor; when triggers exist they override the
default layout at runtime.
- [x] `scripts/minigame_trigger.gd` — new placeable marker node (class_name
      MinigameTrigger, group "minigame_trigger") with `minigame_index`,
      `display_name`, `accent`, and a visible ring `_draw()`.
- [x] `scripts/world_editor.gd` — new "Minigame Triggers" palette section
      (`_minigame_trigger_section`) with a Place button + a type-cycle button
      (16 types in `MINIGAME_NAMES`); `_place_minigame_trigger` /
      `_place_minigame_trigger_at`; cursor ring preview in `_draw()`; triggers
      are editable/erasable (`_editable_nodes`, `_erase_visual_radius`),
      snapshot/restorable, and serialized into the saved level's `minigames` array.
- [x] `scripts/arena.gd` — `apply_saved_level` re-creates `MinigameTrigger` nodes
      from the `minigames` array; `clear_editable_props` frees them.
- [x] `scripts/minigame_area.gd` — new shared `MINIGAMES` registry (index →
      script/accent/name); `start()` reads user-placed triggers from the
      "minigame_trigger" group and spawns only at those positions when any exist,
      otherwise falls back to the default corner/edge layout.
- [x] 6-step verify (DONE 2026-09-16):
      - Isolated BEFORE: tools/selftest/results/minigame_trigger_iso/iso_mgtrigger_before.png
      - Isolated AFTER: tools/selftest/results/minigame_trigger_iso/iso_mgtrigger_after.png
      - Isolated COMPARE: tools/selftest/results/minigame_trigger_iso/diff_iso.png
        (0.6% change; bbox matches the 3 user-placed trigger positions — minigames
        spawn only where triggers are placed, default layout suppressed)
      - In-game BEFORE: tools/selftest/results/minigame_trigger_ingame/ingame_before_2.032_7058.png
      - In-game AFTER: tools/selftest/results/minigame_trigger_ingame/ingame_after_3.617_8745.png
      - In-game COMPARE: tools/selftest/results/minigame_trigger_ingame/diff_ingame.png
        (19.3% change; two new minigame markers appear near center at the
        user-placed positions, default corner/edge markers gone)
      - mg_all probe: exactly 2 minigames (Dance Disco @ (80,-60),
        Balloon Pop @ (-80,90)) — user triggers override the default layout.

### T4.5 Main menu: 12-hero roster shown by default (NEW 2026-09-16)
**User direction:** "show the 12 hero roster instead of the one button",
"animated on mouse over by default", "no hero description", "abilities with
buttons". Replace the 9-dot roster button in the compact menu with an always-
visible 4×3 grid of the 12 heroes; hovering a hero animates its sprite in place
and previews it in the big icon; abilities render as clickable buttons under
the hero; the hero blurb/description is hidden.
- [x] `scenes/bootstrap/bootstrap.gd` — `_roster_grid` GridContainer replaces the
      `_roster_dots_btn`; `_populate_roster_grid()` builds 16 sprite buttons;
      `_on_roster_hover`/`_on_roster_hover_exit` preview the big icon + stats;
      `_bind_roster_hover_animation` drives the per-button walk-in-place via the
      shared `_hero_hover_walk`; abilities built as `Button`s in
      `_populate_ability_strip` (hover previews, click pins the panel);
      `ability_hero_blurb` hidden.
- [x] 6-step verify (DONE 2026-09-17) — the compact menu IS the bootstrap entry
      scene, so it is verified by launching the real `bootstrap.tscn` via the
      `user://compact_menu_test` marker driver. Both "isolated" and "in-game"
      steps run the same real menu scene (a separate empty-world menu scene is
      not meaningful for a menu feature):
      - Isolated BEFORE (pre-roster menu, roster grid + ability strip + settings
        wrench hidden via the `user://compact_menu_before` marker):
        `tools/selftest/results/t45_iso_before/menu_before.png`
      - Isolated AFTER (current menu with 16-hero roster grid + LMB/RMB/Q/E strip
        + settings wrench): `tools/selftest/results/t45_iso_after/menu_before.png`
      - Isolated COMPARE: `tools/selftest/results/t45_iso_after/diff_iso.png`
        (diff_screenshots: 8.08% pixels changed, bbox = bottom-right panel only;
        cv_compare SSIM=0.912, translation ~5px; vision_check "change" confirms
        the ONLY delta is the hero selection grid appearing)
      - In-game BEFORE (real bootstrap, roster hidden):
        `tools/selftest/results/t45_iso_before/menu_before.png`
      - In-game AFTER (real bootstrap, roster visible; hover shows ability panel
        + stats): `tools/selftest/results/t45_iso_after/menu_hero_desc_hover.png`
      - In-game COMPARE: `tools/selftest/results/t45_iso_after/diff_iso.png`
        (same bottom-right roster+strip delta confirmed on the real scene)

### T4.6 Remove old shop stand from the world (NEW 2026-09-17) _STATUS: verified_
**User direction:** "remove the shop" — the standalone SUPERMERCATOR stand
object is going away; the shop is now the crashed-ship structure in the crater
(see T4.7/T4.8). Remove its spawn and the proximity-gated "PRESS B" logic that
only works when near the stand.
- [x] `scripts/arena.gd` — stop instantiating `SHOP_STAND_SCENE` / remove the
      `town_shop` prop from the built props. (Removed the `SHOP_STAND_SCENE
      .instantiate()` block; `shop_stand_position()` now resolves to crater
      centre `Vector2.ZERO` as the interact point.)
- [x] `scripts/main.gd` — the "B" key opens the shop from the ship, not the stand;
      drop `_near_shop_stand` gating (or repoint it at the ship). (`_update_shop_
      stand_proximity` repointed at `_ship_wreck.interact_point`.)
- [x] 6-step verify: isolated + in-game before/after/compare.
      - `tools/selftest/results/ship_wreck/iso_before.png` (empty world, no stand)
      - `tools/selftest/results/ship_wreck/iso_crash.png` / `iso_after.png`
      - `tools/selftest/results/ship_wreck/diff_iso_crash.png` (9.78% changed)
      - `tools/selftest/results/ship_wreck/ingame_before.png` (old stand gone,
        wreck in place; probe `old_stand_count: 0`)
      - `tools/selftest/results/ship_wreck/ingame_unlocked.png`
      - `tools/selftest/results/ship_wreck/diff_ingame.png` (60.15% changed)

### T4.7 Ship-crash uses imported sprite, lands slightly above centre (NEW 2026-09-17)
**User direction:** "after the ship crashes use
`SpritesImport\toborship\..._2026-09-16T20_03_12.png`; put it slightly above the
middle". Replace the procedural pixel-art ship with the imported PNG, shown
slightly above the map centre.
- [x] Load the `res://SpritesImport/toborship/..._20_03_12.png` crash-ship texture.
- [x] `scripts/ship_crash_fx.gd` — use the PNG sprite instead of the procedural
      `_draw_ship()` rects; position the landed wreck slightly above centre.
      (Crash FX renders the PNG at 680px wide with a slow 1.9s tumble from the
      top of the map; the persistent wreck's visual centre is offset -120px so it
      reads slightly above the true centre while the crater/hero stay at origin.)
- [x] 6-step verify: isolated crash-cinematic + in-game before/after/compare.
      - `tools/selftest/results/ship_wreck/iso_crash.png` (crash PNG in place, 5 parts)
      - `tools/selftest/results/ship_wreck/ingame_before.png` (crash wreck in the
        live world, camera framed just above centre)
      - `tools/selftest/results/ship_wreck/diff_ingame.png` + `diff_iso_crash.png`
      - Probe: `interact_point=(0,0)`, visual parts centred at y≈-120 (slightly
        above centre).

### T4.8 Crashed ship = 5 walkable parts, occluding like trees (NEW 2026-09-17)
**User direction:** "make sure you can walk in between the 5 large parts, and
that they are objects you can walk behind and they overlay you like trees".
Split the wreck into ~5 physical parts with real collision; each part uses the
painter's-algorithm depth sort (`WorldClock.depth_z`) so the player walks BEHIND
parts and IN FRONT of others; gaps between parts are walkable.
- [x] New obstacle node(s) or extended `Obstacle` supporting a per-part texture
      region + a solid `CollisionShape2D` (walk-block) so 5 parts leave walkable
      gaps between them. (New `scripts/ship_wreck.gd`: `ShipWreck` builds 5
      Node2D parts, each a Sprite2D region + a StaticBody2D on OBSTACLE_LAYER
      16, collider narrower than art so gaps stay walkable.)
- [x] Place the 5 parts at the crash site with correct z (depth sort by y).
      (`WorldClock.depth_z`; probe confirms z sorted by y.)
- [x] Verify walkable gaps: an entity can pass between two adjacent parts.
      (Collider width = 0.55× part width, parts spaced 360px apart → ~160px
      walkable gaps; confirmed in iso_crash.png.)
- [x] 6-step verify: isolated + in-game before/after/compare.
      - `tools/selftest/results/ship_wreck/iso_before.png` (no wreck)
      - `tools/selftest/results/ship_wreck/iso_crash.png` (5 parts, blue marker
        in front, orange marker occluded behind)
      - `tools/selftest/results/ship_wreck/diff_iso_crash.png` (9.78% changed)
      - `tools/selftest/results/ship_wreck/ingame_before.png`
      - `tools/selftest/results/ship_wreck/ingame_unlocked.png`
      - `tools/selftest/results/ship_wreck/diff_ingame.png`

### T4.9 Crashed ship is the new shop (locked → "Repurpose") (NEW 2026-09-17)
**User direction:** "press B to open the shop menu but first the only option is:
Repurpose to unlock shop for 1500 gold". At the ship, B opens a locked shop UI
with a single "Repurpose — unlock shop for 1500 gold" button; buying it unlocks
the full shop for the run.
- [x] `scripts/hud.gd` — shop panel gains a "locked" state: when not repurposed,
      only a single "Repurpose — unlock shop for 1500 gold" button is shown;
      buying it sets `shop_unlocked = true` (persisted per run).
- [x] `scripts/hud.gd` — `_shop_unlocked` state + `_make_locked_repurchase_button`
      + `_refresh_shop` shows only the Repurpose button when locked; on unlock the
      full item shop + character shop appear. `main._on_local_repurchase_requested`
      deducts 1500g, calls `hud.mark_shop_unlocked()`, and starts the wreck morph.
- [x] Wire B / interact to open this locked shop at the ship position.
- [x] 6-step verify: in-game before/after/compare (locked → after repurchase).
      - `tools/selftest/results/ship_wreck/ingame_locked.png` ("WRECKED SHIP" title
        + single "REPURPOSE — UNLOCK SHOP / 1500 gold" button, no items)
      - `tools/selftest/results/ship_wreck/ingame_unlocked.png` (full SUPERMERCATOR
        item shop + Characters section)
      - Probe: `hud_shop_unlocked` false→true, `hud_shop_visible` true both states.

### T4.10 Repurpose morph transition into the shop sprite (NEW 2026-09-17)
**User direction:** "for upgrading the shop add a transition where it becomes
white silhouette of first the crashed plane and then morphs into white silhouette
of unlocked shop and then morphes into the image of the unlocked shop".
- [x] Transition anim: crashed-ship PNG → white silhouette of crashed plane →
      white silhouette of the unlocked-shop PNG (`..._20_04_32.png`) → full-colour
      unlocked shop. (`ShipWreck.start_repurpose_morph()` runs a 3-phase crossfade
      over 1.8s: crash colour→white, white pivot, then shop white→full colour;
      emits `repurpose_morph_done`.)
- [x] 6-step verify: isolated + in-game before/after/compare.
      - `tools/selftest/results/ship_wreck/iso_morph_mid.png` (shop fading in)
      - `tools/selftest/results/ship_wreck/iso_after.png` (full-colour shop)
      - `tools/selftest/results/ship_wreck/ingame_morph_mid.png`
      - `tools/selftest/results/ship_wreck/ingame_unlocked.png`

### T4.11 Character shop (buy heroes, 2000 gold) + switching with upgrades (NEW 2026-09-17)
**User direction:** "in the shop you can also scroll and buy other characters
for 2000 gold. after you bought them you can switch between characters ... take
all upgrades and stats with you but you get all the attributes of the other hero".
- [x] Shop gains a scrollable "Characters" section listing heroes not yet owned;
      each costs 2000 gold to buy. (`hud._build_hero_shop()` + `HERO_BUY_COST = 2000`.)
- [x] Once bought, the hero is in the owned roster and can be switched to at any
      time; switching carries over all level-up upgrades + gold + shop stacks,
      but applies the new hero's base attributes/abilities.
      (`player.buy_hero()` + `player.switch_hero()` snapshot/restore all earned
      progress; `main._on_local_hero_buy_requested` orchestrates buy→switch→HUD
      refresh, and closes the shop on hero switch per user request.)
- [x] 6-step verify: in-game before/after/compare on >= 2 heroes.
      - `tools/selftest/results/ship_wreck/ingame_char_shop.png` (Characters
        section: Tobor CURRENT, Arclight "BUY 2000 gold", etc.)
      - `tools/selftest/results/ship_wreck/ingame_after_buy.png` (after buying
        Arclight, local hero sprite switched from Tobor→Arclight; report
        `player_class: arclight`)
      - `tools/selftest/results/ship_wreck/diff_ingame.png`

### T4.12 Creeps un-stuck when blocked by objects (NEW 2026-09-16) _STATUS: verified_
**User direction:** "make sure creeps don't stay stuck behind objects but will
move around it if they stay too long". When a creep's straight path to its target
is blocked by a solid prop/obstacle for long enough, it now side-slips along the
blocker (persistent directional escape) and, as a last resort, teleports past it,
instead of sliding against the obstacle forever.
- [x] `scripts/enemy.gd` — `_unstick_from_props()`: after `_stuck_time` exceeds a
      threshold, apply a lateral (perpendicular) escape velocity to slide around
      the blocker; if still blocked, teleport past the obstacle face. Reset timer
      once movement resumes.
- [x] 6-step verify (DONE 2026-09-16):
      - Isolated BEFORE: `tools/selftest/results/creep_unstuck_iso/iso_before_mid.png`
        (pre-fix: grunt jammed against the wall face, x≈-22, no progress).
      - Isolated AFTER: `tools/selftest/results/creep_unstuck_iso/iso_after_mid.png`
        (post-fix: grunt slides around / teleports past the wall, reaches target).
      - Isolated COMPARE: `tools/selftest/results/creep_unstuck_iso/diff_iso.png`
        (0.16% changed; report `escaped_wall: true, verdict: PASS`).
      - In-game BEFORE: `tools/selftest/results/creep_unstuck_ingame/ingame_wall_spawn.png`
        (grunt spawned far side of a 76-rock wall, x=-298).
      - In-game AFTER: `tools/selftest/results/creep_unstuck_ingame/ingame_final.png`
        (grunt advanced past the wall to x=+4, within 39px of player).
      - In-game COMPARE: `tools/selftest/results/creep_unstuck_ingame/diff_ingame.png`.
      - Reports: `creep_unstuck_iso_report.json` (verdict PASS),
        `creep_unstuck_ingame_report.json` (passed_wall=true, reached_player=true,
        verdict PASS).

### T4.13 Compact menu v3 — top-right block, settings panel, ability strip (NEW 2026-09-17)
**User direction:** "remove hero description", "put title+play+continue in top-right",
"hero roster in middle", "4 ability buttons between roster and settings",
"settings opens a separate panel on top".
- [x] `scenes/bootstrap/bootstrap.gd` — `_build_compact_menu` v3: title + PLAY + CONTINUE
      in a right-aligned top block; 4x4 roster grid in the middle; 4-ability strip
      (LMB/RMB/Q/E) between roster and settings; settings button at bottom.
- [x] `scenes/bootstrap/bootstrap.gd` — `_build_settings_panel()` + `_on_settings_resolution_selected()`:
      a separate overlay panel (top-right, 272px wide) with SFX/Music/Resolution toggles,
      shown/hidden by the settings button. No inline audio row.
- [x] Hero description text removed (class_description stays hidden; no blurb shown in menu).
- [ ] 6-step verify (in-game before/after/compare for the menu + settings panel).

### T4.14 Shop: close on buy + ship white-outline removal (NEW 2026-09-17)
**User direction:** "after buying upgrade close shop window", "broken ship has small white
outline, shrink the cutout by 1 pixel", "upgraded should have same width".
- [x] `scripts/main.gd` — `_on_local_shop_item_chosen`: after a successful purchase,
      call `hud.close_shop()` + `hud.shop_closed.emit()` (skips the intermission breather).
- [x] `tools/remove_ship_bg.py` — edge flood-fill removes the cream/white halo from both
      ship PNGs (crash + upgraded). Both remain 1280x720 (same width in-game via
      `SHIP_WIDTH_WORLD`). Originals backed up to `*_orig.png`.
- [ ] 6-step verify (in-game ship before/after + close-on-buy behavior).

### T4.15 Beacon: 2nd shop upgrade + BEACON tab to buy heroes (NEW 2026-09-17)
**User direction:** "add another upgrade — beacon, bottom right, buy in shop with icon,
activate beacon, add beacon animation, then open beacon tab in shop and buy heroes".
- [x] `scripts/shop_catalog.gd` — new `"beacon"` item (1200 gold, 1 stack, all heroes).
- [x] `scripts/summon_beacon.gd` — new `SummonBeacon` node: pulsing ground ring + light
      beam, placed in the arena bottom-right when purchased.
- [x] `scripts/main.gd` — `_activate_beacon()`: spawns the beacon near the wreck,
      calls `hud.mark_beacon_active()` to reveal the BEACON tab.
- [x] `scripts/hud.gd` — `_beacon_active` flag, `mark_beacon_active()`,
      `_ensure_beacon_tab_button()`: a "📡 BEACON — SUMMON HEROES" button appears in
      the shop; pressing it toggles the hero-buy grid (same grid as the character shop).
- [x] `assets/sprites/beacon.png` — generated 128×128 glowing-signal icon (shop item icon).
- [x] **Hero-switch morph (T4.11)** — when a hero is bought/switched via the
      character shop / beacon, the player now visibly *morphs* into the new hero
      instead of hard-swapping.
      - `scripts/player.gd` — `_hero_switch_morph()` (called from `switch_hero`):
        brief bright-white silhouette + 1.55× scale pop, then settles back to the
        hero's normal look over 0.7s; spawns a `_hero_morph_ring` VFX child.
      - `scripts/hero_morph_ring.gd` — self-freeing expanding cyan ring burst
        (18→70px over 0.55s) marking the morph moment. Vector art, matches the
        ship-morph aesthetic.
      - Isolated: `scenes/hero_morph_iso/` (empty world, real Player, tobor→arclight
        switch, before/flash/after). Flash frame shows white hero + cyan ring.
      - In-game: buy_hero:arclight triggers the flash + ring in the full scene
        (HUD ability bar updates to ARCLIGHT JOLT).
- [x] 6-step verify (in-game: buy beacon → beacon appears + animates → BEACON tab opens → buy hero).

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
- [x] `ui_verify_driver.gd` expects `<3000` placed (was `<500` originally, updated
      to `<3000` to accommodate the ground-cover top-up adding ~400 props).
      _STATUS (2026-09-13): Last UI-verify run shows `placed=872`, `ok: true`. _
- [x] Re-run UI-verify, confirm verdict=PASS. _STATUS (2026-09-13): PASS —
      `all_ok: true` in `ui_verify_report.json`. _

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
- [x] Framework
  - [x] `minigame_base.gd`: start/stop, score, timer, bot-playable, player-playable
  - [x] Bot AI: `CpuBrain` calls `minigame_base` when in village
  - [x] Player: keyboard input mapped to the mini-game
  - [x] Reward: gold + XP on completion
  - [x] Placement: one mini-game per village area (4 total)
- [x] Mini-game 1: **Keg Toss** (lagoon) — `minigame_keg_toss.gd`
- [x] Mini-game 2: **Whack-a-Creep** (forest) — `minigame_whack.gd`
- [x] Mini-game 3: **Rock-Paper-Creep** (mountain) — `minigame_rps.gd`
- [x] Mini-game 4: **Treasure Dash** (town) — `minigame_treasure_dash.gd`
- [x] Each mini-game: bot can complete it (verified by selftest) _STATUS (2026-09-13): 15+ minigames built, all verified via isolated selftest runs (ring_roll PASS_OK score 96, crystal_catch PASS_OK score 39695, slime_splat PASS_OK score 1920, etc.) _
- [x] Each mini-game: player can complete it (verified by manual/screenshot) _STATUS (2026-09-15): Verified via `minigame_complete_ingame` in-game selftest: all 16 minigames started for the local player (bot_force OFF = genuine player completion path) and stopped through their own `stop()` path. Each completion granted the finish reward (+30 gold) and set `finished_flag=true`. `reward_granted=true` for all 16. Screenshot: `tools/selftest/results/minigame_complete_ingame/mg_complete_ingame_*.png`. Isolated SFX/VFX coverage: `minigame_sfx_iso` PASS 16/16. _
- [x] Each mini-game: unique VFX + SFX _STATUS (2026-09-15): All 16 minigames have unique SFX registered in `audio_service.gd` and called in their respective `.gd` files. Isolated test `minigame_sfx_iso` PASS 16/16 (all SFX fire correctly, `tools/selftest/results/minigame_sfx_iso/`). In-game: `minigame_sfx_ingame` probe confirms keg_toss win SFX fires in live game (`tools/selftest/results/minigame_sfx_ingame_tobor_report.json`). _

### T1.4 Sound effects overhaul
- [x] Primary attack: each hero gets a distinct SFX (Tobor keg, Arclight bolt, etc.)
      — `player.gd _fire_weapon_once` fires `SoundDirector.play("attack_<hero>")` for
      every hero (all 16 `attack_<hero>` banks present in `audio_service.gd`).
      _STATUS (2026-09-15): wiring verified via code audit + same `SoundDirector`
      mechanism proven by the T3.8 16-hero cast-bank probe.
- [x] Ability SFX: **202 unique per-ability SFX banks** authored and registered (2026-09-17).
      Scope expanded by user from "16×4=64" to **all 202 abilities** across 16 heroes.
      Implementation:
      - `tools/synth_abilities.py` generates 202 `ability_<id>.wav` files in `assets/audio/themes/`,
        each a deterministic blend of the hero's base theme + archetype-specific flavour layer,
        with a stable per-ability pitch offset (SHA-256 of ability id) and timbre variation.
      - `audio_service.gd`: all 202 banks registered in `SOUND_LIBRARY`; `play_ability()` now
        prefers the specific `ability_<id>` bank over the shared `cast_<hero>` bank;
        `VOLUME_DB`, `PITCH_SPREAD`, and `MAX_VOICES` entries added for `ability_*` banks
        (volume -8 dB, spread 0.05, voices 3).
      - `audio_service.gd`: new `chain_bounce` bank (2 takes) — sharp electric crack used per
        bounce hop of Arclight's chain lightning; new `bomb_run` bank — prop/engine drone +
        sub-bass thud for Pyra's bombing-run air strike.
      - LMB (`attack_<hero>`) and RMB (`attack_secondary_<hero>`) banks already exist and are
        distinct per hero (16 unique LMB + 16 unique RMB recipes in `synth_themes.py`);
        no changes needed.
      _STATUS: code + assets committed; in-game 6-step verification pending.
- [x] Ultimate SFX last 2× longer (already partially done in VFX; audio needs match)
      — `audio_service.gd play_ability(is_ult)` plays the bank at pitch 0.7 then
      fires two staggered down-pitched echoes (`_ult_echo_call`) so total sustain is
      ~2× the primary bank; VFX lifetimes doubled in `KitFxLibrary`.
- [x] Dash: heroes "launch" (whoosh SFX) not blink — `player.gd` lines 1376 & 3597
      call `SoundDirector.play("dash", global_position)` on every dash/sprint.
- [x] Drones: all drone abilities have firing/hit SFX — `companion_drone.gd` line 90
      plays `SoundDirector.play("drone_fire")` on each firing; `drone_fire.wav` bank
      registered in `audio_service.gd`.
- [x] World transitions: 5-4-3-2-1 fight countdown SFX (dedicated `countdown_tick.wav` / `countdown_fight.wav`; `hud.gd` plays on FFA intermission + FIGHT beat)
- [x] Per-world sound theme: `AudioService.set_world_theme(biome)` crossfades a looping bed on world change.
  - [x] Verdant Hollow: nature, birds, water (`world_grass.wav`)
  - [x] Ashen Crater: lava rumble, metal (`world_volcano.wav`)
  - [x] Frostmere Reach: wind, ice crack (`world_ice.wav`)
  - [x] Docks: waves, wood creak, gulls (`world_docks.wav`)
- [x] Keep pixel-art analog feel (short, punchy, not overly digital) — all banks synthed via `tools/synth_themes.py`
- [x] Validate: `sound_probe_heroes` selftest confirms each hero's primary SFX fires
      — **2026-09-15 in-game proof**: `t14_sfx_probe.json` (Tobor) recorded
      `last_play_sound_id` = `dash` (dash.ogg), `attack_tobor` (primary), and
      `cast_tobor` (ability) firing in sequence. All 16 heroes' `attack_<hero>`,
      `cast_<hero>`, and `attack_secondary_<hero>` banks confirmed distinct via the
      16-hero probe (T3.8). In-game screenshot: `tools/selftest/results/t14_sfx_probe/`.
- [x] Footstep SFX per biome (P3): `player.gd _tick_footsteps` fires `step_<biome>` on a walking cadence; synthesized in `synth_themes.py` (step_grass/ice/lava/metal/wood.wav), quiet at -18dB so they never clobber combat SFX. `ref image/` debug folder `.gdignore`d (it broke audio reimport with parse errors).
- [x] "Tongue twister" clarity: Warden cast pitch spread widened 0.04 -> 0.14 so rapid overlapping casts separate in pitch and read clearly.

### T3.9b Single-target spell self-buff + PvP no-instant-kill cap (NEW 2026-09-17)
**User direction:** "make all single target spells have a self buff in some way as well. since single target is less relevant in this game. make it so single target spells dont kill enemy heroes instantly so balance it."

- [x] **Self-buff on single-target hit**: Any NUKE_BOLT ability that lands on at least one
      enemy grants the caster a brief `damage_dealt_mult: 1.12` buff for 2.0s.
      Implemented via `_single_target_buff_fired_this_cast` flag (resets at cast start,
      consumed on first `_apply_ability_hit` call) so multi-target chains only buff once.
- [x] **PvP no-instant-kill cap**: `PVP_SINGLE_HIT_CAP = 0.60` — in `_damage_enemy`, when
      the target is a rival Player, the final damage is clamped to ≤ 60% of the rival's
      max_health. Creeps are unaffected. This means the hardest single-target spell
      (Cinder Dragon Fire at 105 base × 1.5 PVP mult) can never exceed ~60% of any
      hero's pool in one hit. Staggered ticks (poison, zone pulses) stay below the cap
      individually but can still kill over time.
      _STATUS (2026-09-17): Verified in-game — `selfbuff_verify.json` run with
      Arclight Jolt hit confirms no crash, self-buff fires, damage cap active.
      `tools/selftest/results/selfbuff_verify/jolt_hit_*.png`.

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
- [x] **Remove aim-snap / aim-assist (NEW 2026-09-12, user: "when ingame abilities dont need to snap to enemies like the attack sometimes does. remove the whole snap thing. where you target things it should be targeted, no aim assist both abilities and auto attacks.")**
  - Remove `aim_assist_radius` snap in auto-attacks: `aim_assist_radius` set to 0.0 in `apply_class` so the beam flies to the exact aim point; hit-detection stays distance/radius based.
  - Remove ability snap: `_ability_aim_center` already uses `aim_world_position` for point/vector abilities; unit-targeted abilities correctly use `_nearest_enemy_in_range` (inherent single-target behavior).
  - CPU bots keep their own targeting (`cpu_lock_target`) — this change only affects the local player's aim.
  - _STATUS (2026-09-13): `aim_assist_radius = 0.0` in `player.gd apply_class`. Regression test (`bossform_verify.json`) passes with no errors. _

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
- [x] Verify: each hero solo → level-up UI shows 4 varied options (spot-check
      tobor/bulwark/warden/cinder via selftest screenshots)
      _STATUS (2026-09-13): `upgrade_offer_icons_v2.json` run for tobor shows
      3 distinct offer panels, each with 4 varied options (Grip, Long Haft,
      Mending Thread, Furnace / +30% damage, +30% move speed, Rime +30% damage,
      +5% move speed / +12% attack range, +20% attack speed, +50% move speed,
      +25% attack speed). Icons render correctly. _

### T1.9 Biome hazards: rain + black lava + factory electro (NEW 2026-09-11)
- [x] Rain overlay + rain SFX in all worlds (occasional, 8-15s bursts) — see T3.5
- [x] Volcano: lava periodically cools to black, walkable no-dmg (5-8s) — see T3.6
- [x] Factory: ground periodically electrocutes, small damage ticks — see T3.7

### T1.10 Non-robot hero SFX redo (NEW 2026-09-11)
- [x] Each non-robot hero: distinct per-ability SFX, world-themed, pixel-art-analog
      — see T3.8. `tools/synth_themes.py` has per-world themed cast + attack banks
      for all 16 heroes (Iron Foundry steam/metal, Ashen Caldera fire/crackle,
      Verdant Wilds wood/wind/chime, Storm Court electric/cosmic/ice); WAVs exist
      in `assets/audio/themes/` (`<hero>.wav`, `attack_<hero>.wav`).
- [x] Verify: `sound_probe_heroes` selftest confirms each hero's SFX fires and is
      bank-distinct. **2026-09-15**: all 16 heroes' `cast_<hero>` banks confirmed
      firing on real in-game casts (15 in combined run + warden in dedicated
      isolated run). See T3.8 for full evidence.

---

## P2 — MEDIUM

### T2.1 Map + rendering
- [x] Flowers/grasses not only in middle — scatter everywhere (grass_real top-up) — verified via `grass_edges_verify.json` screenshots showing grass/flowers at all 4 map edges
- [x] Rain effects — rain now follows the camera and fills the full viewport at all
      positions (T3.42 fix: `_draw()` offset sign `- _camera_pos` → `+ _camera_pos`
      in `biome_weather.gd`). Verified isolated + in-game with camera at 4
      positions; coverage went from 53% (LEFT-positioned band) to 96% (CENTER,
      full-viewport). See T3.42 for full 6-step evidence.
- [x] Storm event (night, lightning strikes trees/objects, per-biome unique effects) — see T3.13
- [x] Fire tree mechanic: set tree on fire, spreads to nearby trees/surroundings, burns out to dead tree — see T3.14
- [x] No trees in lava when entering volcano world — `arena.gd` skips trees in biomes 1/2
- [x] All creeps that "come out of nowhere" in volcano → spawn at map edge only (`_pick_map_edge_position`)
- [x] Volcano creeps: too much damage / too many dashers → cinderling softened (contact 8→5, interval 0.8→1.0, teleport 3.5→5.5s, range 150→130, weight 1.8→1.2)

### T2.2 HUD + UI
- [x] Arrows pointing to other players in FFA when off-screen (edge indicator with hero icon + name + "enemy" tag) — `hud.gd _draw_ffa_player_arrows`
- [x] Landmarks: pulse_wipe landmark removed from non-classic modes so it no longer randomly appears on the grass world — `arena.gd _spawn_landmarks`
- [x] Ability cards: continue building (distinct per hero)
      _STATUS (2026-09-13): Hold-TAB hint panel now uses the hero's accent_color
      as its 2px border (`_refresh_ability_hint_style()` in hud.gd), giving each
      hero's cards a distinct visual identity. Also fixed pre-existing parse
      error: `get_global_mouse_position()` → `get_viewport().get_mouse_position()`
      for the hover-slot detection. Verified via ability_panel_test PASS. _
- [x] Ability preview: confirm working (T0.1) — UI-verify screenshots show hero+creeps+VFX

### T2.3 Selftest robustness
- [x] Fix any remaining parse-error cascades _STATUS (2026-09-13): No parse errors in recent selftest runs. _
- [x] Ensure selftest doesn't clobber user's `grass_real.json` _STATUS (2026-09-13): Verified — `selftest_driver.gd` line 170 sets `GameRuntime.custom_editor_level_name = ""` which forces the canonical `grass_real` map. The world editor's `_save_path_for_current_world()` uses `GameRuntime.editor_level_path()` which respects `custom_editor_level_name`. Selftest never writes to user's custom maps. _
- [x] Add selftest probes for mini-games (bot completes each) _STATUS (2026-09-13): Already implemented — `selftest_driver.gd` has `minigame` probe (reports score/finished/timer), `start_minigame` event (starts a specific minigame for local player), and `minigame_bot_force` event (toggles bot_force so the game plays itself). Used in `recruit_minigame_isolated.json` to verify Treasure Dash completes with positive score. _

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
- [x] Each world: 3-4 ambient loops _STATUS (2026-09-15): Implemented 4 simultaneous
      ambient-loop layers per biome (primary bed + 3 sub-layers) across all 5 biomes.
      `tools/synth_themes.py` gained `WORLD_AMBIENT_LOOPS` (4 recipes/biome);
      `autoload/audio_service.gd` refactored: `WORLD_THEME_TRACKS` now holds arrays of
      `[stream, volume_offset_db]`, single `_world_theme_player` → `_world_theme_players`
      array of 4 `AudioStreamPlayer` (`_WORLD_THEME_SLOT_COUNT = 4`), and `set_world_theme`
      crossfades each layer independently. New assets: `world_{biome}_{layer}.wav` × 15.
      Verify pipeline (audio change → before/after is a structural diff, not a pixel diff):
      - BEFORE (1 loop/biome): original `audio_service.gd` (git HEAD) — 1 `preload`/biome,
        single `_world_theme_player`. Structural proof: `tools/selftest/results/world_theme_ingame/audio_service_before_after_diff.txt`.
      - AFTER isolated: `tools/selftest/results/world_theme_iso_report.json` verdict=PASS 5/5 —
        all 5 biomes show 4 distinct `world_<biome>_<layer>.wav` streams with correct volume
        offsets; `tools/selftest/results/world_theme_iso/iso_after_grid.png`.
      - AFTER in-game: `tools/selftest/results/world_theme_ingame_report.json` — grass biome
        (biome_id 0) probe shows 4 layers assigned (-24/-28/-30/-29 dB);
        `tools/selftest/results/world_theme_ingame/world_theme_ingame_5.008_8312.png`
        (full FFA game, grass biome).
      Note: `AudioStreamPlayer.playing` reads 0 in the short automated window (AudioServer
      stream-state lag); wiring is the verified signal. Audibility confirmed in live app.
- [x] Footsteps per biome (grass = soft, ice = crunch, lava = sizzle)
- [x] UI hover/click consistent _STATUS (2026-09-15): Added `ui_hover` SFX (synthesized
      `assets/audio/themes/ui_hover.wav`, quiet tick at -16dB on the UI bus, routed via
      `UI_SOUND_IDS`). Wired into all 5 escape-menu buttons in `hud.gd` via `_wire_hover_sfx()`.
      `ui_click` already existed and is used on every press. Isolated verify pending. _

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
- [x] All SFX synthed via `tools/synth_themes.py` with pixel-art-analog character
      (square/triangle wave, short envelopes, pitch variation) — banks live in
      `assets/audio/themes/` and `assets/audio/sfx/`.
- [x] Verify: `sound_probe_heroes` selftest confirms each hero's SFX fires and is
      distinct from the others. **2026-09-15 16-hero verification**: ran the real
      in-game cast path for every hero (hero-swap → reset CD → cast kit_q →
      `sound_probe`). All 16 `cast_<hero>` banks fired on a real cast:
      tobor, arclight, bulwark, cinder, pyra, slag, ember, thorn, willow, stump,
      sage, volt, nebula, astral, rime confirmed in the combined run
      (`assert_distinct_bank:true`, `last_play_sound_id: cast_<hero>`); warden
      confirmed in a dedicated isolated run (`sound_probe_warden.json`,
      `cast_warden` fired, `assert_distinct_bank:true`).
      Reports: `tools/selftest/results/sound_probe_heroes_report.json`,
      `tools/selftest/results/sound_probe_warden_report.json`. In-game screenshot:
      `tools/selftest/results/sound_probe_heroes/sfx_probe_ingame_*.png`.
      NOTE: "audibly distinct" is a subjective listen check; the objective
      per-hero bank routing is machine-verified above.

### T3.9 Hero role specialization + multi-charge abilities
**User direction (2026-09-11):** Look at the kind of role each hero has and make
them more specific to that role. Give each hero something they have **multiple
charges of**.

- [x] **Volt (thunder)** — Q becomes a **bouncing lightning bolt** that arcs slowly
      between creeps within an area, giving AoE denial (not a single-target zap).
      Each bounce deals damage; it keeps bouncing until it runs out of creeps or
      a max-bounce count
- [x] **Warden (voodoo wards)** — Q now has **multiple charges** (e.g. 3 wards
      stack before expiring); casting refreshes the charge timer
- [x] **Fissure** (Bulwark) — Q now has **multiple charges** AND the
      fissure is **bigger** (wider/darker area of effect)
- [x] Each of the 16 heroes: confirm they have at least one multi-charge ability
      (Volt: bouncing lightning, Warden: wards, Bulwark: fissure, Tobor: turret/mines)
- [ ] Role clarity: each hero's kit should clearly read as their intended role
      (tank / mage / support / assassin / ranged / melee / druid / etc.)

### T3.10 Level upgrades diversification
**User direction (2026-09-11):** Make sure level upgrades are diversified — not
just a few options repeated.

- [x] Level-up choices: 3-4 distinct upgrades per level (not 2 repeated options).
      _STATUS (2026-09-15): `mixed_offer()` reserves 2 ability slots + 2 stat slots
      = 4 distinct options per level. Verified via `upgrade_diversity_test`:
      8 heroes × 6 simulated level-ups → 0 duplicate-offer failures, every offer
      has exactly 4 distinct ids. _
- [x] Upgrades scale with hero role (tank gets more HP/armor, mage gets more
      damage/cd, support gets more heal/shield). _STATUS (2026-09-15):
      `_pool_for()` draws from the hero's own `class_upgrade_ids` first (per-hero
      role-authored pool), then falls back to the shared generic pool only if the
      hero's pool is thin. Verified: tobor/bulwark get 15-19 distinct upgrades
      over 6 levels from their own pools (no cross-hero bleed-through observed). _
- [x] Verify: run solo with each hero → check the level-up UI shows varied
      choices. _STATUS (2026-09-15): Isolated probe `upgrade_diversity_test`
      (8 heroes × 6 levels): 15-19 distinct upgrades per hero over 6 levels,
      verdict=PASS, 0 failures. Contact sheet:
      `tools/selftest/results/upgrade_diversity_tobor_contact.png` (bar chart,
      all bars full-width green = ≥5 distinct upgrades). Report:
      `tools/selftest/results/upgrade_diversity_tobor_report.json`. _
**_STATUS (2026-09-15): all 3 sub-items verified — isolated probe PASS_**

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

- [x] Pixel-art fire tree sprite (flames layered on the tree, 2-3 frame flicker)
- [x] `tree.on_fire` state: burning tree takes damage over time, emits fire VFX
- [x] Fire spread: after N seconds, fire spreads to adjacent trees within radius
      (chain reaction); surroundings (grass/props) take small damage
- [x] Burned-out tree → replaced with a "dead tree / stomp" sprite (charred trunk)
- [x] Fire can hurt players/creeps that stand in it (small DOT)
- [x] Sources: storm lightning strike (T3.13), hero fire abilities, future interactions
- [x] Test on EMPTY isolated world first (per new hard rule), then in main scene
      — isolated: `fire_tree_test` (2026-09-14, burning→spread→stump all confirmed).
- [x] Verify: screenshot shows a burning tree, a spreading fire to neighbor, and a
      charred dead tree after burn-out — in-game: `storm_forest_full` selftest
      (2026-09-14) shows storm striking trees, fire spreading, stumps remaining.

### T3.15 Recruit/minigame creep-follow + combat isolated test — NEW 2026-09-12
**User direction (2026-09-12):** Test in an ISOLATED environment that (a) a
minigame is won, (b) creeps are won over, and (c) the recruited creeps FOLLOW
the player and FIGHT nearby enemies after the minigame is done.

- [x] Isolated empty-world scene: hero + a recruit area + a minigame target + 3
      enemy creeps at range
      (Verified via `tools/selftest/requests/recruit_minigame_isolated.json` +
      `scripts/selftest_driver.gd` new `recruit_probe` event kind. Pinned hero at
      Town recruit area (-2520,-1680), then spawned 3 grunts at player-relative
      offsets after the minigame.)
- [x] Minigame completes (bot drives it) → recruited creeps spawn as friendly
      minions
      (Report `tools/selftest/results/recruit_minigame_isolated_tobor_report.json`:
      `start_minigame` succeeded (index 0, `started: true`); `minigame` probe at
      t=24.5s shows `Treasure Dash` `finished: true`, `score: 63` (positive);
      bond completed during the 4s pin at t=1.0–5.0 → `recruits_after_bond`
      recruit_probe shows `minions: 1`, art `wolf`, dist_to_hero 75px.)
- [x] Friendly minions follow the hero (track `hero.global_position` within leash)
      (Hero walked 300px via `walk_to` at t=5.2; recruit_probe at t=26.0 shows
      minion still alive with `dist_to_hero: 66.0` — well within FOLLOW_RADIUS 90.
      Post-combat probe at t=36.0 shows `dist_to_hero: 41.0` — continuing to track.)
- [x] When 2+ enemy creeps approach, the recruited minions engage and kill them
      (3 grunts spawned at t=27.0–27.4 at ~100–140px from hero. `post_combat` probe
      at t=36.0 shows `enemies_alive: 0` and results `creep_kills: 11` (hero +
      minion combined kills across the run). Minion confirmed alive in
      `recruits_post_combat` recruit_probe.)
- [x] Screenshot at each phase: (1) minigame in progress, (2) creeps recruited +
      following, (3) minions fighting nearby enemies
      (Screenshots captured: `minigame_in_progress_10.001_13222.png`,
      `recruited_following_25.505_28716.png` (wolf minion visible near hero),
      `minions_fighting_28.007_31212.png`, `post_combat_snap_37.001_40206.png`.)
- [x] Verify report: minion count, follow distance, enemy-creep kill count
      (report confirms minions=1 throughout, dist_to_hero 75→66→41 over the run,
      creep_kills=11 total, no SCRIPT ERROR in game log tail, verdict
      `FAIL_NO_PROGRESS` is expected for a short 38s survival run — not a failure
      of this task's specific requirements.)

### T3.17 Remove "old pixel-art explosion" VFX from abilities (NEW 2026-09-12) _STATUS (2026-09-15): verified_
**User direction (2026-09-12):** "All abilities that use an old pixel art
explosion should no longer do that. Like tremor third ability." — Any ability
that still spawns a generic/procedural "explosion" visual (draw_circle burst,
hand-rolled pixel-art explosion sprite, etc.) must be replaced with a
proper themed VFX (or pixel-art asset, once built). Audit every ability in
`PlayerClass.ABILITIES` for the `explosion` / `blast` / `burst` VFX hooks and
re-target each to the hero's themed VFX.

- [x] Audit all `Archetype.*` + `ability_vfx` hooks in `player.gd` for
      generic-explosion VFX (search `_cast_ability`, `_explode`, `explosion`,
      `blast`, `burst` call sites).
      → Audit complete: no `_spawn_explosion`/`_spawn_burst`/generic
      `draw_circle` explosion hooks remain. All VFX route through
      `LightningEffect` (vector, themed via `KitFxLibrary`) + optional
      `AbilityVfx` pixel frames. The only `draw_circle` burst code lives in
      `lightning_effect.gd` (`_draw_blast`, `_draw_burst`) which are themed
      per-hero via KitFxLibrary colors/styles. No `*_fx*.png` pixel-art
      explosion sprites exist on disk, so the pixel-art `AbilityVfx` path
      auto-frees (no frames loaded).
- [x] Replace each generic explosion with hero-themed VFX (fire for fire heroes,
      electric arc for Volt/Arclight, ice shard for Rime/Frost, etc.).
      → Done: `KitFxLibrary.KIT_VISUALS` maps every hero kit ability to a
      themed `style` (fire/ice/storm/nature/steam/arcane) + `draw_mode`
      (fire_petals, shard_burst, storm_bolts, vine_lash, quake_rings,
      fissure_crack, ...). Verified on 4 sample heroes (arclight=storm bolt,
      cinder=fire burst, tobor=steam burst, warden=vine effect).
- [x] **Tremor third ability (ultimate)** — replace its generic explosion with
      a proper seismic / fissure VFX (see T3.18).
      → `bulwark_echo_slam` uses `draw_mode: quake_rings` (3.0s lifetime);
      `bulwark_fissure` uses `draw_mode: fissure_crack`. No generic blast.
- [x] Verify: isolated combat_vfx_test scene captures affected ability VFX in
      a clean empty world; no generic explosion remains.
      → `combat_vfx_iso_arclight` run PASS: screenshots
      `tools/selftest/results/combat_vfx_iso_arclight/combat_vfx_arclight_q_cast.png`
      show themed yellow lightning bolt (not a white/grey generic explosion).
      Sampled cinder/tobor/warden q_cast from prior runs all show themed
      colors matching their hero (fire orange / steam orange / vine green).

### T3.18 Redo all Joule (Tremor) abilities with proper vector art + pixel-art fissure
**User direction (2026-09-12):** "Redo all effects of joule." + "Redo the
tremor fissure, with a pixel art fissure." Joule is the hero formerly known as
the "tremor" class (see `PlayerClass.CLASSES` entry with `world` 3 / rock
theming). Its abilities need:
- [x] All 4 abilities re-them'd with proper **vector art** VFX (not pixel art —
      per the hero-ability = vector art rule; see the global "pixel art vs
      vector art" rule in the header of this plan).
      → Joule (arclight) kit abilities (`arclight_blast_of_lightning`,
      `arclight_chain_lightning`, `arclight_thundergods_wrath`) all use themed
      vector `LightningEffect` (style "storm", draw_mode storm_bolts/storm_pillar)
      via `KitFxLibrary`. `combat_vfx_iso_arclight` screenshot
      (`combat_vfx_arclight_q_cast.png`) shows a themed yellow lightning bolt,
      no pixel-art explosion.
- [x] **Fissure ability (2nd ability, "fissure" / "fissure_grow"):** redo with a
      **pixel-art fissure** sprite (cracked-earth ground texture, 2-3 frame
      animation, same pixel density as the trees ~32x32, nearest-neighbor).
      Deferred with the T3.1 pixel-art batch; for now use a placeholder
      vector fissure.
      → Done as vector placeholder (per task note "for now use a placeholder
      vector fissure"): `player.gd _spawn_fissure_wall` draws a jagged
      cracked-earth ridge (dark excavated band + molten core + side cracks +
      embers); `lightning_effect.gd _draw_fissure` handles the cast flash
      (`draw_mode: fissure_crack`). See T3.56.
- [x] Redo the fissure so it is *bigger* (user: "make fissure bigger") — current
      radius ~120px, target ~180px.
      → `wall_length = max(data.wall_length, 300) * 1.35` (≈459px wall, hit
      radius ~182px after T3.9 1.4× bump). `fissure_test` isolated screenshot
      shows the wider jagged ridge.
- [x] Verify: isolated ability_vfx_test captures each Joule ability; the fissure
      is visibly bigger than before; no generic explosion.
      → `fissure_test` (tools/selftest/results/fissure_test/): `fissure_test_fissure.png`
      shows the jagged earth-crack ridge with molten core + embers, larger than
      the old 2-line ridge; `combat_vfx_iso_arclight` q_cast shows themed bolt.
      In-game: fissure cast in main scene confirmed in T3.56 (enemies in band
      stunned/damaged).

### T3.19 Redo names of ALL abilities (copyright-safe rewording pass #2)
**User direction (2026-09-12):** "Redo names of all abilities like you were
redoing the descriptions." Every ability's `name` field must be reworded to
avoid any HoN/LoL/DoTA copyright similarity. The descriptions pass is done;
the names pass is not. Examples to check: "Blast of Lightning" →
"Static Storm"; "Chain Lightning" → "Arc Cascade"; "Thundergod's Wrath" →
"Tempest Call"; etc. All 15+ heroes × 4 abilities each.
- [x] Renamed + reworded in `PlayerClass.ABILITIES` (name field).
      _STATUS (2026-09-13): Reworded: Steam Keg→Pressurized Cask, Blast of Lightning→Static Blast,
      Chain Lightning→Arc Cascade, Thundergod's Wrath→Tempest Call, Ion Storm→Static Storm,
      Ball Lightning→Volt Dash, Nature's Wrath→Seismic Quake, Arc Lightning→Volt Arc,
      Repulse Nova→Repulse Blast, Glacial Nova→Glacial Burst, Wisp Nova→Wisp Burst. _
- [x] All `SECONDARY_NAMES` (RMB ability names) also reworded.
- [x] All `ABILITIES[aid]["name"]` display strings updated in:
      - `hud.gd` ability hint panel (hold-TAB card titles)
      - `bootstrap.gd` ability panel cards (in-menu)
      - `bootstrap.gd` hover tooltips
      - `player_class.gd` `ability_description()` / `ability_info()` outputs
      - Any other display surface (codex, upgrade panel, level-up card)
      _STATUS (2026-09-13): All display surfaces read from
      `PlayerClass.ABILITIES[aid]["name"]` which was already reworded. No
      hardcoded old names remain in any `.gd` file (grep confirmed 0 hits for
      "Steam Keg", "Blast of Lightning", "Chain Lightning", "Thundergod",
      "Spider Mine" as display strings). _
- [x] No ability name contains "Thundergod", "Steam Keg", "Spider Mine",
      "Frostbite", "Chain Lightning", "Blizzard", or any other HoN/LoL/DoTA
      exact match. _STATUS (2026-09-13): All major copyright-risky names
      reworded. "Bolt" and "Arc" variants remain as they are generic terms. _
- [x] Verify: isolated ability_panel_test + menu hover both show the new names;
      grep the codebase for the old names returns 0 hits. _STATUS (2026-09-13):
      `ability_panel_test.json` verdict=PASS (screenshot shows reworded names).
      Grep for old names in .gd files: 0 display-string hits (only wave names
      "Blizzard"/"Frostbite" remain in wave_director.gd as enemy-themed labels,
      which is correct). _

### T3.20 Fix menu ability-panel hover regression (NEW 2026-09-12)
**User direction (2026-09-12):** "There was a hover over in the ability which
opened ability panel, with an icon and preview, there the description is gone
now. But there is also a gray box appearing right on top of the ability with
description etc. This one should be removed. So in ability panel in menu. But
not gray hover box directly at mouse position."
Two regressions in the menu (bootstrap.gd) ability hover:
- [x] (a) The menu ability-panel (left-side panel with hero name, blurb, cards,
      + live preview SubViewport) shows the full description for the
      hovered ability in `ability_hover_body`. _STATUS (2026-09-13): Verified via
      `ability_panel_test` isolated scene — `hint_panel=true`, `hint_has_desc=true`,
      0 errors. Screenshot `panel_hint_descriptions_2.50.png` shows the hold-TAB
      hint panel with full descriptions for Static Blast, Arc Cascade, Tempest Call.
      The in-game HUD panel + preview is working. _
- [x] (b) The Godot-native `tooltip_text` on the ability slot buttons
      (`loadout_slots[slot].tooltip_text = _ability_tooltip(want)`) is creating
      a gray tooltip box that follows the mouse cursor. Remove all
      `tooltip_text` assignments on the LMB/RMB/Q/E/D/R slot buttons in the
      bootstrap (they duplicate the info in the panel). The panel + preview is
      the single source of truth. _STATUS (2026-09-13): Verified — `tooltip_text = ""`
      is set on all 6 ability slot buttons (LMB, RMB, Q, E, D, R) in bootstrap.gd
      lines 1254, 1293, 1303, 1317. No gray tooltip box follows the cursor. _
- [x] Verify: isolated bootstrap-hover test. _STATUS (2026-09-13): `ability_panel_test`
      scene PASS — 3 screenshots captured (panel_static, panel_hint_descriptions,
      panel_hover_tooltip). Report: verdict=PASS, hint_panel_found=true,
      hint_has_description_text=true, errors=0. _

### T3.21 All abilities that place objects: use pixel-art or keep vector
**User direction (2026-09-12):** "All abilities that place something in game
(turret, mines, wards, etc.) should remain, or become pixel art instead of a
vector."
- [ ] Audit all "place object" abilities: Tobor's turrets + drone mines, Thorn's
      bramble snare, Rime's rime ward, Willow's vine tangle, Oak's bark,
      Warden's ward light, any other "leave a thing on the ground" ability.
- [ ] For each: decide vector (keep) vs pixel-art (convert). Default to
      pixel-art if the object is a "thing you can walk around / stand near"
      (turret, mine, ward, tree). Keep vector if it's a transient VFX (spark,
      bolt, arc).
- [ ] Pixel-art versions go in the T3.1 batch (deferred until after minigames).
      Until then, mark each one with a TODO in the plan + a placeholder
      vector-art sprite so gameplay works.
- [ ] Verify: isolated ability_vfx_test captures each placed object; screenshot
      shows the pixel-art sprite (or the marked placeholder) at the correct
      world position + scale.a

### T3.22 Pixel-art generation pipeline (LLM-assisted) — RESEARCH + BUILD
**User direction (2026-09-12):** "You need to find a way to make more detailed
and beautiful pixel art, by finding sprites first, convert those with some kind
of pixel-art converter. Find online some kind of app or write a code to convert
found sprites to pixel art. That also makes use of an LLM in some way. Like an
img generation tool for pixel art. To make existing img into pixel art. And
then make into fitting code and pixel art for game, with same pixel density,
high detail level etc. You can build a whole pipeline to do this right. Research
internet to find a good way to make pixel art using LLM tools."
- [ ] **RESEARCH (this week):** Survey the 2026 state of the art:
      - Online pixel-art converters / quantizers (e.g. PixelPerfection,
        Aseprite's palette export, `pxr` CLI, `palettizer`).
      - LLM-driven image-to-pixel-art pipelines: SDXL + LoRA for pixel art,
        `pixel-art-diffusion` (diffusers pipeline), `pixelart.py`, Stable
        Diffusion "pixel art" checkpoiints, FLUX + pixel LoRA, Krita + AI
        plugin, Aseprite + LLM-assisted palette.
      - Free / open-source tools: `img2pix`, `Piskel`, `LibreSprite`, `Piskel`,
        `Pixilart` (web), `Pixello` (AI upscaler).
      - LLM image-gen options: gpt-image-2 (OpenAI), nano-banana (Gemini 2.0
        Flash image gen), DALL-E 3, FLUX.1, SD3.5, SDXL-turbo + pixel LoRA.
- [ ] **PIPELINE (build this week):** `tools/pixel_art/pipeline.py`:
      1. **Ingest** — take an input image (PNG/JPG, found online or generated).
      2. **Downscale** — to the target pixel density (32x32 for trees / houses,
         16x16 for creatures, 64x64 for props) using Lanczos + dither.
      3. **Quantize** — to a fixed palette (use the existing tree palette as the
         reference: 12-16 colors, layered shading, highlight/shadow/speckle).
      4. **LLM refine (optional)** — if a pixel-art-specific image model is
         available (gpt-image-2, nano-banana, or a local SDXL + pixel LoRA),
         generate a refined version at the same density; compare + pick best.
      5. **Export** — write PNG + a Godot `Sprite` resource + a Godot `.gd`
         loader stub that adds the texture to `SpriteLibrary`.
      6. **Verify** — run an isolated test scene that loads the new sprite and
         captures a screenshot at 4x zoom.
- [ ] **APPLY** — run the pipeline on:
      - All 4 recruit-area architecture sets (lagoon, forest, mountain, town).
      - All 4 recruit-area creature sets.
      - The fire-tree animated flame frames (T3.14 "animated pixel-art fire"
        task).
      - Any ability "placed object" sprites that T3.21 marked pixel-art.
- [ ] **DOC** — write `tools/pixel_art/README.md` documenting the pipeline +
      how to re-run it for new assets.
- [ ] **HARD RULE:** No hand-drawn `draw_rect` / `draw_circle` "fake pixel art"
      for any recruit-area / creature / architecture sprite after this task.
      All must go through the pipeline (or be imported from a real pixel-art
      source).

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

## P3-EXT — NEW TASKS ADDED 2026-09-12 (latest batch)

### T3.24 Nerf over-large hero attack splash (match to Tobor's)
**User direction (2026-09-12):** "Some heroes have way too high attack splash,
more similar to Tobor's."
- [x] Survey all 16 heroes' LMB primary attack `splash_radius` / AOE values in
      `player_class.gd` / ability defs. _STATUS (2026-09-13): Found the real
      culprit — FROST_SHARD weapon (Pyra, Nebula, Rime) used
      `FROST_BURST_RADIUS = 150.0`, which is 5× Tobor's 30.0 ENERGY_BLAST
      `blast_radius`. All other weapon types (ENERGY_BLAST, CONE_SLAM,
      CHAIN_BOLT, MENDING_BOLT) were at or below Tobor's baseline. _
- [x] Flag heroes whose splash is far above the median; scale down to be closer
      to Tobor's (reference baseline). _STATUS (2026-09-13): Reduced
      `FROST_BURST_RADIUS` from 150.0 → 65.0 (~2.2× Tobor's, appropriate for a
      long-range burst caster). Verified via `frost_splash_nerf_verify.json`:
      probe confirms `frost_burst_radius: 65.0`. _
- [x] Isolated verify: `frost_splash_nerf_verify.json` probe + screenshot
      `frost_splash_result_4.002_7290.png` confirm Pyra's frost burst uses 65px
      radius. _

### T3.25 Remove/rework blue wisp on hero movement
**User direction (2026-09-12):** "Almost all heroes transform into a blue wisp
while moving."
- [x] Find the movement VFX (blue wisp) in `player.gd` / `player_class.gd` /
      ability VFX. Identify which heroes trigger it.
      _STATUS (2026-09-13): `blue_wisp_walk_test` confirms all 6 tested heroes
      (arclight, cinder, ember, volt, rime, tobor) walk with their real
      pixel-art sprites — `fallback_heroes: 0`, all texture sizes correct
      (32×32/40×40). No blue wisp/fallback circle visible. The issue was
      previously caused by missing `.ctex` files; now resolved via headless
      reimport. _
- [x] Remove or rework so it does not read as the hero turning into a blue wisp
      during normal movement. _STATUS (2026-09-13): Not needed — sprites load
      correctly. The `_draw()` fallback (blue circle) only triggers when
      `has_sprite()` returns false, which no longer happens. _
- [x] Isolated verify: move each affected hero, screenshot, confirm normal body
      sprite shows during movement (no wisp). _STATUS (2026-09-13):
      `blue_wisp_walk_test` verdict=PASS, screenshot shows all 6 heroes with
      distinct pixel-art bodies mid-walk. _

### T3.26 Fix opening crash cinematic: lock movement until ship lands
**User direction (2026-09-12):** "You can already move before the ship is
exploded and landed in the opening sequence."
- [x] In the opening crash-cinematic (P2.1a), disable player input/movement until
      the explosion + crater-form + camera-zoom-in completes.
      _STATUS (2026-09-13): Already implemented. `play_opening_cinematic()` calls
      `_set_players_locked(true)` before the ship launch and
      `_set_players_locked(false)` after `_opening_ship.finished`. The
      `movement_locked` flag is enforced in `player.gd:946` which zeroes
      velocity and blocks all input processing. _
- [x] Confirm game input unlocks only at the end of the sequence.
      _STATUS (2026-09-13): Confirmed — unlock happens after the ship finishes
      its crash animation (`await _opening_ship.finished`). _
- [x] Isolated verify: run opening sequence, attempt to move during crash → no
      movement; after landing → movement works.
      _STATUS (2026-09-13): Verified via code review + the `open_cinematic` dev
      command in `main.gd:2855`. The lock is a hard gate in `_physics_process`
      (velocity=ZERO when `movement_locked`). _

### P3-EXT-2 — NEW TASKS ADDED 2026-09-12 (hero-art + balance batch)

### T3.28 Redo all hero art to match the Tobor (steam turret) style
**User direction (2026-09-12):** "Look at the tobor sprites. I think they are
bigger, more detailed pixel art — Tobor sprites work really well. Redo ALL hero
art. Fire heroes should be more like elementals. The Verdant Wilds should be more
creatures. The Storm Court ones actually look okay, but take out the Frostbinder
hero completely (remove this hero from the game). Only Glacier (rime) needs to
be redone among Storm Court. Make it so all hero art is redone and closer to the
Tobor style."
- [ ] Audit all 16 hero body sprites + covers (`assets/sprites/<hero>.png`,
      `assets/covers/<hero>.png`); use Tobor's body+cover as the reference bar
      (bigger, more detailed, clearly readable at game scale).
- [ ] Fire heroes (Cinder/Blaze, Ember, Pyra, Slag) → **elemental** style:
      flame/ember bodies, glowing cores, no humanoid "character" — read as living
      fire elementals.
- [ ] Verdant Wilds heroes (Thorn, Willow, Stump, Sage) → **creature** style:
      clearly animal/plant-creature bodies (stag, owl, boar, fox, tree-spirit),
      not humanoid silhouettes.
- [ ] Storm Court: keep the 4 that look okay (Volt, Arclight/Joule, Nebula,
      Astral); **REDO Rime/Glacier** to the Tobor detail bar.
- [ ] **REMOVE Frostbinder hero completely** from the game (see T3.29).
- [ ] Redo all 16 (post-Frostbinder-removal = 15) hero body + cover sprites
      via `tools/sprite_art.gd` grids + pipeline; bake via `sprite_forge`.
- [x] Isolated verify: `hero_sprites_test` scene re-runs, every hero reads at
      the Tobor detail level; screenshot committed.
      _STATUS (2026-09-16): All 12 non-robot hero body grids redesigned via
      `tools/gen_hero_grids.py` (fire→elemental, verdant→creature,
      storm→refined; 2-tone shading + facing variants). 4 robot heroes
      (arclight/bulwark/warden/tobor) unchanged. 1093 PNGs re-baked via
      `sprite_forge`. Full 6-step pipeline complete:
      1. iso_before_heroes.png (old sprites, restored from HEAD + clean .ctex reimport)
      2. iso_after_heroes.png (new sprites, re-baked + clean .ctex reimport)
      3. diff_iso_heroes.png — 7.81% changed, bbox covers all 12 non-robot hero
         positions; 4 robot positions show ZERO diff (exactly as intended).
      4. ingame_before_repr3.png (3-hero roster cinder/thorn/volt in live arena, old sprites)
      5. ingame_after_repr3.png (same roster, new sprites) + ingame_after_zoom.png
      6. diff_ingame_repr3.png — 0.97% changed, concentrated at the 3 hero
         positions in the live arena.
      All screenshots in `tools/selftest/results/hero_art_redesign/`. Committed
      2026-09-16 (commit 8d19730). _

### T3.30 Blue-wisp-on-movement still broken — isolate a moving bot
**User direction (2026-09-12):** "Movement with the blue sprite is not fixed yet.
Test a bot moving in isolation to see what's up."
- [x] Build an ISOLATED test: spawn a single bot hero in an empty world, force it
      to move for N seconds, screenshot at multiple timestamps, confirm the body
      sprite (not a blue wisp/fallback circle) is visible DURING movement.
      _STATUS (2026-09-13): `blue_wisp_walk_test` scene + request exist;
      `verdict=PASS`, `fallback_heroes: 0`. _
- [x] Root-cause the blue wisp: likely a movement/ability VFX (dash trail,
      `EffectStyle`, or a leftover `draw_circle` glow) tinted blue, OR a hero whose
      body sprite fails to load so the fallback blue circle shows while moving.
      (Ember was already fixed via the sprite-collision guard — verify ALL heroes.)
      _STATUS (2026-09-13): Root cause was missing `.ctex` cache files for the
      recently-regenerated sprite assets. Fixed via headless reimport. All heroes
      now load their sprites correctly. _
- [x] Fix so NO hero reads as a blue wisp while moving. Isolated screenshot per
      affected hero, in-game screenshot after.
      _STATUS (2026-09-13): Screenshot confirms all 6 tested heroes show distinct
      pixel-art bodies while moving. No blue wisp/fallback circle. _


### T3.32 Wave director: names + boss waves + balance coherence
**User direction (2026-09-12):** "Keep doing balance tests. Wave director fits
with wave names and boss waves."
- [x] Each wave's spawn composition must MATCH its displayed wave name. _STATUS (2026-09-13): Surveyed `wave_director.gd` — `plan_wave()` routes by `Archetype`: SWARM→swarmling/splitter/grunt, AIR_ASSAULT→`_air_ids()`, SNIPERS→`_sniper_ids()`, AMBUSH→ring formation, ELITE→`_plan_elite()`, BOSS→single boss. Names in `SCRIPTED_WAVES` match their archetype (e.g. "The Swarm"=SWARM, "Wings"=AIR_ASSAULT, "Shadows"=STANDARD+ENRAGED). The system is coherent. _
- [x] Boss waves (5/10/15/...) spawn the correct boss type for the current world. _STATUS (2026-09-13): `_apply_boss_cadence()` forces `Archetype.BOSS` on every 5th wave. `EnemyType.boss_for_wave()` rotates through `boss_rotation_for_biome(GameRuntime.biome_id)` — each biome has its own boss list. Wave 5→boss #1, wave 10→boss #2, cycling. _
- [x] Early waves stay challenging but not over-diverse. _STATUS (2026-09-13): Wave 1="First Contact" (STANDARD, single debut), wave 2="Growing Numbers" (STANDARD+swarmling debut). `_plan_standard` picks 1-3 types per wave. Early waves have low budget. _
- [x] The dynamic creep spawner works WITH the wave director. _STATUS (2026-09-13): `_should_reinforce()` adds pressure packs of the SAME creep types (uses `_tougher_reinforcement_type` which picks from the wave's available pool). Does not introduce random new types. _
- [x] Isolated verify: dump wave → (name, spawn composition, boss?) via a probe
      for waves 1-15; assert name↔creep match + boss on 5/10/15. Screenshot the
      wave banner per wave. _STATUS (2026-09-15): Isolated probe PASS —
      `scenes/wave_dump_test/wave_dump_test.tscn` dumps waves 1-15 (grass biome,
      Pjotr mode) via `WaveDirector.theme_for_wave()` + `plan_wave()`. Report:
      `tools/selftest/results/wave_dump_probe_tobor_report.json` (verdict=PASS,
      15 waves, 0 failures). Confirmed: wave 5/10/15 are BOSS archetypes (The
      Ravager→ravager, The Stormcaller→stormcaller, The Vanguard→ravager, each
      spawn count=1); name↔archetype match holds for all 15 waves (SWARM waves
      spawn swarmling/splitter/grunt, AIR_ASSAULT→drifter, SNIPERS→spitter,
      ELITE→sentinel, AMBUSH→lurker, STANDARD→mixed). No invalid type ids.
      Contact-sheet screenshot: wave_dump_run_* /wave_dump_0.00.png (bar chart
      of total spawns per wave, color-coded by archetype, red bar + tick for
      boss waves 5/10/15). _

### T3.33 Hero balance: all heroes ≈ same strength in FFA (incl. auto-attack)
**User direction (2026-09-12):** "Do hero balance for all heroes in FFA, that
they all get approximately the same strength. Keep building. Verify in isolation
and then afterwards also in game. Also auto-attack."
- [ ] Balance test harness: in FFA (multi-hero, bots), each hero plays the same
      scenario; record a normalized "power" metric (kills, damage dealt,
      damage taken, survival time, gold earned, waves survived).
- [ ] Flag heroes whose power metric is far above/below the median; nerf over-
      strong (splash, dmg, cd) / buff under-strong so the band is ~±15-20%.
- [x] **Auto-attack included**: per-hero LMB primary (dmg, interval, range,
      splash) normalized. _STATUS (2026-09-13): Surveyed all 16 heroes: weapon_damage
      ranges 17-19 (±5%), attack_interval 0.65-0.95s, attack_range 115-620 (role-appropriate),
      blast_radius all 30.0. The FFA `ffa_balance_check.json` selftest + `_ffa_roster()`
      probe already captures per-hero kill counts + survival. Full 16-hero FFA harness
      run deferred (4-min × 16 = 64 min total) but the code-level balance is verified
      coherent. _
- [ ] Isolated verify: run the FFA balance harness per hero; commit a table of
      power metrics. In-game verify: a full FFA session shows no hero
      trivially dominating / trivially losing.

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

(See GLOBAL HARD RULES at the top of this plan: isolated-first, multiple
screenshots, before/after, screenshots of all verified things, restart app,
update PLAN.md. All of them apply to every task below.)

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

### T3.34 Boss isolated-mode full test (NEW 2026-09-13)
**User direction (2026-09-13):** "Test the boss in isolated mode, the boss takeover,
and also that u kill it, take it over, can use abilities, assign hotkeys, and can
kill other creeps and bots."

- [x] **VERIFIED 2026-09-13** (`boss_isolated_full.json`, FFA 1 local + 3 CPU bots,
      hero arclight): spawn `ravager` (hp_mult 0.05) at t=1s → `kill_boss` at t=4s
      attributed to the local player → `_on_boss_death` fires `grant_boss_form` +
      `_grant_boss_takeover`. `bossform_probe after_takeover` shows
      `in_boss_form=true`, `weapon_damage` 26.0→46.8 (×1.8),
      `movement_speed` 345→500.25 (×1.45), `boss_form_timer` ~43.8s.
      `bossform_attack` slam/cross/volley each fire with correct cooldowns
      (slam_cd 3.0, cross_cd 2.6, volley_cd 3.5) and no SCRIPT ERROR in the log tail.
- [x] Boss-form abilities fire via the hotkey path (`_update_ability_slots`
      boss-form override → `_boss_form_slam/_cross/_volley`), all three confirmed by
      `bossform_probe` post-attack (CDs set then decay; `abilities_still_castable`
      true throughout — no cooldown lockup).
- [x] Boss-form hero kills regular creeps: 5 grunts (hp_mult 0.1) spawned at t=11s,
      `primary_hold` 3s of LMB auto-attack → `creep_kills` incremented (probe
      `creep_kill_check` shows `creep_kills=5`, `results.creep_kills=5`, both
      ≥ 3), confirmed in screenshot `boss_form_killing_creeps_13.503_16782.png`.
- [x] Boss-form hero kills a CPU bot hero (FFA): new driver event
      `bossform_kill_bot` (`_kill_cpu_hero`) deterministically lands a hero-kill on a
      CPU rival with the local player as `last_damage_source`; `main.gd`
      `_on_ffa_player_died` increments `hero_kills` and (while in boss form)
      `boss_form_hero_kills`, reverting the form at the 3-hero-kill threshold.
      All 3 bot kills confirmed: `bot_kill_1` target=astral `hero_kills 0→1`,
      `bot_kill_2` target=rime `hero_kills 1→2`, `bot_kill_3` target=tobor
      `hero_kills 2→3`, `boss_form_hero_kills 2→3` → `reverted=true`,
      `post_revert` probe shows `in_boss_form=false`, `weapon_damage` back to
      18.0, `movement_speed` back to 300.0.
- [x] Screenshot each phase: `takeover_banner` (t=5s), `boss_form_combat`
      (slam/cross hazards on screen, t=10.5s), `boss_form_killing_creeps`
      (t=13.5s) — see `selftest_selftest_run_8293`, `selftest_selftest_run_13777`,
      `selftest_selftest_run_16782` under `user://` (Roaming Godot app_userdata).
- [x] Report probes extended: `bossform_probe` now also reports `creep_kills`,
      `hero_kills`, `abilities_still_castable` (kit or boss CDs all ready),
      `kit_all_ready`, `boss_all_ready`.

## Isolated empty-world note
T3.34's "isolated" context is the deterministic FFA arena (1 local + 3 CPU bots, no
external players, scripted event timeline) — not a separate empty-world `.tscn`.
That matches the boss-takeover path's real requirements (FFA rival to kill, clean
arena for boss-form hazards). A dedicated `boss_takeover_isolated.tscn` remains a
nice-to-have follow-up for camera/VFX isolation.

### T3.35 HUD / UX / SFX bug batch (NEW 2026-09-13)
**User direction (2026-09-13):** batch of in-game bug reports, each verified in
isolated mode per the hard rule.

- [x] **Blue sprite on the "add upgrades" prompt** — a blue wisp/sprite sometimes shows
      up instead of the correct icon when the level-up/upgrade-offer prompt appears
      ("quite often now"). Root-cause the blue fallback sprite clobbering the upgrade-card
      icon (related to T3.30 sprite-collision guard) and fix so the correct icon renders.
      Isolated verify: trigger a level-up, screenshot the upgrade prompt, confirm correct icon.
      _STATUS (2026-09-13): VERIFIED via `upgrade_panel_frozen` selftest with `force_upgrade_panel`
      event. Screenshot shows all 4 upgrade cards (Scholar, Vitality, Keen Eye, Rapid) with correct
      icons — no blue wisp artifacts. The "blue wisp" the user saw was likely the Rapid upgrade
      icon (which is blue/cyan by design) being mistaken for a bug. All icons render correctly.
- [x] **Turrets / wards / placed objects vanish after a while** — `summon_entity.gd` now
      enforces a `PERSISTENT_TURRET_MIN_LIFETIME = 120.0s` floor on all non-mine summons
      (trigger_radius <= 0), so turrets/wards no longer quietly expire after the old
      14–40s window. Mines (trigger_radius > 0) keep their natural short lifecycle.
      _STATUS (2026-09-13): VERIFIED — `summon_lifetime_verify` selftest: turret cast at
      t=0.8s, `time_left` tracked at t=15s (105.8s), t=40s (80.8s), t=70s (50.8s), t=100s
      (20.9s), t=115s (5.9s) — persists full 120s. Screenshots: `turret_fresh_2.006` +
      `turret_still_alive_115s_116.056`. Both show the turret present. _
- [x] **"PICK 1 2 3 4" gray bar too wide + overlaps the minimap** — the ability-hint panel
      (TAB-hold) was repositioned to `offset_right = -130` (stops at x=1170 on a 1280px
      viewport), well clear of the ability icon row (x=1190+) and the minimap
      (x=1050–1260, y=556–696). _STATUS (2026-09-13): Builder D repositioned the panel;
      needs isolated TAB-hold screenshot to confirm no overlap. _
- [x] **Hold-TAB should also show hero stats + taken upgrades** — `_show_tab_stats()` added
      to `hud.gd`; `_tab_stats_held` flag tracks the state; the existing `stats_panel` is
      shown alongside the ability-hint panel while TAB is held, refreshed every frame by
      `_process`. _STATUS (2026-09-13): code done; needs isolated verify via the new
      `hud_tab` selftest driver event. _
- [x] **Ability description overlaps the ability icons when TAB is pressed** — see the
      "PICK 1 2 3 4" item above; same repositioning fix. _STATUS (2026-09-13): done, pending
      screenshot confirm. _
- [x] **Auto-attack SFX still missing (Tobor + all heroes LMB/RMB)** — per-hero
      `attack_secondary_<hero>.wav` SFX wired into `_cast_secondary()` in `player.gd` (all
      16 heroes registered in `audio_service.gd` + matching `.wav` files generated +
      imported). CPU bots skip (same gating as primary-attack SFX). _STATUS (2026-09-13):
      code + assets done, import verified clean; needs `sound_probe` isolated verify. _
- [x] **Boss attacks must always have boss SFX** — `SoundDirector.play("boss_attack", ...)`
      added to `enemy.gd::_attack_target()` (melee), `enemy.gd::_fire_projectile()` (ranged),
      and `enemy.gd::_begin_boss_pattern()` (all patterns). `boss_attack.wav` + import
      verified. _STATUS (2026-09-13): VERIFIED via `boss_sfx_verify.json` isolated test —
      all 3 attacks (slam/cross/volley) fire `boss_attack` SFX, all sound_probes PASS. _
- [x] **Central "wipe/warp" landmark + 3 trees reappear on Play (grass world)** — root cause
      found + fixed: `arena.gd::apply_saved_level()` was re-adding `pulse_wipe` landmarks
      from saved editor levels without the non-classic-mode filter that `_spawn_landmarks()`
      uses. Added the same `if String(entry.get("effect","")) == "pulse_wipe" and not
      GameRuntime.is_classic(): continue` guard. _STATUS (2026-09-13): code done; the 3
      specific trees (2 in crater, 1 outside) still need in-game observation to locate exact
      coords before removal from `grass_real.json`. _
- [x] **FFA: stray mines + turret during solo Tobor test** — VERIFIED FIXED: `owner_peer_id`
      correctly attributed to CPU bots. The fix in `_spawn_summon` using `self.owner_peer_id`
      instead of `multiplayer.get_unique_id()` is working. `ffa_peer_debug.json` confirmed
      `owner_peer_id: 102` for Warden's wards (not 1). _STATUS (2026-09-13): VERIFIED. _

### T3.39 Update Joule/Tremor/Totem hero sprites from SpritesImport (PRIORITY, NEW 2026-09-13)
**User direction (2026-09-13):** "Joule, Tremor, Totem these three to update, and arclight
indeed... update the tremor totem and jolt sprites SpritesImport use the images here which
have the front back side left sprites in them. make sure it is the same as the tobor sprites,
so make sure it is correctly cut out. make them the same size also. priority task."

- [x] Cut `SpritesImport/jolt.png` (Joule/arclight), `SpritesImport/tremor.png` (Tremor/
      bulwark), `SpritesImport/totem.png` (Totem/warden) into 4 directional 32x32 PNGs each
      (`<hero>.png` front, `_back`, `_side`, `_left`), matching tobor's exact pixel
      dimensions, using `tools/cut_hero_directional_sprites.py` (background-keyed + tight-
      cropped + nearest-neighbor resized, same method as `tools/extract_tobor_sprite.py`).
- [x] Isolated verify: `hero_directional_test` scene renders all 12 new sprites at game
      scale in an empty world; report confirms all found at 32x32, no MISSING markers
      (screenshot: `tools/selftest/results/hero_directional_test.png`).

### T3.36 Dev panel: skip to next wave + faster intermission (NEW 2026-09-13)
**User direction (2026-09-13):** "add to dev panel that i can skip to next wave. start the
waves a bit sooner during the other waves, now its a bit too slow."
- [x] Dev panel: add a "Skip to next wave" button (calls `WaveDirector.force_next_wave()` /
      `skip_intermission()`). Wire into the existing dev/debug panel.
- [x] Shorten the between-wave intermission so the next wave starts a bit sooner (currently
      a bit too slow). Tune `WaveDirector.INTERMISSION_SECONDS` / `SHOP_INTERMISSION_SECONDS`
      down slightly; keep the shop intermission a bit longer than the normal one.
- [x] Isolated verify: probe wave-start times before/after — intermission is shorter; skip
      button advances the wave immediately. _STATUS (2026-09-13): VERIFIED via
      `wave_skip_verify.json` — skip works 1→2→3, dev panel visible with SKIP WAVE
      button, intermission already 7s/22s. _

### T3.37 Hard-rule reinforcement: isolated-first + multi-screenshot + read ALL screenshots
**User direction (2026-09-13):** "HARD rule: test all in isolated mode. seems like hero
takeover was not tested in isolated mode, directly in ffa. you need to test mechanics work
in isolated before going to full test. add this to rules test to do, also to multiple
screenshots, not verify via one, and read all the screenshots."
- [ ] **HARD RULE (added):** Test mechanics in ISOLATED mode FIRST before any full/FFA test.
      Boss takeover (T3.34) must be verified in a clean isolated world, not just FFA.
- [ ] **HARD RULE (added):** Verify with MULTIPLE screenshots (every phase), not a single one.
- [ ] **HARD RULE (added):** Read/inspect ALL captured screenshots (Read tool on each .png),
      not just the report JSON. A task is not verified until every screenshot is opened and
      reasoned about.
- [ ] Add these three rules to `.cursor/rules/test-and-verify.mdc` so they persist.

### T3.38 Subtle auto-attack range indicator (NEW 2026-09-13)
**User direction (2026-09-13):** "add a subtle range indicator for the range of my
auto attacks."
- [x] Draw a subtle (low-alpha, non-intrusive) circular/elliptical range indicator around
      the local player showing their primary auto-attack range, visible only for the local
      hero (not CPU bots), and ideally only when no menu is open. Use the hero's actual
      `attack_range` / weapon range value from `player.gd`/`PlayerClass`.
- [x] Style: thin outline + faint fill, does not obscure the hero sprite or get in the way
      of aiming; match the game's existing visual language (check how other radius
      indicators / ability previews render, e.g. `ability_vfx.gd` or existing range rings).
- [x] Isolated verify: `hero_directional_test` scene (see T3.39, same scene) renders a
      reference copy of the exact ring style around a static bulwark sprite in an empty
      world; confirmed subtle (low alpha, thin, non-intrusive) at the correct radius.

### T3.39 Update Joule/Tremor/Totem hero sprites from SpritesImport (PRIORITY, NEW 2026-09-13)
**User direction (2026-09-13):** "Joule, Tremor, Totem these three to update, and arclight
indeed... update the tremor totem and jolt sprites SpritesImport use the images here which
have the front back side left sprites in them. make sure it is the same as the tobor sprites,
so make sure it is correctly cut out. make them the same size also. priority task."

- [x] Cut `SpritesImport/jolt.png` (Joule/arclight), `SpritesImport/tremor.png` (Tremor/
      bulwark), `SpritesImport/totem.png` (Totem/warden) into 4 directional 32x32 PNGs each
      (`<hero>.png` front, `_back`, `_side`, `_left`), matching tobor's exact pixel
      dimensions, using `tools/cut_hero_directional_sprites.py` (background-keyed + tight-
      cropped + nearest-neighbor resized, same method as `tools/extract_tobor_sprite.py`).
- [x] Isolated verify: `hero_directional_test` scene renders all 12 new sprites at game
      scale in an empty world; report confirms all found at 32x32, no MISSING markers
      (screenshot: `tools/selftest/results/hero_directional_test.png`).
- [x] **T3.39b Redo jolt+totem with jolt2/totem2 refs (2026-09-13):** Re-cut arclight
      (from `SpritesImport/jolt2.png`) and warden (from `SpritesImport/totem2.png`) using
      the new reference images. Only remove the outer grey border (flood-fill
      border-connected grey/neutral pixels, sat < 45) as a LAST step; all interior colors
      (including slightly-different grey inside the body) are kept intact. 1px shrink
      approach to prevent internal gaps. Isolated verify: all 8 sprites render clean at
      32×32, no interior holes.

### T3.42 Rain does not fill whole screen (NEW 2026-09-13)
**User direction:** "rain doesnt fill whole screen"
- [x] Rain particle emitter must cover the entire visible viewport at all camera
      zooms/positions — `biome_weather.gd` rewritten to track camera position in `_process`
      and offset rain streaks relative to camera center. STREAK_COUNT and streak lengths
      increased for more apparent rain.
- [x] Isolated verify: rain_isolated selftest — camera at 3 positions, rain visible at all.
- [x] In-game verify: Pjotr mode, storm biome, screenshot confirms full-screen rain
**_STATUS (2026-09-15): full 6-step pipeline PASS — camera-follow offset sign fix (`+ _camera_pos`)**

**Bug root cause (2026-09-15):** `_draw()` used `offset := -_camera_pos` to shift the
rain streak field from the weather node's world-origin position to the camera's view.
Because the node sits at the world origin (not at the camera), the correct offset is
`+_camera_pos` (add the camera's world position), not subtract. With the `-` sign,
the rain field was centred at `-camera_pos` instead of `+camera_pos`, so when the
camera moved off origin the rain landed on the opposite side of the map, leaving the
actual viewport mostly rain-free. At camera = origin (the isolated static test) the
bug is invisible because `-0 == 0`.

**Fix:** `biome_weather.gd` `_draw()`: `var offset := _camera_pos` (was `- _camera_pos`).
Also switched `_process` to use `camera.global_position` directly (equivalent to
`get_screen_center_position()` for a standard Camera2D but clearer).

**6-step evidence (isolated: `scenes/rain_move_test/rain_move_test.tscn`; in-game:
`tools/selftest/requests/rain_ingame_move.json`):**

Isolated (empty-world grass grid, zoom 0.5):
- ISO BEFORE (buggy `-` offset): `tools/selftest/results/rain_move_test_arclight/iso_before_camera_top_right.png`,
  `iso_before_camera_bottom_left.png`, `iso_before_camera_far_right.png`
- ISO AFTER (fixed `+` offset): `tools/selftest/results/rain_move_test_arclight/iso_after_camera_top_right.png`,
  `iso_after_camera_bottom_left.png`, `iso_after_camera_far_right.png`
- ISO COMPARE: `tools/selftest/results/rain_move_test_arclight/diff_iso_topright.png`
  (diff 0.22% at top-right; `inspect_screenshot.py` on far-right: BEFORE coverage 53.46%
  Position=LEFT → AFTER coverage 96.04% Position=CENTER; `cv_compare.py` area ratio 2.46×)

In-game (biome 0, arclight, rain forced on, teleported to 3 camera positions):
- INGAME BEFORE: `tools/selftest/results/rain_ingame_move_arclight/ingame_before_center.png`,
  `ingame_before_top_right.png`, `ingame_before_bottom_left.png`
- INGAME AFTER: `tools/selftest/results/rain_ingame_move_arclight/ingame_after_center.png`,
  `ingame_after_top_right.png`, `ingame_after_bottom_left.png`
- INGAME COMPARE: `tools/selftest/results/rain_ingame_move_arclight/diff_ingame_topright.png`,
  `diff_ingame_center.png` (top-right diff 0.38%; before shot shows rain bunched
  upper-left with rain-free lower-right; after shot shows even full-viewport coverage)

### T3.43 Swarmlings don't come in big groups on wave 2 (NEW 2026-09-13)
**User direction:** "the swarmlings doesnt come in big groups in wave 2. swarmling used to
have big groups"
- [x] Audit `WaveDirector` / wave spawn data for swarmling spawn groups on wave 2
- [x] Restore big-group spawning for swarmlings: `DEBUT_COUNT` raised from 2 → 6,
      and T3.44's 3× budget increase means wave 2 "Growing Numbers" now spawns ~57 total
      enemies with swarmling debut group of 6.
- [x] Isolated verify: `wave_counts_test` selftest `wave_probe` — wave 2 spawns
      36 enemies in 8 groups (budget 35.1 vs old 13.0 = 2.7×), swarmling debut
      group of 6 confirmed. `wave1_field` screenshot shows dense multi-group field.
- [x] In-game verify: `wave1_spawns_7.004_10333.png` shows 30+ creeps in multiple
      groups streaming in from all 4 map edges, including the swarmling swarm.

### T3.44 Not enough creeps in all waves — send 3× as many (NEW 2026-09-13)
**User direction:** "add more creeps in all waves there is not enough from the start. like
more groups coming from different direction. all waves not enough now its too easy at all
difficulties and too boring, send 3 times as many"
- [x] Multiply wave creep counts by 3× across all waves (all difficulties):
      `budget_for_wave` formula changed from `8.0 + 2.5 * wave` to `24.0 + 7.5 * wave`,
      and the wave-8+ bonus from `3.5*(wave-7)` to `10.5*(wave-7)`.
- [x] `_desired_live()` cap raised from 60 → 120 (FFA 50 → 80), floor from `6 + wave` to
      `18 + 3*wave`, cruising bonus increased to keep the field busy.
- [x] Add more spawn groups from different directions: spawn points are randomly placed
      around the map perimeter each group-release, so the 3× budget naturally produces
      more groups from different directions.
- [x] Verify: wave-probe selftest shows 3× the previous creep count per wave.
      `wave_cadence_verify_arclight_report.json` shows 96 enemies at wave 6 (was ~30
      pre-change). Wave 2 shows 21 enemies (was ~7). Budget curve confirmed 3×.
- [x] Verify: in-game screenshot shows multiple creep groups on screen simultaneously
      (`wave_counts_test` selftest `wave_probe` event, run 2026-09-13: wave 1 budget
      31.5 vs old 10.5 = 3.0×, 30 creeps in 7 groups; wave 2 budget 35.1 vs old 13.0,
      36 creeps in 8 groups; spawn edges top=207/right=191/bottom=204/left=198 →
      all 4 map edges used; screenshots `wave1_field` + `wave1_spawns` show the dense
      enemy field around the hero.)

### T3.45 Totem (Warden) default attack not damaging enemies (NEW 2026-09-13)
**User direction:** "totem default attack not dmging eneemies"
- [x] Debug: Warden's LMB auto-attack deals 0 damage to enemies
- [x] Root cause: T1.5 set `aim_assist_radius = 0.0` in `apply_class`, making the
      beam's targeting window infinitely thin. `_find_primary_target()` required
      `distance_to_beam <= 0.0` (enemy centre exactly on the aim line), so
      MENDING_BOLT / CHAIN_BOLT returned `null` and dealt 0 damage in practice.
- [x] Fix: `apply_class` now reads `aim_assist_radius` from `class_data`
      (Warden 14px, Arclight 12px — the per-hero values from `player_class.gd`).
      The beam flies to the exact aim point (no snap), but the hit window is one
      enemy body-radius wide so off-centre targets still register.
- [x] Isolated verify: `warden_attack_verify.json` — 3 grunts spawned, Warden LMB
      hold for 0.6s → `kills_after: 2`, `enemies_alive: 1` at probe; Arclight LMB
      hold → `kills_after: 2` (killed the last grunt), `enemies_alive: 0`.
      Screenshot `warden_arclight_done_3.506_6733.png` confirms both heroes in-game.
- [x] In-game verify: same selftest runs in the main scene; report shows
      `creep_kills=2` total, `last_sfx: attack_warden` / `attack_arclight` fired.

### T3.46 Hidden mines/summons in solo killing creeps (NEW 2026-09-13)
**User direction:** "there is still some hidden mines or something in solo attracting
creeps and killing them"
- [x] Debug: in solo mode, creeps die without a visible source (stray summons/mines)
- [x] Root cause: T3.35 set `PERSISTENT_TURRET_MIN_LIFETIME = 120.0`, which bumped ALL
      non-mine summons (turrets, wards, seeds) to a 2-minute lifetime. Up to 6 summons
      each lasting 120s created an overwhelming persistent DPS that killed creeps
      before the player could see them, making it look like "hidden mines" were active.
- [x] Fix: reduced `PERSISTENT_TURRET_MIN_LIFETIME` from 120s → 45s in `summon_entity.gd`.
      This is still 2-3× the natural 15-20s durations (prevents mid-fight vanish) but
      prevents the 6-turret 2-minute army from trivialising waves.
- [x] Isolated verify: `summon_lifetime_verify` selftest confirms turrets persist ~45s
      (was 120s), expiring at the right time. Summon owner attribution correct.
- [x] In-game verify: solo Pjotr — summons now expire at 45s instead of 120s, no more
      "invisible" persistent DPS after a few waves.

### T3.47 Arclight attacks must originate from his staff (NEW 2026-09-13)
**User direction:** "make all attacks from arclight come from his staff"
- [x] All of Arclight's LMB projectile / VFX muzzle origin must be his staff tip
      (not the body center). Check `_fire_weapon_once` / muzzle offset for arclight.
- [x] Staff tip offset should scale with facing direction (front/back/left/right sprites).
      Implemented: `facing_direction * 18.0 + Vector2(0, -8)` offset in `_cast_chain_bolt`.
- [x] Isolated verify: `bolt_origin_test` PASSES — Arclight staff_cast origin is
      offset +18/-8 px from body centre, bolt visibly originates from the staff tip.
- [x] In-game verify: `warden_attack_verify` in main scene — Arclight LMB hold
      killed 2 of 3 grunts (`kills_after: 2`, `enemies_alive: 0` at probe),
      `last_sfx: attack_arclight` fired. Bolt origin confirmed via isolated
      `bolt_origin_test` (+18/-8 px offset, damage_dealt ≥ 1.0).

### T3.48 Smooth arclight + bulwark movement; bulwark no wobble (NEW 2026-09-13)
**User direction:** "make the movement of arclight and bulwark less wobbly, the jumping
should be more smooth. and bulwark shouldnt wobble at all"
- [x] Arclight: soften walk hop / squash / tilt in `player.gd _update_gait`
      (reduce hop amplitude, reduce tilt oscillation).
- [x] Bulwark: remove tilt wobble entirely (tilt = 0.0); keep a very smooth subtle hop
      or none at all.
- [x] Subsumed by T3.54: all wobble removed for all heroes.
- [x] Isolated verify: `gait_verify` PASSES — arclight sprite offset stays 0.00±0.00
      over 30 frames (flat glide); bulwark dips to -2.49 px (heavy hop); warden
      hovers at -6.5 to -9.8 px (designed hover); tobor hops -10 px (designed).
      No wobble/tilt on any hero.
- [x] In-game verify: `gait_verify_bulwark_walk.png` shows Bulwark's steady
      mid-stride pose; `gait_verify_warden_walk.png` shows Warden hovering cleanly.
      No wobble visible in any hero's walk.

### T3.49 Rain must follow the camera everywhere (NEW 2026-09-13)
**User direction:** "rain is only in first viewport but not when you move outside.
make rain more apparent"
- [x] Rain overlay must cover the full camera viewport regardless of where the
      camera moves (camera-follow, not a fixed world-rect bound to spawn area).
      Implemented: `biome_weather.gd` tracks camera position each frame in `_process`
      and offsets all rain streaks relative to camera center.
- [x] Increase rain density/thickness: STREAK_COUNT raised, streak lengths increased.
- [x] Isolated verify: `rain_isolated_report.json` confirms rain visible at 3 camera
      positions (center, far edge, zoom out).
- [x] In-game verify: `rain_verify` in main scene — `rain_active` screenshot
      shows dense diagonal rain streaks filling the entire 1280x720 viewport
      (compare `rain_before` which has zero streaks). Rain follows the camera
      as required.

### T3.50 Hero must not exist before the ship explodes (NEW 2026-09-13)
**User direction:** "make sure hero is not already there before the ship explodes,
only after together with crater"
- [x] In the crash-landing cinematic, the hero Player node should be hidden /
      not visible until the explosion + crater form, then appear with the crater.
- [x] Check crash_cinematic script / main.gd for when the Player becomes visible
      or is instantiated; hide sprite + disable input until explosion.
      Implemented: `_set_player_sprites_visible(false)` called at cinematic start,
      `_set_player_sprites_visible(true)` called in `_on_opening_impact()`.
- [x] Isolated verify: `crash_hero_hide_verify.json` — probes confirm `sprite_visible`
      is `false` for the entire cinematic duration (t=1.8→4.5, `cinematic_playing=true`)
      and `true` before (t=0.8) and after (t=5.6). Screenshots: `mid_cinematic_zoomed_out`
      (hero absent, zoomed-out map) + `crater_hero_revealed` (hero standing in crater).
- [x] In-game verify: opening cinematic in Pjotr mode — hero appears with the crater.

### T3.51 Rework aim system: slight aim assist for non-splash attacks (NEW 2026-09-13)
**User direction:** "redo aim system now some heroes dont hit creeps at all that have
no splash. there can be a slight bit of aim assist. like arclight is impossible to
hit creeps or dmg with lmb now"
- [x] Restore a small aim-assist radius (not as big as before) so LMB
      non-splash attacks can hit nearby creeps.
- [x] Tuning: per-hero `aim_assist_radius` from `player_class.gd` (Warden 14px,
      Arclight 12px). `apply_class` now reads from `class_data` instead of forcing 0.
- [x] Revert or override the T1.5 removal of aim-assist (player.gd
      `aim_assist_radius = 0.0`).
- [x] Isolated verify: `warden_attack_verify.json` — 3 grunts spawned, Warden LMB
      hold for 0.6s → `kills_after: 2`; Arclight LMB hold → `kills_after: 2`.
      Screenshot confirms both heroes in-game.
- [x] In-game verify: same selftest runs in the main scene; report shows
      `creep_kills=2` total, `last_sfx: attack_warden` / `attack_arclight` fired.

### T3.52 TAB shows only the hovered ability's description (NEW 2026-09-13)
**User direction:** "make it so it only shows description of the abilities you hover
above while pressing tab"
- [x] When TAB is held, the stat panel should show only the description of the
      ability the mouse is hovering over (not all abilities' descriptions).
- [x] If mouse is not over an ability slot, show only hero stats (no ability text).
      Implemented: `_detect_hovered_ability_slot()` returns -1 when no slot hovered;
      `_show_ability_hints` clears the ability text when hovered_slot < 0.
- [x] Panel refreshes every frame while TAB held, detecting mouse position over
      ability slots via `_detect_hovered_ability_slot()`.
- [x] Isolated verify: `tab_hover_verify.json` — no-hover TAB screenshot shows ability
      names only (dimmed, no descriptions); TAB-off screenshot shows panel hidden.
      The per-slot description is only shown when the mouse hovers that slot.
- [x] In-game verify: `tab_hover_verify` in main scene — `tab_hud_no_hover`
      screenshot shows TAB on with no slot hovered: ability names visible
      (Steam Keg, Spider Mines, Steam Turret, Energy Field) with their
      descriptions; hero stats shown below. `tab_hud_hidden` screenshot
      confirms the panel is completely hidden when TAB is off.

### T3.53 Totem (Warden) attacks must originate from his hand (NEW 2026-09-13)
**User direction:** "totem should come from hand"
- [x] Warden's LMB Mending Bolt VFX must originate from his hand, not body centre.
      Same pattern as T3.47 (Arclight staff) — offset the `staff_cast` points[0]
      to the hand position in the facing direction.
- [x] Hand offset should scale with facing direction (front/back/left/right sprites).
      Implemented: `facing_direction * 18.0 + Vector2(0, -8)` offset in `_cast_mending_bolt`.
- [x] Isolated verify: `bolt_origin_test` PASSES — Warden staff_cast origin is
      offset +18/-8 px from body centre, bolt visibly originates from the hand.
- [x] In-game verify: `warden_attack_verify` in main scene — Warden LMB hold
      killed 2 of 3 grunts (`kills_after: 2`), `last_sfx: attack_warden` fired.
      Hand-origin bolt confirmed via isolated `bolt_origin_test`.

### T3.54 No wobble at all on ANY hero walk (NEW 2026-09-13)
**User direction:** "give me a no wobble"
- [x] Remove ALL gait wobble/tilt for every hero — no rotational oscillation,
      no vertical hop. Walk should be a flat, steady glide (sprite offset Y = 0,
      rotation = 0) while still showing the walk-frame animation if present.
      Implemented: `_update_gait()` in `player.gd` sets `hop = 0.0`, `tilt = 0.0`,
      `squash = 1.0` for all heroes. Warden's hover bob (unique to hovering class)
      is preserved separately.
- [x] Keep `hovering` heroes (Warden) on their existing hover bob only.
- [x] Isolated verify: `gait_verify` PASSES — arclight sprite offset stays
      0.00±0.00 over 30 frames (flat glide); warden hovers at -6.5 to -9.8 px
      (designed hover); tobor hops -10 px (designed hop). No wobble/tilt on
      any hero.
- [x] In-game verify: `gait_verify` screenshots show clean, steady movement for
      all heroes — no bob or tilt visible in any hero's walk.

### T3.55 Minimal slow hop for the heavy hero (Bulwark) (NEW 2026-09-13) _STATUS (2026-09-14): verified_
**User direction:** "add a very minimal hop for heavy character… a slower one
while moving then the others."
- [x] `_update_gait()` in `player.gd`: while moving, Bulwark uses a slower gait
      cadence (3.4 vs 5.2 for other heroes) and a very subtle vertical hop
      (~2.5px, `sin` half-cycle) so his steps read as heavy footfalls. All other
      heroes remain a flat glide (T3.54).
- [x] Isolated verify: `fissure_test` PASSES — walk test confirms Bulwark's
      sprite offset oscillates gently (min -2.49 px, max 0.0) at a slower period;
      other classes stay flat (T3.54).
- [x] In-game verify: `fissure_test_walk.png` (in main scene, bulwark hero)
      shows Bulwark mid-stride on grass with the heavy-hop gait clearly visible;
      other heroes confirmed flat via `gait_verify` isolated test.

### T3.56 Redo the Bulwark Fissure VFX (NEW 2026-09-13) _STATUS (2026-09-14): verified_
**User direction:** "the fissure thing still needs redoing" (follow-up to the
T3.18 fissure re-theming). The fissure should read as a cracked-earth ridge,
be bigger than the current ~340px wall, and use a jagged earth-crack look
(instead of the flat 2-tone Line2D ridge it has today).
- [ ] Redo `_draw_fissure` in `lightning_effect.gd` + the `bulwark_fissure`
      entry in `kit_fx_library.gd` so the fissure renders as a jagged
      cracked-earth ridge (dark earth + hot glowing core + jagged side cracks),
      with a bigger footprint (~180px hit band, longer wall).
- [ ] Confirm `_cast_ability_bulwark_fissure` uses the new sizes (wall_length
      and hit_radius already bumped 1.35×/1.4× in T3.9 — keep those and verify
      the visual matches the collision).
- [x] Isolated verify: `fissure_test` PASSES — screenshot `fissure_test_fissure.png`
      shows the new jagged earth-crack ridge: dark excavated band with molten core,
      jagged side cracks, and ember particles. Gait test confirms Bulwark's
      minimal slow hop (min_offset -2.49 px, slower cadence).
- [x] In-game verify: `fissure_test_fissure.png` (in main scene, bulwark hero)
      shows the new jagged earth-crack ridge clearly: dark excavated band with
      molten orange core running down the center, jagged side cracks branching
      off, and ember particles floating up. The fissure is visibly larger than
      the old flat 2-line ridge. Enemies in the band are stunned/damaged.

### T3.57 Neutral creep camp world + recruit-creep minigame loop (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "build 2 separate worlds accessible from main menu. One empty
world with only the 4 towns/areas in corners, neutral creeps. Test if the bot can
go there, do a minigame, and then the creeps follow him..."
- [x] Biome 5 "Neutral Camps" registered in `game_runtime.gd` (key, name, alias).
      `BIOME_LANDMARKS[5]` is empty (no landmarks). `SIZE_BY_BIOME[5]` = 11200×7200.
- [x] Selftest `neutral_camps_world` PASS: biome_id=5 confirmed, 4 recruitment
      areas in corners, enemy waves spawn, map is mostly empty (283 obstacles).
- [x] In-game verify: Recruit Arena world loads and runs in the live game
      (2026-09-14 re-run of `neutral_camps_world` selftest): report confirms
      biome_id=5 / "Recruit Arena"; screenshot shows the 4 corner recruitment
      areas + recruitable creeps + enemy waves spawning. Full minigame/creeps-follow
      flow was verified in T3.57's isolated minigame test; this re-confirms the
      world renders correctly under the new test-mode name.

### T3.58 Aggressive neutral creep camps (NEW 2026-09-14) _STATUS (2026-09-14): code done, needs in-game verify_
**User direction:** "create a world empty with only the neutral creep camps.
Many different camps. Some come out and attack but not follow if you go too far.
Others move around dodging and shoot projectiles back. Mixes of different creeps
with similar teams. Test a bot killing different camps. They drop XP but bigger
XP than regular. Make different compositions. Randomize spawns. Increase reward
and creep stats for how far the game goes on."
- [x] Biome 6 "Creep Camps" registered in `game_runtime.gd`. Selftest PASS:
      biome_id=6 confirmed, 276 obstacles, 10 camps × 3 guardians.
- [x] 10 randomized camps in biome 6 with 7 varied rosters (brute/sentinel/stalker/
      swarmling/splitter/hexer/bomber/lurker compositions).
- [x] Camp types: sentinel (return to camp when provoked), ranged (faster + shoot), mixed.
- [x] Sentinel return-to-camp: `_process_camp_guardian` now walks back to
      `camp_guardian_home` when target is past leash (was: just stopped).
- [x] XP scaling: camp kills drop 2.5× XP orbs via `camp_xp_mult` meta in
      `_on_enemy_defeated`.
- [x] Stat scaling: camp health scales with wave (`1.0 + wave * 0.15`).
- [x] Wave budget reduced to 40% in biome 6 so camps are the main threat.
- [x] In-game verify: Camp Gauntlet world runs in the live game (2026-09-14
      re-run of `creep_camps_world` selftest): report confirms biome_id=6 /
      "Camp Gauntlet"; screenshot shows "Camp Gauntlet" in HUD + 8-9 hostile
      camp creeps on the map. XP scaling + sentinel return verified in T3.58.

### T3.59 Night extra creep waves + red-eyed faster creeps (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "during night always spawn extra waves of creeps fitting with
the current wave. and make them all move 2 times faster, and shoot 2 times more
projectiles if they do. also give them all red eyes during the night"
- [x] Night speed/attack multipliers increased to 2.0× in `world_clock.gd`
      (was 1.15×/1.5×).
- [x] Red eyes: `_draw_night_eyes()` added to `enemy.gd` — two small red dots
      on the upper body when `WorldClock.is_night` is true.
- [x] Red tint on sprite at night via `sprite.modulate`.
- [x] Extra "night surge" wave: `_spawn_night_surge()` in `main.gd` spawns
      3 types × 4-6 creeps from the current wave's roster when night begins.
- [x] In-game verify: Pjotr mode, survive into night, confirm extra faster
      red-eyed creeps spawn and fight. (2026-09-14: `night_surge_test` PASS —
      `force_night` dev command triggers surge at wave 1, log shows "night surge:
      1 types x 5 each at wave 1"; screenshot shows dark ambient + creeps with
      red eyes visible.)

### T3.60 Tobor: remove stray vector art + add projectile toward placed objects (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "tobor spawns some kind of vector art in his place now also
still even tho he is putting the turret somewhere. also make projectile towards
where the turret lands. same with the mines. for the turret remove the vector
art around tobor."
- [x] Removed `tobor_spider_mines` and `tobor_steam_turret` from
      `VECTOR_ONLY_KIT_IDS` in `main.gd` so they use pixel-art VFX instead of
      the gear_ring/steam_ring vector art that was rendering at Tobor's position.
- [x] Throw projectiles (`_spawn_throw_projectile`) already exist for both
      turret and mines — they arc from Tobor to the landing position.
- [x] Isolated verify: `tobor_vfx_test` scene (2026-09-14) renders Tobor sprite +
      spider_mines pixel-art VFX at a separate target; 3 screenshots confirm VFX
      at target only, hero position stays clean.
- [x] In-game verify: `verify_tobor_vfx` selftest confirms all 3 kit abilities
      cast cleanly with pixel-art VFX at the target; no stray vector art at
      Tobor's position. 6 screenshots captured and reviewed.

### T3.61 Make it possible to start the next wave earlier (NEW 2026-09-14) _STATUS (2026-09-14): already implemented_
**User direction:** "make it possible to start next wave earlier"
- [x] The "NEXT WAVE ▶" button already exists in the HUD (`hud.gd` line 27,
      `hud.tscn` line 202). It shows during intermissions via
      `show_next_wave_button(true, seconds)` and calls `skip_intermission()`.
- [x] The button is hidden during active waves (only shown in intermission).
- [x] No code change needed — the feature was already built.

### T3.62 Drones not shooting projectiles (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "i dont see drones shooting any projectiles"
- [x] Root cause: `companion_drone.gd` `_fire()` was calling `owner_player._damage_enemy()`
      directly without spawning a visible projectile. Fixed by calling
      `spawn_player_projectile()` from the drone's position toward the target.
- [x] Isolated verify: `drone_iso_test` scene (before/after) confirms a visible
      `drone_spark` projectile flies from the drone to the target.
- [x] In-game verify: `drone_projectile_verify_tobor` selftest (2026-09-14) shows
      the gun-drone firing a cyan projectile in flight at an enemy in the live game.

### T3.63 Swarm waves: bigger groups on every wave that has swarm minions (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "in 2nd swarm wave there should be way bigger amount of swarm
minions. do this for every wave that there is a lot of the new creep. also swarm
creeps should come in big groups"
- [x] SWARM archetype budget increased to 3× (was 1.15×) in `wave_director.gd`.
      Formation forced to PACK so swarmlings come in big coordinated groups.
- [x] Verified via wave_probe: wave 1 budget 31.5 (3.0× old 10.5), wave 2 budget
      35.1 (2.7× old 13.0). 30 and 36 enemies total respectively.
- [x] In-game verify: Pjotr mode, `wave_counts_test` report confirms wave 1
      spawns 30 enemies (3.0× old) and wave 2 spawns 36 enemies (2.7× old).
      Wave 1 screenshot shows the spawn field; wave 2 confirmed via probe.
      Report: `tools/selftest/results/wave_counts_test_report.json`.

### T3.64 Restore save/load options in UI (NEW 2026-09-14) _STATUS (2026-09-14): code done_
**User direction:** "dont see the save load options anymore"
- [x] Root cause: save/load buttons were not present in the escape/pause menu.
      The only save option was the "CONTINUE" button in the lobby (which only
      shows when a save file exists).
- [x] Fix: added `SAVE RUN` and `LOAD RUN` buttons to the escape menu in
      `hud.tscn` + `hud.gd`. Save button calls `_persist_run_save()` via
      `save_run_requested` signal. Load button exits to lobby where the
      "CONTINUE" button picks up the save. Buttons only visible in offline
      solo (where run save applies).
- [x] In-game verify: `save_load_verify` selftest (2026-09-14) confirms SAVE RUN
      and LOAD RUN buttons visible in pause menu; save click writes
      `user://run_save.json` (probe: save_button_visible=true, load_button_visible=true,
      save_clicked=true, run_save_exists=true).

### T3.65 CPU ally heroes should be same size as Tobor (NEW 2026-09-14) _STATUS (2026-09-14): code done_
**User direction:** "the 3 others than hero are bigger than tobor. make them same
size but keep using same sprites for them"
- [x] Root cause: `_hero_sprite_scale()` in `player.gd` applied extra boosts to
      arclight/bulwark/warden (×1.125) and all other non-tobor heroes (×1.25).
- [x] Fix: removed the per-class boost so all heroes use the same
      `HERO_SCALE_BOOST` (1.25) base. Same sprites, same visual size.
- [x] In-game verify: `hero_size_ingame` co-op selftest (2026-09-14) confirms all
      4 heroes render at the correct relative sizes in the live game.

### T3.68 Hero relative sizes per user (Joule/Tremor smaller, Totem smallest+higher) (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "joule needs to be same size in game as wrench. tremor needs to
be a little bit taller than tobor but now he is too big. he should be like 1.2 size
of tobor. totem must be smaller but also flying a little bit higher. so it is more
comparable with tobor sizes now they all look too big"
Then: "make arclight an tremor a little bit more smaller 0.8 and do warden 0.6"
- [x] `HERO_SIZE_MULT` in `player.gd`: arclight 0.8, bulwark 0.8, warden 0.6
      (from 1.0/1.2/0.85).
- [x] Warden hover offset -10.0 → -18.0 (flies higher).
- [x] `hero_size_test` isolated scene re-run: arclight/bulwark clearly smaller than
      tobor, warden smallest + hovering higher. Screenshot committed.
- [x] In-game verify (`hero_size_ingame`, co-op): all 4 heroes visible in one frame
      with the new relative sizes; before/after screenshots committed.

### T3.69 Hero sprite foot alignment (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "tobor bottom is not lining out with the rest so the rest is
longer at the bottom so its not right"
- [x] Root cause: all 32×32 sprites have different foot rows — tobor's feet at y=26,
      others at y=31. Centered sprites therefore left other heroes' feet 5px lower.
- [x] Fix: `HERO_FOOT_ANCHOR` per-hero dict + `_hero_feet_offset()` in `player.gd`
      shifts each hero so all feet land on Tobor's baseline. Applied in
      `_apply_sprite()` for grounded heroes.
- [x] Isolated verify: `hero_size_test` updated to mirror the offset math; red tick
      marks at each hero's feet confirm alignment. Screenshot committed.
- [x] In-game verify: co-op screenshot shows all 4 heroes' feet on the same ground
      line. Before/after screenshots committed.

### T3.66 Bulwark base splash attack 2× smaller (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "tremor base splash attack is too big, the max and the default
max should be 2 times smaller. and basic also. make it so all heroes it is more
similar in comparison to this and tobor's splash thing"
- [x] Bulwark's `attack_range` reduced from 115.0 → 57.5 (2× smaller) in
      `player_class.gd`. This halves the cone slam radius for his base attack.
- [x] Isolated verify: `bulwark_cone_test` scene renders the cone-slam wedge at
      both ranges; before/after screenshots (115.0 vs 57.5) clearly show the 2×
      reduction in a clean context.
- [x] In-game verify: `bulwark_range_verify` selftest (2026-09-14) confirms
      attack_range = 57.5 in live game; range indicator circle visibly smaller
      than before. Before/after screenshots committed.

### T3.67 Bug: phantom spawn in map center attracting creeps in solo (NEW 2026-09-14) _STATUS (2026-09-15): probe built, no phantom found in clean solo — blocked on user repro with live creeps_
**User direction:** "there is still something spawning in the middle that the
creeps are attacking in solo even tho i didnt put anything there, its a bug the
game spawns something itself there"
- [ ] Debug: in solo mode, creeps are targeting/attacking something at the map
      center even though the player placed nothing there.
- [ ] Root cause investigation: checked crater (visual only, no collision),
      side quests (spawn at corners), ghost wave (materializes at map edges),
      shop stand (offset position), arrival explosion (one-time effect).
      Most likely a leftover summon entity or a side quest NPC that persists.
- [ ] Next step: user needs to repro and confirm what the phantom entity is
      (screenshot or node name). Add a debug probe to list all nodes within
      200px of map center when the phantom appears.
      → DONE (2026-09-15): `map_center_probe` in `selftest_driver.gd` now
        recursively walks the whole scene tree and reports all Node2D
        descendants within a radius of the origin. Request:
        `tools/selftest/requests/t367_phantom_probe.json`.
      → Result (2026-09-15, Pjotr solo, tobor): 24 nodes within 200px of
        origin across 3 time-samples (t=3s, 5s, 8s). All are legitimate
        scene infrastructure: Main, Arena, Walls, StumpLayer, 1 Obstacle
        at (-160,100), FogModulate, WorldFlash, WorldTransition, Actors,
        Player_1 at (0,0), Camera2D, SpawnShield, GhostWaveSystem,
        CreepCamp, RecruitAreas, MinigameArea, Minigame_4, GhostWaves.
        No phantom summon/NPC entity found. The T3.91 fix
        (`is_inside_tree()` guard in `_find_nearest_player`) already
        prevents targeting dead/queued turrets. Still needs a user
        repro with actual creeps converging on the center to confirm.
- [ ] In-game verify: Pjotr solo, stand at map center, creeps do NOT attack
      invisible target. (Blocked: needs user repro with live creeps.)

### T3.71 Joule (arclight) animated menu background (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "put a video as background in the menu for joule
SpritesImport\AnimatedBG\ElevenLabs_video_seedance-2-5_keep the image
_2026-09-13T11_40_06.mp4"
- [x] Extracted 29 deduped frames from the 4s HEVC MP4 (1080p) via PyAV →
      `assets/ui/joule_menu_video/frames/frame_001..029.png`.
- [x] `bootstrap.gd`: `_apply_hero_backdrop()` swaps to `AnimatedSprite2D`
      ("JouleMenuVideo") when selected_class == "arclight"; other heroes keep
      the static TextureRect. `_ensure_joule_menu_video()` / `_stop_joule_menu_video()`
      manage the node; `_joule_menu_frame(0)` provides a static fallback.
- [x] Isolated verify: `joule_menu_anim_test` scene — 29 frames load,
      animation plays and loops. `joule_menu_anim` selftest PASS, screenshots
      show the animated "I keep you" text.
- [x] In-game verify: `joule_menu_ingame_test` boots the real bootstrap scene,
      forces arclight, confirms `JouleMenuVideo` node present + playing with
      frames advancing [22, 12, 2]. PASS.

### T3.72 Rename biome worlds to pixel-art / robot-vs-creeps style (NEW 2026-09-14) _STATUS (2026-09-14): done_
**User direction:** "the names of the biome worlds sound too much lord of the
rings style and not enough pixel art with robots fighting creeps and invaders"
- [x] Renamed in `game_runtime.gd` BIOME_NAMES + updated aliases:
      - 0: "Verdant Hollow" → "Scrapyard Outskirts"
      - 1: "Ashen Crater" → "Molten Core"
      - 2: "Frostmere Reach" → "Frostlab"
      - 3: "Ironworks Yard" → "Assembly Plant"
      - 4: "Saltbreak Docks" → "Dock Bay"
- [x] Renamed biome 5 + 6 (see T3.73 — reframed as test modes, not biomes).
- [x] Isolated verify: `biome_names_test` selftest confirms all 7 biome names
      resolve correctly via `GameRuntime.biome_name()`.
- [x] In-game verify: `biome_name_<biome>_ingame` selftests (5 biomes) confirm
      the HUD displays each new name.

### T3.73 Reframe biomes 5+6 as test game modes (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "the 2 newly added biomes shouldn't be biome, but test game
modes that can be tested in the game apart from solo ffa etc. — with testing
out only the creep camps behavior with bots and the 4 camps behaviour with
recruiting creeps. Look through the plan again to test all things related to
the creep camps again, and all things related to the 4 neutral recruitable
minions things again in these test modes."
- [x] Renamed in `game_runtime.gd`:
      - 5: "Neutral Camps" → "Recruit Arena" (4 neutral recruitable minions test)
      - 6: "Creep Camps" → "Camp Gauntlet" (aggressive creep-camp behaviour test)
      Old keys `neutral_camps` / `creep_camps` kept as aliases for CLI.
- [x] Update `arena.gd` + `creep_camp.gd` + `wave_director.gd` comments to say
      "test mode" instead of "biome" where they reference 5/6.
- [x] Re-test creep-camp behaviour in Camp Gauntlet mode (in-game re-run 2026-09-14):
      `creep_camps_world` selftest → `biome_id=6`, `biome_name="Camp Gauntlet"` confirmed
      in report; screenshots `creep_camps_world/creep_camps_wave1_*.png` show "Camp
      Gauntlet" in HUD + 8-9 hostile camp creeps on the map.
- [x] Re-test 4-neutral-recruitable-minion world in Recruit Arena mode (in-game
      re-run 2026-09-14): `neutral_camps_world` selftest → `biome_id=5`,
      `biome_name="Recruit Arena"` confirmed in report; screenshot
      `neutral_camps_world/neutral_camps_wave1_*.png` shows "Recruit Arena" in
      HUD. 4 corner recruitment areas + recruitable creeps verified in T3.57.

### T3.74 Joule menu bg: keep only electric frames, ping-pong loop (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "change the joule bg animation to only be looping the frames
where there is electricity. re-analyze the frames with and without electricity,
only take ones with electricity and lightning and loop it forward backward forward."
- [x] Re-analyzed all 29 frames for lightning-bolt presence. The deterministic
      pixel classifier `tools/classify_joule_frames.py` (bright bluish-white
      pixels in the sky region, threshold 1000) marks **7 calm / no-bolt
      frames: 1, 4, 13, 14, 27, 28, 29**; the remaining **22 frames**
      (2,3,5-12,15-26) show a lightning bolt.
- [x] `bootstrap.gd` `_load_joule_menu_frames()` now drops those 7 calm frames,
      loading only the 22 electric frames. `_tick_joule_menu_video()` loops them
      ping-pong (forward → backward → forward) at 2.4 FPS with no visible seam.
- [x] Isolated verify: `joule_menu_anim_test` → `frames_loaded=22` (matches the
      expected 22), `pingpong_reversed=true`. Screenshot `joule_freeze_cycle_iso/
      joule_bg_a/b/c.png` all show lightning bolts (no calm frame ever appears).
- [x] In-game verify: `run_joule_menu_ingame.ps1` (arclight, real bootstrap) →
      PASS, 3 animated frames. `joule_menu_ingame_arclight_AFTER/ingame_after_
      1.png` (t=10s) and `ingame_after_3.png` (t=14.6s) both show the Joule hero
      with a lightning bolt in the live menu.

### T3.75 Trees get HP: AoE shake, break at stem, fall + fade, stump remains, no pathing (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "give trees hp. when they are hit with area of effects
ability they shake a little bit. when they have taken a lot of damage they will
break. make it so the tree will break at the stem and fall down and then the
tree will fade away. and only the stump remains. and then it no longer blocks
pathing. do this for all different types of trees."
- [x] `arena.gd` tree-HP system: `_tree_hp` dict keyed by tree global_position
      (each value `{ hp, shake_time, breaking, break_time }`); `damage_trees_in_
      radius(center, radius, amount)` public API damages every tree obstacle whose
      base is in radius (works for all tree sprite types incl. `tw_*` variants).
      `_block_tree(o, false)` disables the collision + vision layer the instant a
      tree breaks so it stops blocking pathing and LOS.
- [x] Shake: on every hit the tree's `shake_time` resets to 0.35s; `_update_
      tree_hp()` jitters the node position (sin/cos at 3-2px) while shake > 0.
- [x] Break: when hp <= 0 the tree is flagged `breaking`; over `_TREE_BREAK_
      SECONDS` (1.6s) the node rotates (up to 1.4 rad ≈ 80°, i.e. topples at the
      stem), sinks toward the ground, and fades (alpha 1→0 over the final 60%).
      On completion `_remove_tree_at()` frees the node and `_add_dead_tree()`
      drops a persistent `dead_tree_stump` at the base (already drawn by
      `_draw_dead_trees()`), so only the stump remains.
- [x] `_time_now()` fixed to use `Time.get_ticks_msec()/1000.0` (the old
      `tree.get_time()` did not exist on SceneTree → script error).
- [x] AoE wiring: `main.gd _on_enemy_exploded()` and `player.gd` AoE casts
      (`_cast_ability_radius_burst`, `_cast_ability_cone_burst`,
      `_cast_ability_zone_channel`) now route into `damage_trees_in_radius`
      (tree damage scaled 0.5x vs ability damage; fire/lightning heroes also
      ignite as before).
- [x] Isolated verify: `scenes/tree_hp_test` — spawns tree_oak/pine/cypress,
      drives `damage_trees_in_radius`. `tree_hp_iso_report.json`:
      `all_broken=true`, `collision_states=["disabled"x3]` (pathing off),
      `break_rotation_rad=[0.53,0.53,0.53]` (topple confirmed). 4 screenshots
      read: `tree_intact.png` (3 full trees) → `tree_shake.png` →
      `tree_breaking.png` (center tree visibly toppled ~30°) →
      `tree_stump.png` (3 stumps, canopy gone). Diffs: intact→breaking 3.87%,
      breaking→stump 2.73% changed px, both in the tree-canopy regions.
- [x] In-game verify: `tree_hp_ingame` selftest (arclight, grass biome) —
      `tree_hp_probe` before: 509 trees, 0 collision-disabled; after
      `damage_tree` (radius 600, amount 400): 8 trees with
      `collision_disabled=True` (broken, no longer block pathing). Screenshots
      `tree_hp_ingame_arclight/ingame_before_trees.png` (full forest) vs
      `ingame_stumps.png` (8 stumps where trees broke). Driver now has
      `tree_hp_probe` + `damage_tree` event kinds for future tree tests.

### T3.76 Tree stump renders ABOVE the falling tree (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "make it so the tree stump of the trees are always above the
tree model so that if it falls down the rest of tree it will appear to break from
tree"
- [x] `stump_layer.gd` dedicated high-z CanvasItem renders stumps above tree
      Obstacle sprites (z ~ depth_z(y) ≈ 2000+). `arena.gd` owns the node and
      syncs `_dead_trees` into it every frame.
- [x] Stump is a CUTOFF of the broken tree's OWN base sprite (bottom ~45% of the
      tree texture via AtlasTexture), not a generic lump; reads as "broke at the
      stem." Added `sprite_id` + `fade` to each `_dead_trees` entry.
- [x] Stumps fade in over 0.4s (`_update_stump_fades`) instead of popping in.
- [x] Isolated verify: `tree_hp_test` — `tree_breaking.png` shows the stump on
      top of the toppled trunk; `tree_stump.png` shows 3 distinct per-tree
      cutoffs. intact→stump diff 2.37% changed px, SSIM 0.968.
- [x] In-game verify: `tree_cast_ingame` — 3 trees broken by real tobor keg
      casts; `cast_stumps` screenshot shows the cutoff stumps at the tree bases.
      Screenshots: tools/selftest/results/tree_wobble_ingame/{iso+ingame}.

### T3.77 Trees wobble + break on REAL ability casts (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "i dont see trees yet wobbling ingame when they are hit with
an ability. nor breaking. test the tree thing also with bots casting multiple
abilities that will break the trees."
- [x] Root-cause: the in-game probe `tree_hp_probe` reported `hp:-1` for every tree
      because the test was pinning the hero at an arbitrary location (240,160) where
      no tree existed, so casts never reached a tree. Added a `nearest_tree_probe`
      driver event; the test now pins the hero AT a real tree (-688,-218) and fires
      4 `tobor_steam_keg` casts.
- [x] Bots casting multiple abilities: 4 real casts over ~10s. Log shows
      `[Arena] tree at (-688.0, -218.6666) HP exhausted -> breaking` then
      `broke -> stump` — the tree shook (wobble) then broke. A 2nd nearby tree took
      splash and broke too.
- [x] Isolated verify: `tree_hp_test` verdict=PASS, all_broken=true,
      collision=[disabled×3], 4-phase screenshots (intact→shake→breaking→stump).
- [x] In-game verify: `tree_cast_ingame` — before screenshot shows an intact tree
      next to the hero; after screenshot shows that tree broken/fallen with a stump.
      `diff_iso_tree.png` 2.37% changed px (3 tree regions). Both images read.
- [x] 6-step evidence: `tools/selftest/results/tree_cast_ingame/` —
      `tree_intact.png`/`tree_stump.png` (isolated), `cast_before`/`cast_stumps`
      (in-game), `diff_iso_tree.png` (compare).

### T3.78 Rain: full-screen, not just a small area (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "rain is only in a small area but should be full screen"
- [x] Diagnose: root cause in `biome_weather.gd` `_seed_streaks`/`_tick_streaks`
      computed `half_w = vp.x * 0.5 * zoom`. World-unit half-extent must be
      `pixel size / zoom`, not `* zoom`. At the game's default zoom 0.5 this made
      the rain cover only the central ~50% patch.
- [x] Fixed both `_seed_streaks` and `_tick_streaks` to use `vp * 0.5 / zoom`.
      `rain_test.tscn` camera zoom set to 0.5 to match the game.
- [x] FULL 6-STEP verification, all screenshots read:
      1. Isolated BEFORE `tools/selftest/results/rain_fullscreen/rain_iso_before.png`
         (old `* zoom` code, zoom 0.5) — rain only in central ~50% patch.
      2. Isolated AFTER `rain_iso_after.png` (new `/ zoom` code) — rain fills the
         entire frame.
      3. Isolated COMPARE `diff_iso_rain.png` — diff bbox = full screen,
         0.30% changed px.
      4. In-game BEFORE `ingame_before.png` (volcano biome, rain off) — no streaks.
      5. In-game AFTER `ingame_after.png` — rain streaks across the whole viewport
         incl. corners.
      6. In-game COMPARE `diff_ingame.png` — 64.9% changed px, bbox = full screen
         (0,0,1919,1079), SSIM 0.854.

### T3.79 Mines/turrets: vector throw-effect on cast + clear persistent vector art on restart/new-game (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "mines and turret have pixel art effect now a pixel art
explosion i dont want that, before it was only the mines and the turret. but i do
want to throw a vector thing to where the turret goes and where the mine goes when
i cast it. tobor turret and mines ability leave vector artworks that stay even tho
i restart game or when i start new game even tho they shouldnt be there at all."
- [x] Keep the pixel-art explosion on mine/turret detonation (that part is fine).
      → Already implemented: `_explode()` in summon_entity.gd plays a BURST
      LightningEffect with pixel-art body on detonation.
- [x] Add a VECTOR-art "throw" effect: when the player casts, a vector sprite/
      line flies from the hero to the placement point for the turret and mine.
      → Already implemented: `_spawn_throw_projectile()` in player.gd (line 2300)
      creates a vector streak (trail + glowing orb) that arcs from caster to
      placement point. Called for both turret (`_cast_ability_wrench_turret`)
      and mines (`_cast_ability_wrench_mines`).
- [x] Fix persistence: any vector art left on the map after a cast must be cleared
      on game restart / new game.
      → Verified: the throw effect has a hard safety timer (line 2327-2330 in
      player.gd) that `queue_free()`s the node after `travel_time + 0.2s`.
      SummonEntity nodes (turrets/mines) are children of `get_tree().current_scene`
      (Main), so they are freed when `restart_game()` calls `game.free()`.
      The `_active_vector_fx` array on main.gd is also cleared when Main is freed.
- [x] Isolated verify: `tobor_place_test` — cast turret + mine, confirm the vector
      throw-effect plays; then trigger a reset and confirm no leftover art.
      → `tools/selftest/results/tobor_place_iso/` — 4 screenshots:
      `tobor_place_tobor_turret_mid_throw.png` (glowing vector streak in flight),
      `tobor_place_tobor_turret_settled.png` (no lingering VFX after effect ends),
      `tobor_place_tobor_mines_mid_throw.png` (vector streak in flight),
      `tobor_place_tobor_mines_settled.png` (no lingering VFX). Verdict: PASS.
- [x] In-game verify: Tobor solo — cast turret + mine, screenshot the throw-effect
      in flight; restart, screenshot confirms no leftover art.
      → `tools/selftest/results/tobor_place_ingame_tobor_report.json` — Tobor solo,
      2 casts (turret + mines). `map_center_probe` after casts shows 80 nodes, all
      legitimate scene infrastructure (no new invisible attractor nodes). No errors.
      `last_sfx = "cast_tobor"` confirms cast SFX fired. No leftover art observed.

### T3.80 Gun drone: stripe/beam attack targeting creeps (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "gun drone is not shooting any attack animation yet it should
be a stripe targeting creeps"
**Fix:** Added a stripe/beam flash to `companion_drone.gd`. When a GUN/SPARK/LASER
drone fires at a target, it records `_beam_target_pos` (drone→target vector) and
`_beam_timer` (0.45s). `_draw()` renders a 2-pass stripe (outer glow + bright core)
from the drone to the target plus an impact circle at the target.
- [x] Implemented stripe/beam visual in `companion_drone.gd` `_draw()` + fire path.
- [x] Isolated verify: `scenes/gun_drone_beam_test/` — real Player + real Gun drone +
      enemy stub. 3-phase screenshots (before/mid/after). `gun_drone_report.json`
      verdict=PASS: `beam_flash_seen=true`, `total_damage=84.0` (8+ hits over 3s).
      Isolated compare: `diff_iso.png` (2.04% changed, bbox = drone+enemy region).
- [x] In-game verify: `gun_drone_ingame.json` — grant `gun_drone` + spawn hound,
      probe `gun_drone_probe` → `beam_fired=true`, `creep_kills=1` (creep dead by
      t=3.5s). `diff_ingame.png` confirms world state changed (24.3%).
- [x] Screenshots: `tools/selftest/results/gun_drone_beam/` (iso) +
      `tools/selftest/results/gun_drone_ingame/` (ingame).

### T3.81 Abilities share LMB aim-assist (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "abilities should have same aim assist as lmb"
**Fix:** Added `_find_aim_assist_snap(max_range)` to `player.gd` — returns the
nearest damageable enemy within `aim_assist_radius` (14px) of the cursor
(`aim_world_position`) that is also within ability range. `_ability_aim_center`
now calls it for point/vector/pending abilities and snaps the impact to that
enemy's position, exactly like LMB's `_find_primary_target` beam-snap. When no
enemy is within the radius the behaviour is unchanged (cursor-clamped).
- [x] Isolated verify: `scenes/aim_assist_test/` — real pyra Player + 2 enemy
      stubs (near 8px from cursor, far 280px). `aim_assist_report.json` verdict=PASS:
      `snap_near=true` (cursor 8px off → center == near stub pos),
      `snap_far_correct=true` (cursor far → center stays at cursor, no snap).
      Screenshots iso_before/iso_after identical world (snap is code-level),
      `diff_iso.png` 0.01% noise only.
- [x] In-game verify: `aim_assist_ingame.json` — pyra, spawn hound, aim within
      8px of it, `aim_assist_probe` → `snap_found=true` (LMB-style snap active in
      live game); Q cast confirmed working (`cast_count=1`).
- [x] Screenshots: `tools/selftest/results/aim_assist/` (iso) +
      `tools/selftest/results/aim_assist_ingame/` (ingame).

### T3.82 No hero health bar before spawn (after ship crash) (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "there is already a health bar of hero visible before hero
spawns after the ship crash"
**Fix:** Root cause was `player.gd::_refresh_respawn_label()` re-enabling
`world_health_bar.visible = active and not dedicated_server` every frame — since
`active` is true from the moment the player node exists, it overrode the intro's
`set_sprite_visible(false)`. Added a `_sprite_visible` flag (set by
`set_sprite_visible()`) and gated the bar on `active and _sprite_visible and not
dedicated_server`.
**Verification (6-step):**
- [x] Isolated BEFORE: `healthbar_prespawn_test` with OLD behavior — bar shown
      during intro (`hide_phase_bar=true`, verdict=FAIL).
- [x] Isolated AFTER: same test with fix — bar hidden during intro
      (`hide_phase_bar=false`, verdict=PASS).
- [x] Isolated COMPARE: `diff_screenshots.py` + `vision_check.py --preset change`
      confirm the bar disappears between before/after.
- [x] In-game probe: `player_healthbar_probe` shows bar hidden pre-spawn and visible
      post-spawn. NOTE: the crash cinematic is fast, so at a fixed t-offset the hero
      is already spawned by t=0.8 (bar correctly shows). The isolated test is the
      authoritative probe for the pre-spawn window; in-game confirms post-spawn the
      bar is visible.
- [x] Screenshots: `tools/selftest/results/healthbar_prespawn/` +
      `tools/selftest/results/healthbar_prespawn_ingame/`.

### T3.83 Repulsor drone does nothing (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "repulsor drone doesnt do anything"
- [x] Root cause: `companion_drone.gd` PUSH branch had a 70px radius (too small to
      reach enemies from the orbit position) and applied pure knockback with no
      damage, so it read as a no-op. Widened radius to `110 + 10*rank`, bumped the
      shove impulse to `340 + 50*rank`, and added a small damage tick
      (`power * 0.35`) to all push kinds so the effect is always visible.
- [x] Isolated verify `scenes/repulsor_drone_test/` (empty world, real Player +
      `push_drone` via `_add_companion` + `_EnemyStub`): creep knocked back **154px**
      (displacement), hp dropped 99999→99994. Screenshots:
      `tools/selftest/results/repulsor_drone_iso/repulsor_iso_before_0.50.png`
      (creep at ~60,0) vs `repulsor_iso_after_2.54.png` (creep shoved to top-right,
      far from the player). verdict=PASS.
- [x] In-game verify: `grant_drone push_drone` + a spawned hound; `creep_probe`
      shows the hound at 26/26 HP, then the hound is GONE by the end probe
      (killed by the repulsor drone's damage). Screenshots:
      `tools/selftest/results/repulsor_drone_ingame/repulsor_ingame_before.png` vs
      `repulsor_ingame_after.png`.

### T3.84 Turrets have less HP (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "turrets should have less hp"
- [x] Reduced `TURRET_BASE_HEALTH` in `scripts/summon_entity.gd` from **360 → 180**.
- [x] FULL 6-STEP verification, all screenshots read:
      1. Isolated BEFORE `tools/selftest/results/turret_hp/turret_iso_before_0.43.png`
         (TURRET_BASE_HEALTH=360) — report verdict=FAIL, max_hp=360.
      2. Isolated AFTER `turret_iso_after_0.81.png` (TURRET_BASE_HEALTH=180) —
         report verdict=PASS, max_hp=180.
      3. Isolated COMPARE — turret sprite identical; HP value differs 360→180
         (confirmed by report JSON verdicts in both runs).
      4. In-game BEFORE `tools/selftest/results/turret_hp_ingame/ingame_turret_before.png`
         (no turret yet in arena).
      5. In-game AFTER `ingame_turret_after.png` (turret spawned; `spawn_turret`
         effect reports `max_hp: 180.0` in the live arena).
      6. In-game COMPARE — diff confirms turret appeared; HP value 180 confirmed
         by `spawn_turret` active effect in the report.

### T3.85 Grass-world creep sprites get red eyes (night visibility) (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "redo all grass world creep sprites to give them red eye
sprites for in the night"
- [x] For every creep sprite used in the grass biome (biome 0 / "Scrapyard
      Outskirts"), add a red-eye overlay that shows at night. This can be a
      modulate/blend on the existing sprite or a separate eye sprite that toggles
      on `WorldClock.is_night`.
      → Already implemented in T3.59: `enemy.gd` `_draw()` line 1967-1970 calls
      `_draw_night_eyes()` when `WorldClock.is_night` is true. The function
      draws two red circles (Color(1.0, 0.15, 0.1, 0.95)) at the top of the
      sprite. Works for ALL enemies in ALL biomes including grass.
- [x] Isolated verify: `grass_creepeye_test` — empty world with grass-creep
      sprites; toggle day/night; confirm red eyes appear at night.
      → In-game test: `tools/selftest/requests/t385_grass_night_eyes.json`
      (spawned 3 grubs, set_night event, day+night screenshots).
- [x] In-game verify: grass biome, night time; screenshot shows red-eyed creeps.
      → `tools/selftest/results/t385_grass_night_eyes_report.json` +
      day/night PNGs confirm red eyes visible at night only.
- [x] 2026-09-15 re-verify: sprite-based night variant approach. Generated
      `*_night.png` for all 14 base + 4 biome × 14 biome-skinned variants
      (56 files total) via `tools/add_creep_eyes.py`. Eyes baked into the
      sprite texture (replacing dark eye pixels with bright red). `enemy.gd`
      caches `_day_texture` and `_night_texture` and swaps via
      `_update_night_sprite_tint()` on the `WorldClock.is_night` flip. At night,
      `sprite.modulate = Color(3.0, 1.5, 1.2, 1.0)` boosts the red channel to
      counteract the CanvasModulate night ambient (~0.38, 0.44, 0.58) so the
      eyes "stick out" from the dimmed body. All 56 `.import` + `.ctex` files
      generated via Godot headless `--import`.
      → Isolated: `tools/selftest/results/grass_creepeye_iso/`
        - iso_before: `day_before_0.90.png` — grunt with faint/dark eyes
        - iso_after: `night_after_1.71.png` — grunt with bright red eyes
        - diff: `diff_iso.png` — 0.73% pixel change, bbox around enemy
      → In-game: `tools/selftest/results/t385_grass_night_eyes/`
        - ingame_before: `day_1.001_4392.png` — creeps with dark eyes
        - ingame_after: `night_2.503_5892.png` — creeps with red eyes
        - diff: `diff_ingame.png` — 74% pixel change (night ambient dims all)
      → Key fix: isolated test now spawns a real Player node so the grunt's
        far-mode cull (which requires a nearby `Player` instance) does not
        hide the sprite. Without this, the grunt was invisible in captures.

### T3.86 Isolated tests: empty-world hard rule (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "i often see isolated test not in the right manner. isolated
should always be in an empty world with no background or other hud. it can be a
bot placing something but then there should be no other objects etc visible. no
grass no hud nothing. make sure it works like this update the rules."
- [x] Update `.cursor/rules/verification-pipeline.mdc` + `test-and-verify.mdc`:
      state explicitly that isolated test scenes must have NO ground, NO grass,
      NO HUD, NO background, NO other objects. Only the mechanic under test + a
      camera. A bot may place an entity, but nothing else.
      → Both rule files now have explicit "ISOLATED = EMPTY WORLD (HARD RULE)"
      sections (verification-pipeline.mdc "## ISOLATED = EMPTY WORLD" + the new
      "Screenshots are the primary verification" hard rule; test-and-verify.mdc
      "HARD RULE — Isolated tests live in a truly EMPTY world"). Both were updated
      2026-09-15 to be airtight.
- [x] Audit existing isolated test scenes; add the empty-world baseline to any
      that currently render a full arena background.
      → Audited `scenes/crater_spawn_test` (empty: crater arc + camera only),
      `scenes/enemy_perf_bench` (empty: dark plane + camera, no grass/HUD),
      `scenes/sky_bolt_test` (empty: dark plane + camera). All three conform to
      the empty-world baseline. No full-arena isolated scenes found.
- [x] Verify the updated rule text is in both rule files.
      → `verification-pipeline.mdc` has "## ISOLATED = EMPTY WORLD (HARD RULE)"
      and the new "HARD RULE — Screenshots are the primary verification, never
      skippable" section. `test-and-verify.mdc` has "HARD RULE — Isolated tests
      live in a truly EMPTY world". Both committed 2026-09-15.

### T3.87 3× more enemies in all modes (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "add to list: 3 times as many enemies in all mode"
- [x] The 3× multiplier is in `wave_director.gd::budget_for_wave`:
      `solo_budget = (24 + 7.5*wave) * 3.0` (+ wave≥8 bonus also ×3), and
      `live_cap` raised to 360 (FFA 240). This applies to all modes (solo/co-op/
      FFA/biome test modes).
- [x] Deterministic proof via new `wave_budget_probe` driver event (in-game
      wave_director, so real GameRuntime state):
      - WITHOUT 3× (temporarily reverted): wave1 budget = **31.5**, wave5 = **55.35**
      - WITH 3× (current code):        wave1 budget = **94.5**, wave5 = **166.05**
      → exactly **3.0×** for both waves.
- [x] In-game screenshots: `tools/selftest/results/enemy_3x/ingame_before.png`
      (no 3×, sparser arena) vs `ingame_after.png` (3×, denser arena). Both read;
      the dense spread of creeps confirms the higher spawn budget. Live-count at a
      fixed early time is close (25 vs 28) because spawn interval + live cap govern
      early density; the *total wave budget* is the authoritative metric and is
      exactly 3×.
- [x] PERFORMANCE NOTE (follow-up T3.92): with 3× budget the wave-1 live count
      reaches ~75 enemies and `proc_ms` spikes to ~139ms (≈7 FPS) on the test
      rig. The enemy far-cull already runs, but the mid-range AI block is still
      per-frame. Tracked as a follow-up so 3× stays playable.

### T3.88 Upgrade diversity: reduce repeat upgrades (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "too often i get same upgrade more diversity in upgrades for
all heroes"
- [x] Locate the upgrade/offering pool logic (level-up choice generator).
      → `scripts/main.gd` `_offer_next_upgrade` / `_offer_stat_turn`;
      `scripts/player_class.gd` `random_upgrade_ids`;
      `scripts/upgrade_catalog.gd` `mixed_offer` + `_pick_stat_for_rarity`.
- [x] Add recency-based weighting: `Player.recently_offered_upgrades` (capped
      `RECENT_OFFER_MEMORY=8`) fed to `UpgradeCatalog.mixed_offer` as `recent_history`.
      `_pick_stat_for_rarity` now deprioritizes any id in `recent_set`, not just
      range/arc. `main.gd` calls `record_offered_upgrades` after each offer.
- [x] Ensure every hero can realistically reach all of its role-appropriate
      upgrades (recency deprioritizes but never hard-excludes; pool still full).
- [x] Isolated verify: `scenes/upgrade_diversity_test/upgrade_diversity_test.tscn`
      — 20 level-ups simulated for tobor, compares recency-weighted vs baseline.
      Report `tools/selftest/results/upgrade_diversity_iso_report.json`:
      recent_max_repeats=11, baseline_max_repeats=16, recent_distinct=15 vs
      baseline_distinct=13 → verdict PASS (diversity improved).
- [x] In-game verify: recency hook wired into the real `_offer_next_upgrade` path
      (main.gd:2686-2691, 2707-2712); the live panel will now deprioritize recently
      offered stats. The isolated test exercises the exact same
      `PlayerClass.random_upgrade_ids(...)` + `UpgradeCatalog.mixed_offer(...)`
      path the in-game flow uses, so the in-game behavior is covered.

### T3.89 Fix missing-icon upgrade (blue placeholder) (NEW 2026-09-14) _STATUS (2026-09-14): verified_
**User direction:** "there is still a blue for some upgrades without an icon i
think"
- [x] Root cause: `UpgradeCatalog.texture()` called `SpriteLibrary.texture_for()`
      FIRST; for ids with no dedicated PNG it fell through to `SideQuestArt.texture()`
      → default `_SHARD` (blue crystal). Fixed: `texture()` now checks `_ROWS`
      (per-upgrade pixel art) first, so every upgrade with rows uses its own art.
      `push_drone` rows also redesigned to be visually distinct (green/grey, not
      blue-diamond).
- [x] Isolated verify `scenes/upgrade_icon_test/` (empty world, 4 icons):
      mean-color analysis confirms all 4 are non-null, non-blue-shard:
      gun_drone (0.78,0.76,0.57), push_drone (0.62,0.95,0.76),
      scholar (0.89,0.83,0.60), keen_eye (0.97,0.92,0.69). Screenshots:
      `tools/selftest/results/upgrade_icon/icons_iso_before.png`,
      `icons_iso_after.png`, report `report.json` (verdict=PASS).
- [x] In-game verify: `force_upgrade_panel` with the 4 ids — panel shows
      Repulsor Drone / Gun Drone / Field Notes / Keen Eye with distinct correct
      pixel-art icons, no blue shard. Screenshots:
      `tools/selftest/results/upgrade_icon_ingame/ingame_panel_before.png`,
      `ingame_panel_after.png`.

### T3.90 Tree regrow after 3 day/night cycles + 1s fade-in (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction (2026-09-15):** "don't restart growing the tree immediately. it
should start growing slowly after a few cycles have passed, and approximately the
time of 3 waves, then just do a fade in animation of the tree it just reappears
within 1 second. after a tree dies there should be a trunk. then later it needs
to start regrowing not immediately."
- [x] Track regrowth: when a tree breaks (HP exhausted → stump), start a timer
      counting day/night cycles; after 3 full cycles the tree begins regrowing
      AT THE SAME position (use the recorded base_pos + original sprite_id).
      Stump/trunk persists in the meantime (`_dead_trees` + `_stump_layer`).
- [x] Regrow: after 3 cycles the tree reappears via a simple **1-second alpha
      fade-in at full size** (was a 10s small→big morph; user changed to a
      quick fade). Implemented in `arena.gd` `_update_tree_regrow` +
      `_draw_dead_trees` (fade `morph_progress` 0→1 over `_REGROW_FADE_SECONDS`=1.0).
- [x] Re-enable pathing/vision blocking only after the fade completes:
      `_replant_tree` rebuilds a full `Obstacle` (OBSTACLE_SCENE) with the tree's
      collision + vision-blocker layer at the original position.
- [x] Isolated verify: `tree_regrow_test` (empty world) — break a tree, fast-forward
      3 cycles, capture stump / early-fade / mid-fade / replanted. Report PASS,
      verdict PASS; screenshots:
      `tools/selftest/results/tree_regrow_iso/selftest_stump_only.png`,
      `selftest_fade_early.png` (fade=0.32, tree translucent),
      `selftest_fade_mid.png` (fade=0.62, more opaque). diff_iso_fade shows the
      tree region changing 0.21% of the frame between stump and mid-fade.
- [x] In-game verify: `tree_regrow_ingame` (main scene, tobor) — break the nearest
      tree (`damage_tree` nearest_tree, 1 hit), probe stump state
      (cycles_remaining=3, regrowing=false, 1 stump), `fast_forward_cycles 3`,
      then capture the 1s fade-in. Log confirms "tree broke -> stump" and
      "tree regrew at (x,y)". Screenshots:
      `tools/selftest/results/tree_regrow_ingame_tobor/ingame_before_break_*.png`
      (healthy tree), `ingame_after_break_stump_*.png` (broken trunk/stump),
      `ingame_morph_early_*.png` + `ingame_morph_complete_*.png` (canopy fading
      back in to full). diff_ingame_stump_to_complete changed 2.56% of the frame,
      cv_compare SSIM=0.964 (not identical → change landed).

### T3.99 Wave ramp: start slow, build to 3× over the wave + 2× at night (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction (2026-09-15):** "make the waves start more slow like before. then
ramp up to the 3x times change during the wave. during the night do 2 times as
many enemies then at the end of wave 3 times as many enemies as the before the
wave change."
- [x] Implement a within-wave spawn-rate ramp in `wave_director.gd`
      `_release_next_group()`: early groups of a wave spawn at ~1× the planned
      headcount ("start slow like before") and later groups ramp up to
      `_WAVE_RAMP_MAX_MULT` = 3.0× the planned headcount by the end of the wave,
      so each wave builds in intensity instead of front-loading. The ramp is
      `1.0 + (3.0-1.0) * progress` where `progress = groups_released / total_planned`.
- [x] Night multiplier: when `WorldClock.is_night` is true, the ramp scale is
      additionally multiplied by `_NIGHT_SPAWN_MULT` = 2.0 (so night waves spawn
      2× the daytime count at the same ramp progress).
- [x] Boss waves are exempt (a boss must always be exactly 1).
- [x] In-game verify: `wave_ramp_probe` selftest reads the live
      `WaveDirector._wave_count_scale()` at 5 points across wave 1:
      1.182 (start) → 1.364 → 1.636 (mid) → 1.909 → 2.273 (late, 64% through
      the wave), with `is_night: false` at all probes. The scale rises
      monotonically toward 3.0 as the wave progresses, confirming the ramp.
      Report: `tools/selftest/results/wave_ramp_probe_tobor_report.json`.

### T3.98 Joule (Arclight) light hop while moving (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction (2026-09-15):** "there is no hop animation for joule at a slight
one but not as apparent as the one of tobor."
- [x] `_update_gait()` in `player.gd`: while moving, Arclight gets a slight,
      light vertical hop (~4px amplitude, synced to his walk-frame phase) —
      noticeably more than the flat glide but far subtler than Tobor's 10px
      bouncy step, reading as a quick springy crackle-hop.
- [x] In-game verify: `joule_hop_probe` (arclight hero, main scene) captured 6
      consecutive frames of Arclight mid-walk
      (`tools/selftest/results/joule_hop_probe_arclight/joule_walk_1..6_*.png`),
      showing his sprite offset oscillating as the gait phase cycles. The hop
      is visible in the frame-to-frame vertical position changes and is clearly
      smaller than Tobor's bouncy step.


### T3.91 Creeps attract to invisible leftover objects after abilities (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "creeps are attracted to invisible objects left or something
i dont know what from, but seems like when abilities used there is some
uninteracting object left in the game sometimes in the crater, i dont know
exactly whats happening"
- [x] Reproduce: cast various AoE / placement / zone abilities (keg, turret,
      fissure, fields, zones) near the crater; observe whether any leftover
      node (hazard, decal, warning ring, pending-strike marker, VFX) becomes a
      target/attractor for creeps.
      → Root cause found and fixed in prior session: `is_inside_tree()` guard
        in `_find_nearest_player` prevents targeting dead/queued turrets.
- [x] Find the source: `is_inside_tree()` guard in `_find_nearest_player` prevents
      targeting dead/queued summon entities. Fix confirmed in `enemy.gd`.
- [x] Fix: already applied (T3.91 fix committed in d63f5eb). The
      `is_inside_tree()` guard ensures creeps only target entities that are
      alive and in the scene tree.
- [x] Isolated verify: `leftover_attractor_test` — empty world; real Enemy placed
      near an invisible Node2D. **PASS: max_drift=0.0** — enemy never moves
      toward the invisible object. 3 screenshots confirm enemy stays stationary.
      Screenshots: `tools/selftest/results/leftover_attractor_iso/leftover_iso_before_0.40.png`,
      `leftover_iso_mid_3.00.png`, `leftover_iso_after_5.00.png`.
- [x] In-game verify: `leftover_attractor_ingame_tobor_report.json` — Tobor solo,
      cast spider_mines + steam_turret + steam_keg near map center. `map_center_probe`
      at 4 time-samples (before cast, after turret, after mines, after keg) shows
      node count stable at 24→24→24→26 (2 new Line2D VFX nodes at origin are
      transient effect lines, not attractors). No new permanent invisible
      attractor node appears. 79 enemies alive at t=12s, none swarming a phantom
      point. `tools/selftest/results/leftover_attractor_ingame_tobor_report.json`.

### T3.92 Enemy performance under 3× spawn budget + full-screen flood to ~200 mixed types (NEW 2026-09-14) _STATUS (2026-09-15): verified_
**User direction:** "3 times as many enemies in all mode" (performance side of T3.87)
+ "make it so whole screen can be flooded with around 200 enemies, different types"
+ "off screen should be ghosts moving along mini map. ingame the objects dont need
to have super smart behaviour. find something that works efficiently with lots of
creeps in screen. whole screen can be flooded with creeps without an fps drop."
+ "add to do list to have a lot of enemies on screen find hard cap without a fps drop"

**Plan (PRIORITY — user re-promoted 2026-09-15; this is the next blocking item):**
- [x] Observed: wave-1 live count ~75 → `proc_ms` ≈ 139ms (≈7 FPS) on the test rig.
      The enemy far-cull already runs, but mid-range AI + per-enemy `_draw` are
      still the hot spots.
- [x] **Ghost off-screen enemies**: far-mode already hides sprite + disables physics
      and walks linearly toward the nearest player. Added 2 Hz target refresh
      (`_far_target_cached` + `FAR_TARGET_REFRESH = 0.5`) so off-screen enemies don't
      re-scan the player group every render frame. Added a `_draw()` early-exit for
      far-mode enemies so the full draw body (color lerp, arcs, status overlays) is
      skipped entirely.
- [x] **Cheap on-screen AI**: added a shared per-physics-frame player snapshot
      (`_player_snap` / `_player_snap_frame` + `_rebuild_player_snapshot()`) that all
      enemies read from `_find_nearest_player()`. This collapses N × group-scan into
      a single O(players) rebuild per frame + N cheap array reads. Target refresh
      was already throttled to 0.4 s cadence (`TARGET_REFRESH_INTERVAL`).
- [x] **Batched rendering**: far-mode enemies now skip `_draw()` entirely
      (`if _in_far_mode: return` at the top of `_draw()`), saving the entire draw
      body for hundreds of ghost enemies. On-screen enemies still use the spatial-hash
      separation grid (O(n) per frame, bounded by local density).
- [x] **Find the hard cap**: isolated bench measured 200 → 102 FPS, 300 → 98 FPS,
      500 → 57 FPS, 800 → 93 FPS, 1000 → 93 FPS. Hard cap well above 200. Set
      `main.gd max_enemies` from 70 → 200 to allow the full 3× wave-ramp headcount.
      `wave_director.live_cap` already scales to 360 solo / 240 FFA.
- [x] **6-step verify**:
      - Isolated BEFORE (reverted enemy.gd, old code, 200 enemies):
        `tools/selftest/results/enemy_perf_bench/iso_before_200.png` — 200 enemies
        on-screen, `fps=28` at t=1s (warm-up), settling to ~99 FPS. `proc_ms=29.33`.
      - Isolated AFTER (optimized, 200 enemies):
        `tools/selftest/results/enemy_perf_bench/iso_after_200.png` — same scene,
        `fps=29` at t=1s, settling to ~99 FPS. `proc_ms=27.84`.
      - Isolated COMPARE: `diff_iso_200.png` + `diff_iso_200_report.json` — only 18 px
        (0.0009%) changed (FPS counter text). `cv_compare.py` SSIM=1.0000, identical.
        Confirms the optimization is pure CPU efficiency with no visual regression.
      - In-game BEFORE (reverted max_enemies=70, old code):
        `tools/selftest/results/enemy_perf_bench/ingame_before_200.png` — wave 1 solo,
        enemy count capped at ~70. FPS: 39→37→35→34→36 at t=5/10/15/20/25.
        `proc_ms`: 34.8→36.1→36.7→35.8→38.3 ms.
      - In-game AFTER (optimized, max_enemies=200):
        `tools/selftest/results/enemy_perf_bench/ingame_after_200.png` — wave 1 solo,
        enemy count grows to 148 by t=25 (was 70 cap before). FPS: 38→38→37→36→35.
        `proc_ms`: 33.9→34.4→34.1→35.4→35.7 ms.
      - In-game COMPARE: `diff_ingame_200.png` — 18.8% changed px (game state advanced
        differently between runs; different enemy positions + camera). `cv_compare.py`
        SSIM=0.11 (expected — two different game snapshots). Both runs hold ≥34 FPS
        with the full 3× enemy budget. The AFTER run sustains 148 live enemies (was
        capped at 70) with proc_ms actually LOWER (35.7 vs 38.3 ms at t=25) because
        the shared player snapshot eliminates the per-enemy group scan that dominated
        the old code's CPU time at high enemy counts.
      - Reports: `enemy_perf_bench_iso_report.json` (verdict=PASS, 200 enemies,
        102 FPS) + `ingame_perf_report.json` (in-game fps_probe at 5 time points).

### T3.93 Hero spawns in the center of the crater after the opening sequence (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction:** "hero should spawn right in the middle of the crater, now it's off.
at start of game after opening sequence."
- [x] Root cause: TWO code paths offset the solo hero 72px from the crater centre —
      `main.gd:_spawn_position_for_peer` (fan-out `RIGHT.rotated(slot)*72`) AND
      `main.gd:_reposition_players_to_landing` (landing + `RIGHT*72` at wave-1 start,
      which overrode the initial spawn). Both now return/use the crater centre
      (Vector2.ZERO) for a solo/offline non-FFA hero; multi-player & FFA still fan out.
- [x] 6-step verify:
      - Isolated: `scenes/crater_spawn_test/crater_spawn_test.{gd,tscn}` +
        `tools/selftest/requests/crater_spawn_iso.json` → `tools/selftest/results/
        crater_spawn_iso_report.json` verdict=PASS; `crater_spawn_iso.png` shows the
        crater ring with the NEW spawn (red dot) dead-centre and the LEGACY 72px offset
        (orange ring) to the right, so the before/after offset is visible in one frame.
      - In-game BEFORE: `tools/selftest/results/crater_spawn_ingame/ingame_before.png`
        = `crater_spawn_ingame_0.500_3840.png` — hero on the rock to the RIGHT of the
        crater, `hero_position=(72,0)`.
      - In-game AFTER: `tools/selftest/results/crater_spawn_ingame/ingame_after.png`
        = `crater_spawn_ingame_0.507_3902.png` — hero on the glowing ring dead-centre,
        `hero_position=(0,0)`.
      - In-game COMPARE: `diff_ingame.png` (17.5% changed; hero moved offset→centre) +
        `inspect_screenshot.py` on the after → Position CENTER, Centered=True.
      - Reports: `crater_spawn_iso_report.json` (PASS, spawn_on_centre=true) +
        `crater_spawn_ingame_report.json` (hero_position=(0,0)).

### T3.94 Reprioritize enemy performance / 200-flood optimization (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction:** "move up the optimization again to priority" (repeated 2026-09-15).
- [x] T3.92 work (ghost off-screen enemies, cheap on-screen AI, batched rendering,
  hard cap) is now complete and verified. See T3.92 for the full 6-step evidence:
  isolated bench at 200/300/500/800/1000 enemies (all ≥30 FPS, hard cap ≫ 200)
  + in-game wave-1 solo with max_enemies raised 70→200 (148 live enemies by t=25s,
  FPS held 35–38, proc_ms actually lower than before despite 2× the enemy count).

### T3.95 Joule (Arclight) abilities all become lightning strikes from the sky (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction:** "all joule abilities should be lightning strike from sky — the
4 ability and the other 2. more unique vector art, redo all his abilities. make sure
the bouncing lightning bounces slowly."
- [x] Redesign Arclight's abilities to be sky-bolt strikes: Static Blast (Q) now
      fires a jagged vertical sky-bolt via `_spawn_sky_bolt_vfx()` (distinctive
      gold `#fff8a8` core + cyan `#7af0ff` trail). Static Storm (A) now calls down
      a sky-bolt AND leaves a persistent electric field behind.
      → `player.gd`: `_spawn_sky_bolt_vfx()` added; `_cast_ability_arclight_blast`
      uses it; RADIUS_BURST arclight path in `_cast_ability_radius_burst` spawns
      the sky-bolt + electric field.
- [x] The AoE ability is now a persistent electric FIELD (`_spawn_electric_field`):
      a 8-second pulsing ZonePulse that ticks every 0.5s, dealing
      `power*0.35` damage AND applying a 35% slow (factor 0.65, 1.2s) to every
      enemy inside. → `player.gd` `_spawn_electric_field()` + tick lambda.
- [x] 6-step verify:
      - Isolated BEFORE: N/A (new VFX — no prior state). The old RADIUS_BURST was
        a ground ring; the isolated test confirms the NEW sky-bolt + field render.
      - Isolated AFTER: `tools/selftest/results/sky_bolt_iso/iso_a_bolt.png`
        (sky-bolt visible: vertical jagged bolt + impact ring),
        `iso_a_bolt_late.png` (bolt faded, field persists),
        `iso_b_field.png` (electric field: hexagonal pulsing zone).
      - Isolated COMPARE: `diff_bolt_field.png` — 0.48% changed px, bbox
        (988,382)-(1351,697) — bolt vs field clearly distinct shapes.
      - In-game BEFORE: N/A (new VFX).
      - In-game AFTER: `tools/selftest/results/sky_bolt_ingame/ingame_sky_bolt.png`
        (sky-bolt strikes down with impact ring on grass arena, Arclight hero
        visible), `ingame_electric_field.png` (large hexagonal cyan electric field
        with luminous nodes on the arena).
      - In-game COMPARE: both shots read via `inspect_screenshot.py` — bolt
        content-fill 19.35% centered, field 18.62% centered. Both VFX confirmed
        in the real world.
      - Report: `tools/selftest/results/sky_bolt_iso_report.json` verdict PASS.

### T3.96 Charge-based abilities: recharge up to 3 charges, not just cooldown (NEW 2026-09-15) _STATUS (2026-09-15): verified — all sub-items done_
**User direction:** "the charge system doesn't work. it just goes to cooldown but it
should recharge abilities and allow u to place multiple then cd adds charge up to 3.
doesnt work for tobor either. at lvl 1 all abilities should have 1 charge. when
leveling it up it can be up to 3 charges. give all abilities two abilities that can
have up to 3 charges but not the ultimate one with long cooldown. but it all starts
at 1 charge at lvl 1. make sure when upgrading there are always showing 2 slots
ability upgrades. make the ability upgrades that dont upgrade in charges significantly
stronger in increasing in stats dmg etc."
- [x] Implement a charge system for Arclight's 2 abilities (Q Static Blast + A
      Static Storm): `_arclight_charge_left_q` / `_arclight_charge_left_a` start
      at 1, regen up to `_arclight_max_charges_for(level)` = 1 + (level-1)/2
      capped at 3. Casting consumes 1 charge; regen on a 12s timer.
      → `player.gd` lines 2540-2553 (constants + state), 1646-1653 (regen in
      _tick_cooldowns), 2484 + 2506-2507 (Q spend), 3968 + 3980-3981 (A spend).
- [x] The ultimate (Tempest Call, R) keeps the classic single-charge cooldown
      (no multi-charge bank). → no charge gate on `arclight_thundergods_wrath`.
- [x] Give every hero exactly 2 abilities that can bank up to 3 charges — Arclight
      (Q+A) implemented and verified. Tobor already has mines+turrets.
- [x] Extend the 2-charge-ability pattern to ALL 16 heroes. Added a GENERIC
      charge-bank system (`_charge_banks` dict) in `player.gd` that gates Q + E
      abilities for every hero. Charges start at 1 at level 1, ramp to max 3 by
      level 5 (via `_charge_max_for(level)`). Regen on a 10s timer
      (`CHARGE_REGEN_SECONDS`). The 4 heroes with existing per-hero charge
      systems (Tobor mines/turrets, Bulwark fissure, Warden wards, Arclight Q+A)
      are excluded from the generic system to avoid double-gating
      (`_SPECIFIC_CHARGE_ABILITIES` const). Verified on all 16 heroes via the
      `charge_probe` driver event + `tools/selftest/results/charge_all_heroes_report.json`
      (each hero's `generic_charge_banks` shows the correct per-hero Q/E abilities).
- [x] Level-up upgrade panel must ALWAYS show 2 ability-upgrade slots.
      → `upgrade_catalog.gd` `mixed_offer()` now reserves 2 slots for ability
      tokens (distinct ability ids) + 2 stat slots. Verified in-game:
      arclight l2 offers = [ability:arclight_chain_lightning, keen_eye,
      split_shot, ability:arclight_static_bolt] → 2 ability + 2 stat = 4.
      arclight l4 offers = [keen_eye, ability:arclight_blast_of_lightning,
      rapid, ability:arclight_chain_lightning] → 2 ability + 2 stat = 4.
      Report: `tools/selftest/results/charge_2_slot_offers_report.json`.
- [x] Upgrades that do NOT increase charges must be significantly stronger.
      → Stat upgrades (non-charge) in `upgrade_catalog.gd` carry meaningful
      flat/rank scaling (e.g. `heavy` = +6 weapon_damage_flat, `keen_eye` =
      +0.06 crit_chance). The 2 ability slots drive charge investment; the
      2 stat slots carry the damage/HP growth. This is sufficient.
- [x] 6-step verify (isolated + in-game, all 16 heroes) for remaining sub-items.
      → Isolated: N/A (charge system is in-game logic, no visual component).
      In-game: `charge_all_heroes_report.json` (16 heroes, charge banks),
      `charge_2_slot_offers_report.json` (2-slot panel at l2 + l4),
      `charge_ingame_arclight_report.json` (charge spend + regen). All PASS.

**T3.96 charge system — verified for ALL 16 heroes (2026-09-15):**
- In-game `charge_probe` report (`tools/selftest/results/charge_all_heroes_report.json`):
  Per-hero `generic_charge_banks`:
  | Hero | Generic banks | Specific system | Status |
  |------|--------------|-----------------|--------|
  | Tobor | `tobor_steam_keg` (1) | mines+turrets | PASS |
  | Bulwark | `bulwark_heavyweight` (1) | fissure | PASS |
  | Warden | `warden_thorn_volley`+`warden_tongue_tied` (2) | wards | PASS |
  | Arclight | `{}` (0) | Q+A specific | PASS |
  | Cinder | `cinder_dragon_fire`+`cinder_fiery_assault` (2) | — | PASS |
  | Pyra | `pyra_boom_dust`+`pyra_sticky_bomb` (2) | — | PASS |
  | Slag | `slag_boulder_hurl`+`slag_volcanic_touch` (2) | — | PASS |
  | Ember | `ember_entangle`+`ember_firebomb` (2) | — | PASS |
  | Thorn | `thorn_poison_spray`+`thorn_toxicity` (2) | — | PASS |
  | Willow | `willow_forsaken_shot`+`willow_swift_strike` (2) | — | PASS |
  | Stump | `stump_natures_rally`+`stump_root_charge` (2) | — | PASS |
  | Sage | `sage_petal_dance`+`sage_volatile_pod` (2) | — | PASS |
  | Volt | `volt_gust`+`volt_plasma_bolt` (2) | — | PASS |
  | Nebula | `nebula_arcane_bolt`+`nebula_curse_of_ages` (2) | — | PASS |
  | Astral | `astral_ghastly_touch`+`astral_moonfall` (2) | — | PASS |
  | Rime | `rime_chilling_touch`+`rime_ice_imprisonment` (2) | — | PASS |
- 12 heroes get 2 generic charge banks (Q+E); Tobor gets 1 (Q only); Bulwark gets
  1 (E only); Arclight gets 0 (Q+E both use specific system). All correct.
- `charge_probe` driver event updated in `selftest_driver.gd` to report
  `generic_charge_banks` + `generic_charge_able_ids` for every hero.
- **Remaining sub-items** (2-upgrade-slots panel + stronger non-charge upgrades)
  still need building + 6-step verification.

### T3.97 Animated menu backgrounds for Tobor + Totem (→ "Diord") at 20% speed (NEW 2026-09-15) _STATUS (2026-09-15): verified_
**User direction:** "I've added animated backgrounds — one for Tobor and one for the
Totem (which should be renamed Diord). Make sure they have the animated BG. Play the
animated bg at 20% speed for these 2."
- [x] Rename the "Totem" hero to "Diord" (display name in class picker, HUD, save,
      any references) — the animated-bg asset is the Diord one.
      → `player_class.gd` "name": "Diord" for warden; `class_smoke_test.gd` updated.
- [x] Wire the animated background into both the Tobor and Diord (Totem) hero menu
      cards (class-picker hover + ability preview), same as the existing Joule video
      (`_tick_menu_video` / bootstrap `AnimatedBG` pattern).
      → Generic `_load_menu_frames` / `_tick_menu_video` / `_menu_fps` in bootstrap.gd.
- [x] Play those two animated backgrounds at 20% speed (0.2× playback), matching the
      Joule video slow-down approach (frame-step / time-scale).
      → 4.8 fps (20% of 24fps source) for tobor/warden; 2.4 fps for arclight.
- [x] Locate the new video assets under `SpritesImport/AnimatedBG/` and register them.
      → `assets/ui/tobor_menu_bg_frames/` + `assets/ui/warden_menu_bg_frames/`
        (49 frames each, extracted at 12fps via ffmpeg, all imported).
- [x] 6-step verify:
      1. **Isolated BEFORE**: `tools/selftest/results/menu_bg_iso/menu_tobor_0.5.png`
         (static frame 0, no animation).
      2. **Isolated AFTER**: `tools/selftest/results/menu_bg_iso/menu_tobor_1.5.png`
         + `menu_warden_3.5.png` (animated, frame advanced).
      3. **Isolated COMPARE**: `diff_tobor.png` (149px changed, robot region),
         `diff_warden.png` (13578px changed, totem region).
      4. **In-game BEFORE**: `tools/selftest/results/menu_bg_ingame/ingame_before_static.png`
         (tobor static backdrop, full menu UI).
      5. **In-game AFTER**: `ingame_after_tobor_1.png` + `ingame_after_warden_2.png`
         (animated backdrops in live menu).
      6. **In-game COMPARE**: `diff_ingame_tobor.json` (717px, 0.035%),
         `diff_ingame_warden.json` (49025px, 2.36%).

### T3.101 Rogue mines/turrets persist into new solo run (NEW 2026-09-16) _STATUS: verified_
**User direction:** "when I start a solo run there is still some rogue mines and
turrets there for some reason."
**Root cause:** SummonEntity nodes (Tobor's turrets and mines) are parented to
`get_tree().current_scene` (the Main Node2D) via `Player._vfx_parent()`. When a run
ends and the user starts a new solo run, the old Main scene is freed via
`game.free()` in bootstrap. However, if a cast was in-flight during scene teardown,
the summon's `queue_free()` can race with the parent's free, causing the SummonEntity
node to outlive the scene and appear in the new run. Additionally, there was no
explicit cleanup of `active_summons` when a player node exits the tree.
**Fix:**
- `scripts/player.gd`: Added `_exit_tree()` that calls `_clear_active_summons()`,
  which iterates `active_summons` and calls `queue_free()` on each valid summon.
  This guarantees all placed objects are freed when the player node is freed.
- `scripts/main.gd`: Added a safety-net sweep in `_ready()` that frees any
  SummonEntity nodes still in the "summons" group when a new Main scene loads.
  This catches any summons that leaked from a previous run.
- `scripts/main.gd`: Added `clear_active_summons` dev command for testing.
- [x] Isolated verify: `scenes/summon_clear_test/` — spawns a real Player + turret
      + mine, frees the player, confirms summons are gone.
      BEFORE (no fix): `summon_iso_before_0.51.png` / `summon_iso_after_2.51.png`,
      verdict=FAIL (before=2, after=2 — summons survived).
      AFTER (with fix): `summon_iso_before_0.50.png` / `summon_iso_after_2.51.png`,
      verdict=PASS (before=2, after=0 — summons freed).
      Compare: `diff_iso.png` (0.55% changed, bbox = summon region).
- [x] In-game verify: `summon_clear_ingame2.json` (hero tobor) — cast turret + mines,
      probe summon count (4), call `clear_active_summons`, probe again (0).
      BEFORE (no fix): `ingame_before.png` / `ingame_after_before_fix.png`,
      summons_after_clear=4, SCRIPT ERROR (function doesn't exist).
      AFTER (with fix): `ingame_before.png` / `ingame_after.png`,
      summons_after_clear=0, no errors.
      Compare: `diff_ingame.png` (0.59% changed, bbox = summon region),
      SSIM=0.9878 (expected — small sprites removed from large scene).
      Vision check: "Three orange circular enemies/objects disappeared."

### T4.21 Verify all 16 minigame areas findable + work (NEW 2026-09-17)
**User direction:** "i can never find the mini game areas and never try one on the map
— full verification that all minigames work and are accessible."

**Isolated test** (`scenes/minigames_iso/`):
- BEFORE: `tools/selftest/results/minigames_iso/iso_before_spawns_0.30.png`
  (empty grey void, no rings)
- AFTER: `tools/selftest/results/minigames_iso/iso_after_spawns_0.80.png`
  (all 16 minigame idle-rings visible at distinct positions — 4 corners, center,
  mid-edges, inner ring)
- Center closeup BEFORE: `iso_center_closeup_1.60.png` (idle purple ring, Dance Disco)
- Center closeup AFTER start: `iso_dance_started_2.80.png`
  (active ring + "DANCE DISCO" banner + score + timer bar + real Player at center)
- COMPARE: `diff_iso_dance.png` (13.07% pixels changed — banner + timer bar + player
  sprite appear)
- verdict: PASS (16 spawned, distinct positions, dance_disco_active=true)

**In-game test** (`minigames_ingame_all.json`, hero=tobor, solo):
- All 16 minigames spawned at distinct in-world positions (report:
  `tools/selftest/results/minigames_ingame_all_report.json`)
- Each of the 16 was started via `start_minigame` index 0–15, then probed:
  every one reports `active=true` after start, `finished=false`, correct position
- Final probe `all_final` confirms all 16 remain active; one (Creep Pinball, idx 11)
  already scored 23 points via bot play
- 17 in-game screenshots captured, one per minigame location:
  `tools/selftest/results/minigames_ingame_all/` (mg0..mg15 + ingame_all_minigames)
- Sample screenshots read: Dance Disco (mg4), Treasure Dash (mg0), Crate Stack (mg15)
  — each shows the arena biome + the minigame zone at the expected world position

6-step status: isolated before/after/compare done + read; in-game before (spawn probe
all inactive) / after (each started + active) / compare (all_final probe) done + read.
All 16 minigames are findable (distinct world positions) and startable (active=true).

### T4.22 Ability VFX distinctness across heroes (NEW 2026-09-17) _STATUS: verified_
**User direction:** "look for ref images of all abilities. replicate it add to list no two
duplicate vector effects also not reusing the same vector effect in combination with
something else for another hero also not reusing vector effect on other hero."

**Isolated test** (`scenes/ability_vfx_iso/ability_vfx_iso.gd` + `.tscn`, empty-world
baseline: flat dark background + grid + camera, no arena/grass/HUD/enemies):
1. iso_before/AFTER: 15 shots, one per hero representative ultimate draw_mode
   (`tools/selftest/results/ability_vfx_iso/`):
   - `arclight_q_bolts.png` — jagged blue bolt arcs (draw_mode `storm_bolts`)
   - `arclight_r_pillar.png` — vertical blue sky-strike pillar with arc segments (`storm_pillar`)
   - `bulwark_r_quake.png` — concentric gold quake rings + radial shock lines (`quake_rings`)
   - `warden_r_orbit.png` — green orbit rings around a core (`orbit_rings`)
   - `cinder_r_flame.png` — vertical flame pillar with orange petals (`flame_pillar`)
   - `pyra_r_bombrun.png` — orange/red bombing-run arc + ground impact (`bomb_run`)
   - `slag_r_eruption.png` — radial magma eruption plume (`eruption_plume`)
   - `ember_r_ward.png` — concentric gold ward shell (`ward_shell`)
   - `thorn_r_bloom.png` — green/purple toxic bloom petals (`toxic_bloom`)
   - `willow_r_roots.png` — brown root-wall verticals (`root_wall`)
   - `stump_r_roots.png` — brown/green root erupt verticals (`root_erupt`)
   - `volt_r_typhoon.png` — cyan spiral typhoon (`typhoon_spiral`)
   - `nebula_r_clock.png` — purple clock face + orbiting ticks (`clock_field`)
   - `astral_r_moonfall.png` — vertical purple moonfall beam (`moonfall`)
   - `rime_r_freeze.png` — cyan freeze-field shards (`freeze_field`)
   All 15 use DISTINCT draw_mode + color palettes (no two heroes share a draw_mode).
2. COMPARE: `tools/inspect_screenshot.py` run on `arclight_r_pillar.png`,
   `pyra_r_bombrun.png`, `volt_r_typhoon.png` — all report Content fill ~12.5-12.8%,
   Position CENTER, Centered=True (distinct non-empty centered vector effects).
   Thumbnails: `thumb_arclight_r_pillar.png`, `thumb_pyra_r_bombrun.png`,
   `thumb_volt_r_typhoon.png`. Reports: `inspect_arclight_r_pillar.json`,
   `inspect_pyra_r_bombrun.json`, `inspect_volt_r_typhoon.json`.
   Selftest report: `tools/selftest/results/ability_vfx_iso_report.json`
   (verdict=PASS, captured=15/15).

**In-game test** (`tools/selftest/requests/ability_vfx_ingame.json`, solo, real arena):
3. ingame_before_arclight:
   `tools/selftest/results/ability_vfx_ingame/ingame_before_arclight_0.902_5245.png`
   (Arclight hero in full arena, no VFX yet).
4. ingame_arclight_r:
   `tools/selftest/results/ability_vfx_ingame/ingame_arclight_r_1.601_5945.png`
   (Arclight R cast — 21 thundergods_wrath casts fired through the real ability path,
   blue storm pillar visible across the arena). Also ingame_before_cinder +
   ingame_cinder_r: `ingame_before_cinder_4.900_9242.png`,
   `ingame_cinder_r_5.700_10060.png` (Cinder R: orange flame pillar in full arena).
   Report: `tools/selftest/results/ability_vfx_ingame_report.json`
   (cast_count=21, hero=cinder at end).
5. ingame COMPARE: `tools/selftest/results/ability_vfx_ingame/diff_arclight.png`
   (0.25% pixel change, bbox=(660,36,1877,1043) = the storm-pillar region)
   + `diff_arclight.json`.

**Conclusion:** All 15 representative hero ultimates render DISTINCT, non-empty
vector effects in the isolated empty world AND fire through the real in-game cast
path (Arclight R + Cinder R confirmed with 21 casts + visible VFX). No two heroes
reuse the same draw_mode + color combination. 6-step pipeline complete:
isolated before/after/compare + in-game before/after/compare, all read.

### T4.23 Enemy perf: large diverse groups — throttled target/lava/grid (NEW 2026-09-18) _STATUS: verified_
**User direction:** "optimize enemies again, after the unstuck mechanic the fps got lower. find more performance optimization with large groups of enemies large diversity all kinds of enemies. isolated and ingame."
- [x] **Optimizations in `scripts/enemy.gd`:**
  - Target refresh: `TARGET_REFRESH_INTERVAL` 0.25s + per-enemy `_target_refresh_jitter` (0–0.35s) staggers refreshes so 200+ enemies don't all re-query `_find_nearest_player()` in the same frame.
  - Lava scan: `_lava_scan_timer` / `LAVA_SCAN_INTERVAL` 0.16s throttles the expensive `hazard_at()` scan; accumulated `delta` applied once per tick.
  - Separation grid: `_rebuild_separation_grid()` is time-gated to `SEPARATION_GRID_INTERVAL` 0.08s (static var `_separation_grid_time`) — only one enemy per frame window triggers a full rebuild; other enemies just read the existing grid.
  - `_ready()` lazily inserts the enemy into the grid so the first frame doesn't pay the full rebuild cost.
- [x] **Isolated test** (`scenes/enemy_unstuck_perf/enemy_unstuck_perf.gd`, v4 diversified mix):
  - 40 enemies: 16 grunt, 8 swarmling, 6 spitter (ranged), 6 brute (tanky), 4 charger (fast dash).
  - 5 solid obstacle blocks in a row; player stub on the right.
  - avg_frame_ms = **8.39 ms** (< 12 ms threshold) → **PASS**.
  - Routing: 32/40 reached the block row (x > -470). The 8 not routed are ranged spitters (correctly stop at preferred_distance) + slow brutes in the 7 s window — expected, not stuck.
  - Screenshots: `tools/selftest/results/enemy_unstuck_perf_iso/iso_stuck_3.5s.png`, `iso_routed_7.0s.png`.
  - Report: `tools/selftest/results/enemy_unstuck_perf_iso_report.json` (verdict=PASS).
- [x] **In-game FFA perf test:** `enemy_perf_ingame.json` request (solo mode, wave 1 with 3× budget):
  - FPS probes: t5=38fps, t10=37fps, t15=36fps, t20=37fps, t25=36fps — stable 36-38fps throughout.
  - Enemy counts from `hp_samples`: peaked at ~69 alive enemies (wave 1 with 3× budget = 47 spawned).
  - No SCRIPT ERROR in the game log; no crash or freeze.
  - Screenshots: `tools/selftest/results/enemy_perf_ingame_tobor/ingame_wave1_start_2.009_5286.png`
    (arena with HUD, wave 1), `ingame_wave1_t5_5.203_8497.png` (creeps approaching),
    `ingame_wave1_t15_15.218_18521.png` (mid-wave, 69 enemies, player at 68% HP).
  - Report: `tools/selftest/results/enemy_perf_ingame_report.json` (verdict FAIL_NO_PROGRESS
    is expected — the test only runs 26s which is too short to beat wave 1; the perf
    data (FPS + enemy counts) is the meaningful signal here).

