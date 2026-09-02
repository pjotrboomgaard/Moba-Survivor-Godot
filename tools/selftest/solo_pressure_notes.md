# Solo pressure notes

Offline PLAY (`GameRuntime.fill_cpu_allies = false`) does **not** spawn CPU heroes.
Only the CO-OP menu button sets the flag; `_spawn_cpu_allies` returns immediately when it is false.

## Wave 1 (fair)

- Budget: `24 + 6 * wave` = **30** (no solo pressure)
- Health mult: **2.0** (`BASE_HEALTH_MULTIPLIER`, no solo pressure)
- Planned count: **~24–30 grunts** (STANDARD, grunt cost 1, groups of 3–5 until the budget is spent)
- Theme: always **First Contact**, even on a locked volcano/ice/factory/docks map

## Wave 5

- Theme: **The Ravager** (BOSS). Count is **1** — never a pack of bosses
- Budget formula still evaluates to **58.32** but `_plan_boss` ignores budget and emits one Ravager
- Health mult at Normal solo: **2.832**

## Health multiplier formula

```
base = 2.0 + 0.10 * (wave - 1)
if solo PLAY and wave >= 2:
    base *= 1.18
health_mult = base * difficulty
```

Difficulty: Easy 0.65, Normal 1.0, Hard 1.5, Brutal 2.25.

Solo PLAY means `player_count == 1` and `fill_cpu_allies == false` (CO-OP CPU fill skips this bump; 4-player host uses the existing `1 + 0.85 * (players - 1)` budget scale instead).

Budget from wave 2: `(24 + 6 * wave) * 1.08 * (1 + 0.85 * (players - 1))`.

## Landmark timing

Intermission is **10s** (was 14s) so the next wave often starts while you are still crossing to a landmark. The director does not auto-wipe the map.

## Biome pools (when `uses_biomes()` and `biome_id > 0`)

| Biome | Pool |
| --- | --- |
| Volcano (1) | grunt, swarmling, spitter, **lurker, hexer**, charger, splitter, bomber (cinder) |
| Ice (2) | grunt, swarmling, spitter, **stalker, lurker, hexer, brute, summoner** (frost) |
| Factory (3) | grunt, swarmling, spitter, **brute, sentinel**, splitter, charger, summoner |
| Docks (4) | grunt, swarmling, spitter, **drifter, bomber**, stalker, lurker, hexer |

Grass (`biome_id == 0`) keeps the full roster. Unlock waves still apply, so wave 1 is grunts only on every map. Scripted debuts that are off-pool are remapped (e.g. volcano `drifter` → `bomber`, factory `lurker` → `brute`). Locked-biome runs cycle the restored 20-wave theme names (Kindling / Pack Ice / Assembly Line II / Boardwalk, …) from wave 2.
