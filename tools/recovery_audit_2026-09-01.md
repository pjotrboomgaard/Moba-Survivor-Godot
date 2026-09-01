# Recovery Audit — 2026-09-01

Read-only catalog of features implemented in the past 24 h (Aug 30 21:00 → Sep 1 20:00 UTC+2)
and their current status in the working tree of branch `pjotrboomgaard`.

**How to read the status column**

| Status | Meaning |
|---|---|
| **present** | Feature's code/data exists in the current tree and is wired to a live call path. |
| **degraded** | Code exists but is partially broken, mis‑keyed, disconnected from its UI, or failing its own tests. |
| **lost** | Feature was implemented (per transcript) but no longer exists in the live code path. |

**Grounding evidence used**
- Godot 4.7.2 headless `--editor --quit` import pass → **no parse errors** (build is syntactically loadable).
- `class_smoke_test.tscn` headless run → **exits 1 with 56 FAIL lines** (stale expectations + missing assets).
- Headless `--check-only` **crashes** (exit `-1073741819`) and full `--check-only --path .` **hangs in the Steam lobby thread** → the bare "headless boot" the workspace rule relies on is currently wedged.
- Transcript `ebac881b-…jsonl` + 35 recovery sub‑transcripts.

---

## Executive summary — the one catastrophic event

Around **Sep 1 17:49** a working `player_class.gd` (≈2312 lines, full HoN rework) was **clobbered to an
861‑line stub** containing only 5 hero IDs and no `World` enum. The transcript's assistant notes this directly
("*player_class.gd is gone or empty!*", "*861 lines, 5 hero IDs, no World enum*").

Recovery agents then rebuilt the **data layer** (`player_class.gd` is now 2393 lines, 17 heroes, `enum World`,
48 kit refs all resolvable) — but the rebuild **re‑keyed kit ability IDs** (`cinder_blazing_pillar` →
`cinder_pillar_of_flame`, `sage_grace_of_the_nymph` → `sage_grace`, `stump_rally` → `stump_natures_rally`, etc.)
while the **runtime cast table, VFX map, targeting table, and icon/animation assets still use the old IDs**.
That single key drift is what produces the 56 smoke failures and most of the "abilities feel missing" reports.

A second, separate loss: the **entire menu/lobby/loadout UI overhaul** (world tabs, per‑world hero cards,
4‑slot loadout panel with ability icons, MP lobby loadout readout) only survives in the orphaned
`scenes/bootstrap/bootstrap.gd.bak_1788284305` (1302 lines). The committed `bootstrap.gd` reverted to the
**old 4‑button 5‑hero menu** (805 lines), and `bootstrap.tscn` reverted to 4 `ClassButton`s + no
`LoadoutPanel`/`WorldRow`/`AbilityPool` nodes.

---

