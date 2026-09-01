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
## The grass meadow crater is open and visible from the first wave. The bramble seal
## and unlock hook remain for a possible future gate; set this above 1 to re-arm it.
const CRATER_UNLOCK_WAVE := 1
var crater_unlocked := true
var _crater_unlock_announced := true
## Server-only tracking of landmark cool-downs by id, so one player can't spam the bell.
var _landmark_last_trigger: Dictionary = {}
const LANDMARK_GLOBAL_COOLDOWN := 16.0
## Last snapshot send time per peer so the crater-state RPC supplements, not floods.
var _crater_snapshot_sent: Dictionary = {}
## Peer ids that have pressed the Next Wave button this breather (co-op requires everyone).
var ready_for_next_wave: Dictionary = {}
## peer_id of the downed player -> seconds a stationary teammate has stood next to them.
var revive_progress: Dictionary = {}

const REVIVE_RADIUS := 60.0
const REVIVE_DURATION := 5.0
const BOSS_MAX_ENEMIES := 160
const RAVAGER_MINION_START_SPEED := 0.28
const RAVAGER_MINION_RAMP := 18.0
const RAVAGER_MINION_CAP := 2.2

## Rift Clash: one WaveDirector per active team, keyed by team id. Created lazily on the
## server once `RiftClashManager.assign_teams` has run; stays empty in co-op and on clients
## (their wave metadata flows in via the co-op snapshot from whichever director raced ahead).
var team_wave_directors: Dictionary = {}  # team_id -> WaveDirector


func _ready() -> void:
	randomize()
	NetworkService.peer_left.connect(_on_peer_left)
	if arena is Arena:
		for landmark in (arena as Arena).landmarks:
			if is_instance_valid(landmark):
				landmark.triggered.connect(_on_landmark_triggered)
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
	## group_ready is *not* gated by team mode: the co-op `_on_wave_group_ready` handler
	## runs the plain formation path for Classic & Pjotr co-op, while team directors bind
	## themselves to `_on_team_wave_group_ready` instead.
	wave_director.group_ready.connect(_on_wave_group_ready)
	wave_director.intermission_started.connect(_on_intermission_started)

	_init_crater()

	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		_create_player(1, Player.SimulationMode.OFFLINE, true, GameRuntime.active_class_id())
		_spawn_cpu_allies()
		_spawn_initial_wave()
		# Self-test harness: if a request file exists, the driver takes over the local player's
		# input + spawns staged enemies + captures screenshots headlessly. Agents iterate with
		# `tools/selftest/run_selftest.ps1 -Request <json>`, parsing `selftest_report.json`.
		# Self-test harness: if a request file exists, the driver takes over the local player's
		# input + spawns staged enemies + captures screenshots headlessly.
		_right_selftest_boot()
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
			var snap_time := Time.get_ticks_msec()
			for peer_id in registered_remote_peers.keys():
				client_receive_snapshot.rpc_id(peer_id, snapshot)
				_crater_snapshot_sent[peer_id] = snap_time
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		input_accumulator += delta
		if input_accumulator >= 1.0 / input_send_rate:
			input_accumulator = 0.0
			_send_local_input()
	if not GameRuntime.is_dedicated_server() and not GameRuntime.is_classic():
		_update_shop_stand_proximity()
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		_update_revives(delta)


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
	# Snapshot floods carry the same crater key, so only bridge the gap when the run
	# already unlocked and this peer will not see a snapshot within a heartbeat.
	var last_snapshot := int(_crater_snapshot_sent.get(peer_id, 0))
	if crater_unlocked and Time.get_ticks_msec() - last_snapshot > 4500:
		client_crater_unlocked.rpc_id(peer_id)
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
	if bool(snapshot.get("crater_unlocked", true)) and not crater_unlocked:
		if arena is Arena:
			(arena as Arena).set_crater_unlocked(true)
		crater_unlocked = true
		if not _crater_unlock_announced:
			_crater_unlock_announced = true
			hud.announce_boss_phase(1, "THE CRATER HAS OPENED")
	var snapshot_wave := int(snapshot.get("wave", current_wave))
	if snapshot_wave != current_wave:
		current_wave = snapshot_wave
		current_wave_name = str(snapshot.get("wave_name", ""))
		if GameRuntime.is_rift_clash():
			# Everyone in team mode chases their own clock; co-op's global wave counter
			# is only a view over whichever director the host happened to have grown.
			var local_player := _local_player()
			if local_player != null and team_wave_directors.has(local_player.team_id):
				var my_director := team_wave_directors[local_player.team_id] as WaveDirector
				current_wave = maxi(current_wave, my_director.wave)
				current_wave_name = my_director.display_name()
		hud.set_wave(current_wave, current_wave_name)
	hud.update_boss(_find_boss())


