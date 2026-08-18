# Co-op MOBA Survivor — Product Roadmap

Last updated: 18 August 2026  
Engine baseline: Godot 4.7.2  
Primary targets: Windows, macOS and Linux dedicated servers  
Later target: mobile clients using the same authoritative game simulation

## Product direction

Build a one-to-four-player cooperative action survivor with short, replayable runs, cursor-directed combat and meaningful build choices. The game should be enjoyable solo, become richer in co-op without requiring fixed tank/support roles, and combine survivor simplicity with the build experimentation and team interactions of a MOBA.

The Arc Staff is the only production weapon until its combat, upgrade tree and online synchronization feel excellent. Earlier HTML systems are design references, not code to copy blindly. Every returning system must fit the authoritative multiplayer architecture.

## Non-negotiable technical rules

- Use Godot 4.7.2 for all developers and automated builds.
- Maintain one shared Godot project for Mac, Windows, future mobile clients and the Linux headless server.
- The server owns movement validation, enemies, damage, health, XP, gold, drops, upgrades, bosses and run state.
- Clients send intentions: movement, cursor aim, attack state and menu choices.
- Keep platform services behind adapters; Steam, Apple and Google IDs never become the canonical player ID.
- New gameplay must work solo and online before it is considered complete.
- Never store credentials, export credentials or local `.godot/` data in Git.
- Use small feature branches and pull requests; do not edit the same `.tscn` scene simultaneously.

## Current checkpoint — completed

- Godot project opens and runs in Godot 4.7.2 on macOS.
- Solo mode works.
- Mac host and Windows client can play together over Tailscale.
- Dynamic players, enemies, health, damage, XP and level choices synchronize.
- Arc Staff aims with the cursor and chains between targets.
- Host, join and solo entry flows exist.
- Server-authoritative ENet/UDP foundation exists.
- Project is stored in the private GitHub repository.

This proves the core cross-platform networking direction. Tailscale is only a development tunnel and will not be required by players in the final product.

---

## Stage 1 — Stabilize the multiplayer baseline

### Work

- Run repeatable Mac-host/Windows-client smoke tests.
- Fix all Godot parser errors and reduce meaningful warnings.
- Add visible player names/colours so players can identify each other.
- Test join, disconnect, host death, client death and simultaneous level-ups.
- Prevent clients from moving too fast, selecting invalid upgrades or attacking beyond valid limits.
- Add clear connection, rejection, timeout and server-full messages.
- Add a pause/menu flow with resume, settings, leave run and restart where valid.
- Document the exact Godot version and local test procedure.
- Add a lightweight automated project validation workflow in GitHub Actions.

### Exit criteria

- Two players complete a ten-minute run without divergent health, enemies or XP.
- Disconnecting one client does not break the remaining run.
- No red Godot errors occur during the test.

## Stage 2 — First real dedicated staging server

This comes early because the final product must be tested on its intended architecture instead of repeatedly moving between temporary hosting models.

### Work

- Add reproducible export presets for macOS, Windows and Linux headless server.
- Produce a Godot 4.7.2 Linux server build.
- Complete and test the Docker image.
- Add configuration through environment variables without storing secrets in Git.
- Deploy one inexpensive EU staging server.
- Add server health checks, structured logs, crash restart and version reporting.
- Add a staging address selectable from the join screen.
- Automatically build and deploy the staging server from an approved GitHub branch.
- Keep Tailscale available only as a backup developer test path.

### Exit criteria

- Mac and Windows clients on different networks can join the staging server without Tailscale.
- The server can restart and recover without manual file copying.
- Client and server reject incompatible build versions with a clear message.

## Stage 3 — Developer tools and gameplay parity foundation

Build testing tools before adding large amounts of content.

### Developer mode

- Toggle developer mode only in development builds.
- Add XP, gold and multiple levels without opening every picker.
- Advance time/waves and jump to elite or boss phases.
- Increase or decrease every owned upgrade, ability and item level.
- Spawn specific enemy types, bosses, XP, gold and item drops.
- Toggle invulnerability, damage display and network information.
- Save and load named test builds.
- Ensure online developer actions require server authority.

### Core interface restored from the HTML prototype

- Damage, healing, critical-hit and XP number indicators.
- Compact stat panel showing movement speed, weapon damage, cast speed, crit, chains, range, armour, regeneration and lifesteal.
- Proper health and XP bars.
- Escape menu and restart/leave controls.
- Developer overview pages for all upgrades, abilities, evolutions and items.

