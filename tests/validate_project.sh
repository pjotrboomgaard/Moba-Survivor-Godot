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
  scripts/player_class.gd
  scripts/enemy_type.gd
  scripts/wave_director.gd
  scripts/shop_catalog.gd
  scripts/sprite_library.gd
  tools/sprite_art.gd
  tools/sprite_forge.tscn
  scenes/projectile/projectile.tscn
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

if ! rg -q '^config_version=5$' project.godot; then
  echo "Godot 4 project configuration version is missing" >&2
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
  echo "Weapon network event is missing" >&2
  exit 1
fi

if ! rg -q '^class_name PlayerClass$' scripts/player_class.gd; then
  echo "Player class catalog is missing" >&2
  exit 1
fi

for class_id in arclight bulwark warden frostbinder; do
  if ! rg -q "\"id\": \"${class_id}\"" scripts/player_class.gd; then
    echo "Missing player class: ${class_id}" >&2
    exit 1
  fi
done

if ! rg -q 'func apply_class' scripts/player.gd; then
  echo "Player cannot apply a class loadout" >&2
  exit 1
fi

if ! rg -q 'func apply_slow' scripts/enemy.gd; then
  echo "Enemy is missing the control-role slow hook" >&2
  exit 1
fi

if ! rg -q '^class_name EnemyType$' scripts/enemy_type.gd; then
  echo "Enemy type catalog is missing" >&2
  exit 1
fi

for enemy_id in grunt swarmling spitter drifter brute stalker bomber hexer sentinel splitter charger summoner ravager stormcaller; do
  if ! rg -q "\"id\": \"${enemy_id}\"" scripts/enemy_type.gd; then
    echo "Missing enemy type: ${enemy_id}" >&2
    exit 1
  fi
done

if ! rg -q '^class_name WaveDirector$' scripts/wave_director.gd; then
  echo "Wave director is missing" >&2
  exit 1
fi

if ! rg -q 'wave_director: WaveDirector' scripts/main.gd; then
  echo "Main scene must drive enemy spawning through the wave director" >&2
  exit 1
fi

if rg -q 'EnemySpawnTimer' scenes/main/main.tscn; then
  echo "The flat enemy spawn timer must be replaced by the wave director" >&2
  exit 1
fi

if ! rg -q '"type_id": type_id' scripts/enemy.gd; then
  echo "Enemy snapshots must replicate the enemy type" >&2
  exit 1
fi

if ! rg -q 'enum GameMode' autoload/game_runtime.gd; then
  echo "Classic and Pjotr game modes are missing" >&2
  exit 1
fi

if ! rg -q 'func is_classic' autoload/game_runtime.gd; then
  echo "The classic Arc Staff mode must stay selectable" >&2
  exit 1
fi

if ! rg -q 'func _process_classic' scripts/wave_director.gd; then
  echo "Classic mode must keep its original flat spawn rhythm" >&2
  exit 1
fi

if ! rg -q 'enum DamageType' scripts/player_class.gd; then
  echo "Hero damage types are missing" >&2
  exit 1
fi

if ! rg -q 'func damage_multiplier_for' scripts/enemy.gd; then
  echo "Enemies must expose their resistances to hero damage types" >&2
  exit 1
fi

if ! rg -q 'func _separation_offset' scripts/enemy.gd; then
  echo "Enemies need separation steering so they stop clumping" >&2
  exit 1
fi

for archetype in SWARM SNIPERS ELITE AIR_ASSAULT AMBUSH BOSS; do
  if ! rg -q "${archetype}," scripts/wave_director.gd; then
    echo "Missing wave archetype: ${archetype}" >&2
    exit 1
  fi
done

if ! rg -q 'SCRIPTED_WAVES' scripts/wave_director.gd; then
  echo "Waves need hand-written themes" >&2
  exit 1
fi

if ! rg -q '"debut"' scripts/wave_director.gd; then
  echo "New enemies must get a debut wave" >&2
  exit 1
fi

if ! rg -q 'class_name ShopCatalog' scripts/shop_catalog.gd; then
  echo "The shop catalog is missing" >&2
  exit 1
fi

if ! rg -q 'func buy' scripts/player.gd; then
  echo "Shop purchases must resolve on the player" >&2
  exit 1
fi

if ! rg -q '"gold_value"' scripts/enemy_type.gd; then
  echo "Enemies must be worth gold" >&2
  exit 1
fi

for item in carapace phase_boots bloodfang pendant prism aegis ember frostbite lodestone; do
  if ! rg -q "\"${item}\"" scripts/shop_catalog.gd || ! rg -q "\"${item}\"" scripts/player.gd; then
    echo "Shop item '${item}' is not wired up end to end" >&2
    exit 1
  fi
done

for stat in weapon_damage attack_interval movement_speed; do
  if rg -q "\"${stat}\"" scripts/shop_catalog.gd; then
    echo "The shop must not resell the level-up stat ${stat}" >&2
    exit 1
  fi
done

if ! rg -q '^ability=' project.godot || ! rg -q 'func ability_held' autoload/input_service.gd; then
  echo "The active item needs an 'ability' input action" >&2
  exit 1
fi

if ! rg -q 'SHOP_WAVE_INTERVAL' scripts/wave_director.gd || ! rg -q 'shop_opens_before' scripts/main.gd; then
  echo "The shop must only open on its wave interval" >&2
  exit 1
fi

	if ! rg -q 'SHOP_PRICE_MULTIPLIER' scripts/shop_catalog.gd; then
  echo "Shop prices must be scaled up for the economy" >&2
  exit 1
fi

if ! rg -q 'class_name AbilityArt' tools/ability_art.gd; then
  echo "Ability icons and cast animations must be generated" >&2
  exit 1
fi

if ! rg -q 'class_name AbilityVfx' scripts/ability_vfx.gd; then
  echo "Ability cast VFX must exist" >&2
  exit 1
fi

if ! rg -q 'func try_cheat_death' scripts/player.gd; then
  echo "Aegis Sigil must hook into lethal damage" >&2
  exit 1
fi

for sprite in arclight bulwark warden frostbinder grunt swarmling spitter drifter brute stalker bomber hexer sentinel splitter charger summoner ravager stormcaller spit bolt spark xp_orb coin; do
  if [[ ! -f "assets/sprites/${sprite}.png" ]]; then
    echo "Missing pixel art: assets/sprites/${sprite}.png (run tools/sprite_forge.tscn)" >&2
    exit 1
  fi
done

if ! rg -q '"class_id": class_id' scripts/player.gd; then
  echo "Player snapshots must replicate the chosen class" >&2
  exit 1
fi

if ! rg -q '^class_name GameHUD$' scripts/hud.gd || ! rg -q '@onready var hud: GameHUD' scripts/main.gd; then
  echo "HUD must be strongly typed for Godot 4.7 parser compatibility" >&2
  exit 1
fi

echo "Project structure validation passed."
