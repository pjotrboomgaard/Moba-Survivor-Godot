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
@onready var world_flash: Node2D = get_node_or_null("WorldFlash")

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
var xp_orb_scene: PackedScene = preload("res://scenes/xp/xp_orb.tscn")
var lightning_scene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
var ability_vfx_scene: PackedScene = preload("res://scenes/effects/ability_vfx.tscn")
var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

var players: Dictionary = {}
var enemies: Dictionary = {}
var xp_orbs: Dictionary = {}
var pending_inputs: Dictionary = {}
var pending_upgrades: Dictionary = {}
## Mirrors pending_upgrades but for the ability track (see offer_turn_index below).
var pending_ability_offers: Dictionary = {}
## How many more upgrade choices a peer is owed, for when several levels land in one frame
## (a big XP orb, or the dev menu's "+5 levels") so no choice gets silently skipped.
var queued_upgrade_choices: Dictionary = {}
## Level-ups alternate: even count so far -> an ability choice (learn new or rank up known),
## odd count so far -> the classic flat stat-upgrade choice. Incremented on every resolution.
var offer_turn_index: Dictionary = {}
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
## Peer ids that have pressed the Next Wave button this breather (co-op requires everyone).
var ready_for_next_wave: Dictionary = {}
## peer_id of the downed player -> seconds a stationary teammate has stood next to them.
var revive_progress: Dictionary = {}

const REVIVE_RADIUS := 60.0
const REVIVE_DURATION := 5.0
const BOSS_MAX_ENEMIES := 160
const CHANT_POLL_SECONDS := 0.85
const CHANT_SUCCESS_COOLDOWN := 2.4
const RAVAGER_MINION_START_SPEED := 0.28
const RAVAGER_MINION_RAMP := 18.0
const RAVAGER_MINION_CAP := 2.2

var _chant_active := false
var _chant_mantra := ""
var _chant_time_left := 0.0
var _chant_matched := 0
var _chant_poll := 0.0
var _chant_cooldown := 0.0
var _chant_polling := false


