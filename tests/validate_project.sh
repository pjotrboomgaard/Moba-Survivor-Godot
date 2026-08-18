#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"

required_files=(
  project.godot
  scenes/bootstrap/bootstrap.tscn
  scenes/main/main.tscn
  autoload/game_runtime.gd
  autoload/network_service.gd
  autoload/player_profile.gd
  autoload/input_service.gd
  scenes/effects/lightning_effect.tscn
  scripts/lightning_effect.gd
  infra/docker/Dockerfile
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing required file: $required_file" >&2
    exit 1
  fi
done

while IFS= read -r resource_path; do
  local_path="${resource_path#res://}"
  if [[ ! -e "$local_path" ]]; then
    echo "Broken resource reference: $resource_path" >&2
    exit 1
  fi
done < <(rg --no-filename -o 'res://[^" ]+' --glob '*.tscn' --glob '*.gd' | sort -u)

if ! rg -q 'run/main_scene="res://scenes/bootstrap/bootstrap.tscn"' project.godot; then
  echo "Bootstrap is not configured as the main scene" >&2
  exit 1
fi

if rg -q '\[node name="Player" parent="Actors"' scenes/main/main.tscn; then
  echo "Main scene still contains a static player; phase 1 requires network spawning" >&2
  exit 1
fi

for network_method in server_register_client server_submit_input client_receive_snapshot; do
  if ! rg -q "func ${network_method}" scripts/main.gd; then
    echo "Missing phase-1 network method: ${network_method}" >&2
    exit 1
  fi
done

if ! rg -q 'signal staff_cast' scripts/player.gd; then
  echo "Arc Staff network event is missing" >&2
  exit 1
fi

echo "Project structure validation passed."