### Exit criteria

- A developer can reproduce a late-game build or final boss test in under one minute.

## Stage 4 — Arc Staff production combat and tech tree

### Base behaviour

- Cursor-directed main lightning bolt.
- Visible staff/spell origin and readable hit target.
- Cyan main lightning and visually smaller, differently coloured chains.
- Smooth, unique casting animation and clear impact feedback.
- Damage, range and aim assistance tuned for mouse and controller.

### Weapon-specific upgrade tree

- Weapon damage.
- Cast speed.
- Main-bolt range and width.
- Additional chain targets.
- Chain range.
- Chain damage retention.
- Split cast: a second main bolt with its own chain path.
- Critical chance and critical damage where appropriate.
- One or more mutually exclusive Arc Staff evolutions.

Generic projectile upgrades such as pierce or follow-through must not appear unless they have a clear Arc Staff-specific interpretation.

### Exit criteria

- Every offered staff upgrade changes visible behaviour or a clearly displayed stat.
- Split casts and every chain synchronize correctly for all clients.
- At least three genuinely different Arc Staff builds are viable.

## Stage 5 — Wave director, enemies and bosses

### Work

- Replace simple spawning with a server-owned run director.
- Define run phases, intensity budget, spawn composition and recovery moments.
- Add enemy archetypes: swarm, fast flanker, ranged attacker, tank, disruptor and summoner.
- Make stronger enemies visually distinguishable by silhouette, size, colour, animation and effects.
- Add elites with readable modifiers rather than only inflated health.
- Add minibosses and a final boss with telegraphed mechanics.
- Scale enemy count, health and pressure by time and player count without making solo unfair.
- Tune the XP curve so late-game levels remain useful without becoming excessively slow.
- Prevent the late game from becoming permanently easy.

### Exit criteria

- A full run has a readable escalation, a mid-run threat and a final climax.
- Difficulty remains engaging for both one and two players.

## Stage 6 — Gold, shop and item system

### Work

- Add server-owned gold drops from selected enemies.
- Give bosses guaranteed item drops.
- Add gold pickup attraction and a Gold Magnet item.
- Add an inventory with a maximum of six equipped items.
- Add shop buy and sell flows.
- Define item rarity, price, stacking and resale rules.
- Add survivability choices such as regeneration, lifesteal, armour and movement.
- Add offensive and utility items without duplicating staff upgrades.
- Decide whether the shop appears between phases, at fixed map locations or both after playtesting.

### Exit criteria

- Gold cannot be duplicated or spent by the client without server approval.
- Players can make meaningful trade-offs within six item slots.

## Stage 7 — Level choices, abilities and evolutions

### Level-up structure

- Test a structured offer containing one offence, one survival and one movement/utility choice.
- Compare it with fully random offers using playtest data.
- Add reroll or protection systems only if bad luck damages runs.

### Abilities

- Choose a starting ability or gain new abilities at milestone levels.
- Maximum three active/passive abilities per build.
- Abilities can be levelled after acquisition.
- Skillshots follow the cursor.
- Replace single-player-only Taunt with a useful ability such as Snipe/railgun.
- Add co-op-relevant utility that still works solo.

### Evolutions

- Evolutions must change mechanics, visuals and build direction—not merely add percentage damage.
- Requirements must be visible in the developer catalogue and eventually in the player UI.
- Avoid hidden combinations that require external wikis during the demo.

### Exit criteria

- At least three distinct builds can be identified from gameplay alone.
- No level-up option is nonsensical for the current weapon or hero.

## Stage 8 — Heroes and class identity

### Work

- Add a five-slot hero selection screen.
- Keep the current mage/staff hero selectable during the demo.
- Grey out unreleased heroes with `Unlocks after the demo` messaging.
- Reserve one slot for an Engineer/Builder.
- Define each hero through a passive, starting ability, stat profile and build hooks.
- Do not require tank/support roles; every hero must survive and contribute damage solo.
- Add hero-specific co-op synergies without making combinations mandatory.

### Exit criteria

- The mage has a complete identity before a second hero enters production.
- Engineer/Builder design is validated on paper and in a small prototype before full content production.

## Stage 9 — Large tactical map and minimap

### Work

