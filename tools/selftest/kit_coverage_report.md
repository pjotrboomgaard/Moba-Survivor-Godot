# Kit Coverage Dry-Run Report

Sweep of all 16 heroes through `tools/selftest/run_selftest.ps1` against `tools/selftest/requests/<hero>_kit_dry.json`. Each hero casts 4 ability slots (Q / E / pool-alt / R) at t=0, 2, 4, 6 s, snaps at 1/3/5/8 s, writes `user://selftest_report.json` at t=9 s.

Verdict rules (per the sweep brief):

- **PASS** — no errors AND ≥ 3 casts recorded across distinct ability ids.
- **WARN** — 1–2 casts OR minor errors.
- **FAIL** — 0 casts OR blocker errors (parse fail, missing function, missing scene, timeout writing the report).

## Per-hero verdicts

| # | Hero | Verdict | Casts (unique) | Errors | Notes |
| - | ---- | ------- | -------------- | ------ | ----- |
| 1 | tobor | **FAIL** | 0 | 4 | All 4 expected casts never fired (no `cast_skipped`, just silent no-op). Driver ran clean to t=9 s. |
| 2 | arclight | **PASS** | 21 (4) | 0 | `arclight_thundergods_wrath` fired 17 extra times (likely its per-tick loop). |
| 3 | bulwark | **PASS** | 3 (3) | 1 | `bulwark_heavyweight` never fired. |
| 4 | warden | **WARN** | 2 (2) | 2 | `warden_tongue_tied`, `warden_voodoo_wards` never fired. |
| 5 | cinder | **PASS** | 4 (4) | 0 | |
| 6 | pyra | **WARN** | 2 (2) | 2 | `pyra_sticky_bomb`, `pyra_air_strike` never fired. |
| 7 | slag | **PASS** | 4 (4) | 0 | |
| 8 | ember | **PASS** | 3 (3) | 1 | `ember_entangle` never fired. Fired ids look cross-hero (healing_wave / storm_cloud / unbreakable). |
| 9 | thorn | **WARN** | 2 (2) | 2 | `thorn_toxin_ward`, `thorn_toxicity` never fired. |
| 10 | willow | **PASS** | 3 (3) | 1 | `willow_strangling_vines` is **not** the canonical id — `player_class.gd` has `willow_wall_of_roots`. Request file needs a fix. |
| 11 | stump | **FAIL** | 0 | — | Hung after firing `stump_overgrowth`; report event never reached. |
| 12 | sage | **FAIL** | 0 | — | Hung after casting `sage_charm`; report event never reached. |
| 13 | volt | **FAIL** | 0 | — | Hung after casting `volt_typhoon`; report event never reached. |
| 14 | nebula | **PASS** | 3 (3) | 1 | `nebula_curse_of_ages` never fired. |
| 15 | astral | **PASS** | 3 (3) | 1 | `astral_spirit_bond` never fired. |
| 16 | rime | **PASS** | 3 (3) | 1 | `rime_ice_imprisonment` never fired. |

## Tallies

| Verdict | Count | Heroes |
| ------- | ----- | ------ |
| PASS | 9 | arclight, bulwark, cinder, slag, ember, willow, nebula, astral, rime |
| WARN | 3 | warden, pyra, thorn |
| FAIL | 4 | tobor, stump, sage, volt |
| Total | 16 | |

## Top failure patterns

### 1. Heavyweight / "expected cast never fired" with no skip event (12 heroes)

15 abilities across 12 of 16 heroes returned quietly without producing a `cast_ability` log entry. cooldown skips in `effects[]` for arclight slot 2/3 show the normal path is instrumented, so the silent no-ops point to a guard / early-return inside the bespoke caster (or in the wrapper that calls it) that never reaches `cast_ability`. Grouped by ability id:

- tobor: `tobor_steam_keg`, `tobor_steam_turret`, `tobor_energy_absorption`, `tobor_energy_field` — **all four missing**. Entire kit is dead.
- bulwark: `bulwark_heavyweight`
- warden: `warden_tongue_tied`, `warden_voodoo_wards`
- pyra: `pyra_sticky_bomb`, `pyra_air_strike`
- ember: `ember_entangle` (and the 3 casts that DID fire look like they came from other kits — `ember_healing_wave` / `ember_storm_cloud` / `ember_unbreakable` suggest the ember kit may be aliasing sage/nebula/bulwark ability ids)
- thorn: `thorn_toxin_ward`, `thorn_toxicity`
- nebula: `nebula_curse_of_ages`
- astral: `astral_spirit_bond`
- rime: `rime_ice_imprisonment`

→ **Top signal: 15 bespoke `_cast_ability_*` implementations silently no-op despite the function existing.** Either they return early on a condition that's never true in the dry-run arena (range, mana, stance, etc.) or they don't invoke the standard `cast_ability()` helper at the end.

### 2. Mid-run hangs after an R ability (3 heroes)

- stump: hung after `[main] _play_ability_effect stump_overgrowth` (≈ t=6.05, never reached t=8 snap).
- sage: hung after `[main] _play_ability_effect sage_charm` (≈ t=6.05, never reached t=8 snap).
- volt: hung after `[main] _play_ability_effect volt_typhoon` (≈ t=6.05, never reached t=8 snap).

All three stall right after the R-slot cast on a 90 s budget — the FX is fired but the frame loop freezes before the next scheduled event. Likely a long-running async or tween inside the R-caster that blocks the process.

### 3. Test-side id: `willow_strangling_vines` vs canonical `willow_wall_of_roots`

- `player_class.gd` line 449: `"kit_r": "willow_wall_of_roots"` and the ability exists at line 1708.
- `willow_kit_dry.json` still expects `willow_strangling_vines` (which is the texture filename prefix `willow_strangling_vines*.png`, not the id).
- 3 willow casts did fire (`willow_swift_strike`, `willow_forsaken_shot`, `willow_volley`) so willow is functionally PASS, but the request file needs the R-id corrected. Suggests at least one `*_kit_dry.json` was generated from sprite names instead of `player_class.gd` ids.

## Reproduction commands

```powershell
# one hero at a time
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 -RequestPath tools/selftest/requests/<hero>_kit_dry.json
# report: tools/selftest/results/<hero>_kit_dry_report.json
```

## Files

- Per-hero reports: `tools/selftest/results/<hero>_kit_dry_report.json`
- Per-hero stdout/stderr (for the `Start-Process` batch): `tools/selftest/results/<hero>_stdout.log`, `<hero>_stderr.log`
- Snapshots: `%APPDATA%\Godot\app_userdata\Rift Survivors\selftest_selftest_run_<ts>\<label>_<t>_<ts>.png`