func _ready() -> void:
	randomize()
	NetworkService.peer_left.connect(_on_peer_left)
	hud.upgrade_chosen.connect(_on_local_upgrade_chosen)
	hud.ability_chosen.connect(_on_local_ability_chosen)
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
		_spawn_cpu_allies()
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
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		_update_revives(delta)
	if not GameRuntime.is_dedicated_server():
		_update_chant(delta)


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("restart") and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_parent().call_deferred("restart_game")
	if event.is_action_pressed("interact_shop") and _near_shop_stand and not game_over:
		if not hud.upgrade_panel.visible and not hud.escape_menu.visible and not hud.dev_panel.visible and not hud.codex_panel.visible:
			hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
			_cpu_auto_shop()


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
func server_submit_input(move_input: Vector2, aim_position: Vector2, attack_held: bool, ability_held: bool = false, ability_slots_held: Array = [false, false, false, false], secondary_held: bool = false) -> void:
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
		"ability_slots": ability_slots_held,
		"secondary": secondary_held,
	}
	_apply_pending_input(peer_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		return
	_apply_player_snapshot(snapshot.get("players", []))
	_apply_enemy_snapshot(snapshot.get("enemies", []))
	_apply_xp_snapshot(snapshot.get("xp_orbs", []))
	var snapshot_biome := int(snapshot.get("biome_id", GameRuntime.biome_id))
	if snapshot_biome != GameRuntime.biome_id:
		_transition_to_biome(snapshot_biome)
	var snapshot_wave := int(snapshot.get("wave", current_wave))
	if snapshot_wave != current_wave:
		current_wave = snapshot_wave
		current_wave_name = str(snapshot.get("wave_name", ""))
		hud.set_wave(current_wave, current_wave_name)
	hud.update_boss(_find_boss())


@rpc("authority", "call_remote", "reliable")
func client_spawn_arena_hazard(spec: Dictionary) -> void:
	spec["cosmetic"] = true
	_spawn_arena_hazard(spec)


@rpc("authority", "call_remote", "reliable")
func client_announce_boss_phase(phase: int, boss_name: String) -> void:
	hud.announce_boss_phase(phase, boss_name)
	_shake_cameras(18.0, 0.7)
	_play_world_flash()


@rpc("authority", "call_remote", "reliable")
func client_play_staff_effect(effect_kind: String, points: PackedVector2Array) -> void:
	_play_staff_effect(effect_kind, points)


@rpc("authority", "call_remote", "reliable")
func client_play_secondary_fx(class_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_play_secondary_fx(class_id, effect_style, points)


@rpc("authority", "call_remote", "reliable")
func client_spawn_support_wall(points: PackedVector2Array, duration: float, color: Color) -> void:
	_spawn_support_wall(points, duration, color)


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


@rpc("authority", "call_remote", "reliable")
func client_offer_ability_choices(ability_ids: Array[String]) -> void:
	var local_player := _local_player()
	if local_player != null:
		hud.show_ability_offer(local_player, ability_ids, false)


@rpc("any_peer", "call_remote", "reliable")
func server_choose_ability(ability_id: String) -> void:
	if not GameRuntime.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_apply_ability_choice(peer_id, ability_id)


@rpc("authority", "call_remote", "reliable")
func client_play_ability_effect(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_play_ability_effect(ability_id, effect_style, points)


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
	if wave > 0 and wave % WaveDirector.BOSS_WAVE_INTERVAL == 0:
		_shake_cameras(16.0, 0.6)
		_play_world_flash()


@rpc("authority", "call_remote", "reliable")
func client_open_shop() -> void:
	hud.open_shop(false)


@rpc("authority", "call_remote", "reliable")
func client_show_next_wave_button(seconds: float) -> void:
	hud.show_next_wave_button(true, seconds)


@rpc("authority", "call_remote", "reliable")
func client_update_next_wave_ready(ready_count: int, total_count: int) -> void:
	hud.set_next_wave_ready_count(ready_count, total_count)


@rpc("any_peer", "call_remote", "reliable")
func server_ready_for_next_wave() -> void:
	if not GameRuntime.is_server():
		return
	_mark_ready_for_next_wave(multiplayer.get_remote_sender_id())


## Solo just skips outright; co-op needs everyone in before the breather actually ends, so
## nobody gets dropped into the next wave mid-shop because a teammate was trigger-happy.
func _mark_ready_for_next_wave(peer_id: int) -> void:
	if not players.has(peer_id) or ready_for_next_wave.get(peer_id, false):
		return
	ready_for_next_wave[peer_id] = true
	var ready_count := ready_for_next_wave.size()
	var total_count := players.size()
	if not GameRuntime.is_dedicated_server():
		hud.set_next_wave_ready_count(ready_count, total_count)
	if GameRuntime.is_server():
		for peer_id_to_notify in registered_remote_peers.keys():
			client_update_next_wave_ready.rpc_id(peer_id_to_notify, ready_count, total_count)
	if ready_count >= total_count:
		ready_for_next_wave.clear()
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


## Tracks whether the local player is close enough to the arena's shop stand to interact
## (see _unhandled_input's "interact_shop" handling) at any point in a wave, not just during
## the forced breather every 10 waves. Walking away still auto-closes it.
func _update_shop_stand_proximity() -> void:
	var local_player := _local_player()
	if local_player == null or not local_player.active or game_over:
		if _near_shop_stand:
			_near_shop_stand = false
			hud.close_shop()
		if local_player != null:
			local_player.set_shop_hint_visible(false)
		return
	var in_range := local_player.global_position.distance_to(Arena.shop_stand_position()) <= Arena.SHOP_STAND_INTERACT_RADIUS
	if in_range != _near_shop_stand:
		_near_shop_stand = in_range
		local_player.set_shop_hint_visible(in_range)
		if not in_range:
			hud.close_shop()


## Solo has nobody to revive it (the loop below only ever finds the downed player itself),
## so this only ever matters in co-op, which is the point — dying isn't a full reset there
## as long as someone can reach you and hold position.
func _update_revives(delta: float) -> void:
	for peer_id in players.keys():
		var downed := players[peer_id] as Player
		if downed == null or not is_instance_valid(downed) or downed.active:
			revive_progress.erase(peer_id)
			continue
		var reviver := _find_stationary_reviver(downed)
		if reviver == null:
			var fading: float = revive_progress.get(peer_id, 0.0)
			if fading > 0.0:
				revive_progress[peer_id] = maxf(0.0, fading - delta * 2.0)
			continue
		var progress: float = float(revive_progress.get(peer_id, 0.0)) + delta
		if progress < REVIVE_DURATION:
			revive_progress[peer_id] = progress
			continue
		revive_progress.erase(peer_id)
		downed.revive()


func _find_stationary_reviver(downed: Player) -> Player:
	for candidate_node in players.values():
		var candidate := candidate_node as Player
		if candidate == null or not is_instance_valid(candidate) or candidate == downed or not candidate.active:
			continue
		if candidate.global_position.distance_to(downed.global_position) > REVIVE_RADIUS:
			continue
		var input_state: Dictionary = pending_inputs.get(candidate.owner_peer_id, {})
		var moving: bool = (input_state.get("move", Vector2.ZERO) as Vector2).length() > 0.05
		var attacking: bool = input_state.get("attack", false)
		if moving or attacking:
			continue
		return candidate
	return null


func _on_local_next_wave_requested() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		wave_director.skip_intermission()
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_ready_for_next_wave.rpc_id(1)
		return
	var local_player := _local_player()
	if local_player != null:
		_mark_ready_for_next_wave(local_player.owner_peer_id)


const CPU_PEER_BASE := 101


func _spawn_cpu_allies() -> void:
	if not GameRuntime.fill_cpu_allies:
		return
	if GameRuntime.is_classic() or GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	var cpu_peer := CPU_PEER_BASE
	for class_id in PlayerClass.cpu_ally_ids(GameRuntime.active_class_id()):
		_create_player(cpu_peer, Player.SimulationMode.CPU, false, class_id)
		cpu_peer += 1


func _cpu_auto_shop() -> void:
	for player_node in players.values():
		var player := player_node as Player
		if player == null or not player.is_cpu() or not player.active:
			continue
		for item in ShopCatalog.items_for(player.class_id):
			player.buy(str(item.id))


func _create_player(peer_id: int, mode: int, local_player: bool, class_id: String = PlayerClass.DEFAULT_CLASS_ID) -> Player:
	if players.has(peer_id):
		return players[peer_id] as Player
	var player := player_scene.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.global_position = _spawn_position_for_peer(peer_id)
	actors.add_child(player)
	player.configure(peer_id, mode, local_player, class_id)
	if arena is Arena:
		player.apply_camera_limits((arena as Arena).half_extents())
	player.staff_cast.connect(_on_staff_cast)
	player.ability_cast.connect(_on_ability_cast)
	player.secondary_fx.connect(_on_secondary_fx)
	player.support_wall_spawned.connect(_on_support_wall_spawned)
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
	wave_director.set_player_count(players.size())
	return player


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	var slot := players.size()
	var angle := float(slot) * TAU / float(GameRuntime.DEFAULT_MAX_PLAYERS)
	return Vector2.RIGHT.rotated(angle) * 72.0


func _local_ability_slots_held() -> Array:
	return [
		InputService.ability_slot_held(0), InputService.ability_slot_held(1),
		InputService.ability_slot_held(2), InputService.ability_slot_held(3),
	]


func _update_host_input() -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.HOST or not players.has(1):
		return
	var host_player := players[1] as Player
	host_player.set_authority_command(
		InputService.movement_vector(),
		InputService.aim_world_position(host_player),
		InputService.primary_attack_held(),
		InputService.ability_held(),
		_local_ability_slots_held(),
		InputService.secondary_attack_held()
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
		InputService.ability_held(),
		_local_ability_slots_held(),
		InputService.secondary_attack_held()
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
		input_state.get("ability", false),
		input_state.get("ability_slots", [false, false, false, false]),
		input_state.get("secondary", false)
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
	ready_for_next_wave.clear()
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		for player in players.values():
			(player as Player).refresh_wave_items()
	if not GameRuntime.is_dedicated_server():
		hud.close_shop()
		hud.set_wave(wave, theme_name)
		hud.announce_wave(wave, theme_name, debut_type_id)
		hud.show_next_wave_button(false)
		if wave > 0 and wave % WaveDirector.BOSS_WAVE_INTERVAL == 0:
			_shake_cameras(16.0, 0.6)
			_play_world_flash()
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_wave.rpc_id(peer_id, wave, theme_name, debut_type_id)


## Shop waves keep their own "START NEXT WAVE" button in the shop panel; the standalone
## Next Wave button only shows for the plain breathers between waves, so it doesn't sit
## underneath the shop panel doing the same thing twice.
func _on_intermission_started(next_wave: int, seconds: float) -> void:
	if not GameRuntime.is_dedicated_server():
		AudioService.play("wave_clear")
	if GameRuntime.uses_biomes():
		var previous_biome := GameRuntime.biome_id
		GameRuntime.set_biome_for_wave(next_wave)
		if GameRuntime.biome_id != previous_biome:
			_play_world_flash()
	if WaveDirector.shop_opens_before(next_wave):
		if not GameRuntime.is_dedicated_server():
			hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
			_cpu_auto_shop()
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_open_shop.rpc_id(peer_id)
		return
	if not GameRuntime.is_dedicated_server():
		hud.show_next_wave_button(true, seconds)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_show_next_wave_button.rpc_id(peer_id, seconds)


func _on_wave_group_ready(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float) -> void:
	if game_over or players.is_empty():
		return
	_spawn_formation(type_id, formation, count, health_multiplier, speed_multiplier)


func _spawn_formation(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0) -> void:
	var base_angle := randf_range(0.0, TAU)
	var pack_center := Vector2.RIGHT.rotated(base_angle) * randf_range(spawn_distance_min, spawn_distance_max)
	for index in count:
		if enemies.size() >= _enemy_cap():
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
	if arena is Arena:
		var half := (arena as Arena).half_extents() - Vector2(40.0, 40.0)
		candidate_position.x = clampf(candidate_position.x, -half.x, half.x)
		candidate_position.y = clampf(candidate_position.y, -half.y, half.y)
	else:
		candidate_position.x = clampf(candidate_position.x, -1160.0, 1160.0)
		candidate_position.y = clampf(candidate_position.y, -760.0, 760.0)
	enemy.global_position = arena.free_position_near(candidate_position, 22.0)
	actors.add_child(enemy)
	enemy.configure(entity_id, true, type_id, health_multiplier, speed_multiplier)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.projectile_fired.connect(_on_enemy_projectile_fired)
	enemy.spawn_requested.connect(_on_enemy_spawn_requested)
	enemy.exploded.connect(_on_enemy_exploded)
	if enemy.is_boss:
		enemy.arena_hazard_requested.connect(_on_arena_hazard_requested)
		enemy.boss_phase_changed.connect(_on_boss_phase_changed)
	enemies[entity_id] = enemy
	return enemy


func _on_enemy_spawn_requested(type_id: String, origin: Vector2, count: int) -> void:
	if game_over:
		return
	var focus := _first_active_player()
	if focus == null:
		return
	var multiplier := wave_director.health_multiplier_for_wave(current_wave)
	var ravager_flood := _ravager_alive()
	for index in count:
		if enemies.size() >= _enemy_cap():
			return
		var jitter := Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0))
		var spawned := _spawn_enemy(origin + jitter - focus.global_position, type_id, multiplier)
		if spawned == null or not ravager_flood or type_id != "swarmling":
			continue
		var base_speed := float(EnemyType.field("swarmling", "movement_speed"))
		spawned.movement_speed = base_speed * RAVAGER_MINION_START_SPEED
		spawned.speed_ramp = RAVAGER_MINION_RAMP
		spawned.speed_cap = base_speed * RAVAGER_MINION_CAP


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


func _on_arena_hazard_requested(spec: Dictionary) -> void:
	_spawn_arena_hazard(spec)
	var kind := str(spec.get("kind", ""))
	if not GameRuntime.is_dedicated_server():
		hud.pulse_danger(float(spec.get("telegraph", 0.9)))
	if kind == "ring" or kind == "line":
		_shake_cameras(12.0, 0.4)
	else:
		_shake_cameras(7.0, 0.22)
	if GameRuntime.is_server():
		var remote_spec := spec.duplicate()
		remote_spec["cosmetic"] = true
		for peer_id in registered_remote_peers.keys():
			client_spawn_arena_hazard.rpc_id(peer_id, remote_spec)


func _spawn_arena_hazard(spec: Dictionary) -> void:
	if GameRuntime.is_dedicated_server() and bool(spec.get("cosmetic", false)):
		return
	if not GameRuntime.is_dedicated_server():
		AudioService.play("charge")
	var hazard := ArenaHazard.new()
	actors.add_child(hazard)
	hazard.configure(spec)


func _on_boss_phase_changed(phase: int) -> void:
	var boss := _find_boss()
	var boss_name := "BOSS"
	if boss != null:
		boss_name = str(EnemyType.by_id(boss.type_id).name)
	if not GameRuntime.is_dedicated_server():
		hud.announce_boss_phase(phase, boss_name)
		_shake_cameras(20.0, 0.75)
		_play_world_flash()
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_boss_phase.rpc_id(peer_id, phase, boss_name)


func _shake_cameras(amplitude: float, duration: float) -> void:
	if GameRuntime.is_dedicated_server():
		return
	for player in players.values():
		if is_instance_valid(player):
			(player as Player).shake_camera(amplitude, duration)


func _find_boss() -> Enemy:
	for enemy in enemies.values():
		if is_instance_valid(enemy) and (enemy as Enemy).is_boss and not (enemy as Enemy).health.is_dead:
			return enemy as Enemy
	return null


func _ravager_alive() -> bool:
	var boss := _find_boss()
	return boss != null and boss.type_id == "ravager"


func _enemy_cap() -> int:
	return BOSS_MAX_ENEMIES if _ravager_alive() else max_enemies


func _update_chant(delta: float) -> void:
	if game_over or not _ravager_alive() or enemies.size() <= 1:
		if _chant_active:
			_stop_chant()
		return
	VoiceService.ensure_capture()
	if _chant_cooldown > 0.0:
		_chant_cooldown = maxf(0.0, _chant_cooldown - delta)
		hud.hide_chant()
		return
	if not _chant_active:
		_start_chant()
	_chant_time_left -= delta
	if Input.is_action_just_pressed("ui_accept"):
		var word_count := VoiceService.mantra_words(_chant_mantra).size()
		_chant_matched = mini(_chant_matched + 1, word_count)
		if _chant_matched >= word_count:
			_succeed_chant()
			return
	_chant_poll += delta
	if VoiceService.voice_ready() and _chant_poll >= CHANT_POLL_SECONDS and not _chant_polling:
		_chant_poll = 0.0
		_poll_chant()
	if _chant_active:
		hud.show_chant(_chant_mantra, _chant_matched, _chant_time_left, VoiceService.voice_ready())
	if _chant_active and _chant_time_left <= 0.0:
		_fail_chant()


func _start_chant() -> void:
	_chant_active = true
	_chant_mantra = VoiceService.next_mantra()
	_chant_time_left = VoiceService.CHANT_SECONDS
	_chant_matched = 0
	_chant_poll = 0.0
	VoiceService.start_recording()


func _stop_chant() -> void:
	_chant_active = false
	_chant_polling = false
	VoiceService.stop_recording()
	hud.hide_chant()


func _fail_chant() -> void:
	_stop_chant()
	_chant_cooldown = 0.35


func _succeed_chant() -> void:
	_stop_chant()
	_chant_cooldown = CHANT_SUCCESS_COOLDOWN
	_pulse_clear_minions()


func _poll_chant() -> void:
	_chant_polling = true
	var heard := await VoiceService.transcribe_current(_chant_mantra)
	_chant_polling = false
	if not _chant_active:
		return
	_chant_matched = VoiceService.matched_count(_chant_mantra, heard)
	if VoiceService.is_complete(_chant_mantra, heard):
		_succeed_chant()


func _pulse_clear_minions() -> void:
	var origin := Vector2.ZERO
	var local := _local_player()
	if local != null:
		origin = local.global_position
	_play_chant_pulse(origin)
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		return
	var doomed: Array = []
	for enemy in enemies.values():
		if not is_instance_valid(enemy):
			continue
		var minion := enemy as Enemy
		if minion.is_boss or minion.health.is_dead:
			continue
		doomed.append(minion)
	for minion in doomed:
		minion.health.take_damage(minion.health.max_health + 80.0)


func _play_chant_pulse(origin: Vector2) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.style = PlayerClass.EffectStyle.BURST
	effect.main_color = Color("ffe08c")
	effect.chain_color = Color("4f8fe0")
	effect.points = PackedVector2Array([origin, Vector2(420.0, 0.0)])
	add_child(effect)
	AudioService.play("explosion")


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


func _on_secondary_fx(class_id: String, style: int, points: PackedVector2Array) -> void:
	_play_secondary_fx(class_id, style, points)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_secondary_fx.rpc_id(peer_id, class_id, style, points)


func _on_support_wall_spawned(points: PackedVector2Array, duration: float, color: Color) -> void:
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_spawn_support_wall.rpc_id(peer_id, points, duration, color)


func _play_secondary_fx(class_id: String, style: int, points: PackedVector2Array) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var class_data := PlayerClass.by_id(class_id)
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.style = style
	effect.main_color = Color(class_data.effect_color)
	effect.chain_color = Color(class_data.effect_secondary)
	if style == PlayerClass.EffectStyle.BLAST or style == PlayerClass.EffectStyle.BURST:
		effect.lifetime = 0.48
	effect.points = points
	add_child(effect)
	AudioService.play("cast_%s" % class_id)


func _spawn_support_wall(points: PackedVector2Array, duration: float, color: Color) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var wall := SupportWall.new()
	actors.add_child(wall)
	wall.configure(points, duration, null, color)
	AudioService.play("sfx_force")


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


func _on_ability_cast(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_play_ability_effect(ability_id, effect_style, points)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_ability_effect.rpc_id(peer_id, ability_id, effect_style, points)


## Pixel-art cast animation for Pjotr-mode abilities, with a subtle vector flash underneath.
func _play_ability_effect(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	if GameRuntime.is_dedicated_server() or GameRuntime.is_classic():
		return
	var class_prefix := ability_id.split("_")[0]
	var class_data := PlayerClass.by_id(class_prefix)
	var flash := lightning_scene.instantiate() as LightningEffect
	flash.style = effect_style
	flash.main_color = Color(class_data.effect_color)
	flash.chain_color = Color(class_data.effect_secondary)
	flash.lifetime = clampf(0.14 + (points[1].x if points.size() >= 2 else 80.0) / 900.0, 0.14, 0.42)
	flash.points = points
	add_child(flash)
	var vfx := ability_vfx_scene.instantiate() as AbilityVfx
	vfx.configure(ability_id, effect_style, points)
	add_child(vfx)
	AudioService.play_ability(ability_id)


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


## Level-ups grant small incremental stat upgrades (no hero abilities).
func _offer_next_upgrade(peer_id: int) -> void:
	if pending_upgrades.has(peer_id) or pending_ability_offers.has(peer_id):
		return
	if int(queued_upgrade_choices.get(peer_id, 0)) <= 0:
		return
	var leveled_player := players.get(peer_id) as Player
	if leveled_player == null:
		return
	_offer_stat_turn(peer_id, leveled_player)


func _offer_stat_turn(peer_id: int, leveled_player: Player) -> void:
	var upgrade_ids := PlayerClass.random_upgrade_ids(leveled_player.class_id)
	if upgrade_ids.is_empty():
		_advance_offer(peer_id)
		return
	pending_upgrades[peer_id] = upgrade_ids
	if leveled_player.is_cpu():
		_apply_upgrade_choice(peer_id, str(upgrade_ids[0]))
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE or peer_id == 1:
		hud.show_upgrade_ids(players[peer_id], upgrade_ids, GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
	else:
		client_offer_upgrades.rpc_id(peer_id, upgrade_ids)


func _offer_ability_turn(peer_id: int, leveled_player: Player) -> void:
	var ability_ids := PlayerClass.ability_offer_ids(leveled_player.class_id, leveled_player.known_abilities)
	if ability_ids.is_empty():
		# All 4 abilities known and maxed — nothing left to offer, so this turn resolves itself.
		leveled_player.apply_fallback_bonus()
		_advance_offer(peer_id)
		return
	pending_ability_offers[peer_id] = ability_ids
	if leveled_player.is_cpu():
		_apply_ability_choice(peer_id, str(ability_ids[0]))
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE or peer_id == 1:
		hud.show_ability_offer(players[peer_id], ability_ids, GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
	else:
		client_offer_ability_choices.rpc_id(peer_id, ability_ids)


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
	_advance_offer(peer_id)


func _on_local_ability_chosen(ability_id: String) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_choose_ability.rpc_id(1, ability_id)
	else:
		var local_player := _local_player()
		if local_player != null:
			_apply_ability_choice(local_player.owner_peer_id, ability_id)


func _apply_ability_choice(peer_id: int, ability_id: String) -> void:
	var offered: Array = pending_ability_offers.get(peer_id, [])
	var player := players.get(peer_id) as Player
	if player == null or ability_id not in offered:
		return
	var already_known := false
	for entry in player.known_abilities:
		if entry.id == ability_id:
			already_known = true
			break
	if already_known:
		player.upgrade_ability(ability_id)
	else:
		player.learn_ability(ability_id)
	pending_ability_offers.erase(peer_id)
	_advance_offer(peer_id)


func _advance_offer(peer_id: int) -> void:
	queued_upgrade_choices[peer_id] = maxi(0, int(queued_upgrade_choices.get(peer_id, 0)) - 1)
	offer_turn_index[peer_id] = int(offer_turn_index.get(peer_id, 0)) + 1
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
		"biome_auto":
			if GameRuntime.uses_biomes():
				GameRuntime.unlock_biome_for_wave(maxi(1, current_wave))
				_play_world_flash()
		"add_gold":
			player.add_gold(500)
		_:
			if command.begins_with("biome_") and GameRuntime.uses_biomes():
				GameRuntime.set_biome(int(command.trim_prefix("biome_")))
				_play_world_flash()


func _rebuild_arena() -> void:
	if arena is Arena:
		(arena as Arena).rebuild()
	_sync_playfield()
	for enemy in enemies.values():
		if enemy is Enemy and is_instance_valid(enemy):
			(enemy as Enemy).refresh_biome_look()


func _play_world_flash() -> void:
	if GameRuntime.is_dedicated_server() or world_flash == null:
		_rebuild_arena()
		return
	world_flash.visible = true
	world_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(world_flash, "modulate:a", 1.0, 0.12)
	tween.tween_callback(_rebuild_arena)
	tween.tween_interval(0.08)
	tween.tween_property(world_flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if world_flash != null:
			world_flash.visible = false
	)


func _transition_to_biome(next_id: int) -> void:
	if next_id == GameRuntime.biome_id:
		return
	GameRuntime.biome_id = next_id
	_play_world_flash()


func _sync_playfield() -> void:
	if not arena is Arena:
		return
	var half := (arena as Arena).half_extents()
	for player in players.values():
		if not is_instance_valid(player):
			continue
		var body := player as Player
		body.apply_camera_limits(half)
		if (arena as Arena).is_blocked(body.global_position, 18.0):
			body.global_position = Vector2.ZERO


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
		"biome_id": GameRuntime.biome_id,
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
	pending_ability_offers.erase(peer_id)
	queued_upgrade_choices.erase(peer_id)
	offer_turn_index.erase(peer_id)
	registered_remote_peers.erase(peer_id)
	ready_for_next_wave.erase(peer_id)
	revive_progress.erase(peer_id)
	var player := players.get(peer_id) as Player
	players.erase(peer_id)
	if player != null:
		player.queue_free()
	if not ready_for_next_wave.is_empty() and ready_for_next_wave.size() >= players.size():
		ready_for_next_wave.clear()
		wave_director.skip_intermission()


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
