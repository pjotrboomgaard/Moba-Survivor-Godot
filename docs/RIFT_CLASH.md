# Rift Clash (Ranked Team FFA) — Interim Design Notes

Resurrect this document when continuing the build; it's the source of truth for decisions that didn't need their own file yet.

## What Rift Clash is

- 1–4 teams (A/B/C/D), each owning a **corner** of a big shared arena.
- Each team's `WaveDirector` targets that corner's members; everyone else can
  **walk over and steal enemy-wave XP**, or **PvP-eliminate** a rival team.
- Last team standing wins; tied survivors split points 25/8/2/-15 by placement.
- Rank = Steam `SkillPoints` stat → Bronze → Immortal in `RankService`.
- Leaderboard = Steam `rift_clash_skill` board, uploaded from `SteamService`.
- Rich Presence = `#riftclash_ingame`, populated per wave.

## Decisions locked in Phase 0/1

1. **GodotSteam GDExtension 4.21 already loads.** Project for dev AppID 480.
2. **Team assignment lives in Steam lobby member data** (`team` key), not custom RPCs. Syncs through the lobby itself.
3. **Lobby mode flag** (`NetworkService.LOBBY_MODE_KEY`) separates Coop (existing) from Rift Clash (competitive) so the same build keeps the 4-player co-op flow untouched.
4. **Each team has its own `WaveDirector` node**, started with `player_count=team_size`. This is true to the current `player_count` scaling and keeps bosses intact.
5. **Corner spawn zones** are four 700×700 `Rect2`s near the corners of `Arena.playfield_size()`; the arena itself grows for 3+ teams.
6. **Steam stats** are handled when the client is online; offline falls back to `user://rift_clash_rank.json` (implemented in `RankService`).

## Still intentionally hand-waved

- **PvP hit detection**: projectiles currently team-filter by physics layers (players vs enemies). For v1 we layer *players on the same physics layer, friendly-fire disabled within team*; teams differentiate by a `team_id` property on `Player` and skip damage if `target.team_id == mine`. Add `if shooter.team_id != target.team_id` gating in `Projectile` and `Player.melee`.
- **Kill credit**: v1 grants XP to the player who last clogged a target within a window (last-hit); assist credit is out of scope.
- **Scoreboard per wave**: the lobby HUD only shows final placement in v1; per-wave team progress bars are Phase 5+.
- **Reconnect / drop-in**: relies on the existing reconnect logic; a Rift Clash–specific "team rejoin" grace period is future work.
