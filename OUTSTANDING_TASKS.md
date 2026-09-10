# OUTSTANDING TASKS — Rift Survivors (Phase 1)

_Last updated: 2026-09-10_

This is the running checklist of work for the game. It's grouped by priority and
marked with status. Use it to see what's done, what's in progress, and what still
needs to be verified or finished.

---

## P0 — Critical / Blocks Gameplay

| ID | Item | Status | Notes |
|----|------|--------|-------|
| game_boots | Game boots and reaches gameplay | ✅ Done | Root cause was a duplicate `_draw()` in `summon_entity.gd` and an untyped `destination` var in `player.gd` (`_cast_ability_blink`). Both fixed; clean `--import` and boot probe PASS. |
| default_map | Default world = user's `grass_real` map | ✅ Done | `autoload/game_runtime.gd → editor_level_path()` now returns `user://world_editor_level_grass_real.json` when no custom name is set. Verified via `probe_boot` + landmark positions match. |
| grass_real_integrity | Don't clobber the saved `grass_real.json` (6744 props) | ✅ Done | `run_ui_verify.ps1` backs up / restores the editor level; confirmed `grass_real.json` still has 6744 obstacles after runs. |

## P1 — High / Core Feel

| ID | Item | Status | Notes |
|----|------|--------|-------|
| house_art | Houses match the 2 reference images | ✅ Done (needs eyeball) | `town_house` = A-frame thatched (tan roof, stone base, red arched door, round gable window). `town_house2` = semi-iso timber-frame (grey tiled roof, yellow walls, dark cross-brace beams, teal shutters, orange door). Baked via `tools/gen_town_art.gd`. |
| house_size | Houses 1.5× bigger than before | ✅ Done | `scripts/obstacle.gd → display_zoom()`: town multiplier `1.8 → 2.7`. |
| camera_zoom | Default camera zoom 1.5× | ✅ Done | `scenes/player/player.tscn` Camera2D zoom `0.4444 → 0.6666`. `hud.gd` resolution rescale keeps zoom unchanged, so no override. |
| previews | Main-menu ability previews work | ✅ Done | Was broken by the P0 parse cascade (blocked `Player`/`Enemy` preloads). UI-verify `probe_preview_screen_visible` = 1.000. LMB projectile, transparent background, muted audio all present. |
| save_as_load | World editor: Save As (name it) + Load picker | ✅ Done | `scripts/world_editor.gd`. Save As writes `user://world_editor_level_<name>.json`; Load lists the folder. `LineEdit.text_submitted` (Godot 4 API) wired. |

## P2 — Medium / Polish

| ID | Item | Status | Notes |
|----|------|--------|-------|
| dash_smooth | Dashes move smoothly point-to-point | ✅ Done | `player.gd → _dash_to()` tweens `global_position`; used by blink, dash_strike, windstep. |
| vfx_dedup | No stacked/repeating vector effects | ✅ Done | `main.gd`: `_active_vector_fx` + cap `_MAX_CONCURRENT_VECTOR_FX_PER_ABILITY = 3`. |
| vfx_ult | Ultimates last ~2× longer | ✅ Done | `main.gd → _ULT_ABILITY_IDS` + `lifetime_scale = 2.0`. |
| vfx_vectors | Pixel-art abilities get a distinct vector VFX | ✅ Done | `ability_preview_world.gd` `VECTOR_ONLY_KIT_IDS` mirrors `main.gd`. |
| turret_hp | Turret / summon health bars | ✅ Done | `summon_entity.gd` `_draw()` includes HP bar (only when damaged, color by fraction). |
| recruit_areas | 4 themed recruitment areas + bot recruit | ✅ Done | `recruit_areas.gd`; themed art; bot behavior recruits + fights. |
| grass_edges | Dense ground cover on map edges | ✅ Done | `arena.gd → _top_up_ground_cover()` fills gaps after loading a saved level. |
| selftest_hang | "Steam hang" resolved | ✅ Done | It was actually the P0 parse cascade, not Steam. |

## P3 — Low / Needs User Verification

| ID | Item | Status | Notes |
|----|------|--------|-------|
| visual_qa_houses | Confirm new house art reads well in-game | ⏳ Needs you | Eyeball the town cluster (top-left of Verdant Hollow). |
| zoom_qa | Confirm 1.5× zoom feels right | ⏳ Needs you | If too tight/wide, adjust `player.tscn` Camera2D zoom. |
| map_qa | Confirm default map is the dense `grass_real` world (no sparse town) | ⏳ Needs you | Solo + FFA launch. |

## Known Bugs / Risks

- **`grass_real.json` is in `user://`** — it lives in
  `%APPDATA%\Godot\app_userdata\Rift Survivors\` and is NOT in the git repo.
  A backup copy is committed at `assets/levels/grass_real.json`. If the user
  profile is wiped, the default map falls back to procedural. Consider adding a
  "restore default map from repo" button in the editor.
- **Selftest runner is sensitive to any parse error** — a single script parse
  error anywhere cascades into a non-boot and looks like a "hang". Keep a habit
  of running `godot --headless --import` after script edits.
- **UI-verify screenshots pile up** in `tools/selftest/results/ui_verify/` —
  these are committed; consider gitignoring the `.png` / `.import` shot files.
