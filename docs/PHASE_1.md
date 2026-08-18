# Phase 1 — Network vertical slice

## Implemented in this checkpoint

- Start screen with Solo, Host and Join flows.
- Address entry supporting `host:port`, defaulting to `127.0.0.1:27015`.
- Dynamic player creation for one to four total players.
- Clients send movement, aim and attack intentions to the server.
- The host or dedicated server simulates player movement and attacks.
- Server snapshots synchronize players, enemies, health and XP orbs.
- Cursor-directed Arc Staff replaces the placeholder auto-projectile.
- The first lightning segment is bright cyan; follow-up chains are smaller and purple.
- Enemy movement, contact damage, death and XP collection are server-owned.
- Level-up offers are generated and validated by the server.
- Solo mode keeps pausing during a level choice; online players choose in real time.
- Disconnect cleanup removes the departed player from the authoritative world.

## Test on one Mac

The most reliable test uses one host build and one client build:

1. Open the project in Godot 4 and run it.
2. Choose **Host Co-op Game**.
3. Start a second instance of the project or an exported debug build.
4. Choose **Join Game** and use `127.0.0.1:27015`.
5. Confirm both players are visible and can move independently.
6. Hold the left mouse button and aim through an enemy.
7. Confirm both windows show the same cyan main bolt and purple chain.
8. Kill enemies and confirm XP orbs disappear for both players when collected.
9. Reach a level, choose an upgrade and confirm the run continues.
10. Close the client and confirm its character disappears on the host.

For a LAN test, enter the host Mac's local IPv4 address instead of `127.0.0.1`. Internet play still requires port forwarding or the hosted dedicated server planned for the next infrastructure checkpoint.

## Deliberate limitations

- Movement is server-authoritative without client prediction, so remote movement may feel delayed. Prediction and reconciliation come after correctness is proven.
- Snapshots currently contain complete small-world state rather than delta compression.
- There is no Steam authentication, matchmaking or reconnect token yet.
- The lobby does not list discoverable games; joining uses an address.
- Art remains placeholder vector rendering.
- Godot must still perform the engine-level smoke test on the development Mac.

## Exit criteria

Phase 1 is accepted when two instances complete a short run without divergent health, enemies or XP. Any engine parse/runtime errors found during the first Mac test are fixed before adding more content.
