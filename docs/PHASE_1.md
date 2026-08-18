# Phase 1 — Network vertical slice

## Implemented in this checkpoint

- Start screen with Solo, Host and Join flows.
- Address entry supporting `host:port`, defaulting to `127.0.0.1:27015`.
- Dynamic player creation for one to four total players.
- Clients send movement, aim and attack intentions to the server.
- The host or dedicated server simulates player movement and attacks.
- Server snapshots synchronize players, enemies, health and XP orbs.
- Four server-owned roles: Arclight (damage), Bulwark (tank), Warden (support), Frostbinder (control).
- Role choice is made in the start screen, stored in the local profile and validated by the server on join.
- Each role replicates its class id in snapshots, so remote players render in the right colours.
- Damage reduction, taunt weighting, healing auras and enemy slows are all applied on the server.
- Upgrade offers are drawn from the levelling player's own class pool.
- Classic and Pjotr game modes: Classic pins every player to the Arclight and the original grunt-only spawn rhythm.
- Thirteen enemy types with melee, ranged, support and charge behaviour, replicated by type id.
- Hero damage types and per-enemy resistances, resolved on the server when damage is applied.
- Server-owned separation steering keeps crowds from stacking on one point.
- A server-owned wave director picks a wave archetype, escalates budget, unlocks and health, and spawns groups in four formations.
- Boss waves every ten waves, with the boss health bar driven from replicated enemy state.
- Enemy projectiles, explosions, death splits and summons are resolved on the server; clients receive cosmetic copies.
- The current wave and its theme name travel in the snapshot and are shown in the HUD.
- Hand-written wave themes with debut waves that introduce one new enemy at a time.
- Shared gold per kill, replicated per player, with server-validated shop purchases in the breather after every tenth wave.
- Shop items sell mechanics (reflect, lifesteal, regeneration, resistance pierce, cheat death, burn aura, on-hit slow, pickup range) plus one active, Phase Boots, so they never duplicate the level-up stat pool.
- Pixel art sprites for heroes, enemies, projectiles and pickups, baked by tools/sprite_forge.tscn.
- Enemy movement, contact damage, death and XP collection are server-owned.
- Level-up offers are generated and validated by the server.
- Solo mode keeps pausing during a level choice; online players choose in real time.
- Disconnect cleanup removes the departed player from the authoritative world.

## Test on one Mac

The most reliable test uses one host build and one client build:

1. Open the project in Godot 4 and run it.
2. Pick Pjotr mode and a role, then choose **Host Co-op Game**.
3. Start a second instance of the project or an exported debug build.
4. Pick a different role, then choose **Join Game** and use `127.0.0.1:27015`.
5. Confirm both players are visible, move independently and render in their class colours.
6. Hold the left mouse button and aim through an enemy.
7. Confirm both windows show the same weapon effect for each role.
8. Kill enemies and confirm XP orbs disappear for both players when collected.
9. Reach a level, choose an upgrade and confirm the run continues.
10. Clear wave ten and confirm both players see the shop, their shared gold and identical prices, and that earlier waves never open it.
10. Close the client and confirm its character disappears on the host.

For a LAN test, enter the host Mac's local IPv4 address instead of `127.0.0.1`. Internet play still requires port forwarding or the hosted dedicated server planned for the next infrastructure checkpoint.

## Deliberate limitations

- Movement is server-authoritative without client prediction, so remote movement may feel delayed. Prediction and reconciliation come after correctness is proven.
- Snapshots currently contain complete small-world state rather than delta compression.
- There is no Steam authentication, matchmaking or reconnect token yet.
- The lobby does not list discoverable games; joining uses an address.
- Art is hand-authored placeholder pixel art without animation frames.
- Godot must still perform the engine-level smoke test on the development Mac.

## Exit criteria

Phase 1 is accepted when two instances complete a short run without divergent health, enemies or XP. Any engine parse/runtime errors found during the first Mac test are fixed before adding more content.
