# Phase 0 — Production foundation

## Completed in this checkpoint

- Existing playable Godot movement prototype preserved.
- Compatibility renderer retained for desktop and future mobile support.
- Bootstrap scene added as the single executable entry point.
- Explicit offline, host, client and dedicated-server runtime modes.
- Reusable ENet/UDP service with a four-player default.
- Platform-neutral local player identifier scaffold.
- Input service separating gameplay from keyboard/touch implementation.
- Linux server container definition using an exported Godot binary.
- Architecture and authority rules documented.

## Not yet claimed as complete

- Host and client do not replicate gameplay yet.
- Accounts are local placeholders; there is no production authentication API.
- Entitlements and store purchases are not implemented.
- Mobile UI and controller bindings are not implemented.
- The Docker image requires a Linux server export before it can build.

## Phase-0 acceptance test on a development Mac

1. Install the current stable Godot 4 release.
2. Import `project.godot`.
3. Run the project and confirm the existing arena opens.
4. Move with WASD, survive, collect XP and select an upgrade.
5. Run a second editor instance with `-- --host` and confirm it starts without an ENet error.
6. Run a headless instance with `--headless -- --server` and confirm the terminal prints the UDP listening message.

After these pass, phase 1 begins with a real lobby and two connected players.
