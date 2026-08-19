extends Node2D

@export var max_enemies := 70
@export var spawn_distance_min := 520.0
@export var spawn_distance_max := 760.0
@export var snapshot_rate := 20.0
@export var input_send_rate := 30.0

@onready var arena: Node2D = $Arena
@onready var actors: Node2D = $Actors
@onready var wave_director: WaveDirector = $WaveDirector
@onready var hud: GameHUD = $HUD

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
var xp_orb_scene: PackedScene = preload("res://scenes/xp/xp_orb.tscn")
var lightning_scene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

var players: Dictionary = {}
var enemies: Dictionary = {}
var xp_orbs: Dictionary = {}
var pending_inputs: Dictionary = {}
var pending_upgrades: Dictionary = {}
## How many more upgrade choices a peer is owed, for when several levels land in one frame
## (a big XP orb, or the dev menu's "+5 levels") so no choice gets silently skipped.
var queued_upgrade_choices: Dictionary = {}
var registered_remote_peers: Dictionary = {}
var next_entity_id := 1
var snapshot_accumulator := 0.0
var input_accumulator := 0.0
var initial_wave_spawned := false
var game_over := false
var current_wave := 0
var current_wave_name := ""
var current_debut_type_id := ""
var _near_shop_stand := false

const SHOP_STAND_INTERACT_RADIUS := 70.0