## A) Heroes + abilities

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| A1 | 17 heroes total (tobor/arclight/bulwark/warden/frostbinder + 12 non‑robot) | **present** | `player_class.gd` now (2393 lines), `CLASSES` = 17 entries, `enum World` + `world_of()` | `scripts/player_class.gd` | None — data intact. (frostbinder slated for removal but still present; sprite has front only.) |
| A2 | 16 hero renames (Tobor→Wrench, Cinder→Blaze, Arclight→Joule, Bulwark→Tremor, Warden→Totem, Stump→Keeper, …) | **degraded** | Transcript 31 Aug → 1 Sep, names present in `CLASSES` now | `scripts/player_class.gd` | Names are in the data, but the smoke test still asserts old names (`Diord/Romra/Enord`) → test is stale AND any code keyed on old display names breaks. Update test + cross‑references. |
| A3 | 48 HoN kit abilities (16 heroes × Q/E/R) with definitions | **present** | Every `kit_q/e/r` ref resolves to an `ABILITIES` entry (48/48 verified) | `scripts/player_class.gd` | Definitions present; **see A5/B5** — several robot‑hero kit IDs have no icon/cast anim and the runtime cast table is keyed to old IDs. |
| A4 | 9 alternates per hero in `ability_pool` (12 pool abilities each) | **present** | `ability_pool` arrays present in all 17 entries | `scripts/player_class.gd` | None — data intact. |
| A5 | Kit‑specific icons (per‑hero shape + accent) | **degraded** | `SHAPE_KIT` commit `f0d2ffe` (Sep 1 19:52) landed icon vectors; **smoke reports `has no icon` for all renamed robot kits** (`tobor_steam_keg`, `tobor_energy_absorption`, …) | `tools/sprite_forge.gd`, `tools/sprite_art.gd`, `assets/sprites/*.png` | Icons exist as vectors in the forge, but PNG `<ability_id>.png` assets were **not regenerated for the renamed IDs**. Re‑run `tools/sprite_forge` after ID table is final. |
| A6 | Kit‑specific vector VFX (`KitFxLibrary` palette, `VECTOR_ONLY_KIT_IDS`) | **degraded** | `6404ad8` (Sep 1 19:44) added `kit_fx_library.gd` (397 lines); `main.gd` consumes `KitFxLibrary.kit_visual()` | `scripts/kit_fx_library.gd`, `scripts/main.gd`, `scripts/lightning_effect.gd` | `kit_fx_library.gd` is keyed to **old** IDs (`cinder_blazing_pillar`, `cinder_blazing_strike`) while data uses new IDs → `kit_visual()` misses. Re‑key the library to new IDs. |
| A7 | Two‑stage targeting for aimed abilities (press‑to‑arm → press/click‑to‑cast, HUD glow) | **present (data) / degraded (key drift)** | `TARGETED_ABILITIES` table + `_arm_or_confirm_ability()` in `player.gd` | `scripts/player.gd` | Table uses mixed old/new IDs (`cinder_blazing_pillar` old vs new); confirm each hero's kit keys match `CLASSES`. HUD "armed glow" is NOT in `hud.gd` (no armed/pending highlight) → add. |

---

## B) Game mechanics

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| B1 | Meta‑progression: sparks / hero shards / masteries / unlockable abilities | **degraded → partially lost** | Transcript 30 Aug–1 Sep; `main.gd` still calls `grant_sparks`/`hero_shards`/`sparks`/`bank_wave_progress` | `autoload/player_profile.gd`, `autoload/progression_service.gd`, `scripts/main.gd` | **`player_profile.gd` (106 lines) is a stub:** it *calls* `PlayerProfile.sparks`, `grant_sparks()`, `hero_shards`, `unlocked_heroes`, `unlock_hero()`, `bank_wave_progress()` but defines **only** `sparks_for_wave()` + a hollow `bank_wave_progress()` that returns `{"newly_unlocked": [], "banked": 0}`. Runtime will throw on first milestone/masteries/shard path. Rebuild the banked‑shards + mastery + `grant_sparks`/`unlock_hero` state and persistence. |
| B2 | Shop / level‑up menu integration with ability drafting | **present** | `_queue_wave_draft()` (every 3rd wave), `ability_offer_ids()` | `scripts/main.gd`, `scripts/player_class.gd` | None for core draft; smoke shows offer‑pool drift (`missing arclight_overcharge/…`) because offer pool keys differ from ability table — fix keys. |
| B3 | Wave‑5 ability reward flow + game‑over reward flow | **present (calls) / lost (state)** | `main.gd:770‑790` (wave‑5 spark banking), `main.gd:1415‑1435` (end‑of‑run banking + `show_game_over`) | `scripts/main.gd`, `autoload/player_profile.gd` | Call sites live, but they invoke `PlayerProfile` methods that are stubs (B1) → rewards never actually bank. Restore profile methods. |
| B4 | Rift Clash mode stub (`RiftClashManager` autoload) | **present (wired)** | `autoload/rift_clash_manager.gd` + `main.gd` team assignment/anchors/eliminations extensively wired (lines 536‑833) | `autoload/rift_clash_manager.gd`, `scripts/main.gd`, `project.godot` | Present and registered as autoload. Team mode logic is intentionally a no‑op stub ("safe default"), so wiring is live but the mode itself is unimplemented by design for this pass. |
| B5 | `ProgressionService` + `RankService` autoloads | **present (autoloads) / degraded (ProgressionService)** | `06dddb8` (Sep 1 19:13) added stubs; both registered in `project.godot` | `autoload/progression_service.gd`, `autoload/rank_service.gd` | `RankService` is fully implemented (tiers, deltas, persistence). `ProgressionService` calls `PlayerProfile.unlocked_heroes`/`hero_shards`/`HERO_SHARDS_TO_UNLOCK`/`unlock_hero` — **none exist** → will error. Tie to restored profile (B1). |
| B6 | Ultimate abilities unlocked from start | **present** | `PlayerProfile.is_ult_unlocked()` returns `true` unconditionally; `main.gd` comment "Ultimates ship with the hero from the start now" | `autoload/player_profile.gd`, `scripts/main.gd` | None — implemented as unconditional `true`. |

