extends Node2D

@export var max_enemies := 35
@export var spawn_distance_min := 520.0
@export var spawn_distance_max := 760.0
@export var snapshot_rate := 20.0
@export var input_send_rate := 30.0

@onready var actors: Node2D = $Actors
@onready var spawn_timer: Timer = $EnemySpawnTimer
@onready var hud: GameHUD = $HUD

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
var xp_orb_scene: PackedScene = preload("res://scenes/xp/xp_orb.tscn")
var lightning_scene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
var combat_text_scene: PackedScene = preload("res://scenes/effects/combat_text.tscn")

var players: Dictionary = {}
var enemies: Dictionary = {}
var xp_orbs: Dictionary = {}
var pending_inputs: Dictionary = {}
var pending_upgrades: Dictionary = {}
var queued_upgrade_choices: Dictionary = {}
var registered_remote_peers: Dictionary = {}
var next_entity_id := 1
var snapshot_accumulator := 0.0
var input_accumulator := 0.0
var initial_wave_spawned := false
var game_over := false
var run_elapsed := 0.0


func _ready() -> void:
	randomize()
	NetworkService.peer_left.connect(_on_peer_left)
	hud.upgrade_chosen.connect(_on_local_upgrade_chosen)
	hud.dev_command.connect(_on_local_dev_command)
	hud.restart_requested.connect(_on_restart_requested)
	hud.leave_requested.connect(_on_leave_requested)
	hud.set_connection_text(GameRuntime.mode_name())

	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		_create_player(1, Player.SimulationMode.OFFLINE, true)
		_spawn_initial_wave()
	elif GameRuntime.is_server():
		if GameRuntime.mode == GameRuntime.RuntimeMode.HOST:
			_create_player(1, Player.SimulationMode.AUTHORITY, true)
			_spawn_initial_wave()
		if GameRuntime.is_dedicated_server():
			hud.visible = false
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		spawn_timer.stop()
		call_deferred("_register_with_server")


func _physics_process(delta: float) -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT and not game_over:
		run_elapsed += delta
	if not GameRuntime.is_dedicated_server():
		hud.set_run_time(run_elapsed)
	if GameRuntime.is_server():
		_update_host_input()
		snapshot_accumulator += delta
		if snapshot_accumulator >= 1.0 / snapshot_rate:
			snapshot_accumulator = 0.0
			var snapshot := _build_snapshot()
			for peer_id in registered_remote_peers.keys():
				client_receive_snapshot.rpc_id(peer_id, snapshot)
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		input_accumulator += delta
		if input_accumulator >= 1.0 / input_send_rate:
			input_accumulator = 0.0
			_send_local_input()


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart") and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_parent().call_deferred("restart_game")


func _register_with_server() -> void:
	server_register_client.rpc_id(1, {
		"player_id": PlayerProfile.player_id,
		"display_name": PlayerProfile.display_name,
	})


