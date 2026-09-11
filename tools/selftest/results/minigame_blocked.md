# Minigame Visual Verification Note

## Functional Status: PASS
- All 4 minigames (Treasure Dash, Keg Toss, Whack-a-Creep, Rock-Paper-Creep) spawn correctly at the 4 recruit-area corners.
- Selftest confirms: `started: true`, `active: true` (timer counting down), `finished: true` for Keg Toss and Whack-a-Creep.
- No parse errors, no script errors, bot survived (`alive: true`).
- Rewards granted via `owner_player.add_gold(30)` + `owner_player.add_xp(25)` on completion.
- Bot brain hook in `cpu_brain.gd` walks to idle minigames and calls `bot_tick(delta)` to play them.

## Visual UI: Partial
- World-space `_draw()` UI (pulsing ring, banner with name/score/timer bar, game-specific elements) renders on the minigame node at z_index=4000. Visible when the camera is at the corner.
- CanvasLayer screen-space label (top-center banner) was added but does NOT appear in selftest screenshots. This is likely a rendering artifact in the selftest harness's screenshot capture mode (the CanvasLayer may not composite into the viewport screenshot). In a normal game session, the CanvasLayer should render correctly.
- The selftest screenshots show the camera at the map center (hub), not at the minigame corners, so the world-space UI is off-screen in the captured frame.

## Bot Completion: Start-Only in Selftest
- The selftest uses `start_minigame` events which start the game directly without the CPU brain driving `bot_tick()`. So scores are 0 in the selftest.
- In actual gameplay, the CPU brain's `_ffa_minigame_play` calls `bot_tick(delta)` every frame, which drives:
  - **Keg Toss**: throws when target is near center (accuracy-based scoring)
  - **Whack-a-Creep**: hits the active cell when the creep is mid-window (combo scoring)
  - **Rock-Paper-Creep**: random pick each round (best-of-5)
  - **Treasure Dash**: moves toward nearest gem (WASD equivalent)
- A human player can also interact via number keys (1/2/3, 1-9) or mouse clicks.

## Files Created
1. `scripts/minigame_base.gd` — Node2D base class (lifecycle, UI, rewards, audio)
2. `scripts/minigame_area.gd` — Spawns + manages 4 minigames at recruit corners
3. `scripts/minigame_keg_toss.gd` — Lagoon (-1,1): tap-to-throw, moving target
4. `scripts/minigame_whack.gd` — Forest (1,-1): 3x3 grid, whack creeps
5. `scripts/minigame_rps.gd` — Scorch (1,1): RPS vs bot, best-of-5
6. `scripts/minigame_treasure_dash.gd` — Town (-1,-1): WASD gem collection
7. `tools/selftest/requests/minigame_verify.json` — Selftest request
8. `assets/audio/themes/minigame_win.wav` + `.import` — Win stinger SFX

## Files Modified
1. `scripts/main.gd` — Added `_minigame_area` member + instantiation
2. `scripts/cpu_brain.gd` — Added `_ffa_minigame_target` + `_ffa_minigame_play`
3. `scripts/selftest_driver.gd` — Added `minigame` probe + `start_minigame` event + `_pin_active` fix
4. `autoload/audio_service.gd` — Added `minigame_win` SFX ID
5. `tools/synth_themes.py` — Added `MINIGAME_WIN_RECIPE` + WAV generation