- Add terrain, obstacles, chokepoints, open zones, hazards and temporary safe areas.
- Add objectives that encourage movement instead of endless circles in an empty arena.
- Design a larger map using chunks/streaming so desktop and future mobile performance remain viable.
- Add a minimap showing players, enemies as small dots, bosses, shops and objectives.
- Show XP on the minimap with subtle visual differences for XP value.
- Decide how enemy pathfinding and spawn fairness work around obstacles.
- Test whether fixed maps, procedural layouts or curated procedural chunks best support readable co-op.

### Exit criteria

- Positioning changes tactical decisions without causing enemies to become stuck.
- Players can locate each other and important rewards quickly.

## Stage 10 — Co-op systems that create a unique identity

### Candidates to prototype

- Downed/revive system with solo-safe alternatives.
- Shared objectives and short team decisions during a run.
- Ability and status combinations between heroes.
- Chain-lightning interactions that teammates can extend or redirect.
- Team resources with individual build ownership.
- Pings and quick communication without relying on voice chat.
- Optional risk/reward events that the group votes on.

Only keep mechanics that increase cooperation without adding MOBA-style toxicity or requiring a fixed composition.

### Exit criteria

- Playing together changes decisions, not only enemy health scaling.
- A new player can understand the cooperation loop without a long tutorial.

## Stage 11 — Graphics, animation, audio and accessibility

### Work

- Finalize the medieval-fantasy art direction and style guide.
- Define character, enemy, environment, VFX, UI and icon pipelines.
- Replace placeholder vectors in vertical-slice order, not all at once.
- Give every weapon and ability unique, readable animation and sound.
- Add hit, crit, pickup, level-up, elite and boss feedback.
- Add resolution scaling, colour-blind-safe indicators, screen-shake controls and reduced-flash options.
- Add controller support and remapping before final UI polish.

Graphics begin during vertical slices, but mass asset production waits until gameplay proportions and camera scale are stable.

## Stage 12 — Production online services and Steam

### Work

- Add client prediction and server reconciliation for movement.
- Add reconnect tokens and safe session recovery.
- Add lobby codes, invitations and matchmaking.
- Add an internal account ID with Steam identity linking.
- Integrate Steam lobbies/friends, achievements and cloud saves behind platform adapters.
- Create Steam test branches and Steam Playtest distribution.
- Add crash reporting, basic privacy-respecting analytics and server metrics.
- Sign/notarize macOS builds and package Windows builds.
- Perform latency, load, exploit and disconnect testing.

### Commercial decision gate

- Compare a low fixed price with free-to-play plus cosmetic skins.
- Do not build a cosmetics store until retention and session quality justify it.
- Never sell power; gameplay progression remains earnable through play.

## Stage 13 — Mobile adaptation

Mobile uses the same game/server architecture but needs a separate presentation and performance pass.

### Work

- Add touch movement and aim adapters.
- Build mobile-specific HUD layouts instead of shrinking the desktop HUD.
- Profile enemy counts, VFX, bandwidth, memory and battery use.
- Add Android/iOS authentication and store adapters.
- Test cross-play rules, update compatibility and input fairness.

Desktop remains the first commercial target. Mobile production starts only after the desktop combat loop and online service are stable.

## Stage 14 — Demo, beta and release

- Build a polished thirty-to-forty-five-minute demo loop.
- Run closed co-op tests through Steam Playtest.
- Track crashes, completion, difficulty spikes and build diversity.
- Balance from playtest evidence rather than only developer intuition.
- Create onboarding, settings, credits, privacy information and support flow.
- Prepare store assets, trailer, screenshots and launch messaging.
- Launch only after server cost, moderation/support expectations and update workflow are understood.

## Immediate execution order

1. Finish Stage 1 multiplayer stability tests.
2. Establish GitHub branches, pull requests and automated validation.
3. Build and deploy the Stage 2 dedicated staging server.
4. Build Stage 3 developer tools.
5. Restore the strongest HTML gameplay systems through Stages 4–7.
6. Reassess fun, uniqueness and scope before producing additional heroes or large amounts of art.

## Explicitly deferred

- Sword, bow and additional production weapons.
- More than one fully playable hero.
- Final cosmetics store.
- Full mobile production.
- Large-scale asset production.
- Competitive PvP.

These are not cancelled. They are held until the Arc Staff co-op vertical slice proves the full gameplay and production pipeline.