@rpc("authority", "call_remote", "reliable")
func client_spawn_arena_hazard(spec: Dictionary) -> void:
	spec["cosmetic"] = true
	_spawn_arena_hazard(spec)


@rpc("authority", "call_remote", "reliable")
func client_landmark_pulse(origin: Vector2, effect_id: String) -> void:
	match effect_id:
		"pulse_wipe":
			hud.flash_combat_text("Storm pulse!", Color("ffd060"))
		"freeze_time":
			hud.flash_combat_text("Time frozen!", Color("80c0ff"))
		"heal_all":
			hud.flash_combat_text("Blessing!", Color("70d070"))
		_:
			hud.flash_combat_text("Landmark awakened", Color("e8e8e8"))
	var ring := ArenaHazard.new()
	ring.configure({
		"kind": "ring",
		"origin": origin,
		"radius": 700.0,
		"max_radius": 700.0,
		"telegraph": 0.0,
		"active": 0.6,
		"line_width": 70.0,
		"color": "ffd060" if effect_id == "pulse_wipe" else ("80c0ff" if effect_id == "freeze_time" else "70d070"),
		"damage": 0.0,
		"cosmetic": true,
	})
	add_child(ring)
	_play_sound("enemy_death")


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
		if GameRuntime.is_rift_clash() and downed.team_id != "" and candidate.team_id != downed.team_id:
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
	var allies := PlayerClass.cpu_ally_ids(GameRuntime.active_class_id())
	for index in mini(3, allies.size()):
		_create_player(cpu_peer, Player.SimulationMode.CPU, false, allies[index])
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
	if GameRuntime.is_rift_clash() and RiftClashManager.assigned_teams.is_empty():
		if GameRuntime.is_server():
			RiftClashManager.reset_match()
			RiftClashManager.assign_teams([peer_id], _lobby_claims())
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
	if GameRuntime.is_rift_clash():
		if GameRuntime.is_server():
			RiftClashManager.assign_teams(players.keys(), _lobby_claims())
		player.team_id = str(RiftClashManager.team_of(peer_id))
		if GameRuntime.is_server():
			_ensure_team_wave_director(player.team_id)
	pending_inputs[peer_id] = {
		"move": Vector2.ZERO,
		"aim": player.global_position + Vector2.RIGHT * 100.0,
		"attack": false,
	}
	if local_player and not GameRuntime.is_dedicated_server():
		hud.bind_player(player)
		if GameRuntime.is_rift_clash() and player.team_id != "":
			hud.refresh_rift_clash_banner(
				RiftClashManager.team_name(player.team_id),
				RiftClashManager.team_corner_name(player.team_id),
				RiftClashManager.team_color(player.team_id)
			)
	wave_director.set_player_count(players.size())
	return player


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	if GameRuntime.is_rift_clash() and not RiftClashManager.assigned_teams.is_empty():
		var anchor := RiftClashManager.team_anchor(RiftClashManager.team_of(peer_id))
		# Stagger teammates around their anchor so nobody clips through each other.
		var slot := 0
		for other_peer in players.keys():
			if RiftClashManager.team_of(int(other_peer)) == RiftClashManager.team_of(peer_id):
				slot += 1
		var angle := TAU * float(slot) / 4.0
		return anchor + Vector2.RIGHT.rotated(angle) * 96.0
	var slot_index := players.size()
	var angle := float(slot_index) * TAU / float(GameRuntime.DEFAULT_MAX_PLAYERS)
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


func _ensure_team_wave_director(team_id: String) -> void:
	if not GameRuntime.is_rift_clash() or team_wave_directors.has(team_id):
		return
	var director := WaveDirector.new()
	add_child(director)
	director.name = "Wave_%s" % team_id.capitalize()
	director.group_ready.connect(_on_team_wave_group_ready.bind(team_id))
	director.wave_started.connect(_on_team_wave_started.bind(team_id))
	director.intermission_started.connect(_on_team_intermission_started.bind(team_id))
	var members := 0
	for peer_id in players.keys():
		if RiftClashManager.team_of(int(peer_id)) == int(team_id):
			members += 1
	director.start(maxi(1, members), false)
	team_wave_directors[team_id] = director


## Server-local reaction when a team wave begins — the host HUD shows the wave the
## anchor player on this team faces; other corners keep their own pace.
func _on_team_wave_started(team_id: String, wave: int, theme_name: String, debut_type_id: String) -> void:
	if not GameRuntime.is_server():
		return
	var my_team := ""
	for peer_id in players.keys():
		var candidate := players[peer_id] as Player
		if candidate != null and candidate.is_local_player:
			my_team = candidate.team_id
			break
	if my_team == "" or my_team != team_id:
		return
	_on_wave_started(wave, theme_name, debut_type_id)


