# Self-test agent workflow

Each agent works in isolation. Standard loop:

1. Write a request JSON in `tools/selftest/requests/<your_test>.json` describing inputs, spawns, snapshots, and probes.
   - `hero`: the hero id to force-swap the local player to (e.g. "tobor"). Drives `apply_class` on load.
   - `events[]`: timed actions. `t` seconds, then one of:
    - `{"kind":"hero","id":"cinder"}` — swap the local player to another hero mid-run (for probing multiple kits in one request)
     - `{"kind":"spawn","at":[dx,dy],"type":"grunt","hp_mult":1.0,"spd_mult":1.0}` — spawn enemy at player+offset
     - `{"kind":"aim","at":[dx,dy]}` — point aim_world_position at player+offset
     - `{"kind":"cast","slot":N}` — tap ability slot (0..3); two taps in a row = arm + confirm
     - `{"kind":"snap","label":"armed"}` — screenshot now
    - `{"kind":"probe","label":"after_arm"}` — record pending slot, cooldowns, active_summons count, last_tapped, alive enemies, kit
    - `{"kind":"sound_probe","ability_id":"tobor_the_keg","label":"keg_sound"}` — assert the last cast fired its hero bank: checks AudioService.last_play_ability == ability_id, the resolved sound id == `cast_<hero>`, the take's stream comes from that bank, and the AudioStreamPlayer was non-null + playing. Writes per-assert booleans + `ok` to the report.
    - `{"kind":"wait","duration":0.5}` — wait without action
     - `{"kind":"effect_log","text":"..."}` — freeform note for the report
     - `{"kind":"report"}` — write `user://selftest_report.json` and get_tree().quit(0)
2. Run: `powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 -RequestPath <path>`
   - Mounts the request as `user://selftest_request.json` inside the game's user-data (Rift Survivors)
   - Launches `main.tscn` windowed; the SelfTestDriver hooks `_ready` on main.gd if the file exists
   - Waits up to 120s; the driver calls `get_tree().quit(0)` at report event
   - Prints the full selftest_report.json to stdout
3. Assert against the report: `player_class`, `cds[]`, `pending_id/pending_slot`, `last_tapped`, `summons`, `enemies_alive`, screenshots in `%APPDATA%\Godot\app_userdata\Rift Survivors\selftest_selftest_run_<ts>\<label>_<t>_<ts>.png`
4. Inspect screenshots via `Read` on the absolute path — that's how you "see" the game state.

Every screenshot is a real in-game frame grabbed from the Viewport: the same UI/arena/HUD a user sees. This is how you verify visuals without the user.

## Reference requests (samples to copy)
- `tools/selftest/requests/keg_target.json` — arm Keg, aim, confirm, snap armed + impact frames
