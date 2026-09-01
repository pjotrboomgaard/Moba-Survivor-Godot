# Audio SFX Plan

Goal: cover every hero ability with a one-shot SFX in the same style as the current
pack (Kenney CC0, short/dry/synthetic one-shots, ogg, trimmed + faded).

Source: Kenney CC0 packs, exact same ones as `assets/audio/CREDITS.txt` (Sci-Fi,
Digital, Interface, RPG, Impact) plus the Foley Woosh set. All CC0, downloads
mirrored in `tmp/sfx_src/` (180 files staged, not yet processed/wired).

Two layers are planned:

## Layer 1 — Per-hero cast sound (`cast_<hero>`)

Played as the fallback for every ability of that hero (already wired in
`AudioService.play_ability()` -> `play("cast_<hero>")` fallback path). Because
every ability falls back to its hero cast when it has no family mapping, filling
the 11 missing heroes means *every* ability in the game instantly gets a SFX.
2 takes per hero, matching the existing 5 (tobor/arclight/bulwark/warden/rime).

| New sound id    | Hero        | Source takes (Kenney file -> renamed)                          | Character |
|-----------------|-------------|----------------------------------------------------------------|-----------|
| cast_cinder     | Blaze       | dig_laser6, dig_laser7                                           | hot laser |
| cast_pyra       | Barrage     | explosionCrunch_001, explosionCrunch_002                         | artillery boom |
| cast_slag       | Vulcan      | imp_impactMetal_medium_000, imp_impactMetal_medium_001           | molten metal |
| cast_ember      | Witchfire   | dig_laser9, dig_zap1                                             | warm zap |
| cast_thorn      | Venom       | imp_impactSoft_medium_000, imp_impactSoft_medium_001             | wet thorn |
| cast_willow     | Flick       | rpg_knifeSlice, rpg_knifeSlice2                                  | swift shot |
| cast_stump      | Keeper      | imp_impactWood_heavy_000, imp_impactWood_heavy_001               | wood thud |
| cast_sage       | Nymphel     | dig_powerUp2, dig_powerUp5                                       | nature chime |
| cast_volt       | Gale        | dig_zapTwoTone, dig_zapTwoTone2                                  | arc zap |
| cast_nebula     | Aeon        | dig_phaseJump3, dig_phaseJump4                                   | time warp |
| cast_astral     | Lumina      | dig_powerUp7, dig_powerUp9                                       | ethereal chime |

## Layer 2 — Missing archetype families

`FAMILY_FOR_ARCHETYPE` in `autoload/audio_service.gd` maps only 11 of 18
archetypes. These 7 are unmapped, so every ability with one of these archetypes
only ever plays its hero cast. Add:

| Archetype      | New family sfx   | Source take (Kenney)        | Why |
|----------------|------------------|-----------------------------|-----|
| STORM_PULL     | sfx_storm_pull   | dig_phaserDown1             | descending pull |
| ZONE_CHANNEL   | sfx_zone_channel | dig_threeTone1              | channeled build |
| SUMMON_SPIRIT  | sfx_summon       | dig_pepSound2               | sparkle spawn |
| SLAM_TAUNT     | sfx_slam_taunt   | imp_impactPunch_heavy_000   | heavy land |
| BLINK_STRIKE   | sfx_blink        | dig_phaseJump1              | teleport snap |
| PIT_SLOW       | sfx_pit_slow     | dig_lowDown                 | dragging slow |
| ATTACK_FURY    | sfx_fury         | rpg_chop                    | rapid strikes |

With both layers, sound resolution becomes: archetype family (18/18 mapped) ->
hero cast (16/16 have one) -> silence. No ability is ever silent.

## Status / next steps

- [x] Inventory heroes, abilities, archetypes, current pack + style
- [x] Source matching Kenney CC0 files (mirrored to `tmp/sfx_src/`)
- [x] Pick per-hero takes + missing family takes (tables above)
- [ ] Trim/fade to match existing short combat one-shots, name to convention,
      drop into `assets/audio/sfx/`
- [ ] Register in `SOUND_LIBRARY` + `VOLUME_DB` + `PITCH_SPREAD`, extend
      `FAMILY_FOR_ARCHETYPE` for the 7 missing archetypes
- [ ] Test in game + restart app

Notes: takes still need a listen-pass to confirm each pick sounds right before
they get committed. To audition a different take, point the same sound id at
another mirrored file from `tmp/sfx_src/`.