---

## C) World / map

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| C1 | Multi‑world system (Iron Foundry / Ashen Caldera / Verdant Wilds / Storm Court) | **present (data)** | `Arena.set_world()`, `WORLD_NAMES`, `arena.gd` swaps palette/pads/obstacles/landmarks | `scripts/arena.gd`, `scripts/player_class.gd` (`enum World`) | World swapping works in engine. **But the main‑menu world *picker* UI is lost (E1).** `ids_in_world`/`WORLD_ORDER`/`world_name` statics the `.bak` menu used are **missing** from `player_class.gd` → re‑add for the menu. |
| C2 | Landmarks (`Arena.landmarks` + interactable pads) | **present (renamed class)** | `ArenaLandmark.gd` (new), `Arena._spawn_landmarks()` + `main.gd` `_on_landmark_triggered` effects | `scripts/arena_landmark.gd`, `scripts/arena.gd`, `scripts/main.gd` | Working. Note: legacy `scripts/landmark_button.gd` (class `LandmarkButton`) still exists alongside new `ArenaLandmark`; `landmark.gd` was deleted. Pick one canonical class. |
| C3 | Desaturated / biome terrain art | **present** | `tools/tobor_world_art.gd` `TERRAIN_SAT_ADJUST := 0.70` (+ luminance lift) | `tools/tobor_world_art.gd` | Present — user asked for muted grass‑meadow feel and it is wired. |
| C4 | Old vs new map layout | **degraded (singular uniform layout)** | `arena.gd` comment: "Original, pre‑biome open‑field layout: uniform BASE_SIZE … no longer balloons the playfield, carves it into island pads, or floods it with lava voids" | `scripts/arena.gd` | `SIZE_BY_BIOME` flattened to 5× `2400×1600`. Smoke asserts "**Ice must be larger than volcano**", "**Lava must block**", "**Volcano islands not flat field**" → the rich per‑biome layouts the user remembers are **flattened**. Choose: restore per‑biome geometry or accept uniform. |

---

