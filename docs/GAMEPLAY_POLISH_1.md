# Gameplay polish checkpoint 1

This checkpoint restores the highest-value feedback and build systems from the
HTML prototype while keeping the Godot simulation server-authoritative.

## Added

- One offence, one survival and one utility option at each level choice.
- Arc Staff upgrades for damage, cast speed, chain count, chain range and a
  second main bolt with its own chain.
- Critical chance, critical damage, regeneration, lifesteal, movement, health
  and XP pickup upgrades.
- Live Arc Staff statistics.
- Floating damage, critical hit, healing and XP feedback replicated from the
  server.
- Grunt, swift, brute and elite silhouettes with time-based pressure scaling.
- Debug-only XP, multi-level, elite-spawn and invulnerability controls.
- Escape menu with solo restart and leave-to-lobby actions.
- Queued upgrade choices when multiple levels are gained at once.

## Test focus

1. Complete a five-minute solo run and confirm every offered upgrade changes a
   displayed statistic or visible Arc Staff behaviour.
2. Select Split Current and confirm two cyan main bolts each create their own
   purple chain when enough targets are available.
3. Confirm crits are larger/yellow, healing is green and damage taken is red.
4. Open developer tools with `F1`, add five levels, spawn an elite and toggle
   invulnerability.
5. Repeat with Mac host and Windows client. Both players must see the same
   enemies, lightning paths and combat-number events.

## Deliberately deferred

- Sword and Longbow remain frozen.
- Shop, gold, items, active abilities, evolutions, minimap and boss content are
  not part of this checkpoint.
- The next Arc Staff pass adds exclusive Chain Lightning and Storm Caller
  branches after this baseline has been playtested in co-op.