@rpc("any_peer", "call_remote", "reliable")
func server_register_client(_profile: Dictionary) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or players.has(peer_id) or players.size() >= GameRuntime.DEFAULT_MAX_PLAYERS:
		return
	_create_player(peer_id, Player.SimulationMode.AUTHORITY, false)
	registered_remote_peers[peer_id] = true
	if not initial_wave_spawned:
		_spawn_initial_wave()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func server_submit_input(move_input: Vector2, aim_position: Vector2, attack_held: bool) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not players.has(peer_id):
		return
	pending_inputs[peer_id] = {
		"move": move_input.limit_length(1.0),
		"aim": aim_position,
		"attack": attack_held,
	}
	_apply_pending_input(peer_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		return
	_apply_player_snapshot(snapshot.get("players", []))
	_apply_enemy_snapshot(snapshot.get("enemies", []))
	_apply_xp_snapshot(snapshot.get("xp_orbs", []))
	run_elapsed = float(snapshot.get("run_elapsed", run_elapsed))


@rpc("authority", "call_remote", "reliable")
func client_play_staff_effect(points: PackedVector2Array) -> void:
	_play_staff_effect(points)


@rpc("authority", "call_remote", "reliable")
func client_play_combat_number(world_position: Vector2, value: float, kind: String, critical: bool) -> void:
	_play_combat_number(world_position, value, kind, critical)


@rpc("authority", "call_remote", "reliable")
func client_offer_upgrades(upgrade_ids: Array[String]) -> void:
	var local_player := _local_player()
	if local_player != null:
		hud.show_upgrade_ids(local_player, upgrade_ids, false)


@rpc("any_peer", "call_remote", "reliable")
func server_choose_upgrade(upgrade_id: String) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_apply_upgrade_choice(peer_id, upgrade_id)


@rpc("any_peer", "call_remote", "reliable")
func server_dev_command(command: String) -> void:
	if not GameRuntime.is_server() or not OS.is_debug_build():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not registered_remote_peers.has(peer_id):
		return
	_apply_dev_command(peer_id, command)


func _create_player(peer_id: int, mode: int, local_player: bool) -> Player:
	if players.has(peer_id):
		return players[peer_id] as Player
	var player := player_scene.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.global_position = _spawn_position_for_peer(peer_id)
	actors.add_child(player)
	player.configure(peer_id, mode, local_player)
	player.staff_cast.connect(_on_staff_cast)
	player.combat_number.connect(_on_combat_number)
	player.player_died.connect(_on_player_died)
	player.level_reached.connect(_on_player_level_reached.bind(peer_id))
	players[peer_id] = player
	pending_inputs[peer_id] = {
		"move": Vector2.ZERO,
		"aim": player.global_position + Vector2.RIGHT * 100.0,
		"attack": false,
	}
	if local_player and not GameRuntime.is_dedicated_server():
		hud.bind_player(player)
	return player


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	var slot := players.size()
	var angle := float(slot) * TAU / float(GameRuntime.DEFAULT_MAX_PLAYERS)
	return Vector2.RIGHT.rotated(angle) * 72.0


func _update_host_input() -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.HOST or not players.has(1):
		return
	var host_player := players[1] as Player
	host_player.set_authority_command(
		InputService.movement_vector(),
		InputService.aim_world_position(host_player),
		InputService.primary_attack_held()
	)


func _send_local_input() -> void:
	var local_player := _local_player()
	if local_player == null:
		return
	server_submit_input.rpc_id(
		1,
		InputService.movement_vector(),
		InputService.aim_world_position(local_player),
		InputService.primary_attack_held()
	)


func _apply_pending_input(peer_id: int) -> void:
	var player := players.get(peer_id) as Player
	var input_state: Dictionary = pending_inputs.get(peer_id, {})
	if player == null or input_state.is_empty():
		return
	player.set_authority_command(
		input_state.get("move", Vector2.ZERO),
		input_state.get("aim", player.global_position + Vector2.RIGHT),
		input_state.get("attack", false)
	)


func _on_enemy_spawn_timer_timeout() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT or game_over:
		return
	var active_cap := mini(max_enemies + floori(run_elapsed / 45.0) * 4, 75)
	if enemies.size() >= active_cap or players.is_empty():
		return
	var party_bonus := maxi(0, players.size() - 1)
	var spawn_count := 1 + party_bonus
	if run_elapsed >= 180.0:
		spawn_count += 1
	for index in spawn_count:
		if enemies.size() >= active_cap:
			break
		_spawn_enemy(
			randf_range(0.0, TAU),
			randf_range(spawn_distance_min, spawn_distance_max),
			_choose_enemy_kind()
		)


func _spawn_initial_wave() -> void:
	if initial_wave_spawned or players.is_empty():
		return
	initial_wave_spawned = true
	for index in range(5):
		_spawn_enemy(index * TAU / 5.0, 420.0)


func _spawn_enemy(angle: float, distance: float, kind: String = "grunt") -> Enemy:
	var focus := _first_active_player()
	if focus == null:
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	var entity_id := next_entity_id
	next_entity_id += 1
	var candidate_position := focus.global_position + Vector2.RIGHT.rotated(angle) * distance
	candidate_position.x = clampf(candidate_position.x, -1160.0, 1160.0)
	candidate_position.y = clampf(candidate_position.y, -760.0, 760.0)
	enemy.global_position = candidate_position
	actors.add_child(enemy)
	var difficulty := 1.0 + run_elapsed / 420.0
	enemy.configure(entity_id, true, kind, difficulty)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies[entity_id] = enemy
	return enemy


func _choose_enemy_kind() -> String:
	var roll := randf()
	if run_elapsed >= 120.0 and roll < 0.08:
		return "elite"
	if run_elapsed >= 75.0 and roll < 0.30:
		return "brute"
	if run_elapsed >= 30.0 and roll < 0.58:
		return "swift"
	return "grunt"


func _spawn_xp_orb(position: Vector2, value: int) -> XPOrb:
	var orb := xp_orb_scene.instantiate() as XPOrb
	var entity_id := next_entity_id
	next_entity_id += 1
	orb.global_position = position
	orb.xp_value = value
	actors.add_child(orb)
	orb.configure(entity_id, true)
	orb.tree_exited.connect(_on_xp_orb_exited.bind(entity_id))
	xp_orbs[entity_id] = orb
	return orb


func _on_enemy_defeated(enemy: Enemy) -> void:
	enemies.erase(enemy.network_id)
	_spawn_xp_orb(enemy.global_position, enemy.xp_value)


func _on_xp_orb_exited(entity_id: int) -> void:
	xp_orbs.erase(entity_id)


func _on_staff_cast(points: PackedVector2Array) -> void:
	_play_staff_effect(points)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_staff_effect.rpc_id(peer_id, points)


func _play_staff_effect(points: PackedVector2Array) -> void:
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.points = points
	add_child(effect)


func _on_combat_number(world_position: Vector2, value: float, kind: String, critical: bool) -> void:
	_play_combat_number(world_position, value, kind, critical)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_combat_number.rpc_id(peer_id, world_position, value, kind, critical)


func _play_combat_number(world_position: Vector2, value: float, kind: String, critical: bool) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var combat_text := combat_text_scene.instantiate() as CombatText
	combat_text.global_position = world_position + Vector2(randf_range(-9.0, 9.0), -20.0)
	add_child(combat_text)
	combat_text.setup(value, kind, critical)


func _on_player_died(_peer_id: int) -> void:
	if _all_players_dead():
		game_over = true
		spawn_timer.stop()
		if not GameRuntime.is_dedicated_server():
			hud.show_game_over()


func _on_player_level_reached(_level: int, peer_id: int) -> void:
	if not GameRuntime.is_server() and GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	queued_upgrade_choices[peer_id] = int(queued_upgrade_choices.get(peer_id, 0)) + 1
	_offer_next_upgrade(peer_id)


func _offer_next_upgrade(peer_id: int) -> void:
	if pending_upgrades.has(peer_id) or int(queued_upgrade_choices.get(peer_id, 0)) <= 0:
		return
	var player := players.get(peer_id) as Player
	if player == null:
		return
	var upgrade_ids := hud.structured_upgrade_ids(player)
	if upgrade_ids.size() < 3:
		return
	pending_upgrades[peer_id] = upgrade_ids
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE or peer_id == 1:
		hud.show_upgrade_ids(players[peer_id], upgrade_ids, GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
	else:
		client_offer_upgrades.rpc_id(peer_id, upgrade_ids)


func _on_local_upgrade_chosen(upgrade_id: String) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_choose_upgrade.rpc_id(1, upgrade_id)
	else:
		var local_player := _local_player()
		if local_player != null:
			_apply_upgrade_choice(local_player.owner_peer_id, upgrade_id)


func _apply_upgrade_choice(peer_id: int, upgrade_id: String) -> void:
	var offered: Array = pending_upgrades.get(peer_id, [])
	var player := players.get(peer_id) as Player
	if player == null or upgrade_id not in offered:
		return
	player.apply_upgrade(upgrade_id)
	pending_upgrades.erase(peer_id)
	queued_upgrade_choices[peer_id] = maxi(0, int(queued_upgrade_choices.get(peer_id, 0)) - 1)
	_offer_next_upgrade(peer_id)


func _on_local_dev_command(command: String) -> void:
	if not OS.is_debug_build():
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_dev_command.rpc_id(1, command)
	else:
		var player := _local_player()
		if player != null:
			_apply_dev_command(player.owner_peer_id, command)


func _apply_dev_command(peer_id: int, command: String) -> void:
	var player := players.get(peer_id) as Player
	if player == null:
		return
	match command:
		"add_xp":
			player.add_xp(100)
		"add_5_levels":
			pending_upgrades.erase(peer_id)
			queued_upgrade_choices[peer_id] = 0
			player.dev_add_levels(5)
		"spawn_elite":
			_spawn_enemy(randf_range(0.0, TAU), 360.0, "elite")
		"toggle_invulnerable":
			player.set_invulnerable(not player.health.invulnerable)


func _on_restart_requested() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_tree().paused = false
		get_parent().call_deferred("restart_game")


func _on_leave_requested() -> void:
	get_tree().paused = false
	get_parent().call_deferred("leave_game")


func _build_snapshot() -> Dictionary:
	var player_states: Array[Dictionary] = []
	var enemy_states: Array[Dictionary] = []
	var orb_states: Array[Dictionary] = []
	for player in players.values():
		if is_instance_valid(player):
			player_states.append((player as Player).snapshot())
	for enemy in enemies.values():
		if is_instance_valid(enemy):
			enemy_states.append((enemy as Enemy).snapshot())
	for orb in xp_orbs.values():
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			orb_states.append((orb as XPOrb).snapshot())
	return {
		"players": player_states,
		"enemies": enemy_states,
		"xp_orbs": orb_states,
		"run_elapsed": run_elapsed,
	}


func _apply_player_snapshot(states: Array) -> void:
	var seen: Dictionary = {}
	var local_peer_id := multiplayer.get_unique_id()
	for raw_state in states:
		var state: Dictionary = raw_state
		var peer_id := int(state.get("peer_id", 0))
		if peer_id <= 0:
			continue
		seen[peer_id] = true
		if not players.has(peer_id):
			var is_local := peer_id == local_peer_id
			var created_player := _create_player(peer_id, Player.SimulationMode.PROXY, is_local)
			created_player.global_position = state.get("position", Vector2.ZERO)
		var snapshot_player := players[peer_id] as Player
		snapshot_player.apply_network_state(state)
		if snapshot_player.is_local_player and not snapshot_player.active:
			hud.show_game_over()
	_remove_missing_entities(players, seen)


func _apply_enemy_snapshot(states: Array) -> void:
	var seen: Dictionary = {}
	for raw_state in states:
		var state: Dictionary = raw_state
		var entity_id := int(state.get("id", 0))
		if entity_id <= 0:
			continue
		seen[entity_id] = true
		if not enemies.has(entity_id):
			var enemy := enemy_scene.instantiate() as Enemy
			enemy.global_position = state.get("position", Vector2.ZERO)
			actors.add_child(enemy)
			enemy.configure(entity_id, false, str(state.get("kind", "grunt")))
			enemies[entity_id] = enemy
		(enemies[entity_id] as Enemy).apply_network_state(state)
	_remove_missing_entities(enemies, seen)


func _apply_xp_snapshot(states: Array) -> void:
	var seen: Dictionary = {}
	for raw_state in states:
		var state: Dictionary = raw_state
		var entity_id := int(state.get("id", 0))
		if entity_id <= 0:
			continue
		seen[entity_id] = true
		if not xp_orbs.has(entity_id):
			var orb := xp_orb_scene.instantiate() as XPOrb
			orb.global_position = state.get("position", Vector2.ZERO)
			actors.add_child(orb)
			orb.configure(entity_id, false)
			xp_orbs[entity_id] = orb
		(xp_orbs[entity_id] as XPOrb).apply_network_state(state)
	_remove_missing_entities(xp_orbs, seen)


func _remove_missing_entities(collection: Dictionary, seen: Dictionary) -> void:
	for entity_id in collection.keys():
		if seen.has(entity_id):
			continue
		var entity: Node = collection[entity_id]
		collection.erase(entity_id)
		if is_instance_valid(entity):
			entity.queue_free()


func _on_peer_left(peer_id: int) -> void:
	pending_inputs.erase(peer_id)
	pending_upgrades.erase(peer_id)
	queued_upgrade_choices.erase(peer_id)
	registered_remote_peers.erase(peer_id)
	var player := players.get(peer_id) as Player
	players.erase(peer_id)
	if player != null:
		player.queue_free()


func _local_player() -> Player:
	for player in players.values():
		if is_instance_valid(player) and (player as Player).is_local_player:
			return player as Player
	return null


func _first_active_player() -> Player:
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			return player as Player
	return null


func _all_players_dead() -> bool:
	return not players.is_empty() and _first_active_player() == null