## Team-scoped intermission: opens the shop for everyone (the stand is shared), but only
## marks this team's timer down — rivals keep marching on their own clock elsewhere.
func _on_team_intermission_started(team_id: String, next_wave: int, seconds: float) -> void:
	if not GameRuntime.is_server():
		return
	if WaveDirector.shop_opens_before(next_wave):
		if not GameRuntime.is_dedicated_server():
			hud.open_shop(false)
			_cpu_auto_shop()
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_open_shop.rpc_id(peer_id)
		return
	# For the plain breather we don't draw a "next wave" button per team; the next group
	# lands when the timer lands. Host HUD resets its next-wave timer if this is their
	# team's beat.
	var my_team := ""
	for peer_id in players.keys():
		var candidate := players[peer_id] as Player
		if candidate != null and candidate.is_local_player:
			my_team = candidate.team_id
			break
	if my_team == team_id and not GameRuntime.is_dedicated_server():
		hud.show_next_wave_button(false)


func _on_team_wave_group_ready(
		team_id: String, type_id: String, formation: int, count: int,
		health_multiplier: float, speed_multiplier: float
) -> void:
	if game_over or players.is_empty():
		return
	if RiftClashManager.is_team_eliminated(team_id):
		return
	_spawn_team_formation(team_id, type_id, formation, count, health_multiplier, speed_multiplier)


func _spawn_initial_wave() -> void:
	if initial_wave_spawned or players.is_empty():
		return
	initial_wave_spawned = true
	if GameRuntime.is_classic():
		max_enemies = 35
	wave_director.start(players.size(), GameRuntime.is_classic())


func _on_wave_started(wave: int, theme_name: String, debut_type_id: String) -> void:
	# Direct call in team mode from `_on_team_wave_started` filters by team; the co-op
	# director signal doesn't know which corner the wave belongs to, so it must skip.
	# We can tell the difference because `_ensure_team_wave_director` gates itself.
	if GameRuntime.is_rift_clash() and team_wave_directors.is_empty():
		return
	current_wave = wave
	current_wave_name = theme_name
	current_debut_type_id = debut_type_id
	ready_for_next_wave.clear()
	_update_crater_lock(wave)
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
	if GameRuntime.is_rift_clash() and SteamService.is_available():
		var my_team := ""
		for peer_id in players.keys():
			var candidate := players[peer_id] as Player
			if candidate != null and candidate.is_local_player:
				my_team = candidate.team_id
				break
		SteamService.set_rift_clash_presence(wave, my_team)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_wave.rpc_id(peer_id, wave, theme_name, debut_type_id)


## Shop waves keep their own "START NEXT WAVE" button in the shop panel; the standalone
## Next Wave button only shows for the plain breathers between waves, so it doesn't sit
## underneath the shop panel doing the same thing twice.
func _on_intermission_started(next_wave: int, seconds: float) -> void:
	# Rift Clash intermissions come per-team via `_on_team_intermission_started`; the
	# co-op director is stopped before the first wave in team mode so this stays closed.
	if GameRuntime.is_rift_clash():
		return
	if not GameRuntime.is_dedicated_server():
		AudioService.play("wave_clear")
		var beaten := next_wave - 1
		# Solo meta: bank sparks for the local player when a milestone wave is cleared.
		if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
			var sparks: float = PlayerProfile.sparks_for_wave(next_wave)
			var local_player := _local_player()
			var hero_id := local_player.class_id if local_player != null else ""
			if sparks > 0:
				PlayerProfile.grant_sparks(sparks, hero_id)
				ProgressionService.auto_unlock_affordable()
				hud.set_sparks(PlayerProfile.sparks)
			# Ultimates ship with the hero from the start now; the old wave-5 unlock
			# moment is retired (kept as a no-op for legacy saves via maybe_unlock_ult).
			if not hero_id.is_empty() and local_player != null:
				local_player.known_abilities = local_player.known_abilities
		# MOBA draft: every 3rd wave cleared, hand everyone (CPUs pick instantly) a fresh
		# ability offer so the run keeps growing on top of XP/level picks.
		if beaten > 0 and beaten % 3 == 0:
			_queue_wave_draft()
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


## The every-3-waves draft. Uses the level-up offer pipeline directly (queued → stat/ability
## turn → player pick) so CPU allies auto-resolve, clients get an RPC, and offline pauses.
func _queue_wave_draft() -> void:
	for peer_id in players.keys():
		queued_upgrade_choices[peer_id] = int(queued_upgrade_choices.get(peer_id, 0)) + 1
		offer_turn_index[peer_id] = 1  # force this level-up to be an ability (not stat) turn
		_offer_next_upgrade(peer_id)


