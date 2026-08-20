#!/bin/bash
# Kill any Godot instance running this project on macOS, then relaunch it.
set -euo pipefail

PROJECT_PATH="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
MODE_FLAG="${2:-}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot executable not found: $GODOT_BIN" >&2
	exit 1
fi

pkill -f "Godot.*--path $PROJECT_PATH" 2>/dev/null || true
sleep 0.35

if [ -n "$MODE_FLAG" ]; then
	nohup "$GODOT_BIN" --path "$PROJECT_PATH" -- "$MODE_FLAG" >/dev/null 2>&1 &
else
	nohup "$GODOT_BIN" --path "$PROJECT_PATH" >/dev/null 2>&1 &
fi
disown
echo "Restarted Godot for $PROJECT_PATH"