func _ready() -> void:
	randomize()
	NetworkService.peer_left.connect(_on_peer_left)
	hud.upgrade_chosen.connect(_on_local_upgrade_chosen)
	hud.shop_item_chosen.connect(_on_local_shop_item_chosen)
	hud.shop_closed.connect(_on_local_shop_closed)
	hud.next_wave_requested.connect(_on_local_next_wave_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.leave_requested.connect(_on_leave_requested)
	hud.dev_command.connect(_on_local_dev_command)
	hud.set_connection_text(GameRuntime.mode_name())
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.group_ready.connect(_on_wave_group_ready)
	wave_director.intermission_started.connect(_on_intermission_started)

	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		_create_player(1, Player.SimulationMode.OFFLINE, true, GameRuntime.active_class_id())
		_spawn_initial_wave()
	elif GameRuntime.is_server():
		if GameRuntime.mode == GameRuntime.RuntimeMode.HOST:
			_create_player(1, Player.SimulationMode.AUTHORITY, true, GameRuntime.active_class_id())
			_spawn_initial_wave()
		if GameRuntime.is_dedicated_server():
			hud.visible = false
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		wave_director.stop()
		call_deferred("_register_with_server")


func _physics_process(delta: float) -> void:
	if GameRuntime.is_server():
		_update_host_input()
		wave_director.report_enemy_count(enemies.size())
		if not GameRuntime.is_dedicated_server():
			hud.update_boss(_find_boss())
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
	if not GameRuntime.is_dedicated_server() and not GameRuntime.is_classic():
		_update_shop_stand_proximity()


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart") and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_parent().call_deferred("restart_game")


func _register_with_server() -> void:
	server_register_client.rpc_id(1, {
		"player_id": PlayerProfile.player_id,
		"display_name": PlayerProfile.display_name,
		"class_id": GameRuntime.active_class_id(),
	})


@rpc("any_peer", "call_remote", "reliable")
func server_register_client(profile: Dictionary) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or players.has(peer_id) or players.size() >= GameRuntime.DEFAULT_MAX_PLAYERS:
		return
	var requested_class := PlayerClass.DEFAULT_CLASS_ID
	if not GameRuntime.is_classic():
		requested_class = PlayerClass.sanitize_id(str(profile.get("class_id", PlayerClass.DEFAULT_CLASS_ID)))
	_create_player(peer_id, Player.SimulationMode.AUTHORITY, false, requested_class)
	registered_remote_peers[peer_id] = true
	if not initial_wave_spawned:
		_spawn_initial_wave()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func server_submit_input(move_input: Vector2, aim_position: Vector2, attack_held: bool, ability_held: bool = false) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not players.has(peer_id):
		return
	pending_inputs[peer_id] = {
		"move": move_input.limit_length(1.0),
		"aim": aim_position,
		"attack": attack_held,
		"ability": ability_held,
	}
	_apply_pending_input(peer_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		return
	_apply_player_snapshot(snapshot.get("players", []))
	_apply_enemy_snapshot(snapshot.get("enemies", []))
	_apply_xp_snapshot(snapshot.get("xp_orbs", []))
	var snapshot_wave := int(snapshot.get("wave", current_wave))
	if snapshot_wave != current_wave:
		current_wave = snapshot_wave
		current_wave_name = str(snapshot.get("wave_name", ""))
		hud.set_wave(current_wave, current_wave_name)
	hud.update_boss(_find_boss())


@rpc("authority", "call_remote", "reliable")
func client_play_staff_effect(effect_kind: String, points: PackedVector2Array) -> void:
	_play_staff_effect(effect_kind, points)


@rpc("authority", "call_remote", "reliable")
func client_spawn_enemy_projectile(origin: Vector2, direction: Vector2, speed: float, sprite_name: String) -> void:
	_spawn_enemy_projectile(origin, direction, 0.0, speed, true, sprite_name)


@rpc("authority", "call_remote", "reliable")
func client_play_explosion(origin: Vector2, radius: float) -> void:
	_play_explosion_effect(origin, radius)


@rpc("authority", "call_remote", "reliable")
func client_play_sound(sound_id: String) -> void:
	_play_sound(sound_id)


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


## Dev-menu commands only ever apply to the sender's own player, and only in debug builds,
## so there is no way to use this to affect anyone else's run.
@rpc("any_peer", "call_remote", "reliable")
func server_dev_command(command: String) -> void:
	if not GameRuntime.is_server() or not OS.is_debug_build():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not registered_remote_peers.has(peer_id):
		return
	_apply_dev_command(peer_id, command)


@rpc("authority", "call_remote", "reliable")
func client_announce_wave(wave: int, theme_name: String, debut_type_id: String) -> void:
	hud.close_shop()
	hud.set_wave(wave, theme_name)
	hud.announce_wave(wave, theme_name, debut_type_id)
	hud.show_next_wave_button(false)


@rpc("authority", "call_remote", "reliable")
func client_open_shop() -> void:
	hud.open_shop(false)


@rpc("authority", "call_remote", "reliable")
func client_show_next_wave_button() -> void:
	hud.show_next_wave_button(true)


@rpc("any_peer", "call_remote", "reliable")
func server_skip_intermission() -> void:
	if not GameRuntime.is_server():
		return
	wave_director.skip_intermission()


@rpc("any_peer", "call_remote", "reliable")
func server_buy_shop_item(item_id: String) -> void:
	if not GameRuntime.is_server():
		return
	_apply_shop_purchase(multiplayer.get_remote_sender_id(), item_id)


func _apply_shop_purchase(peer_id: int, item_id: String) -> void:
	if GameRuntime.is_classic():
		return
	var player := players.get(peer_id) as Player
	if player != null:
		player.buy(item_id)


func _on_local_shop_item_chosen(item_id: String) -> void:
	AudioService.play("purchase")
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_buy_shop_item.rpc_id(1, item_id)
		return
	var local_player := _local_player()
	if local_player != null:
		_apply_shop_purchase(local_player.owner_peer_id, item_id)


## Only the solo run may cut its own breather short.
func _on_local_shop_closed() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		wave_director.skip_intermission()


## Lets a player pop the shop open by walking up to the arena's shop stand at any point in a
## wave, not just during the forced breather every 10 waves. Purely a local UI toggle — the
## stand's position is a shared constant, so every peer resolves this identically without
## any networking, and purchases already go through the existing buy RPC either way.
func _update_shop_stand_proximity() -> void:
	var local_player := _local_player()
	if local_player == null or not local_player.active or game_over:
		if _near_shop_stand:
			_near_shop_stand = false
			hud.close_shop()
		return
	if hud.upgrade_panel.visible or hud.escape_menu.visible or hud.dev_panel.visible or hud.codex_panel.visible:
		return
	var in_range := local_player.global_position.distance_to(Arena.SHOP_STAND_POSITION) <= SHOP_STAND_INTERACT_RADIUS
	if in_range and not _near_shop_stand:
		_near_shop_stand = true
		hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
	elif not in_range and _near_shop_stand:
		_near_shop_stand = false
		hud.close_shop()


func _on_local_next_wave_requested() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_skip_intermission.rpc_id(1)
	else:
		wave_director.skip_intermission()


func _create_player(peer_id: int, mode: int, local_player: bool, class_id: String = PlayerClass.DEFAULT_CLASS_ID) -> Player:
	if players.has(peer_id):
		return players[peer_id] as Player
	var player := player_scene.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.global_position = _spawn_position_for_peer(peer_id)
	actors.add_child(player)
	player.configure(peer_id, mode, local_player, class_id)
	player.staff_cast.connect(_on_staff_cast)
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
	if GameRuntime.is_server():
		wave_director.set_player_count(players.size())
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
		InputService.primary_attack_held(),
		InputService.ability_held()
	)


func _send_local_input() -> void:
	var local_player := _local_player()
	if local_player == null:
		return
	server_submit_input.rpc_id(
		1,
		InputService.movement_vector(),
		InputService.aim_world_position(local_player),
		InputService.primary_attack_held(),
		InputService.ability_held()
	)


func _apply_pending_input(peer_id: int) -> void:
	var player := players.get(peer_id) as Player
	var input_state: Dictionary = pending_inputs.get(peer_id, {})
	if player == null or input_state.is_empty():
		return
	player.set_authority_command(
		input_state.get("move", Vector2.ZERO),
		input_state.get("aim", player.global_position + Vector2.RIGHT),
		input_state.get("attack", false),
		input_state.get("ability", false)
	)


func _spawn_initial_wave() -> void:
	if initial_wave_spawned or players.is_empty():
		return
	initial_wave_spawned = true
	if GameRuntime.is_classic():
		max_enemies = 35
	wave_director.start(players.size(), GameRuntime.is_classic())


func _on_wave_started(wave: int, theme_name: String, debut_type_id: String) -> void:
	current_wave = wave
	current_wave_name = theme_name
	current_debut_type_id = debut_type_id
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		for player in players.values():
			(player as Player).refresh_wave_items()
	if not GameRuntime.is_dedicated_server():
		hud.close_shop()
		hud.set_wave(wave, theme_name)
		hud.announce_wave(wave, theme_name, debut_type_id)
		hud.show_next_wave_button(false)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_wave.rpc_id(peer_id, wave, theme_name, debut_type_id)


## Shop waves keep their own "START NEXT WAVE" button in the shop panel; the standalone
## Next Wave button only shows for the plain breathers between waves, so it doesn't sit
## underneath the shop panel doing the same thing twice.
func _on_intermission_started(next_wave: int, _seconds: float) -> void:
	if WaveDirector.shop_opens_before(next_wave):
		if not GameRuntime.is_dedicated_server():
			hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_open_shop.rpc_id(peer_id)
		return
	if not GameRuntime.is_dedicated_server():
		hud.show_next_wave_button(true)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_show_next_wave_button.rpc_id(peer_id)


func _on_wave_group_ready(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float) -> void:
	if game_over or players.is_empty():
		return
	_spawn_formation(type_id, formation, count, health_multiplier, speed_multiplier)


func _spawn_formation(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0) -> void:
	var base_angle := randf_range(0.0, TAU)
	var pack_center := Vector2.RIGHT.rotated(base_angle) * randf_range(spawn_distance_min, spawn_distance_max)
	for index in count:
		if enemies.size() >= max_enemies:
			return
		var offset := Vector2.ZERO
		match formation:
			EnemyType.Formation.PACK:
				offset = pack_center + Vector2(randf_range(-110.0, 110.0), randf_range(-110.0, 110.0))
			EnemyType.Formation.RING:
				var ring_angle := base_angle + float(index) * TAU / float(maxi(1, count))
				offset = Vector2.RIGHT.rotated(ring_angle) * spawn_distance_min
			EnemyType.Formation.LONE:
				var lone_angle := randf_range(0.0, TAU)
				offset = Vector2.RIGHT.rotated(lone_angle) * randf_range(spawn_distance_max, spawn_distance_max + 90.0)
			_:
				var scatter_angle := randf_range(0.0, TAU)
				offset = Vector2.RIGHT.rotated(scatter_angle) * randf_range(spawn_distance_min, spawn_distance_max)
		_spawn_enemy(offset, type_id, health_multiplier, speed_multiplier)


func _spawn_enemy(offset: Vector2, type_id: String, health_multiplier: float, speed_multiplier: float = 1.0) -> Enemy:
	var focus := _first_active_player()
	if focus == null:
		return null
	var enemy := enemy_scene.instantiate() as Enemy
	var entity_id := next_entity_id
	next_entity_id += 1
	var candidate_position := focus.global_position + offset
	candidate_position.x = clampf(candidate_position.x, -1160.0, 1160.0)
	candidate_position.y = clampf(candidate_position.y, -760.0, 760.0)
	enemy.global_position = arena.free_position_near(candidate_position, 22.0)
	actors.add_child(enemy)
	enemy.configure(entity_id, true, type_id, health_multiplier, speed_multiplier)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.projectile_fired.connect(_on_enemy_projectile_fired)
	enemy.spawn_requested.connect(_on_enemy_spawn_requested)
	enemy.exploded.connect(_on_enemy_exploded)
	enemies[entity_id] = enemy
	return enemy


func _on_enemy_spawn_requested(type_id: String, origin: Vector2, count: int) -> void:
	if game_over:
		return
	var focus := _first_active_player()
	if focus == null:
		return
	var multiplier := wave_director.health_multiplier_for_wave(current_wave)
	for index in count:
		if enemies.size() >= max_enemies:
			return
		var jitter := Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0))
		_spawn_enemy(origin + jitter - focus.global_position, type_id, multiplier)