func _on_wave_group_ready(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float) -> void:
	if game_over or players.is_empty():
		return
	_spawn_formation(type_id, formation, count, health_multiplier, speed_multiplier)


func _spawn_formation(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0) -> void:
	_spawn_formation_near(_first_active_player(), type_id, formation, count, health_multiplier, speed_multiplier)


## Team-zoned variant: same shapes as co-op, but `focus` is the team's anchor instead of
## an arbitrary player, so each corner gets its own vector-of-attack. Raiding players
## wander into "enemy" formations that simply don't follow them home.
func _spawn_team_formation(team_id: String, type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0) -> void:
	_last_spawn_team = team_id
	_spawn_formation_near(
		RiftClashManager.spawn_focus_for_team(team_id),
		type_id, formation, count, health_multiplier, speed_multiplier
	)
	_last_spawn_team = ""


## Grab the host-side lobby team picks. The map lives on the bootstrap scene — we query
## the parent rather than reaching into autoloads so clients that skipped the lobby
## (headless test, direct join) fall back safely.
func _lobby_claims() -> Dictionary:
	var bootstrap := get_parent()
	if bootstrap == null:
		return {}
	var claims: Variant = bootstrap.get("lobby_team_claims")
	return claims if claims is Dictionary else {}


## Threaded through one spawn call so `_spawn_enemy_at` can tag every enemy of a team
## wave without changing every formation signature. Empty outside team mode.
var _last_spawn_team := ""


func _spawn_formation_near(focus: Variant, type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0) -> void:
	var focus_position := Vector2.ZERO
	if focus is Vector2:
		focus_position = focus
	elif focus is Node2D:
		focus_position = (focus as Node2D).global_position
	else:
		var fallback := _first_active_player()
		if fallback == null:
			return
		focus_position = fallback.global_position
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
		_spawn_enemy_at(focus_position + offset, type_id, health_multiplier, speed_multiplier)


## Backwards-compat for summoners/dev tools: spawn relative to the first active player.
func _spawn_enemy(offset: Vector2, type_id: String, health_multiplier: float, speed_multiplier: float = 1.0) -> Enemy:
	var focus := _first_active_player()
	if focus == null:
		return null
	return _spawn_enemy_at(focus.global_position + offset, type_id, health_multiplier, speed_multiplier)


func _spawn_enemy_at(world_position: Vector2, type_id: String, health_multiplier: float, speed_multiplier: float = 1.0) -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	var entity_id := next_entity_id
	next_entity_id += 1
	var candidate_position := world_position
	if arena is Arena:
		var half := (arena as Arena).half_extents() - Vector2(40.0, 40.0)
		candidate_position.x = clampf(candidate_position.x, -half.x, half.x)
		candidate_position.y = clampf(candidate_position.y, -half.y, half.y)
	else:
		candidate_position.x = clampf(candidate_position.x, -1160.0, 1160.0)
		candidate_position.y = clampf(candidate_position.y, -760.0, 760.0)
	enemy.global_position = arena.free_position_near(candidate_position, 22.0)
	enemy.team_id = _last_spawn_team
	actors.add_child(enemy)
	enemy.configure(entity_id, true, type_id, health_multiplier, speed_multiplier)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.projectile_fired.connect(_on_enemy_projectile_fired)
	enemy.spawn_requested.connect(_on_enemy_spawn_requested)
	enemy.exploded.connect(_on_enemy_exploded)
	# Lava spitter drops its trail through the same arena hazard pipe — hook it up
	# alongside the bosses so its arena_hazard_requested payload actually lands.
	if enemy.is_boss or enemy.type_id == "lava_spitter":
		enemy.arena_hazard_requested.connect(_on_arena_hazard_requested)
	if enemy.is_boss:
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
	if GameRuntime.is_rift_clash() and enemy.health.last_damage_source is Player:
		var killer := enemy.health.last_damage_source as Player
		if killer.team_id != "":
			_award_gold_to_team(killer.team_id, enemy.gold_value)
	else:
		_award_gold(enemy.gold_value)
	_play_sound("enemy_death")
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_sound.rpc_id(peer_id, "enemy_death")