## D) Visuals

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| D1 | Pixel‑art animated hero sprites (4 directions per hero) | **present (16/17)** | `assets/sprites/<hero>{,_left,_right,_back}.png` verified for 16 heroes; frostbinder = front only | `assets/sprites/*.png`, `tools/sprite_art.gd` | Regenerate frostbinder 4‑dir (or remove frostbinder). Otherwise present. |
| D2 | Heroes bigger on screen | **present** | `player.gd` `HERO_SCALE_BOOST := 1.25`, `_hero_sprite_scale()` | `scripts/player.gd` | None. |
| D3 | Ability icons (per‑kit distinct, not generic shape) | **degraded** | `5476` PNGs in `assets/sprites/`; but smoke `has no icon` for all renamed robot kit IDs | `assets/sprites/*.png`, `tools/sprite_forge.gd` | Icons exist for old IDs; new kit IDs lack `<id>.png`. Re‑run sprite forge after re‑keying (A5). |
| D4 | Vector‑only VFX (`LightningEffect`) replacing pixel‑art explosions | **present** | `lightning_effect.gd` `style` match (BOLT/BURST/BLAST/ARC), consumed by `main._play_ability_effect` | `scripts/lightning_effect.gd`, `scripts/main.gd` | Present; degrade only via `KitFxLibrary` key drift (A6). |
| D5 | Projectile sprites (Keg traveling) | **present** | `projectile_sprite.gd` (50 lines) + `scenes/effects/projectile_sprite.tscn`; `player.gd` keg uses it | `scripts/projectile_sprite.gd`, `scripts/player.gd` | Present. |
| D6 | Summon entities (Turret / Mine visuals) | **present** | `summon_entity.gd` (210 lines) + `player.gd` `_cast_ability_wrench_turret/_mines`, `WRENCH_MAX_MINES` | `scripts/summon_entity.gd`, `scripts/player.gd` | Present. |
| D7 | Zone pulses (Energy Field visuals) | **present** | `zone_pulse.gd` (77 lines) + `scenes/effects/zone_pulse.tscn` | `scripts/zone_pulse.gd` | Present. |
| D8 | Audio: hero‑themed ability sounds | **present (assets) / degraded (key mapping)** | 34 `.wav` in `assets/audio/themes/<hero>{,_2,_3}.wav`; `AudioService.play_ability()` exists | `assets/audio/themes/*.wav`, `autoload/audio_service.gd` | Themes exist. Sep 1 sub‑agent reported the bank "doesn't differentiate by hero theme / falls back to generic cast" → re‑map `play_ability`→hero theme by (renamed) hero id. |

---

## E) UI / Lobby

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| E1 | Main menu showing 17 heroes + 4 worlds (world tabs + per‑world hero cards) | **LOST** | `.bak_1788284305` (1302 lines) `_build_world_tabs()`, `ids_in_world(...)`, world tabs | `scenes/bootstrap/bootstrap.gd`, `scenes/bootstrap/bootstrap.tscn` | **Live `bootstrap.gd` reverted to old 4‑button menu** (`ClassGrid` has `ClassButton0..3`, `_build_class_selection` caps at `child_count`). Restore from `.bak`: re‑add `WorldRow`, world tabs, per‑world filtered hero cards, and matching `PlayerClass` statics (`WORLD_ORDER`, `world_name`, `ids_in_world`). |
| E2 | Loadout panel for assigning 4 abilities per hero (3 + ULT, clickable slot icons) | **LOST** | `.bak` `LoadoutPanel`, `LoadoutRow` Slot1/2/3/Ult, `AbilityPool` grid, `_refresh_loadout_panel()` | `scenes/bootstrap/bootstrap.gd`, `scenes/bootstrap/bootstrap.tscn` | Restore `LoadoutPanel` + `AbilityPool` nodes from `.bak` (and their `.tscn` nodes), wire to `PlayerProfile.loadout_for()`. |
| E3 | Multiplayer lobby showing selected abilities per picked character | **LOST** | `.bak` roster/loadout slots replicated per member (`lobby_roster`, slot labels) | `scenes/bootstrap/bootstrap.gd` | Restore `.bak` lobby roster + per‑member loadout replication. |
| E4 | HUD showing ability slots with distinct icons + cooldowns | **degraded** | `hud.gd` `_refresh_ability_bar()` shows text lines `1 Name (Rk n) READY/x.x s` — **text only, no icons, no armed‑glow** | `scripts/hud.gd`, `scenes/ui/hud.tscn` | HUD bar exists but is plain text; add per‑slot icon buttons with cooldown sweep + armed highlight (A7). |

---

## F) Systems / infrastructure