func _on_enemy_exploded(origin: Vector2, radius: float, _damage: float) -> void:
	_play_explosion_effect(origin, radius)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_explosion.rpc_id(peer_id, origin, radius)


func _play_explosion_effect(origin: Vector2, radius: float) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.style = PlayerClass.EffectStyle.BURST
	effect.main_color = Color("ffdc4d")
	effect.chain_color = Color("ff7a29")
	effect.points = PackedVector2Array([origin, Vector2(radius, 0.0)])
	add_child(effect)
	AudioService.play("explosion")


func _play_sound(sound_id: String) -> void:
	if GameRuntime.is_dedicated_server():
		return
	AudioService.play(sound_id)


func _find_boss() -> Enemy:
	for enemy in enemies.values():
		if is_instance_valid(enemy) and (enemy as Enemy).is_boss and not (enemy as Enemy).health.is_dead:
			return enemy as Enemy
	return null


func _on_enemy_projectile_fired(origin: Vector2, direction: Vector2, damage: float, speed: float, sprite_name: String) -> void:
	_spawn_enemy_projectile(origin, direction, damage, speed, false, sprite_name)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_spawn_enemy_projectile.rpc_id(peer_id, origin, direction, speed, sprite_name)


func _spawn_enemy_projectile(origin: Vector2, direction: Vector2, damage: float, speed: float, cosmetic: bool, sprite_name: String = "") -> void:
	if cosmetic and GameRuntime.is_dedicated_server():
		return
	var projectile := projectile_scene.instantiate() as SurvivorProjectile
	projectile.global_position = origin
	actors.add_child(projectile)
	projectile.configure(direction, damage, speed, true, cosmetic, sprite_name)
	if not GameRuntime.is_dedicated_server():
		AudioService.play("enemy_shoot")


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
	_award_gold(enemy.gold_value)
	_play_sound("enemy_death")
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_sound.rpc_id(peer_id, "enemy_death")