## Landmark triggering lives server-side only; clients mirror through the HUD flash RPC.
func _on_landmark_triggered(landmark: LandmarkButton) -> void:
	if not GameRuntime.is_server():
		return
	var now := Time.get_ticks_msec()
	if _landmark_last_trigger.has(landmark.effect_id) and int(_landmark_last_trigger[landmark.effect_id]) + int(LANDMARK_GLOBAL_COOLDOWN * 1000) > now:
		hud.flash_combat_text("%s recharging…" % _effect_display(landmark.effect_id), Color("c0c0c0"))
		return
	_landmark_last_trigger[landmark.effect_id] = now
	print("[landmark] triggered: %s at %s" % [landmark.effect_id, landmark.global_position])
	match landmark.effect_id:
		"pulse_wipe":
			_landmark_pulse_wipe(landmark)
		"freeze_time":
			_landmark_freeze_time(landmark)
		"heal_all":
			_landmark_heal_all(landmark)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_landmark_pulse.rpc_id(peer_id, landmark.global_position, str(landmark.effect_id))


func _landmark_pulse_wipe(landmark: LandmarkButton) -> void:
	var origin := landmark.global_position
	var kill_radius := landmark.effect_radius
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		if enemy.is_boss:
			continue
		if enemy.global_position.distance_to(origin) > kill_radius:
			continue
		enemy.health.take_damage(enemy.health.max_value * 4.0 + 9999.0, self)
	# Three stacked shockwaves sell the wipe far better than one quick ring.
	_play_landmark_ring(origin, kill_radius, Color("ffd060"), 72.0, 1.1)
	_play_landmark_ring(origin, kill_radius * 0.66, Color("fff0b8"), 60.0, 0.9, 0.12)
	_play_landmark_ring(origin, kill_radius * 0.38, Color("ffffff"), 48.0, 0.7, 0.24)
	hud.flash_combat_text("Storm pulse! Minions within %dm wiped." % int(kill_radius / 10.0), Color("ffd060"))


func _landmark_freeze_time(landmark: LandmarkButton) -> void:
	var duration := landmark.effect_arg
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		enemy.set_process(false)
		enemy.set_physics_process(false)
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(true)
		if enemy.has_method("set_frozen_visual"):
			enemy.set_frozen_visual(true)
	_play_landmark_ring(landmark.global_position, 500.0, Color("80c0ff"), 70.0, 1.4)
	_play_landmark_ring(landmark.global_position, 300.0, Color("cfe6ff"), 56.0, 1.0, 0.15)
	hud.flash_combat_text("Time frozen — enemies stunned for %ds" % int(duration), Color("80c0ff"))
	await get_tree().create_timer(duration).timeout
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy):
			continue
		enemy.set_process(true)
		enemy.set_physics_process(true)
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(false)
		if enemy.has_method("set_frozen_visual"):
			enemy.set_frozen_visual(false)
	hud.flash_combat_text("Time resumes.", Color("cfe6ff"))


func _landmark_heal_all(landmark: LandmarkButton) -> void:
	var amount := landmark.effect_arg
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			(player as Player).health.heal(amount)
			# Burst at each player so distant teammates see their heal land too.
			_play_landmark_ring((player as Player).global_position, 160.0, Color("a8f0a8"), 40.0, 0.8)
	_play_landmark_ring(landmark.global_position, 480.0, Color("70d070"), 66.0, 1.3)
	_play_landmark_ring(landmark.global_position, 280.0, Color("d0ffd0"), 52.0, 0.9, 0.15)
	hud.flash_combat_text("Stone's blessing — everyone healed +%d HP" % int(amount), Color("70d070"))


func _effect_display(effect_id: StringName) -> String:
	match effect_id:
		"pulse_wipe": return "Storm Bell"
		"freeze_time": return "Calm"
		"heal_all": return "Blessing"
		_: return "Landmark"


func _play_landmark_ring(origin: Vector2, radius: float, color: Color, line_width := 70.0, duration := 1.0, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var ring := ArenaHazard.new()
	ring.configure({
		"kind": "ring",
		"origin": origin,
		"radius": radius,
		"max_radius": radius,
		"telegraph": 0.0,
		"active": duration,
		"line_width": line_width,
		"color": "#%02x%02x%02x" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)],
		"damage": 0.0,
		"cosmetic": true,
	})
	add_child(ring)
	_play_sound("bell_ring" if AudioService.has_sound("bell_ring") else "enemy_death")


## Gold is shared, so nobody has to race their team mates to the corpse.
func _award_gold(amount: int) -> void:
	if GameRuntime.is_classic() or amount <= 0:
		return
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			(player as Player).add_gold(amount)


## Rift Clash: the kill belongs to the corner that landed it — that's what makes
## wave-stealing pay. Kills by environment (lava, hazards) fall back to _award_gold.
func _award_gold_to_team(team_id: String, amount: int) -> void:
	if GameRuntime.is_classic() or amount <= 0 or team_id == "":
		return
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active and (player as Player).team_id == team_id:
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


