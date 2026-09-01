# 3-Day Recovery Master Plan (2026-09-01)

> Driven by user's directive: "go back 3 days, catalog every change, plan rebuild, test everything myself, max 4 agents parallel, don't overload godot instances."

## Phase 0 — Sweep complete (this file's preamble)

- Chat sessions discovered: **18** top-level IDs in `agent-transcripts/` (Aug 30 21:07 → Sep 1 20:56)
- Git commits in span: **15** — but ALL before 09-01 18:18 are pre-activity (nothing in Aug 29-31 was committed)
- **Key insight:** most of Aug 30-31 work exists only in transcript JSONL, was never git-committed, then was wiped by ~Sep-1 17:49 file stomps.
- Recovery principle: **git commit at every milestone** so future losses are NOT catastrophic.

## Phase 1 — Catalog pass (running now)

- 1 READ-ONLY agent walks all 18 transcripts and produces a per-session feature list.
- Output: `tools/catalog_3day.txt` — one line per feature, with chat_id + timeframe + status hint (committed / only-in-chat / partially / lost).
- Capped at **1 agent** running concurrently (no risk of write races, keep Godot quiescent).

## Phase 2 — Triage pass (after Phase 1 done)

- I read catalog_3day + existing `tools/recovery_audit_2026-09-01.md` and produce a single ordered rebuild queue, segmented by:
  1. **Restore immediately** (game-breaking, needed for user testing flow)
  2. **Restore soon** (high-impact, but app runs without them)
  3. **Defer** (niceties until core stable)

## Phase 3 — Rebuild waves (max 4 agents, single-file scope)

Each wave uses agents that own **non-overlapping files**. After each wave, I commit + restart_app.ps1 so user sees it.

| Wave | Owner files | Purpose |
|------|------------|---------|
| W1 | autoload/player_profile.gd | Restore full progression state (sparks/shards/mastery/loadouts) |
| W1 | scenes/bootstrap/bootstrap.gd + .tscn | Menu overhaul (already done) — verify only |
| W1 | scripts/player_class.gd | 16 HoN kits already in; verify only |
| W2 | scripts/player.gd | Cast functions per kit archetype (HoN-accurate behavior) |
| W2 | scenes/bootstrap + scripts/network_service.gd | MP lobby loads, hero pips, loadout sync |
| W2 | tools/sprite_art.gd | Verify all 64 kit icons + 4-directional hero art present |
| W3 | scripts/main.gd + scripts/kit_fx_library.gd | Wire each kit ID to distinct VFX (LightningEffect/ZonePulse) |
| W3 | autoload/audio_service.gd + assets/audio/* | Per-kit sound + hero themes |
| W4 | tools/tobor_world_art.gd + scripts/arena.gd | Biome themes + landmark variety per world (already mostly done) |
| W4 | tests/class_smoke_test.gd + tools/selftest/* | Test suite alignment with new kits |

## Phase 4 — Self-test sweep (1 agent at a time)

After all waves land:
- 1 agent runs headless `tools/selftest/run_selftest.ps1` for each hero (17 runs, sequential)
- 1 agent triages failures, files bugs
- I commit + restart_app.ps1

## Phase 5 — User sign-off

I report the full feature-by-feature delta summary to the user.

## Discipline rules

- **Agent limit:** 4 running simultaneously max (including recovery + test agents).
- **Godot instance discipline:** ONE headless run at a time. Agents MUST use `Get-Process -Name "Godot*" | Stop-Process -Force` before starting a new Godot run.
- **Commit gate:** each wave ends in a commit before launching the next wave.
- **Transcripts as ground truth:** if a feature isn't referenced in any transcript within 3 days, it didn't exist — do not invent.

## Current catalog location

- `tools/catalog_3day.txt` (Phase 1)
- `tools/recovery_audit_2026-09-01.md` (earlier baseline, persists)