## Gold is shared, so nobody has to race their team mates to the corpse.
func _award_gold(amount: int) -> void:
	if GameRuntime.is_classic() or amount <= 0:
		return
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			(player as Player).add_gold(amount)


func _on_xp_orb_exited(entity_id: int) -> void:
	xp_orbs.erase(entity_id)


func _on_staff_cast(effect_kind: String, points: PackedVector2Array) -> void:
	_play_staff_effect(effect_kind, points)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_staff_effect.rpc_id(peer_id, effect_kind, points)


func _play_staff_effect(effect_kind: String, points: PackedVector2Array) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var class_data := PlayerClass.by_id(effect_kind)
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.style = class_data.effect_style
	effect.main_color = Color(class_data.effect_color)
	effect.chain_color = Color(class_data.effect_secondary)
	effect.points = points
	add_child(effect)
	AudioService.play("cast_%s" % effect_kind)


func _on_player_died(_peer_id: int) -> void:
	if _all_players_dead():
		game_over = true
		wave_director.stop()
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
	var leveled_player := players.get(peer_id) as Player
	if leveled_player == null:
		return
	var upgrade_ids := PlayerClass.random_upgrade_ids(leveled_player.class_id)
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


func _on_restart_requested() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_tree().paused = false
		get_parent().call_deferred("restart_game")