## HoN-accurate vector cast animations for these IDs replace the pixel-art burst entirely.
## The LightningEffect layer reads the same `points`/`effect_style` contract, but we tailor
## its style per ability fantasy — Keg gets a BLAST shatter cone, Energy Field gets a static
## BURST ring, turret gets a WINDUP bounce. Keep pixel-art for heroes we haven't redone.
const VECTOR_ONLY_KIT_IDS := {
	# Robot
	"tobor_the_keg": PlayerClass.EffectStyle.BLAST,
	"tobor_steam_turret": PlayerClass.EffectStyle.BURST,
	"tobor_spider_mines": PlayerClass.EffectStyle.BURST,
	"tobor_energy_field": PlayerClass.EffectStyle.BURST,
	"arclight_blast_of_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_chain_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_electric_field": PlayerClass.EffectStyle.BURST,
	"arclight_thundergods_wrath": PlayerClass.EffectStyle.BURST,
	"bulwark_fissure": PlayerClass.EffectStyle.BLAST,
	"bulwark_heavyweight": PlayerClass.EffectStyle.BURST,
	"bulwark_enrage": PlayerClass.EffectStyle.WAVE,
	"bulwark_echo_slam": PlayerClass.EffectStyle.BURST,
	"warden_tongue_tied": PlayerClass.EffectStyle.BOLT,
	"warden_voodoo_wards": PlayerClass.EffectStyle.BURST,
	"warden_cursed_ground": PlayerClass.EffectStyle.BURST,
	"warden_life_drain": PlayerClass.EffectStyle.WAVE,
	# Caldera
	"cinder_whirling_flame": PlayerClass.EffectStyle.BLAST,
	"cinder_fiery_assault": PlayerClass.EffectStyle.WAVE,
	"cinder_blazing_strike": PlayerClass.EffectStyle.BLAST,
	"cinder_blazing_pillar": PlayerClass.EffectStyle.BLAST,
	"pyra_sticky_bomb": PlayerClass.EffectStyle.BOLT,
	"pyra_boom_dust": PlayerClass.EffectStyle.BURST,
	"pyra_bombardment": PlayerClass.EffectStyle.BURST,
	"pyra_air_strike": PlayerClass.EffectStyle.BOLT,
	"slag_steam_bath": PlayerClass.EffectStyle.BURST,
	"slag_volcanic_touch": PlayerClass.EffectStyle.WAVE,
	"slag_lava_surge": PlayerClass.EffectStyle.BLAST,
	"slag_eruption": PlayerClass.EffectStyle.BURST,
	"ember_entangle": PlayerClass.EffectStyle.WAVE,
	"ember_healing_wave": PlayerClass.EffectStyle.WAVE,
	"ember_storm_cloud": PlayerClass.EffectStyle.BURST,
	"ember_unbreakable": PlayerClass.EffectStyle.BURST,
	# Wilds
	"thorn_poison_spray": PlayerClass.EffectStyle.ARC,
	"thorn_toxin_ward": PlayerClass.EffectStyle.BURST,
	"thorn_toxicity": PlayerClass.EffectStyle.WAVE,
	"thorn_poison_burst": PlayerClass.EffectStyle.BURST,
	"willow_swift_strike": PlayerClass.EffectStyle.BLAST,
	"willow_forsaken_shot": PlayerClass.EffectStyle.BOLT,
	"willow_volley": PlayerClass.EffectStyle.BOLT,
	"willow_strangling_vines": PlayerClass.EffectStyle.WAVE,
	"stump_rally": PlayerClass.EffectStyle.BURST,
	"stump_camouflage": PlayerClass.EffectStyle.WAVE,
	"stump_natures_veil": PlayerClass.EffectStyle.BURST,
	"stump_overgrowth": PlayerClass.EffectStyle.BURST,
	"sage_grace_of_the_nymph": PlayerClass.EffectStyle.WAVE,
	"sage_volatile_pod": PlayerClass.EffectStyle.BOLT,
	"sage_nymphoras_kiss": PlayerClass.EffectStyle.BOLT,
	"sage_charm": PlayerClass.EffectStyle.WAVE,
	# Storm Court
	"volt_gust": PlayerClass.EffectStyle.ARC,
	"volt_wind_shield": PlayerClass.EffectStyle.BURST,
	"volt_wind_control": PlayerClass.EffectStyle.WAVE,
	"volt_typhoon": PlayerClass.EffectStyle.WAVE,
	"nebula_time_shift": PlayerClass.EffectStyle.WAVE,
	"nebula_curse_of_ages": PlayerClass.EffectStyle.WAVE,
	"nebula_rewind": PlayerClass.EffectStyle.WAVE,
	"nebula_chronosphere": PlayerClass.EffectStyle.BURST,
	"astral_essence_link": PlayerClass.EffectStyle.BURST,
	"astral_guardian_angel": PlayerClass.EffectStyle.WAVE,
	"astral_spirit_bond": PlayerClass.EffectStyle.WAVE,
	"astral_as_one": PlayerClass.EffectStyle.WAVE,
	"rime_ice_imprisonment": PlayerClass.EffectStyle.BURST,
	"rime_chilling_touch": PlayerClass.EffectStyle.BURST,
	"rime_glacier_blast": PlayerClass.EffectStyle.BURST,
	"rime_absolute_zero": PlayerClass.EffectStyle.BURST,
}