| # | Feature | Status | Last known good | Files | To restore |
|---|---|---|---|---|---|
| F1 | Self‑test harness (`SelfTestDriver.gd` + `tools/selftest/*`) | **present** | `selftest_driver.gd` (317 lines), 37 request JSONs (kit_audit_*/twostage_*), `_drive.py` | `scripts/selftest_driver.gd`, `tools/selftest/` | Present; driver still references legacy `LandmarkButton`→ now fixed to `ArenaLandmark` in working tree. |
| F2 | Sprite forge reforge works | **degraded** | `tools/sprite_forge.gd` `_ready()` bakes grids→PNG, `_write_tobor_pawns`, `_write_contact_sheet` | `tools/sprite_forge.gd` | Forge runs, but **has not been re‑run for renamed kit IDs** → missing icon/cast‑anim PNGs (A5/D3). Re‑run after ID table final. |
| F3 | Smoke test suite passes | **lost** | `tests/class_smoke_test.gd` → **exits 1, 56 FAILs** | `tests/class_smoke_test.gd` | Two causes: (1) test fixture is **stale** (asserts old names Diord/Romra/Enord, frostbinder, old world sizes, frostbinder slow); (2) real gaps — missing new‑kit icons/cast anims + several archetype handlers (Vital Surge/Fortify/Provoke/Track/Thunder Step) no longer fire. Update fixture + re‑key + repair handlers. |
| F4 | Headless boot test passes | **degraded** | Editor import pass clean (no parse errors), **but** bare `--check-only --path .` crashes (`-1073741819`) / hangs in Steam thread | `project.godot`, autoloads | Boot *imports* clean; the headless boot the restart‑rule relies on wedges on Steam. Add a no‑Steam/CI flag guard to `SteamService` or guard boot for headless. |

---

## Status counts

Counted by feature row (A1–F4, 33 rows). Some rows carry a dual status (e.g. "present (calls) /
lost (state)"); the first **bold** token in the Status cell is what is tallied below, and the
parenthetical qualifier explains the split.

| Status | Count |
|---|---|
| **present** | 12 |
| **degraded** | 9 |
| **lost** | 4 |
| **dual‑status rows** | 8 (counted once under their first token, above) |
| **total catalogued rows** | 33 |

**Lost (gone from live path):** B3‑profile‑state, E1 (17‑hero + world‑tab menu), E2 (loadout panel),
E3 (MP lobby loadout readout), F3 (smoke suite green).

> Note: several "present" items (B1 call sites, C1 world swap) only work end‑to‑end once their
> dependencies in the **lost/degraded** rows are restored — most importantly `player_profile.gd`
> (B1) which is the linchpin for B1/B2/B3/B5 and the `.bak` menu (E1/E2/E3).

---

## Top rebuild priorities (highest leverage first)

1. **Rebuild `autoload/player_profile.gd` progression state** — add `sparks`, `hero_shards`,
   `unlocked_heroes`, `unlock_hero()`, `HERO_SHARDS_TO_UNLOCK`, full `bank_wave_progress()`
   (mastery + newly‑unlocked), `grant_sparks()`, and persistence for all of it. Currently a 106‑line
   stub that *references* methods it never defines — first milestone/shard path will error.
2. **Reconcile ability‑ID keys across 4 tables** — `CLASSES` kit refs ↔ `ABILITIES` ↔ `TARGETED_ABILITIES`
   (`player.gd`) ↔ `KitFxLibrary.KIT_VISUALS` ↔ sprite/icon PNGs. One canonical ID set; then re‑run sprite forge.
3. **Restore the menu/lobby/loadout UI** from `scenes/bootstrap/bootstrap.gd.bak_1788284305` into live
   `bootstrap.gd`/`bootstrap.tscn`, and re‑add `PlayerClass.WORLD_ORDER` / `world_name()` / `ids_in_world()`.
4. **Update + fix the smoke suite** — refresh stale name/world expectations *and* repair the broken
   archetype handlers (Vital Surge / Fortify / Provoke / Track / Thunder Step); target 0 FAILs.
5. **Decide the map layout** — restore per‑biome geometry (islands/lava/sizes) or delete those smoke asserts.
6. **Guard headless boot** from the Steam thread so `--check-only`/CI stop crashing/hanging.