func _on_leave_requested() -> void:
	get_tree().paused = false
	get_parent().call_deferred("leave_game")


func _on_local_dev_command(command: String) -> void:
	if not OS.is_debug_build():
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_dev_command.rpc_id(1, command)
	else:
		var local_player := _local_player()
		if local_player != null:
			_apply_dev_command(local_player.owner_peer_id, command)


func _apply_dev_command(peer_id: int, command: String) -> void:
	var player := players.get(peer_id) as Player
	if player == null:
		return
	match command:
		"add_xp":
			player.add_xp(100)
		"add_1_level":
			player.dev_add_levels(1)
		"add_5_levels":
			player.dev_add_levels(5)
		"spawn_elite":
			_dev_spawn_elite()
		"toggle_invulnerable":
			player.set_invulnerable(not player.health.invulnerable)


## Uses the wave system's own health scaling and spawn plumbing, so it works the same in
## Classic mode too even though Classic's own spawner never picks anything but grunts.
func _dev_spawn_elite() -> void:
	if game_over:
		return
	var offset := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 260.0
	var multiplier := wave_director.health_multiplier_for_wave(maxi(1, current_wave))
	_spawn_enemy(offset, "brute", multiplier)


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
		"wave": current_wave,
		"wave_name": current_wave_name,
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
			var state_class_id := PlayerClass.sanitize_id(str(state.get("class_id", PlayerClass.DEFAULT_CLASS_ID)))
			var created_player := _create_player(peer_id, Player.SimulationMode.PROXY, is_local, state_class_id)
			created_player.global_position = state.get("position", Vector2.ZERO)
		var snapshot_player := players[peer_id] as Player
		snapshot_player.apply_network_state(state)
		if snapshot_player.is_local_player:
			hud.show_player_class(snapshot_player.class_id)
			if not snapshot_player.active:
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
			enemy.configure(entity_id, false, EnemyType.sanitize_id(str(state.get("type_id", EnemyType.DEFAULT_TYPE_ID))))
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
