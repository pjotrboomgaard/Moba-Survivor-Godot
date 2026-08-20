#!/bin/bash
# Restart Godot when Claude edited game files this turn. Mirrors .cursor/hooks/restart-app.ps1.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG_FILE="$DIR/.restart_pending"

cat >/dev/null # drain stdin JSON, unused

if [ ! -f "$FLAG_FILE" ]; then
	exit 0
fi

rm -f "$FLAG_FILE"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
"$REPO_ROOT/tools/restart_app.sh" "$REPO_ROOT"