## Cast animation for Pjotr-mode abilities. Pixel-art layered on vector flash unless the
## ability is in VECTOR_ONLY_KIT_IDS (HoN-faithful robot heroes) — those go pure vector.
func _play_ability_effect(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	print("[main] _play_ability_effect %s" % ability_id)
	if GameRuntime.is_dedicated_server() or GameRuntime.is_classic():
		return
	var class_prefix := ability_id.split("_")[0]
	var class_data := PlayerClass.by_id(class_prefix)
	var vector_only := VECTOR_ONLY_KIT_IDS.has(ability_id)
	var flash := lightning_scene.instantiate() as LightningEffect
	flash.style = VECTOR_ONLY_KIT_IDS.get(ability_id, effect_style)
	flash.main_color = Color(class_data.effect_color)
	flash.chain_color = Color(class_data.effect_secondary)
	flash.lifetime = clampf(0.14 + (points[1].x if points.size() >= 2 else 80.0) / 900.0, 0.14, 0.42)
	flash.points = points
	add_child(flash)
	if not vector_only:
		var vfx := ability_vfx_scene.instantiate() as AbilityVfx
		vfx.configure(ability_id, effect_style, points)
		add_child(vfx)
	AudioService.play_ability(ability_id)


func _on_player_died(_peer_id: int) -> void:
	if GameRuntime.is_rift_clash() and GameRuntime.is_server():
		_check_team_eliminations()
	if _all_players_dead():
		game_over = true
		wave_director.stop()
		if GameRuntime.is_rift_clash():
			_resolve_rift_clash_match()
			return
		if not GameRuntime.is_dedicated_server():
			# End-of-run banking: every ABILITY_EVERY_WAVES survived banks a fresh ability for
			# the hero that just fell, finally paying out what the mid-run draft teased.
			var local_player := _local_player()
			var report := {}
			var wave_beaten := maxi(wave_director.wave - 1, 0)
			if local_player != null and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
				var hero_id := local_player.class_id
				var banked: Dictionary = PlayerProfile.bank_wave_progress(hero_id, wave_beaten)
				ProgressionService.auto_unlock_affordable()
				report = {
					"hero": hero_id,
					"wave": wave_beaten,
					"new_abilities": banked.get("newly_unlocked", []),
					"ult_now": PlayerProfile.is_ult_unlocked(hero_id),
				}
			hud.show_game_over()


## Server-only: any team whose every member is dead is eliminated; their WaveDirector
## stops releasing groups next tick. Winning resolution happens inside RiftClashManager
## once only one team remains.
func _check_team_eliminations() -> void:
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null:
			continue
		var team := player.team_id
		if team == "" or RiftClashManager.is_team_eliminated(team):
			continue
		var any_alive := false
		for other_peer in players.keys():
			var teammate := players[other_peer] as Player
			if teammate != null and teammate.team_id == team and teammate.active:
				any_alive = true
				break
		if not any_alive:
			RiftClashManager.mark_team_eliminated(team)


func _resolve_rift_clash_match() -> void:
	if not GameRuntime.is_server():
		return
	RiftClashManager.apply_local_result(multiplayer.get_unique_id())
	var placements := RiftClashManager.placements()
	for peer_id in registered_remote_peers.keys():
		client_rift_clash_resolved.rpc_id(peer_id, placements)
	# Host's own result screen (clients render theirs inside the RPC handler).
	_show_rift_clash_result_for_peer(multiplayer.get_unique_id(), placements)


@rpc("authority", "call_remote", "reliable")
func client_rift_clash_resolved(placements: Array) -> void:
	if game_over:
		return
	game_over = true
	var local_peer_id := multiplayer.get_unique_id()
	for entry in placements:
		if local_peer_id in (entry.get("players", []) as Array):
			RankService.record_match(
				int(entry.get("placement", 4)) == 1,
				int(entry.get("placement", 4)),
				placements.size()
			)
			if SteamService.is_available():
				SteamService.report_match_result(
					int(entry.get("placement", 4)) == 1,
					RankService.points_for_placement(
						int(entry.get("placement", 4)), placements.size()
					)
				)
			break
	_show_rift_clash_result_for_peer(local_peer_id, placements)


## Render the victory/defeat panel for one peer. Shared between host (after their own
## server's resolution) and clients (inside `client_rift_clash_resolved`).
func _show_rift_clash_result_for_peer(peer_id: int, placements: Array) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var placement := 4
	var winner_name := "Nobody"
	for entry in placements:
		var entry_placement := int(entry.get("placement", 4))
		if entry_placement == 1:
			winner_name = str(entry.get("name", "Team A"))
		var members: Array = entry.get("players", [])
		if peer_id in members:
			placement = entry_placement
	var delta := RankService.points_for_placement(placement, placements.size())
	var total_before := RankService.skill_points
	hud.show_rift_clash_result(
		placement, placements.size(), winner_name,
		delta, total_before + delta
	)


func _on_player_level_reached(_level: int, peer_id: int) -> void:
	if not GameRuntime.is_server() and GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	queued_upgrade_choices[peer_id] = int(queued_upgrade_choices.get(peer_id, 0)) + 1
	_offer_next_upgrade(peer_id)


## Level-ups (and the every-3-waves draft) alternate tracks per peer: even turn index so far
## offers a hero ability (learn new / rank up known), odd index offers the classic stat pick.
func _offer_next_upgrade(peer_id: int) -> void:
	if pending_upgrades.has(peer_id) or pending_ability_offers.has(peer_id):
		return
	if int(queued_upgrade_choices.get(peer_id, 0)) <= 0:
		return
	var leveled_player := players.get(peer_id) as Player
	if leveled_player == null:
		return
	var turn := int(offer_turn_index.get(peer_id, 0))
	if turn % 2 == 0 and not PlayerClass.ability_offer_ids(leveled_player.class_id, leveled_player.known_abilities).is_empty():
		_offer_ability_turn(peer_id, leveled_player)
	else:
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


## Applies the open-by-default crater state to the freshly built arena and marks the
## one-shot unlock HUD/RPC beat as already spent, so wave 1 never re-announces it.
func _init_crater() -> void:
	if arena is Arena:
		(arena as Arena).set_crater_unlocked(crater_unlocked)
	_crater_unlock_announced = crater_unlocked


## Sealed until CRATER_UNLOCK_WAVE: the meadow hides the scar, the bramble wall blocks
## feet, and is_blocked() keeps wave spawns out. From wave CRATER_UNLOCK_WAVE up the
## seal breaks with the same world-flash beat as a biome change.
## Team modes are still being built; for now the crater is a shared world race to the
## middle, so any team plugin inherits the lock unchanged.
func _update_crater_lock(wave: int) -> void:
	if wave < CRATER_UNLOCK_WAVE:
		return
	if not arena is Arena:
		return
	var already := (arena as Arena).crater_unlocked
	(arena as Arena).set_crater_unlocked(true)
	crater_unlocked = true
	if already:
		return
	if not GameRuntime.is_dedicated_server():
		hud.announce_boss_phase(1, "THE CRATER HAS OPENED")
		_play_world_flash()
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_crater_unlocked.rpc_id(peer_id)


@rpc("authority", "call_remote", "reliable")
func client_crater_unlocked() -> void:
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		return
	if arena is Arena:
		(arena as Arena).set_crater_unlocked(true)
	crater_unlocked = true
	_crater_unlock_announced = true
	hud.announce_boss_phase(1, "THE CRATER HAS OPENED")
	_play_world_flash()


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
	var arena_node := arena as Arena
	return {
		"players": player_states,
		"enemies": enemy_states,
		"xp_orbs": orb_states,
		"wave": current_wave,
		"wave_name": current_wave_name,
		"biome_id": GameRuntime.biome_id,
		"crater_unlocked": arena_node != null and arena_node.crater_unlocked,
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
			if GameRuntime.is_rift_clash() and snapshot_player.team_id != "":
				hud.refresh_rift_clash_banner(
					RiftClashManager.team_name(snapshot_player.team_id),
					RiftClashManager.team_corner_name(snapshot_player.team_id),
					RiftClashManager.team_color(snapshot_player.team_id)
				)
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


## Attach the SelfTestDriver child only when a request file exists. Skipping the call
## entirely is the safety: no driver => no weirdness even if the request file lingers.
func _right_selftest_boot() -> void:
	print("[main.gd] SelfTestDriver boot check — request path exists: %s" % FileAccess.file_exists("user://selftest_request.json"))
	var driver := SelfTestDriver.from_request()
	if driver == null:
		return
	add_child(driver)
	print("[main.gd] SelfTestDriver attached")


func _first_active_player() -> Player:
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			return player as Player
	return null


func _all_players_dead() -> bool:
	return not players.is_empty() and _first_active_player() == null
