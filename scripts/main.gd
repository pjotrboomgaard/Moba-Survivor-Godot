extends Node2D

const WorldClock := preload("res://scripts/world_clock.gd")
const UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")
const RunSave := preload("res://scripts/run_save.gd")
const SideQuestDirector := preload("res://scripts/side_quest_director.gd")
const CreepCampScript := preload("res://scripts/creep_camp.gd")
const RecruitAreasScript := preload("res://scripts/recruit_areas.gd")
const MinigameAreaScript := preload("res://scripts/minigame_area.gd")
const _CorpseScript := preload("res://scripts/corpse.gd")
const GhostWaveSystem := preload("res://scripts/ghost_wave_system.gd")

@export var max_enemies := 70
## Spawn ring relative to the player. At the default zoom of 0.5 the viewport
## spans ~2560px wide, so the screen edge is ~1280px from the player. Spawning
## beyond that guarantees enemies appear off-screen and walk in, instead of
## popping into view in front of the player.
@export var spawn_distance_min := 1400.0
@export var spawn_distance_max := 1800.0
@export var snapshot_rate := 20.0
@export var input_send_rate := 30.0

@onready var arena: Node2D = $Arena
@onready var actors: Node2D = $Actors
@onready var fog_modulate: CanvasModulate = $FogModulate
@onready var fog_of_war: FogOfWar = $FogOfWar
@onready var wave_director: WaveDirector = $WaveDirector
@onready var hud: GameHUD = $HUD
@onready var world_flash: Node2D = get_node_or_null("WorldFlash")
@onready var ghost_wave_system: Node2D = $GhostWaveSystem
@onready var world_transition: Node2D = get_node_or_null("WorldTransition")
## Opening cinematic: a pixel-art ship crashes into the map centre, forms the crater,
## then zooms to the hero. Created lazily; null until play_opening_cinematic runs.
var _opening_ship: Node2D = null
## True while the opening crash-landing cinematic is playing; wave 1 spawn waits.
var _opening_cinematic_playing := false
## One-shot helper so the many `game_over = true` sites can flip the ghost trickle
## off without every caller remembering to reach for the node.
func _set_ghosts_game_over(dead: bool) -> void:
	if ghost_wave_system != null:
		(ghost_wave_system as Node).set_game_over(dead)

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")
var xp_orb_scene: PackedScene = preload("res://scenes/xp/xp_orb.tscn")
var lightning_scene: PackedScene = preload("res://scenes/effects/lightning_effect.tscn")
var ability_vfx_scene: PackedScene = preload("res://scenes/effects/ability_vfx.tscn")
var projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

## Per-ability vector-effect dedup. When a hero (or a bot) spams the same ability,
## each cast previously spawned a fresh full-screen LightningEffect; the stacked copies
## overlaid on one another and read as a muddy blob. We now cap how many *same-ability*
## vector flashes can live at once. When the cap is hit, the oldest one is released early
## instead of stacking another copy.
const _MAX_CONCURRENT_VECTOR_FX_PER_ABILITY := 3
var _active_vector_fx: Array = []  # LightningEffect nodes added via _add_vector_fx()

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
var _taken_upgrades: Array[String] = []
var _run_restore_applied := false
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
## Self-test hook: the last boss-defeat transition we played, so a probe can assert
## that the ring + zoom actually ran without needing to simulate a full boss fight.
var _last_boss_transition := {}
## Server-only tracking of landmark cool-downs by id, so one player can't spam the bell.
var _landmark_last_trigger: Dictionary = {}
const LANDMARK_GLOBAL_COOLDOWN := 16.0
## Last snapshot send time per peer so the crater-state RPC supplements, not floods.
var _crater_snapshot_sent: Dictionary = {}
## Peer ids that have pressed the Next Wave button this breather (co-op requires everyone).
var ready_for_next_wave: Dictionary = {}
## peer_id of the downed player -> seconds a stationary teammate has stood next to them.
var revive_progress: Dictionary = {}
var _side_quest_director: Node = null
var _creep_camp: Node = null
var _recruit_areas: Node = null
var _minigame_area: Node = null
var _ghost_waves: Node = null

const REVIVE_RADIUS := 60.0
const REVIVE_DURATION := 5.0
const BOSS_MAX_ENEMIES := 160
const RAVAGER_MINION_START_SPEED := 0.28
const RAVAGER_MINION_RAMP := 18.0
const RAVAGER_MINION_CAP := 2.2

## Drop-in beat: one planet name per GameRuntime.biome_id (grass/volcano/ice/factory/docks),
## established once and reused every time the wave cycle loops back to that biome — see
## _mission_planet_name(). Register matches Arena.WORLD_NAMES ("Iron Foundry", "Ashen
## Caldera", "Verdant Wilds", "Storm Court").
const MISSION_PLANET_NAMES: Array[String] = [
	"Verdant Meridian",
	"Pyrrhan Expanse",
	"Frostspire Court",
	"Ferrum Prime",
	"Brinehold Wilds",
]
## One-line flavor per planet, shown under the title on the mission card.
const MISSION_PLANET_TAGLINES: Array[String] = [
	"Rolling meadows, restless roots",
	"Ash fields and rivers of fire",
	"Glacial floes, aurora skies",
	"Iron halls, endless conveyors",
	"Storm-lashed piers and open water",
]
## How long the black-screen title card holds before fading back into the arena — a real
## beat, not a passing notice (see hud.gd's announce_mission and _play_mission_warp below).
const MISSION_WARP_CARD_HOLD := 2.6
## Landing explosion: smaller and less lethal than a landmark pulse_wipe (1600 radius) —
## flavor for the drop-in, not a wave-clearing nuke. Two passes (immediate + follow-up) so
## enemies that were just out of range when the player lands still get caught as they close in.
const ARRIVAL_EXPLOSION_RADIUS := 460.0
const ARRIVAL_EXPLOSION_FOLLOWUP_DELAY := 2.4
## Mission warp beat (world change on a boss kill): fade to BLACK (not the quick white
## wave-bump flash — this is a bigger, distinct beat), hold on the title card, fade back.
## MISSION_WARP_SCREEN_HOLD is timed to the hud title card's own fade-in/hold/fade-out
## (0.35 + MISSION_WARP_CARD_HOLD + 0.4) so the screen doesn't clear mid-card.
const MISSION_WARP_FADE_IN := 0.65
const MISSION_WARP_SCREEN_HOLD := 0.35 + MISSION_WARP_CARD_HOLD + 0.4
const MISSION_WARP_FADE_OUT := 0.9

## Rift Clash: one WaveDirector per active team, keyed by team id. Created lazily on the
## server once `RiftClashManager.assign_teams` has run; stays empty in co-op and on clients
## (their wave metadata flows in via the co-op snapshot from whichever director raced ahead).
var team_wave_directors: Dictionary = {}  # team_id -> WaveDirector
var _ffa_respawn_in: Dictionary = {}
var _ffa_shop_timer := 0.0
## Fog-of-war LOS recheck cadence -- see _update_fog_visibility(). Raycasts are cheap
## individually so a plain periodic full pass (not per-frame, not round-robin) is plenty;
## this is nowhere near the O(enemies^2)-per-frame territory the separation-offset fix
## (scripts/enemy.gd) had to solve.
const FOG_VISIBILITY_INTERVAL := 0.15
## A target within this range of the local player is always visible regardless of trees
## between you -- otherwise standing right next to someone with a sapling between your feet
## would absurdly hide them at melee range.
const FOG_ALWAYS_VISIBLE_RANGE := 110.0
var _fog_visibility_timer := 0.0
var _ffa_status_timer := 0.0
## Throttle the per-frame enemy-pool scan (wave pressure + alive count) to 15 Hz.
## The wave director only needs a "roughly right" count at this cadence — a
## ±3-frame lag in detecting "all dead" is imperceptible.
const WAVE_PRESSURE_INTERVAL := 1.0 / 15.0
var _wave_pressure_timer := 0.0
var _ffa_scoreboard_timer := 0.0
var _ffa_elapsed := 0.0
var _ffa_bounty_timer := 0.0
const FFA_BOUNTY_CAP := 4
const FFA_BOUNTY_TYPES := ["brute", "hexer", "lurker", "sentinel", "splitter", "bomber"]
const FFA_CPU_SHOP_SECONDS := 12.0
var _ffa_world_wave := 1
## Which path last triggered the boss-defeat ring sweep — "boss_death" (a boss just
## died) or "mission_warp" (the arena rebuilt for a new world). Drives the probe's
## `source` field so a self-test can tell the two apart.
var _last_boss_ring_source := "none"
## FFA opening sequence: all four heroes land in a circle at center, stand still for
## FFA_INTRO_HOLD (can't control), then auto-walk outward in their own directions for
## FFA_INTRO_WALK (camera follows each local player), stand still again, and only then
## do the team wave directors start and creeps begin.
const FFA_INTRO_HOLD := 2.0
const FFA_INTRO_WALK := 3.5
const FFA_INTRO_END_HOLD := 2.0

## Global gold-drop boost so items stay affordable through the late game. Multiplied on
## top of any gold_multiplier upgrade the hero carries. Only applied at the enemy-kill
## award path (not dev/test gold), so unit-test gold expectations stay exact.
const GOLD_DROP_BOOST := 1.45
var _ffa_intro_elapsed := -1.0
var _ffa_intro_done := false
var _ffa_countdown_shown := 0   # last countdown number displayed during walkout
var _ffa_intro_walk_dir := {}
var _landing_fx: Node2D = null


func _ready() -> void:
	randomize()
	if fog_modulate != null:
		fog_modulate.color = Color(1.0, 1.0, 1.0, 1.0)
	NetworkService.peer_left.connect(_on_peer_left)
	if arena is Arena:
		# Bind before dress so a rebuild's landmarks_changed reconnects us.
		(arena as Arena).landmarks_changed.connect(_bind_landmarks)
		if not GameRuntime.return_to_world_editor:
			GameRuntime.reset_biome_for_new_run()
		(arena as Arena).dress_from_runtime_biome()
		_bind_landmarks()
	hud.upgrade_chosen.connect(_on_local_upgrade_chosen)
	hud.upgrade_chosen.connect(_hud_track_upgrade)
	hud.ability_chosen.connect(_on_local_ability_chosen)
	hud.shop_item_chosen.connect(_on_local_shop_item_chosen)
	hud.shop_closed.connect(_on_local_shop_closed)
	hud.next_wave_requested.connect(_on_local_next_wave_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.leave_requested.connect(_on_leave_requested)
	hud.dev_command.connect(_on_local_dev_command)
	hud.set_connection_text(GameRuntime.mode_name())
	if hud.upgrade_panel != null:
		hud.upgrade_panel.visible = false
	wave_director.wave_started.connect(_on_wave_started)
	## group_ready is *not* gated by team mode: the co-op `_on_wave_group_ready` handler
	## runs the plain formation path for Classic & Pjotr co-op, while team directors bind
	## themselves to `_on_team_wave_group_ready` instead.
	wave_director.group_ready.connect(_on_wave_group_ready)
	wave_director.intermission_started.connect(_on_intermission_started)

	# Ghost trickle: continuous stream of unrendered enemies from map edges that
	# materialize into real enemies when they reach the player's screen.
	if ghost_wave_system != null:
		ghost_wave_system.bind(self)

	_init_crater()

	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		if GameRuntime.is_ffa():
			RiftClashManager.reset_match()
		_create_player(1, Player.SimulationMode.OFFLINE, true, GameRuntime.active_class_id())
		_spawn_cpu_allies()
		_try_restore_pending_run()
		if GameRuntime.is_ffa() and GameRuntime.ffa_all_bots:
			_convert_local_to_ffa_bot()
		# Opening crash-landing cinematic (solo + FFA). Skipped under selftest so the
		# harness gets the arena in its normal state; the dev command `open_cinematic`
		# still triggers it on demand for visual verification.
		var _in_selftest := OS.has_feature("selftest") or "--selftest" in OS.get_cmdline_args()
		if not _in_selftest and GameRuntime.return_to_world_editor == false:
			play_opening_cinematic()
		else:
			_spawn_initial_wave()
		if GameRuntime.is_ffa():
			_maintain_ffa_bounties()
		_start_side_quests()
		_start_ghost_waves()
		# Self-test harness: only boot when explicitly requested via --selftest CLI flag
		# AND a request file exists. This prevents stale user://selftest_request.json
		# from hijacking normal play sessions.
		if OS.has_feature("selftest") or "--selftest" in OS.get_cmdline_args():
			_right_selftest_boot()
	elif GameRuntime.is_server():
		if GameRuntime.mode == GameRuntime.RuntimeMode.HOST:
			_create_player(1, Player.SimulationMode.AUTHORITY, true, GameRuntime.active_class_id())
			_try_restore_pending_run()
			_spawn_initial_wave()
			_start_side_quests()
			_start_ghost_waves()
		if GameRuntime.is_dedicated_server():
			hud.visible = false
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		wave_director.stop()
		call_deferred("_register_with_server")


func _physics_process(delta: float) -> void:
	WorldClock.tick(delta)
	if fog_modulate != null and not GameRuntime.is_classic():
		fog_modulate.color = WorldClock.ambient
	# Throttle the O(enemies) wave-pressure scan to 15 Hz — the wave director only
	# needs to know "are there any enemies alive?" at ~60 Hz for timing precision,
	# but a 15 Hz cadence is more than enough for "wave cleared" detection.
	_wave_pressure_timer += delta
	var _do_pressure := _wave_pressure_timer >= WAVE_PRESSURE_INTERVAL
	if _do_pressure:
		_wave_pressure_timer = 0.0
	if GameRuntime.is_server():
		_update_host_input()
		if _do_pressure:
			_update_enemy_reports()
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
	elif GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		if _do_pressure:
			_update_enemy_reports()
		if hud != null:
			hud.update_boss(_find_boss())
	elif GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		input_accumulator += delta
		if input_accumulator >= 1.0 / input_send_rate:
			input_accumulator = 0.0
			_send_local_input()
	if not GameRuntime.is_dedicated_server() and not GameRuntime.is_classic():
		_update_shop_stand_proximity()
		# Vision-hiding disabled entirely (per user request): neither the dark
		# fog-of-war overlay nor the per-sprite distance fade runs. The hero and
		# every enemy stay fully visible everywhere on the map at all times.
		if fog_of_war != null:
			fog_of_war.visible = false
			if fog_of_war.has_method("set_overlay_visible"):
				fog_of_war.set_overlay_visible(false)
	if GameRuntime.mode != GameRuntime.RuntimeMode.CLIENT:
		_update_revives(delta)
		_tick_ffa(delta)
	# Selftest: when a local hero is inside an active minigame with bot_force on,
	# drive their movement from the minigame's bot_tick so movement-based games
	# (Treasure Dash) actually collect gems under selftest.
	_apply_minigame_bot_force_move(delta)


func _apply_minigame_bot_force_move(delta: float) -> void:
	if _minigame_area == null or not is_instance_valid(_minigame_area):
		return
	var local_player := _local_player()
	if local_player == null:
		return
	# Find the active minigame with bot_force on. In selftest there is at most one
	# bot-forced minigame at a time; we drive the local player's movement from it.
	var driving := false
	var games: Array = _minigame_area.all_minigames()
	for g in games:
		if g == null or not is_instance_valid(g):
			continue
		if not bool(g.get("active")) or not bool(g.get("bot_force")):
			continue
		if not g.has_method("bot_tick"):
			continue
		var choice: Dictionary = g.bot_tick(delta)
		var move: Vector2 = (choice.get("move", Vector2.ZERO) if choice.has("move") else Vector2.ZERO) as Vector2
		local_player.minigame_move_override = move.limit_length(1.0)
		if move.length_squared() > 0.04:
			driving = true
		break
	if not driving:
		local_player.minigame_move_override = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if GameRuntime.return_to_world_editor and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F6:
			_on_leave_requested()
			return
	if game_over and event.is_action_pressed("restart") and GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_parent().call_deferred("restart_game")
	if event.is_action_pressed("interact_shop") and not game_over:
		# B toggles the shop: close it if it's already open (no need to be at the stand).
		if hud.shop_panel.visible:
			hud.close_shop()
			hud.shop_closed.emit()
		elif _near_shop_stand and not hud.upgrade_panel.visible and not hud.escape_menu.visible and not hud.dev_panel.visible and not hud.codex_panel.visible:
			hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
			_cpu_auto_shop()
	# Forward gameplay input to the active village minigame (number keys / WASD /
	# mouse) so a human standing at the pad can actually play it. Returns early so
	# the keys don't also fire an ability.
	if _route_minigame_input(event):
		return

## If the local hero is standing at an ACTIVE minigame, hand the raw input event
## straight to that minigame (its on_input_event handles keys 1-9, WASD, mouse)
## and swallow it so abilities don't fire. Returns true when the event was consumed.
func _route_minigame_input(event: InputEvent) -> bool:
	if _minigame_area == null or not is_instance_valid(_minigame_area):
		return false
	var local_player := _local_player()
	if local_player == null:
		return false
	var active: Node2D = _minigame_area.active_minigame_at(local_player.global_position, 170.0)
	if active == null or not bool(active.get("active")):
		return false
	active.on_input_event(event)
	# Movement keys are also normal movement; let them drive the hero (Treasure
	# Dash reads the hero position), so only swallow the ability / interact keys.
	if event is InputEventKey:
		var keycode: int = (event as InputEventKey).physical_keycode
		if event.pressed and not event.echo and (keycode >= KEY_1 and keycode <= KEY_9):
			get_viewport().set_input_as_handled()
			return true
		if event.pressed and not event.echo and (
			keycode == KEY_F or keycode == KEY_SPACE or keycode == KEY_R):
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return true
	return false


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
			_landmark_flash("Landmark pulse!", Color("ffd060"))
		"freeze_time":
			_landmark_flash("Time frozen!", Color("80c0ff"))
		"heal_all":
			_landmark_flash("Blessing!", Color("70d070"))
		"speed_surge":
			_landmark_flash("Speed surge!", Color("ffe066"))
		"phase_cloak":
			_landmark_flash("Phase cloak!", Color("9a70ff"))
		"battle_frenzy":
			_landmark_flash("Battle frenzy!", Color("ff3020"))
		_:
			_landmark_flash("Landmark awakened", Color("e8e8e8"))
	var ring := ArenaHazard.new()
	ring.configure({
		"kind": "ring",
		"origin": origin,
		"radius": 700.0,
		"max_radius": 700.0,
		"telegraph": 0.0,
		"active": 0.6,
		"line_width": 70.0,
		"color": _landmark_ring_color(effect_id),
		"damage": 0.0,
		"cosmetic": true,
	})
	add_child(ring)
	_play_sound("enemy_death")


func _landmark_ring_color(effect_id: String) -> String:
	match effect_id:
		"pulse_wipe":
			return "ffd060"
		"freeze_time":
			return "80c0ff"
		"heal_all":
			return "70d070"
		"speed_surge":
			return "ffe066"
		"phase_cloak":
			return "9a70ff"
		"battle_frenzy":
			return "ff3020"
		_:
			return "e8e8e8"


@rpc("authority", "call_remote", "reliable")
func client_announce_boss_phase(phase: int, boss_name: String) -> void:
	hud.announce_boss_phase(phase, boss_name)
	_shake_cameras(18.0, 0.7)
	_play_world_flash(false)


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


## Dev-menu / self-test command: apply a resolution change (and keep the visible
## world area constant by rescaling the local player's camera zoom) without going
## through the HUD's OptionButton.
func apply_resolution_test(width: int, height: int, fullscreen: bool = false) -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_size(Vector2i(width, height))
	var old_width := maxf(1.0, get_viewport().get_visible_rect().size.x)
	var new_width := float(width) if not fullscreen else old_width
	if fullscreen:
		var screen := DisplayServer.window_get_size()
		new_width = maxf(1.0, screen.x)
	var ratio := new_width / old_width
	if absf(ratio - 1.0) > 0.0001:
		var player := _local_player()
		if player != null and player.camera != null:
			var old_zoom: Vector2 = player.camera.zoom
			player.camera.zoom = Vector2(maxf(0.05, old_zoom.x * ratio), maxf(0.05, old_zoom.y * ratio))


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
func client_announce_mission(mission_number: int, planet_name: String, tagline: String, hold_seconds: float) -> void:
	if not GameRuntime.is_dedicated_server():
		hud.announce_mission(mission_number, planet_name, tagline, hold_seconds)


@rpc("authority", "call_remote", "reliable")
func client_announce_wave(wave: int, theme_name: String, debut_type_id: String) -> void:
	hud.close_shop()
	hud.set_wave(wave, theme_name)
	hud.announce_wave(wave, theme_name, debut_type_id)
	hud.show_next_wave_button(false)
	if wave > 0 and wave % WaveDirector.BOSS_WAVE_INTERVAL == 0:
		_shake_cameras(16.0, 0.6)
		_play_world_flash(false)


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


## Fog-of-war: hides enemies and hostile players outside vision range, or with a tree
## between you (Obstacle.VISION_BLOCKER_LAYER). The FogOfWar overlay dims the map
## so this only ever matters in co-op, which is the point — dying isn't a full reset there
## as long as someone can reach you and hold position.
## Hiding of enemies/hero by distance or trees has been intentionally disabled.
## This is a no-op that forces full visibility so no sprite ever vanishes.
func _update_fog_visibility(delta: float) -> void:
	pass


func _apply_fog_visibility(target: Node2D, from: Vector2) -> void:
	target.modulate.a = 1.0


func _update_revives(delta: float) -> void:
	if GameRuntime.is_ffa():
		return
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
	# Solo PLAY leaves this false. Co-op CPU fill and FFA sim both use it.
	if not GameRuntime.fill_cpu_allies:
		return
	if GameRuntime.is_classic() or GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	var cpu_peer := CPU_PEER_BASE
	if GameRuntime.is_ffa():
		for _index in 3:
			_create_player(cpu_peer, Player.SimulationMode.CPU, false, GameRuntime.ffa_class_for_peer(cpu_peer))
			cpu_peer += 1
		return
	var allies := PlayerClass.cpu_ally_ids(GameRuntime.active_class_id())
	for index in mini(3, allies.size()):
		_create_player(cpu_peer, Player.SimulationMode.CPU, false, allies[index])
		cpu_peer += 1


func _convert_local_to_ffa_bot() -> void:
	var local_player := _local_player()
	if local_player == null:
		return
	local_player.simulation_mode = Player.SimulationMode.CPU
	local_player.apply_class(GameRuntime.ffa_class_for_peer(local_player.owner_peer_id))
	hud.bind_player(local_player)
	hud.refresh_ffa_scoreboard(_ffa_scoreboard_rows())


func _cpu_auto_shop(max_purchases: int = 99, gold_reserve: int = 0) -> void:
	for player_node in players.values():
		var player := player_node as Player
		if player == null or not player.is_cpu() or not player.active:
			continue
		var bought := 0
		for item in ShopCatalog.items_for(player.class_id):
			if bought >= max_purchases:
				break
			var item_id := str(item.id)
			if player.gold - gold_reserve < ShopCatalog.price_for(item_id, player.stacks_of(item_id)):
				continue
			if player.buy(item_id):
				bought += 1


func _create_player(peer_id: int, mode: int, local_player: bool, class_id: String = PlayerClass.DEFAULT_CLASS_ID) -> Player:
	if players.has(peer_id):
		return players[peer_id] as Player
	if GameRuntime.is_rift_clash() and (GameRuntime.is_server() or GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE):
		var upcoming: Array = players.keys()
		upcoming.append(peer_id)
		if RiftClashManager.assigned_teams.is_empty():
			RiftClashManager.reset_match()
		RiftClashManager.assign_teams(upcoming, _lobby_claims())
	var spawn_class := GameRuntime.ffa_class_for_peer(peer_id) if GameRuntime.is_ffa() else class_id
	var player := player_scene.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.global_position = _spawn_position_for_peer(peer_id)
	actors.add_child(player)
	player.configure(peer_id, mode, local_player, spawn_class)
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
		if GameRuntime.is_server() or GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
			RiftClashManager.assign_teams(players.keys(), _lobby_claims())
		player.team_id = str(RiftClashManager.team_of(peer_id))
		player.apply_team_identity()
		if GameRuntime.is_server() or GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
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
			if GameRuntime.is_ffa():
				hud.set_team_health_color(RiftClashManager.team_color(player.team_id))
				hud.refresh_ffa_scoreboard(_ffa_scoreboard_rows())
	wave_director.set_player_count(players.size())
	return player


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	if GameRuntime.is_rift_clash() and not RiftClashManager.assigned_teams.is_empty():
		var anchor := RiftClashManager.team_anchor(RiftClashManager.team_of(peer_id))
		var slot := 0
		for other_peer in players.keys():
			if RiftClashManager.team_of(int(other_peer)) == RiftClashManager.team_of(peer_id):
				slot += 1
		var angle := TAU * float(slot) / 4.0
		return anchor + Vector2.RIGHT.rotated(angle) * 96.0
	if GameRuntime.fill_cpu_allies or GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return Arena.corner_spawn(players.size())
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
	director.team_focus_position = RiftClashManager.team_anchor(team_id)
	team_wave_directors[team_id] = director
	# Defer the actual start until the FFA intro sequence (landing circle → walk-out)
	# completes, so creeps don't spawn while the heroes are still landing.
	if _ffa_intro_done:
		director.start(maxi(1, members), false)


## Server-local reaction when a team wave begins — the host HUD shows the wave the
## anchor player on this team faces; other corners keep their own pace.
func _on_team_wave_started(wave: int, theme_name: String, debut_type_id: String, team_id: String) -> void:
	if not GameRuntime.is_server() and GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	_maybe_advance_ffa_world(wave)
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
func _on_team_intermission_started(next_wave: int, seconds: float, team_id: String) -> void:
	if not GameRuntime.is_server() and GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	_maybe_advance_ffa_world(next_wave)
	if WaveDirector.shop_opens_before(next_wave):
		if not GameRuntime.is_dedicated_server():
			hud.open_shop(false)
			if GameRuntime.is_ffa():
				_cpu_auto_shop(2, 400)
			else:
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


func _maybe_advance_ffa_world(wave: int) -> void:
	if not GameRuntime.is_ffa() or not GameRuntime.uses_biomes():
		return
	_update_crater_lock(wave)
	if wave <= _ffa_world_wave:
		return
	_ffa_world_wave = wave
	var previous := GameRuntime.biome_id
	GameRuntime.set_biome_for_wave(wave)
	if hud != null:
		hud.set_wave(wave)
	if GameRuntime.biome_id == previous:
		return
	_play_mission_warp(wave)


func _on_team_wave_group_ready(
		type_id: String, formation: int, count: int,
		health_multiplier: float, speed_multiplier: float, focus: Variant = null, team_id: String = ""
) -> void:
	if game_over or players.is_empty():
		return
	if RiftClashManager.is_team_eliminated(team_id):
		return
	if focus is Vector2 and (focus as Vector2).length_squared() > 0.0:
		# FFA pressure pack targeted at this team's own spawn lane (main.gd set the focus
		# position so "more creeps come toward the local player's side").
		_spawn_formation_near(focus, type_id, formation, count, health_multiplier, speed_multiplier, false)
	else:
		_spawn_team_formation(team_id, type_id, formation, count, health_multiplier, speed_multiplier)


func _spawn_initial_wave() -> void:
	if initial_wave_spawned or players.is_empty():
		return
	# The opening crash-landing cinematic delays wave 1 until the ship impacts and
	# the hero lands in the crater. If it's still playing, defer; the cinematic's
	# finish handler calls this again.
	if _opening_cinematic_playing:
		return
	initial_wave_spawned = true
	if GameRuntime.is_rift_clash():
		wave_director.stop()
		return
	if GameRuntime.is_classic():
		max_enemies = 35
	wave_director.start(players.size(), GameRuntime.is_classic())


func _try_restore_pending_run() -> void:
	var pending: Dictionary = GameRuntime.pending_run_save.duplicate(true)
	GameRuntime.pending_run_save = {}
	if pending.is_empty() and get_parent() != null:
		var raw: Variant = get_parent().get("_pending_run_save")
		if raw is Dictionary and not (raw as Dictionary).is_empty():
			pending = (raw as Dictionary).duplicate(true)
			get_parent().set("_pending_run_save", {})
	if pending.is_empty():
		return
	GameRuntime.start_wave = maxi(1, int(pending.get("wave", GameRuntime.start_wave)))
	restore_run(pending)


func restore_run(data: Dictionary) -> void:
	if data.is_empty() or _run_restore_applied:
		return
	_run_restore_applied = true
	var wave := maxi(1, int(data.get("wave", GameRuntime.start_wave)))
	GameRuntime.start_wave = wave
	current_wave = wave
	if data.has("biome_id") and not GameRuntime.return_to_world_editor:
		GameRuntime.biome_id = int(data.get("biome_id", GameRuntime.biome_id))
	var player := _local_player()
	if player == null:
		return
	_taken_upgrades.clear()
	for raw_upgrade in data.get("taken_upgrades", []):
		var upgrade_id := str(raw_upgrade)
		if upgrade_id.is_empty():
			continue
		player.apply_upgrade(upgrade_id)
		_taken_upgrades.append(upgrade_id)
	player.gold = int(data.get("gold", player.gold))
	player.gold_changed.emit(player.gold)
	player.current_xp = int(data.get("xp", player.current_xp))
	player.level = int(data.get("level", player.level))
	player.xp_required = int(data.get("xp_required", player.xp_required))
	# Restore per-level upgrade history so the build log shows the correct level per upgrade.
	var saved_lu: Variant = data.get("level_upgrades", {})
	if saved_lu is Dictionary:
		player.level_upgrades = (saved_lu as Dictionary).duplicate(true)
	player.xp_changed.emit(player.current_xp, player.xp_required, player.level)
	var abilities: Array[Dictionary] = []
	for raw_ability in data.get("known_abilities", []):
		if raw_ability is Dictionary:
			abilities.append(raw_ability)
	if not abilities.is_empty():
		player.known_abilities = abilities
		while player.ability_cooldowns.size() < player.known_abilities.size():
			player.ability_cooldowns.append(0.0)
	var stacks: Variant = data.get("shop_stacks", {})
	if stacks is Dictionary:
		for item_id in (stacks as Dictionary).keys():
			var count := int((stacks as Dictionary)[item_id])
			for _i in count:
				player.shop_stacks[str(item_id)] = player.stacks_of(str(item_id)) + 1
				player._apply_shop_item(str(item_id))
	player.health.max_health = float(data.get("max_health", player.health.max_health))
	player.health.current_health = float(data.get("health", player.health.current_health))
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)
	var pos: Variant = data.get("position", null)
	if pos is Dictionary:
		player.global_position = Vector2(float(pos.get("x", player.global_position.x)), float(pos.get("y", player.global_position.y)))
	elif pos is Vector2:
		player.global_position = pos
	elif pos is Array and (pos as Array).size() >= 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))


func capture_run() -> Dictionary:
	var player := _local_player()
	if player == null:
		return {}
	return {
		"wave": maxi(1, current_wave),
		"biome_id": GameRuntime.biome_id,
		"class_id": player.class_id,
		"gold": player.gold,
		"xp": player.current_xp,
		"level": player.level,
		"xp_required": player.xp_required,
		"health": player.health.current_health,
		"max_health": player.health.max_health,
		"known_abilities": player.known_abilities.duplicate(true),
		"shop_stacks": player.shop_stacks.duplicate(true),
		"taken_upgrades": player.taken_upgrades.duplicate() if not player.taken_upgrades.is_empty() else _taken_upgrades.duplicate(),
		"level_upgrades": player.level_upgrades.duplicate(true),
		"position": {"x": player.global_position.x, "y": player.global_position.y},
	}


func _persist_run_save() -> void:
	if game_over or GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
		return
	if GameRuntime.is_ffa() or GameRuntime.return_to_world_editor:
		return
	var data := capture_run()
	if data.is_empty():
		return
	RunSave.write_dict(data)


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
	if wave == 1 and not GameRuntime.is_ffa() and not GameRuntime.fill_cpu_allies:
		# Mission 1: fresh run, drop the player at the crater and light up the landing beat.
		_trigger_world_landing(_mission_number_for_wave(wave))
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
			_play_world_flash(false)
	_persist_run_save()
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
	var beaten := next_wave - 1
	if not GameRuntime.is_dedicated_server():
		AudioService.play("wave_clear")
		# Solo meta: bank sparks for the local player when a milestone wave is cleared.
		if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
			var local_player := _local_player()
			var hero_id := local_player.class_id if local_player != null else ""
			if beaten > 0 and beaten % 5 == 0 and not _selftest_active():
				var sparks: float = PlayerProfile.sparks_for_wave(beaten)
				if sparks > 0:
					PlayerProfile.grant_sparks(sparks, hero_id)
					ProgressionService.auto_unlock_affordable()
					if hud.has_method("set_sparks"):
						hud.set_sparks(PlayerProfile.sparks)
			# Ultimates ship with the hero from the start now; the old wave-5 unlock
			# moment is retired (kept as a no-op for legacy saves via maybe_unlock_ult).
			if not hero_id.is_empty() and local_player != null:
				local_player.known_abilities = local_player.known_abilities
		# MOBA draft: every 6th wave cleared, hand everyone (CPUs pick instantly) a fresh
		# ability offer so the run keeps growing on top of XP/level picks.
		if beaten > 0 and beaten % 6 == 0:
			_queue_wave_draft()
	var world_changed := false
	if GameRuntime.uses_biomes():
		var previous_biome := GameRuntime.biome_id
		# A world transition only happens after 3 bosses have been defeated in the
		# current world (i.e. every 15 waves). Bosses still spawn on every 5th wave;
		# the world just stays put until the 3rd boss of that world drops.
		if beaten > 0 and beaten % WaveDirector.WAVES_PER_WORLD == 0:
			GameRuntime.set_biome_for_wave(next_wave)
		world_changed = GameRuntime.biome_id != previous_biome
	# A boss clear (wave % BOSS_WAVE_INTERVAL == 0) lands on a fresh biome ONLY when
	# the boss is the 3rd one of the world (the world-transition boss). The other two
	# bosses in a world are smaller "world bosses" — they still get the ring sweep +
	# takeover buff but no world warp.
	if beaten > 0 and beaten % WaveDirector.WAVES_PER_WORLD == 0 and not GameRuntime.is_classic():
		_play_mission_warp(next_wave)
	elif world_changed:
		# Defensive fallback for if BOSS_WAVE_INTERVAL and BIOME_CYCLE_WAVES ever diverge —
		# a world change deserves the same beat as the boss-kill path above, not the quick
		# wave-bump flash.
		_play_mission_warp(next_wave)
	if WaveDirector.shop_opens_before(next_wave):
		if _selftest_active():
			pass
		elif not GameRuntime.is_dedicated_server():
			hud.open_shop(GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
			_cpu_auto_shop()
		if GameRuntime.is_server() and not _selftest_active():
			for peer_id in registered_remote_peers.keys():
				client_open_shop.rpc_id(peer_id)
		if not _selftest_active():
			return
	if not GameRuntime.is_dedicated_server():
		hud.show_next_wave_button(true, seconds)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_show_next_wave_button.rpc_id(peer_id, seconds)


## The every-6-waves draft. Uses the level-up offer pipeline directly (queued → stat/ability
## turn → player pick) so CPU allies auto-resolve, clients get an RPC, and offline pauses.
func _queue_wave_draft() -> void:
	for peer_id in players.keys():
		queued_upgrade_choices[peer_id] = int(queued_upgrade_choices.get(peer_id, 0)) + 1
		offer_turn_index[peer_id] = 1  # force this level-up to be an ability (not stat) turn
		_offer_next_upgrade(peer_id)


func _on_wave_group_ready(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float, focus: Variant = null) -> void:
	if game_over or players.is_empty():
		return
	var close := wave_director.take_close_spawn()
	if focus is Vector2 and (focus as Vector2).length_squared() > 0.0:
		# A lane-targeted pack (FFA local-side pressure) spawns from the given corner
		# instead of the map-edge random point.
		_spawn_formation_near(focus, EnemyType.fit_to_biome(type_id), formation, count, health_multiplier, speed_multiplier, close)
	else:
		_spawn_formation(EnemyType.fit_to_biome(type_id), formation, count, health_multiplier, speed_multiplier, close)


func _spawn_formation(type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0, close_spawn: bool = false) -> void:
	_spawn_formation_near(_first_active_player(), type_id, formation, count, health_multiplier, speed_multiplier, close_spawn)


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


func _spawn_formation_near(focus: Variant, type_id: String, formation: int, count: int, health_multiplier: float, speed_multiplier: float = 1.0, close_spawn: bool = false) -> void:
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
	# "Close" reinforcement spawns still need to read as pressure, not enemies popping in
	# adjacent to the player — the reinforcement system got much more frequent this session
	# (fires far more often when healthy), so what used to be an occasional close pack is now
	# a regular occurrence, and 340-620 was reading as "spawns right next to me."
	var dmin := 520.0 if close_spawn else spawn_distance_min
	var dmax := 820.0 if close_spawn else spawn_distance_max
	var base_angle := randf_range(0.0, TAU)
	var pack_center := Vector2.RIGHT.rotated(base_angle) * randf_range(dmin, dmax)
	for index in count:
		if enemies.size() >= _enemy_cap():
			return
		var offset := Vector2.ZERO
		# Enemies spawn from the edges of the map (spread around the perimeter),
		# not just off-screen around the player. This reads as "creeps coming from
		# the map edges" and matches the minimap view. Close reinforcements still
		# spawn near the player for pressure.
		if close_spawn:
			match formation:
				EnemyType.Formation.PACK:
					offset = pack_center + Vector2(randf_range(-110.0, 110.0), randf_range(-110.0, 110.0))
				EnemyType.Formation.RING:
					var ring_angle := base_angle + float(index) * TAU / float(maxi(1, count))
					offset = Vector2.RIGHT.rotated(ring_angle) * dmin
				EnemyType.Formation.LONE:
					var lone_angle := randf_range(0.0, TAU)
					offset = Vector2.RIGHT.rotated(lone_angle) * randf_range(dmax, dmax + 90.0)
				_:
					var scatter_angle := randf_range(0.0, TAU)
					offset = Vector2.RIGHT.rotated(scatter_angle) * randf_range(dmin, dmax)
		else:
			# Spawn on the map perimeter: pick a random edge point, spread along it.
			var edge_pos := _pick_map_edge_position(focus_position)
			# Add a small local jitter so the pack is spread, not stacked.
			offset = edge_pos + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
		_spawn_enemy_at(focus_position + offset, type_id, health_multiplier, speed_multiplier, close_spawn)


## Returns a world position on (or just inside) the map perimeter, spread around the
## whole border. Used so enemies "come from the edges of the map" rather than popping
## up in the void just off the player's screen. The result is clamped to the playfield
## so it never spawns off-map.
func _pick_map_edge_position(near: Vector2) -> Vector2:
	var half := Vector2(2360.0, 1560.0)
	if arena != null and arena.has_method("half_extents"):
		half = (arena as Arena).half_extents() - Vector2(40.0, 40.0)
	# Pick a random point on the rectangle perimeter.
	var t := randf_range(0.0, 4.0)
	var p := Vector2.ZERO
	if t < 1.0:
		# Top edge
		p = Vector2(randf_range(-half.x, half.x), -half.y)
	elif t < 2.0:
		# Right edge
		p = Vector2(half.x, randf_range(-half.y, half.y))
	elif t < 3.0:
		# Bottom edge
		p = Vector2(randf_range(-half.x, half.x), half.y)
	else:
		# Left edge
		p = Vector2(-half.x, randf_range(-half.y, half.y))
	# Bias toward the side of the map that is farthest from the player so spawns
	# are spread "from everywhere" rather than clustering on one side.
	if p.distance_to(near) < half.length() * 0.5:
		# Flip to the opposite region of the map.
		p = Vector2(-p.x, -p.y)
	return p


## Backwards-compat for summoners/dev tools: spawn relative to the first active player.
func _spawn_enemy(offset: Vector2, type_id: String, health_multiplier: float, speed_multiplier: float = 1.0) -> Enemy:
	var focus := _first_active_player()
	if focus == null:
		return null
	return _spawn_enemy_at(focus.global_position + offset, type_id, health_multiplier, speed_multiplier)


func _spawn_enemy_at(world_position: Vector2, type_id: String, health_multiplier: float, speed_multiplier: float = 1.0, close_spawn: bool = false, camp_guardian: bool = false) -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	var entity_id := next_entity_id
	next_entity_id += 1
	var fitted_id := EnemyType.fit_to_biome(type_id)
	var spawn_flying := bool(EnemyType.field(fitted_id, "flying"))
	var spawn_boss := EnemyType.is_boss(fitted_id)
	var candidate_position := world_position
	var skip_pad_snap := false
	if not close_spawn and arena is Arena and (arena as Arena).is_water_biome() and not spawn_boss and randf() < 0.78:
		var toward := Vector2.ZERO
		var focus := _first_active_player()
		if focus != null:
			toward = focus.global_position
		candidate_position = (arena as Arena).water_spawn_point(toward, spawn_flying)
		skip_pad_snap = spawn_flying
	elif arena is Arena:
		var half := (arena as Arena).half_extents() - Vector2(40.0, 40.0)
		candidate_position.x = clampf(candidate_position.x, -half.x, half.x)
		candidate_position.y = clampf(candidate_position.y, -half.y, half.y)
	else:
		candidate_position.x = clampf(candidate_position.x, -2360.0, 2360.0)
		candidate_position.y = clampf(candidate_position.y, -1560.0, 1560.0)
	if skip_pad_snap:
		enemy.global_position = candidate_position
	else:
		enemy.global_position = arena.free_position_near(candidate_position, 22.0)
	enemy.team_id = _last_spawn_team
	actors.add_child(enemy)
	enemy.configure(entity_id, true, fitted_id, health_multiplier, speed_multiplier)
	enemy.apply_wave_growth(current_wave)
	if not enemy.is_boss:
		var dmg := wave_director.contact_multiplier_for_wave(current_wave)
		enemy.contact_damage *= dmg
		enemy.projectile_damage *= dmg
		enemy.explode_damage *= dmg
	# Camp guardian setup: hold position, undodgeable slam pulse, reduced damage
	# taken, and no-chase past the leash radius (see Enemy._process_camp_guardian).
	# Camps now ALSO fire fast projectiles at the engaged player, so they actively
	# attack you when you engage them (per user request: "creep camps should be
	# fast with attacking you or projectiles").
	if camp_guardian:
		enemy.is_camp_guardian = true
		enemy.camp_guardian_home = enemy.global_position
		enemy.health.damage_taken_multiplier = 0.85  # moderately tanky
		enemy.health.max_health *= 2.0  # 2x HP makes them clearly tanky
		# Contact damage is halved — the undodgeable slam pulse (14 dmg / 3s in
		# _process_camp_guardian) is the primary "you always take dmg" element.
		# Contact is secondary so a kiting player chips the guardian without
		# getting shredded by contact + slam stacking.
		enemy.contact_damage *= 0.5
		# Fast ranged attacks: each camp type gets its own projectile profile so
		# camps read as distinct (brute = heavy single bolt, sentinel = precise,
		# stalker = rapid multi-bolt).
		var camp_shot := _camp_projectile_profile(fitted_id)
		enemy.projectile_damage = camp_shot["projectile_damage"]
		enemy.projectile_count = int(camp_shot["projectile_count"])
		enemy.projectile_speed = float(camp_shot["projectile_speed"])
		enemy.attack_interval = float(camp_shot["interval"])
		enemy.camp_projectile_range = float(camp_shot["range"])
		# Reuse the standard hostile bolt sprite for the camp's ranged attack.
		# (Distinct camp identity comes from the bolt cadence/count + the camp
		# marker/guardian art, not a separate projectile texture.)
		enemy.projectile_sprite = "spit"
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
		enemy.boss_death.connect(_on_boss_death)
	enemies[entity_id] = enemy
	if enemy.is_boss:
		_cached_boss = null
	return enemy


## Per-camp-type projectile profile so each camp reads as distinct:
##  brute    = heavy single slow bolt
##  sentinel = precise fast bolt
##  stalker  = rapid 3-bolt fan
func _camp_projectile_profile(type_id: String) -> Dictionary:
	match type_id:
		"brute":
			return {"projectile_damage": 9.0, "projectile_count": 1, "projectile_speed": 320.0, "interval": 0.9, "range": 340.0}
		"sentinel":
			return {"projectile_damage": 6.0, "projectile_count": 1, "projectile_speed": 440.0, "interval": 0.7, "range": 380.0}
		"stalker":
			return {"projectile_damage": 4.0, "projectile_count": 3, "projectile_speed": 360.0, "interval": 1.1, "range": 300.0}
		_:
			return {"projectile_damage": 7.0, "projectile_count": 1, "projectile_speed": 380.0, "interval": 0.85, "range": 340.0}


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
	SoundDirector.play("explosion", origin)


func _play_sound(sound_id: String) -> void:
	if GameRuntime.is_dedicated_server():
		return
	AudioService.play(sound_id)


func _is_tiny_fodder(enemy: Enemy) -> bool:
	return enemy != null and enemy.type_id == "swarmling"


func _play_landmark_sound(effect_id: String) -> void:
	match effect_id:
		"pulse_wipe":
			_play_sound("sfx_radius")
		"heal_all":
			_play_sound("sfx_heal")
		"freeze_time":
			_play_sound("sfx_shield")
		"speed_surge":
			_play_sound("dash")
		"phase_cloak":
			_play_sound("scan")
		"battle_frenzy":
			_play_sound("charge")
		_:
			_play_sound("scan")


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
		SoundDirector.play("charge", spec.get("origin", Vector2.ZERO))
	var hazard := ArenaHazard.new()
	actors.add_child(hazard)
	hazard.configure(spec)


## Public entry point for player boss-form attacks to emit arena hazards, with the
## same RPC/cosmetic handling as enemy hazards.
func player_hazard_requested(spec: Dictionary) -> void:
	_spawn_arena_hazard(spec)
	if GameRuntime.is_server():
		var remote_spec := spec.duplicate()
		remote_spec["cosmetic"] = true
		for peer_id in registered_remote_peers.keys():
			client_spawn_arena_hazard.rpc_id(peer_id, remote_spec)


func _on_boss_phase_changed(phase: int) -> void:
	var boss := _find_boss()
	var boss_name := "BOSS"
	if boss != null:
		boss_name = str(EnemyType.by_id(boss.type_id).name)
	if not GameRuntime.is_dedicated_server():
		hud.announce_boss_phase(phase, boss_name)
		_shake_cameras(20.0, 0.75)
		_play_world_flash(false)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_boss_phase.rpc_id(peer_id, phase, boss_name)


func _on_boss_death(enemy: Enemy) -> void:
	_last_boss_ring_source = "boss_death"
	# Dramatic screen shake on boss death.
	if not GameRuntime.is_dedicated_server():
		_shake_cameras(24.0, 0.9)
		_play_sound("explosion")
		# Boss-defeat ring sweep + zoom-to-middle: a fire line sweeping across the map
		# (old world outside, new world inside) as every camera pulls back to the centre.
		_play_boss_ring(enemy.global_position)
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_play_sound.rpc_id(peer_id, "explosion")

	# Boss takeover: whoever landed the killing blow "becomes the boss" for a
	# while — boosted stats, boss-form attacks, and (FFA) creeps won't target
	# them. In solo they get to stomp the remaining creeps, in FFA they can
	# rival other heroes until killed or the timer expires.
	if not GameRuntime.is_dedicated_server() and enemy.health.last_damage_source is Player:
		var boss_killer := enemy.health.last_damage_source as Player
		if boss_killer != null and is_instance_valid(boss_killer):
			# Every boss defeated grants the killer the boss form for a while.
			boss_killer.grant_boss_form(enemy.type_id)
			# The KILLING player "takes over" the boss role — a short, strong buff so
			# the moment reads as a power shift, not just a payout.
			_grant_boss_takeover(boss_killer, enemy)

	# Boss-kill reward: a clear "boss defeated" payout on top of the XP orb + boss form.
	# Everyone on the killing team/hero gets a bonus of gold + XP so the boss clear is a
	# felt reward beat before the world transition. The amount scales with the wave so
	# later bosses pay out more.
	if not GameRuntime.is_dedicated_server():
		_grant_boss_kill_reward(enemy)


func _shake_cameras(amplitude: float, duration: float) -> void:
	if GameRuntime.is_dedicated_server():
		return
	for player in players.values():
		if is_instance_valid(player):
			(player as Player).shake_camera(amplitude, duration)


## Boss-kill payout. The killing hero gets the full reward; in team/FFA the other heroes
## on the winning side get a reduced share. Announces a "BOSS DEFEATED" beat on the HUD
## so the moment reads as an event rather than just a big enemy dying.
func _grant_boss_kill_reward(enemy: Enemy) -> void:
	var wave := current_wave
	var bonus_gold := 60 + 20 * maxi(1, wave / 5)
	var bonus_xp := 40 + 15 * maxi(1, wave / 5)
	var killer: Player = null
	if enemy.health != null and enemy.health.last_damage_source is Player:
		killer = enemy.health.last_damage_source as Player
	if not GameRuntime.is_dedicated_server() and hud != null:
		hud.announce_boss_defeated(wave)
	if GameRuntime.is_ffa():
		# FFA: only the killing hero gets the full reward.
		if killer != null and is_instance_valid(killer):
			killer.add_gold(bonus_gold)
			killer.add_xp(bonus_xp)
	elif GameRuntime.is_rift_clash():
		# Team: reward every hero on the winning team.
		if killer != null and is_instance_valid(killer):
			var winning_team := killer.team_id
			for player in players.values():
				if is_instance_valid(player) and (player as Player).team_id == winning_team:
					(player as Player).add_gold(bonus_gold / 2)
					(player as Player).add_xp(bonus_xp / 2)
	else:
		# Solo/co-op: every alive hero gets the full reward.
		for player in players.values():
			if is_instance_valid(player) and not (player as Player).health.is_dead:
				(player as Player).add_gold(bonus_gold)
				(player as Player).add_xp(bonus_xp)


## Boss "takeover": whoever lands the killing blow on the boss inherits its power for a
## short window on top of the existing boss form. Big damage + damage-taken-reduction +
## speed buff, then decays over time. The FIRST boss of each world (wave % 15 == 5)
## gives the marquee takeover moment — bigger multiplier, longer duration.
func _grant_boss_takeover(killer: Player, enemy: Enemy) -> void:
	var is_first_of_world := (current_wave % WaveDirector.WAVES_PER_WORLD) == WaveDirector.BOSS_WAVE_INTERVAL
	var dmg_mult := 1.9 if is_first_of_world else 1.4
	var taken_mult := 0.55 if is_first_of_world else 0.75
	var duration := 12.0 if is_first_of_world else 8.0
	killer.damage_dealt_multiplier *= dmg_mult
	killer.health.damage_taken_multiplier *= taken_mult
	killer.movement_speed *= 1.15
	# Play the takeover chime so the buff is felt in the ears too.
	_play_sound("boss_takeover")
	if hud != null:
		hud.announce_takeover(is_first_of_world)
	# Roll back after duration.
	if not GameRuntime.is_dedicated_server():
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if not is_instance_valid(killer):
				return
			killer.damage_dealt_multiplier /= dmg_mult
			killer.health.damage_taken_multiplier /= taken_mult
			killer.movement_speed /= 1.15
		)


var _cached_boss: Enemy = null

## Boss identity only changes when a boss dies or spawns — both fire enemy_killed /
## enemy_spawned — so we cache the lookup and re-scan the pool only on those events
## instead of every physics frame (this ran in main.gd's hot _physics_process).
func _find_boss() -> Enemy:
	if _cached_boss != null and is_instance_valid(_cached_boss) and not _cached_boss.health.is_dead:
		return _cached_boss
	_cached_boss = null
	for enemy in enemies.values():
		if is_instance_valid(enemy) and (enemy as Enemy).is_boss and not (enemy as Enemy).health.is_dead:
			_cached_boss = enemy as Enemy
			return _cached_boss
	return null


## Boss identity only changes when a boss dies or spawns, so _find_boss caches its
## pool scan and only re-runs on these events instead of every physics frame.
func _on_boss_relevant_enemy_event(_enemy: Node) -> void:
	_cached_boss = null


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
		SoundDirector.play("enemy_shoot", origin)


func spawn_player_projectile(origin: Vector2, direction: Vector2, source: Player) -> void:
	if source == null:
		return
	var projectile := projectile_scene.instantiate() as SurvivorProjectile
	projectile.global_position = origin
	actors.add_child(projectile)
	projectile.configure(direction, source.weapon_damage, 520.0, false, false, "spark")


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
	if enemy.is_boss:
		_cached_boss = null
	_spawn_xp_orb(enemy.global_position, enemy.xp_value)
	_spawn_corpse(enemy)
	# Global gold-drop boost so items stay affordable through the late game.
	var drop_amount := maxi(1, int(round(float(enemy.gold_value) * GOLD_DROP_BOOST)))
	if GameRuntime.is_ffa() and enemy.health.last_damage_source is Player:
		var creep_killer := enemy.health.last_damage_source as Player
		creep_killer.add_gold(maxi(1, int(round(float(drop_amount) * 1.5))))
		creep_killer.creep_kills += 1
	elif GameRuntime.is_rift_clash() and enemy.health.last_damage_source is Player:
		var killer := enemy.health.last_damage_source as Player
		killer.creep_kills += 1
		if killer.team_id != "":
			_award_gold_to_team(killer.team_id, drop_amount)
	else:
		_award_gold(drop_amount)
		if enemy.health.last_damage_source is Player:
			var solo_killer := enemy.health.last_damage_source as Player
			solo_killer.creep_kills += 1
	if not _is_tiny_fodder(enemy):
		_play_sound("enemy_death")
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_play_sound.rpc_id(peer_id, "enemy_death")


## Drop a tiny flattened corpse at the kill site. Purely cosmetic; skipped on a
## dedicated server (no rendering), when the enemy has no sprite texture yet, or
## when the live corpse cap is already reached.
func _spawn_corpse(enemy: Enemy) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var sprite_node := enemy.get("sprite") as Sprite2D
	var texture: Texture2D = null
	if sprite_node != null and is_instance_valid(sprite_node):
		texture = sprite_node.texture
	if texture == null:
		texture = SpriteLibrary.texture_for(enemy.type_id)
	if texture == null:
		return
	if get_tree().get_nodes_in_group("corpses").size() >= 60:
		return
	var corpse: Node2D = _CorpseScript.new()
	corpse.global_position = enemy.global_position
	var base_scale := sprite_node.scale if sprite_node != null and is_instance_valid(sprite_node) else Vector2.ONE
	corpse.configure(texture, base_scale, enemy.fill_color)
	actors.add_child(corpse)


## Landmark effects run on the session authority: dedicated/listen server, or OFFLINE solo.
## Clients never simulate the wipe/freeze/heal; they only play the HUD flash RPC.
func _landmark_is_authority() -> bool:
	return GameRuntime.is_server() or GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE


## Rebind after arena rebuild: `set_world` frees the previous landmark nodes, so the
## `_ready` connections would otherwise point at freed instances and drop every trigger.
func _bind_landmarks() -> void:
	if not (arena is Arena):
		return
	for landmark in (arena as Arena).landmarks:
		if not is_instance_valid(landmark):
			continue
		if not landmark.triggered.is_connected(_on_landmark_triggered):
			landmark.triggered.connect(_on_landmark_triggered)


## Signal contract: ArenaLandmark.triggered(position) — look the landmark up by distance.
func _on_landmark_triggered(trigger_position: Vector2) -> void:
	var landmark := _landmark_at(trigger_position)
	if landmark == null:
		return
	if not _landmark_is_authority():
		return
	var now := Time.get_ticks_msec()
	var cooldown_key := landmark.sprite_name if not landmark.sprite_name.is_empty() else str(landmark.effect_id)
	if _landmark_last_trigger.has(cooldown_key) and int(_landmark_last_trigger[cooldown_key]) + int(LANDMARK_GLOBAL_COOLDOWN * 1000) > now:
		_landmark_flash("%s recharging…" % _effect_display(landmark), Color("c0c0c0"))
		return
	_landmark_last_trigger[cooldown_key] = now
	print("[landmark] triggered: %s at %s" % [landmark.effect_id, landmark.global_position])
	_play_landmark_sound(str(landmark.effect_id))
	match landmark.effect_id:
		"pulse_wipe":
			_landmark_pulse_wipe(landmark)
		"freeze_time":
			_landmark_freeze_time(landmark)
		"heal_all":
			_landmark_heal_all(landmark)
		"speed_surge":
			_landmark_speed_surge(landmark)
		"phase_cloak":
			_landmark_phase_cloak(landmark)
		"battle_frenzy":
			_landmark_battle_frenzy(landmark)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_landmark_pulse.rpc_id(peer_id, landmark.global_position, str(landmark.effect_id))


## Find the landmark nearest a fired position; Arena keeps the canonical `landmarks` list.
func _landmark_at(trigger_position: Vector2) -> ArenaLandmark:
	if not (arena is Arena):
		return null
	var best: ArenaLandmark = null
	var best_distance := INF
	for landmark in (arena as Arena).landmarks:
		if not is_instance_valid(landmark):
			continue
		var distance := landmark.global_position.distance_to(trigger_position)
		if distance < best_distance:
			best_distance = distance
			best = landmark
	return best


func _landmark_theme(landmark: ArenaLandmark) -> Dictionary:
	var meters := int(landmark.effect_radius / 10.0)
	var seconds := int(landmark.effect_arg)
	var amount := int(landmark.effect_arg)
	match landmark.sprite_name:
		"tw_factory_landmark_pylon":
			return {"outer": Color("ff5a18"), "mid": Color("ff9a30"), "inner": Color("ffe0a0"), "flash": Color("ff7a28"), "text": "Molten pulse! Minions wiped — elites lose %d%% HP." % int(landmark.effect_arg)}
		"tw_factory_landmark_vat":
			return {"outer": Color("b8dce4"), "mid": Color("e0f4f8"), "inner": Color("ffffff"), "flash": Color("c8e8ee"), "text": "Steam vent — everyone healed +%d HP" % amount}
		"tw_factory_landmark_bay":
			return {"outer": Color("6a90b8"), "mid": Color("a8c8e0"), "inner": Color("e0eef8"), "flash": Color("7aa0c8"), "text": "Quench lock — frozen %ds, extra damage while locked" % seconds}
		"tw_volcano_landmark_arch":
			return {"outer": Color("c45cff"), "mid": Color("e090ff"), "inner": Color("ffe0ff"), "flash": Color("d070ff"), "text": "Rift pulse! Minions within %dm wiped." % meters}
		"tw_volcano_landmark_shrine":
			return {"outer": Color("ff7a40"), "mid": Color("ffb070"), "inner": Color("ffe0b0"), "flash": Color("ff8a48"), "text": "Ember shrine — everyone healed +%d HP" % amount}
		"tw_volcano_landmark_well":
			return {"outer": Color("8ec8ff"), "mid": Color("c8e4ff"), "inner": Color("f0f8ff"), "flash": Color("a0d0ff"), "text": "Obsidian font — frozen %ds, extra damage while locked" % seconds}
		"tw_docks_landmark_bell":
			return {"outer": Color("8fd84a"), "mid": Color("c8f080"), "inner": Color("f0ffe0"), "flash": Color("a0e050"), "text": "Verdant bell! Minions within %dm wiped." % meters}
		"tw_grass_landmark_bell":
			return {"outer": Color("8fd84a"), "mid": Color("c8f080"), "inner": Color("f0ffe0"), "flash": Color("a0e050"), "text": "Grove bell! Minions within %dm wiped." % meters}
		"tw_grass_landmark_pool":
			return {"outer": Color("70d070"), "mid": Color("d0ffd0"), "inner": Color("ffffff"), "flash": Color("70d070"), "text": "Wild spring — everyone healed +%d HP" % amount}
		"tw_grass_landmark_stone":
			return {"outer": Color("6db86a"), "mid": Color("a0d898"), "inner": Color("e0f8d8"), "flash": Color("7cc878"), "text": "Root stone — frozen %ds, extra damage while locked" % seconds}
		"tw_docks_landmark_pool":
			if landmark._hint == "Tide Font":
				return {"outer": Color("6ec8ff"), "mid": Color("b0e0ff"), "inner": Color("e8f8ff"), "flash": Color("80d0ff"), "text": "Tide font — everyone healed +%d HP" % amount}
			return {"outer": Color("5ec8c0"), "mid": Color("90e8e0"), "inner": Color("d8ffff"), "flash": Color("70d8d0"), "text": "Mana spring — everyone healed +%d HP" % amount}
		"tw_ice_landmark_hollow":
			if landmark.effect_id == "heal_all":
				return {"outer": Color("a8e0ff"), "mid": Color("d0f0ff"), "inner": Color("f4fbff"), "flash": Color("b8e8ff"), "text": "Frost well — everyone healed +%d HP" % amount}
			return {"outer": Color("6db86a"), "mid": Color("a0d898"), "inner": Color("e0f8d8"), "flash": Color("7cc878"), "text": "Vines bind — enemies stunned for %ds" % seconds}
		"tw_ice_landmark_glade":
			return {"outer": Color("80c0ff"), "mid": Color("cfe6ff"), "inner": Color("f0f8ff"), "flash": Color("90c8ff"), "text": "Frozen crystal — frozen %ds, extra damage while locked" % seconds}
		"tw_docks_landmark_lighthouse":
			return {"outer": Color("f4c44a"), "mid": Color("ffe080"), "inner": Color("fff8d0"), "flash": Color("ffd060"), "text": "Storm pulse! Minions within %dm wiped." % meters}
		"tw_factory_landmark_turbine":
			return {"outer": Color("ffe066"), "mid": Color("fff2b0"), "inner": Color("ffffff"), "flash": Color("ffe066"), "text": "Turbo manifold — double speed for %ds!" % seconds}
		"tw_volcano_landmark_totem":
			return {"outer": Color("ff3020"), "mid": Color("ff8060"), "inner": Color("ffd0c0"), "flash": Color("ff3020"), "text": "Ember fury — double attack speed and damage for %ds!" % seconds}
		"tw_grass_landmark_thicket":
			return {"outer": Color("9a70ff"), "mid": Color("c8b0ff"), "inner": Color("f0e8ff"), "flash": Color("9a70ff"), "text": "Whispering thicket — cloaked for %ds, nearby foes lose your trail!" % seconds}
		"tw_ice_landmark_rune":
			return {"outer": Color("60e0ff"), "mid": Color("b0f0ff"), "inner": Color("ffffff"), "flash": Color("60e0ff"), "text": "Glacial rush — double speed for %ds!" % seconds}
	match landmark.effect_id:
		"pulse_wipe":
			return {"outer": Color("ffd060"), "mid": Color("fff0b8"), "inner": Color("ffffff"), "flash": Color("ffd060"), "text": "Pulse! Minions within %dm wiped." % meters}
		"freeze_time":
			return {"outer": Color("80c0ff"), "mid": Color("cfe6ff"), "inner": Color("ffffff"), "flash": Color("80c0ff"), "text": "Frozen %ds — extra damage while locked" % seconds}
		"heal_all":
			return {"outer": Color("70d070"), "mid": Color("d0ffd0"), "inner": Color("ffffff"), "flash": Color("70d070"), "text": "Blessing — everyone healed +%d HP" % amount}
		"speed_surge":
			return {"outer": Color("ffe066"), "mid": Color("fff2b0"), "inner": Color("ffffff"), "flash": Color("ffe066"), "text": "Speed surge — double speed for %ds!" % seconds}
		"phase_cloak":
			return {"outer": Color("9a70ff"), "mid": Color("c8b0ff"), "inner": Color("f0e8ff"), "flash": Color("9a70ff"), "text": "Phase cloak — untraceable for %ds!" % seconds}
		"battle_frenzy":
			return {"outer": Color("ff3020"), "mid": Color("ff8060"), "inner": Color("ffd0c0"), "flash": Color("ff3020"), "text": "Battle frenzy — double attack speed and damage for %ds!" % seconds}
		_:
			return {"outer": Color("e8e8e8"), "mid": Color("ffffff"), "inner": Color("ffffff"), "flash": Color("e8e8e8"), "text": "Landmark awakened"}


func _landmark_pulse_wipe(landmark: ArenaLandmark) -> void:
	var origin := landmark.global_position
	var kill_radius := landmark.effect_radius
	var boss_pct := clampf(landmark.effect_arg, 8.0, 35.0) / 100.0
	var theme := _landmark_theme(landmark)
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		if enemy.is_boss:
			# Pads sit on the rim; freeze holds the boss in the crater. Boss chunk always lands.
			var chunk := enemy.health.max_health * boss_pct
			if enemy.has_method("vulnerability_multiplier"):
				chunk *= enemy.vulnerability_multiplier()
			enemy.health.take_damage(chunk, self)
			continue
		if enemy.global_position.distance_to(origin) > kill_radius:
			continue
		enemy.health.take_damage(enemy.health.max_health * 4.0 + 9999.0, self)
	_play_landmark_ring(origin, kill_radius, theme["outer"], 72.0, 1.1)
	_play_landmark_ring(origin, kill_radius * 0.66, theme["mid"], 60.0, 0.9, 0.12)
	_play_landmark_ring(origin, kill_radius * 0.38, theme["inner"], 48.0, 0.7, 0.24)
	_landmark_flash(str(theme["text"]), theme["flash"])


func _landmark_freeze_time(landmark: ArenaLandmark) -> void:
	var duration := maxf(8.0, landmark.effect_arg)
	var theme := _landmark_theme(landmark)
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		if enemy.has_method("apply_mark"):
			enemy.apply_mark(0.75, duration)
		if enemy.has_method("apply_movement_lock"):
			enemy.apply_movement_lock(duration)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		if enemy.has_method("set_ai_paused"):
			enemy.set_ai_paused(true)
		if enemy.has_method("set_frozen_visual"):
			enemy.set_frozen_visual(true)
	_play_landmark_ring(landmark.global_position, 640.0, theme["outer"], 70.0, 1.4)
	_play_landmark_ring(landmark.global_position, 380.0, theme["mid"], 56.0, 1.0, 0.15)
	_landmark_flash(str(theme["text"]), theme["flash"])
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
		# apply_mark/apply_movement_lock above set their timers for `duration` seconds, but
		# those timers only tick inside the _physics_process we just disabled — so they never
		# counted down while frozen and would otherwise take a second full `duration` to
		# expire now that processing is back on, leaving the enemy rooted in place (unable to
		# close on the player) for roughly double the advertised freeze length. Clear them now
		# so the root/mark end exactly when the freeze visually ends.
		if enemy.has_method("clear_movement_lock"):
			enemy.clear_movement_lock()
	_landmark_flash("Time resumes.", theme["inner"])


func _landmark_heal_all(landmark: ArenaLandmark) -> void:
	var amount := landmark.effect_arg
	var theme := _landmark_theme(landmark)
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			(player as Player).health.heal(amount)
			# Brief absorb so a clutch pad-fire isn't immediately undone by the pack
			# that chased you onto the vent.
			(player as Player).health.add_shield(maxf(28.0, amount * 0.45), 1.35)
			_play_landmark_ring((player as Player).global_position, 160.0, theme["mid"], 40.0, 0.8)
	var origin := landmark.global_position
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		var away := enemy.global_position - origin
		if away.length() > 380.0:
			continue
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(away.normalized() * 520.0)
	_play_landmark_ring(landmark.global_position, 480.0, theme["outer"], 66.0, 1.3)
	_play_landmark_ring(landmark.global_position, 280.0, theme["inner"], 52.0, 0.9, 0.15)
	_landmark_flash(str(theme["text"]), theme["flash"])


## Players standing inside the pad when it fires — the new outer buff landmarks bless
## whoever charged them rather than the whole party (unlike heal_all above).
func _players_at_landmark(landmark: ArenaLandmark) -> Array:
	var found: Array = []
	for player in players.values():
		if not is_instance_valid(player) or not (player as Player).active or (player as Player).health.is_dead:
			continue
		if (player as Player).global_position.distance_to(landmark.global_position) <= ArenaLandmark.STAND_RADIUS:
			found.append(player)
	return found


func _landmark_speed_surge(landmark: ArenaLandmark) -> void:
	var duration := maxf(6.0, landmark.effect_arg)
	var theme := _landmark_theme(landmark)
	for player in _players_at_landmark(landmark):
		(player as Player)._apply_ability_buff({"movement_speed_mult": 2.0}, duration)
		_play_landmark_ring((player as Player).global_position, 150.0, theme["mid"], 42.0, 0.9)
	_play_landmark_ring(landmark.global_position, landmark.effect_radius, theme["outer"], 64.0, 1.2)
	_play_landmark_ring(landmark.global_position, landmark.effect_radius * 0.55, theme["inner"], 48.0, 0.9, 0.15)
	_landmark_flash(str(theme["text"]), theme["flash"])


func _landmark_phase_cloak(landmark: ArenaLandmark) -> void:
	var duration := maxf(6.0, landmark.effect_arg)
	var theme := _landmark_theme(landmark)
	for player in _players_at_landmark(landmark):
		(player as Player).apply_phase_cloak(duration)
		_play_landmark_ring((player as Player).global_position, 150.0, theme["mid"], 42.0, 0.9)
	_play_landmark_ring(landmark.global_position, landmark.effect_radius, theme["outer"], 64.0, 1.2)
	_landmark_flash(str(theme["text"]), theme["flash"])


func _landmark_battle_frenzy(landmark: ArenaLandmark) -> void:
	var duration := maxf(15.0, landmark.effect_arg)
	var theme := _landmark_theme(landmark)
	for player in _players_at_landmark(landmark):
		(player as Player)._apply_ability_buff({"damage_dealt_mult": 2.0, "attack_interval_mult": 0.5}, duration)
		_play_landmark_ring((player as Player).global_position, 150.0, theme["mid"], 42.0, 0.9)
	_play_landmark_ring(landmark.global_position, landmark.effect_radius, theme["outer"], 64.0, 1.2)
	_play_landmark_ring(landmark.global_position, landmark.effect_radius * 0.55, theme["inner"], 48.0, 0.9, 0.15)
	_landmark_flash(str(theme["text"]), theme["flash"])


func _effect_display(landmark: ArenaLandmark) -> String:
	if landmark != null and not landmark._hint.is_empty():
		return landmark._hint
	return "Landmark"


## HUD no longer has flash_combat_text; reuse the debut banner so solo/host still get a beat.
## HUD banner for a recruited neutral creep joining the local player's team.
## Called by recruit_areas.gd when an area's quest completes.
func flash_recruit_joined(area_name: String, creature: String, accent: Color) -> void:
	if hud == null:
		return
	if hud.has_method("announce_recruit_joined"):
		hud.call("announce_recruit_joined", area_name, creature, accent)


func _landmark_flash(text: String, color: Color) -> void:
	if hud == null:
		return
	if hud.has_method("flash_combat_text"):
		hud.call("flash_combat_text", text, color)
		return
	var banner: Label = hud.debut_banner
	if banner == null:
		banner = hud.theme_banner
	if banner == null:
		return
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_font_size_override("font_size", 28)
	banner.visible = true
	banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var fade := create_tween()
	fade.tween_property(banner, "modulate:a", 1.0, 0.2)
	fade.tween_interval(2.2)
	fade.tween_property(banner, "modulate:a", 0.0, 0.4)
	fade.tween_callback(func() -> void: banner.visible = false)


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
	elif style == PlayerClass.EffectStyle.TELEPORT:
		effect.lifetime = 0.42
	# Per-hero themed colors for teleport blinks (falls back to class colors when absent).
	var kit_style := KitFxLibrary.kit_visual("%s_%s" % [class_id, str(class_data.get("secondary", ""))])
	if not kit_style.is_empty():
		var primary := str(kit_style.get("primary_color", ""))
		var secondary := str(kit_style.get("secondary_color", ""))
		if primary != "":
			effect.main_color = Color(primary)
		if secondary != "":
			effect.chain_color = Color(secondary)
		effect.ribbon_count = int(kit_style.get("ribbon_count", effect.ribbon_count))
		effect.pulse_count = int(kit_style.get("pulse_count", effect.pulse_count))
		var style_tag := str(kit_style.get("style", ""))
		if style_tag != "":
			effect.style_tag = style_tag
	effect.points = points
	# Dedup: cap concurrent secondary FX per hero so rapid-cast secondaries don't stack.
	_add_vector_fx(effect, "sec_" + class_id)
	SoundDirector.play("cast_%s" % class_id, points[0] if points.size() > 0 else null)


func _spawn_support_wall(points: PackedVector2Array, duration: float, color: Color) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var wall := SupportWall.new()
	actors.add_child(wall)
	wall.configure(points, duration, null, color)
	SoundDirector.play("sfx_force", points[0] if points.size() > 0 else null)


func _play_staff_effect(effect_kind: String, points: PackedVector2Array) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var class_data := PlayerClass.by_id(effect_kind)
	var effect := lightning_scene.instantiate() as LightningEffect
	effect.style = class_data.effect_style
	effect.main_color = Color(class_data.effect_color)
	effect.chain_color = Color(class_data.effect_secondary)
	if effect.style == PlayerClass.EffectStyle.BLAST:
		effect.lifetime = 0.28
		effect.draw_mode = "simple_circle"
	effect.points = points
	add_child(effect)
	SoundDirector.play("attack_%s" % effect_kind, points[0] if points.size() > 0 else null)


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
	# Robot — kit Q/E/R
	"tobor_steam_keg": PlayerClass.EffectStyle.BLAST,
	"tobor_spider_mines": PlayerClass.EffectStyle.BURST,
	"tobor_steam_turret": PlayerClass.EffectStyle.BURST,
	"tobor_energy_field": PlayerClass.EffectStyle.BURST,
	"arclight_blast_of_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_chain_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_thundergods_wrath": PlayerClass.EffectStyle.BURST,
	"bulwark_fissure": PlayerClass.EffectStyle.BLAST,
	"bulwark_heavyweight": PlayerClass.EffectStyle.BURST,
	"bulwark_echo_slam": PlayerClass.EffectStyle.BURST,
	"warden_tongue_tied": PlayerClass.EffectStyle.BOLT,
	"warden_thorn_volley": PlayerClass.EffectStyle.BOLT,
	"warden_life_drain": PlayerClass.EffectStyle.WAVE,
	"warden_voodoo_wards": PlayerClass.EffectStyle.BURST,
	# Caldera
	"frostbinder_ice_spike": PlayerClass.EffectStyle.BOLT,
	"frostbinder_frost_nova": PlayerClass.EffectStyle.BURST,
	"frostbinder_glacial_cone": PlayerClass.EffectStyle.ARC,
	"cinder_dragon_fire": PlayerClass.EffectStyle.BLAST,
	"cinder_fiery_assault": PlayerClass.EffectStyle.BURST,
	"cinder_pillar_of_flame": PlayerClass.EffectStyle.BURST,
	"pyra_sticky_bomb": PlayerClass.EffectStyle.BLAST,
	"pyra_boom_dust": PlayerClass.EffectStyle.BURST,
	"pyra_air_strike": PlayerClass.EffectStyle.BURST,
	"slag_boulder_hurl": PlayerClass.EffectStyle.BLAST,
	"slag_volcanic_touch": PlayerClass.EffectStyle.BURST,
	"slag_eruption": PlayerClass.EffectStyle.BURST,
	"ember_entangle": PlayerClass.EffectStyle.WAVE,
	"ember_firebomb": PlayerClass.EffectStyle.BLAST,
	"ember_unbreakable": PlayerClass.EffectStyle.BURST,
	# Wilds
	"thorn_poison_spray": PlayerClass.EffectStyle.ARC,
	"thorn_toxin_ward": PlayerClass.EffectStyle.BURST,
	"thorn_toxicity": PlayerClass.EffectStyle.WAVE,
	"thorn_poison_burst": PlayerClass.EffectStyle.BURST,
	"willow_forsaken_shot": PlayerClass.EffectStyle.BOLT,
	"willow_wall_of_roots": PlayerClass.EffectStyle.BURST,
	"stump_natures_rally": PlayerClass.EffectStyle.BURST,
	"stump_overgrowth": PlayerClass.EffectStyle.BURST,
	"sage_petal_dance": PlayerClass.EffectStyle.ARC,
	"sage_volatile_pod": PlayerClass.EffectStyle.BLAST,
	"sage_charm": PlayerClass.EffectStyle.BURST,
	# Storm Court
	"volt_gust": PlayerClass.EffectStyle.ARC,
	"volt_plasma_bolt": PlayerClass.EffectStyle.BOLT,
	"volt_typhoon": PlayerClass.EffectStyle.BURST,
	"nebula_arcane_bolt": PlayerClass.EffectStyle.BOLT,
	"nebula_curse_of_ages": PlayerClass.EffectStyle.BURST,
	"nebula_chronofield": PlayerClass.EffectStyle.BURST,
	"astral_ghastly_touch": PlayerClass.EffectStyle.BOLT,
	"astral_moonfall": PlayerClass.EffectStyle.BURST,
	"astral_as_one": PlayerClass.EffectStyle.BURST,
	"rime_ice_imprisonment": PlayerClass.EffectStyle.BURST,
	"rime_chilling_touch": PlayerClass.EffectStyle.BURST,
	"rime_freezing_field": PlayerClass.EffectStyle.BURST,
	# Pool aliases (still castable; keep vector styles so they do not share a generic disc)
	"arclight_electric_field": PlayerClass.EffectStyle.BURST,
	"bulwark_enrage": PlayerClass.EffectStyle.WAVE,
	"warden_cursed_ground": PlayerClass.EffectStyle.BURST,
	"cinder_whirling_flame": PlayerClass.EffectStyle.TELEPORT,
	"cinder_blazing_strike": PlayerClass.EffectStyle.BLAST,
	"cinder_blazing_pillar": PlayerClass.EffectStyle.BURST,
	"pyra_bombardment": PlayerClass.EffectStyle.BURST,
	"slag_steam_bath": PlayerClass.EffectStyle.BURST,
	"ember_healing_wave": PlayerClass.EffectStyle.WAVE,
	"ember_storm_cloud": PlayerClass.EffectStyle.BURST,
	"willow_volley": PlayerClass.EffectStyle.ARC,
	"willow_strangling_vines": PlayerClass.EffectStyle.WAVE,
	"stump_rally": PlayerClass.EffectStyle.BURST,
	"stump_camouflage": PlayerClass.EffectStyle.WAVE,
	"stump_natures_veil": PlayerClass.EffectStyle.BURST,
	"sage_grace": PlayerClass.EffectStyle.WAVE,
	"sage_grace_of_the_nymph": PlayerClass.EffectStyle.WAVE,
	"sage_nymphoras_kiss": PlayerClass.EffectStyle.BOLT,
	"volt_wind_shield": PlayerClass.EffectStyle.BURST,
	"volt_wind_control": PlayerClass.EffectStyle.WAVE,
	"nebula_time_shift": PlayerClass.EffectStyle.TELEPORT,
	"nebula_rewind": PlayerClass.EffectStyle.WAVE,
	"nebula_chronosphere": PlayerClass.EffectStyle.BURST,
	"astral_essence_link": PlayerClass.EffectStyle.BURST,
	"astral_ward_of_light": PlayerClass.EffectStyle.BURST,
	"astral_guardian_angel": PlayerClass.EffectStyle.WAVE,
	"astral_spirit_bond": PlayerClass.EffectStyle.WAVE,
	"rime_glacier_blast": PlayerClass.EffectStyle.BURST,
	"rime_absolute_zero": PlayerClass.EffectStyle.BURST,
	# Dash/blink archetypes → themed TELEPORT blink (vanish ring, motion streak, appear ring)
	"arclight_ball_lightning": PlayerClass.EffectStyle.TELEPORT,
	"bulwark_iron_charge": PlayerClass.EffectStyle.TELEPORT,
	"frostbinder_rime_barrage": PlayerClass.EffectStyle.TELEPORT,
	"pyra_molten_charge": PlayerClass.EffectStyle.TELEPORT,
	"slag_magma_charge": PlayerClass.EffectStyle.TELEPORT,
	"ember_phoenix_dash": PlayerClass.EffectStyle.TELEPORT,
	"thorn_bramble_dash": PlayerClass.EffectStyle.TELEPORT,
	"willow_swift_strike": PlayerClass.EffectStyle.TELEPORT,
	"stump_root_charge": PlayerClass.EffectStyle.TELEPORT,
	"volt_lightning_lunge": PlayerClass.EffectStyle.TELEPORT,
	"rime_cold_rush": PlayerClass.EffectStyle.TELEPORT,
	"nebula_time_shift_blink": PlayerClass.EffectStyle.TELEPORT,
}

## Set of ability IDs that are a hero's ultimate (kit_r). These get a 2x longer vector
## VFX lifetime so the big finisher reads heavier. Built lazily from PlayerClass so new
## heroes' ults are picked up automatically.
var _ULT_ABILITY_IDS: Dictionary = {}

func _build_ult_ability_ids() -> void:
	if not _ULT_ABILITY_IDS.is_empty():
		return
	for class_def in PlayerClass.CLASSES:
		var r_id := str(class_def.get("kit_r", ""))
		if not r_id.is_empty():
			_ULT_ABILITY_IDS[r_id] = true


## Add a vector LightningEffect while enforcing the per-ability dedup cap. Returns the
## node so callers can still configure it; if the cap was hit, the oldest live effect for
## that same key is freed early so the new cast reads cleanly instead of stacking.
func _add_vector_fx(flash: LightningEffect, key: String) -> LightningEffect:
	if flash == null:
		return null
	# Drop any stale entries (already queue_freed / no longer in tree).
	_active_vector_fx.erase(null)
	var same_key: Array = []
	for e in _active_vector_fx:
		if e != null and is_instance_valid(e) and e.get_meta("fx_key", "") == key:
			same_key.append(e)
	# Cap: free the oldest over-cap copies before adding the new one.
	while same_key.size() >= _MAX_CONCURRENT_VECTOR_FX_PER_ABILITY:
		var oldest: LightningEffect = same_key.pop_front()
		_active_vector_fx.erase(oldest)
		if is_instance_valid(oldest):
			oldest.queue_free()
	flash.set_meta("fx_key", key)
	_active_vector_fx.append(flash)
	add_child(flash)
	flash.tree_exited.connect(_on_vector_fx_exited.bind(flash))
	return flash


func _on_vector_fx_exited(node: Node) -> void:
	_active_vector_fx.erase(node)


## Cast animation for Pjotr-mode abilities. Pixel-art layered on vector flash unless the
## ability is in VECTOR_ONLY_KIT_IDS (HoN-faithful robot heroes) — those go pure vector.
func _play_ability_effect(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	_build_ult_ability_ids()
	print("[main] _play_ability_effect %s" % ability_id)
	if GameRuntime.is_dedicated_server() or GameRuntime.is_classic():
		return
	var class_prefix := ability_id.split("_")[0]
	var class_data := PlayerClass.by_id(class_prefix)
	var vector_only := VECTOR_ONLY_KIT_IDS.has(ability_id)
	# Kit-visual styling (HoN-faithful heroes / kit-first abilities) overrides hero defaults
	# when an entry exists — falls back to class colors otherwise so everything still renders.
	var kit_style := KitFxLibrary.kit_visual(ability_id)
	var primary_color := Color(class_data.effect_color)
	var secondary_color := Color(class_data.effect_secondary)
	if not kit_style.is_empty():
		primary_color = Color(str(kit_style.get("primary_color", class_data.effect_color)))
		secondary_color = Color(str(kit_style.get("secondary_color", class_data.effect_secondary)))
	if ability_id != "stump_overgrowth":
		var flash := lightning_scene.instantiate() as LightningEffect
		flash.style = VECTOR_ONLY_KIT_IDS.get(ability_id, effect_style)
		flash.main_color = primary_color
		flash.chain_color = secondary_color
		# BLAST shatter is a short pop; BURST rings (Energy Field) can linger a beat longer.
		var is_ult := _ULT_ABILITY_IDS.has(ability_id)
		var lifetime_scale := 2.0 if is_ult else 1.0
		if flash.style == PlayerClass.EffectStyle.BLAST:
			flash.lifetime = 0.22 * lifetime_scale
		elif flash.style == PlayerClass.EffectStyle.BURST:
			flash.lifetime = clampf(0.28 + (points[1].x if points.size() >= 2 else 80.0) / 1400.0, 0.28, 0.55) * lifetime_scale
		elif flash.style == PlayerClass.EffectStyle.TELEPORT:
			# Blink duration scales with the travel distance so long dashes feel weightier.
			# A dash is a *move*, not a nuke — keep it snappy; don't double it.
			var dist := 0.0
			if points.size() >= 2 and points[1] is Vector2:
				dist = points[0].distance_to(points[1])
			flash.lifetime = clampf(0.28 + dist / 1600.0, 0.28, 0.52)
		else:
			flash.lifetime = clampf(0.14 + (points[1].x if points.size() >= 2 else 80.0) / 900.0, 0.14, 0.42) * lifetime_scale
		flash.points = points
		KitFxLibrary.apply_to_lightning(flash, ability_id)
		_add_vector_fx(flash, ability_id)
		if not vector_only:
			var vfx := ability_vfx_scene.instantiate() as AbilityVfx
			vfx.configure(ability_id, effect_style, points)
			add_child(vfx)
	SoundDirector.play_ability(ability_id, points[0] if points.size() > 0 else null)


func _on_player_died(_peer_id: int) -> void:
	if GameRuntime.is_ffa():
		_on_ffa_player_died(_peer_id)
		return
	if GameRuntime.is_rift_clash() and GameRuntime.is_server():
		_check_team_eliminations()
	if _all_players_dead():
		game_over = true
		_set_ghosts_game_over(true)
		RunSave.clear()
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
	if not GameRuntime.is_server() and GameRuntime.mode != GameRuntime.RuntimeMode.OFFLINE:
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
	_set_ghosts_game_over(true)
	RunSave.clear()
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


## Mixed ability + stat choices from UpgradeCatalog.
func _offer_next_upgrade(peer_id: int) -> void:
	if pending_upgrades.has(peer_id) or pending_ability_offers.has(peer_id):
		return
	if int(queued_upgrade_choices.get(peer_id, 0)) <= 0:
		return
	var leveled_player := players.get(peer_id) as Player
	if leveled_player == null:
		return
	var upgrade_ids := PlayerClass.random_upgrade_ids(
		leveled_player.class_id, 4, leveled_player.known_abilities, leveled_player.level,
		leveled_player.taken_upgrades
	)
	if upgrade_ids.is_empty():
		leveled_player.apply_fallback_bonus()
		_advance_offer(peer_id)
		return
	pending_upgrades[peer_id] = upgrade_ids
	if leveled_player.is_cpu() or _selftest_active():
		_apply_upgrade_choice(peer_id, str(upgrade_ids[0]))
		return
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE or peer_id == 1:
		hud.show_upgrade_ids(players[peer_id], upgrade_ids, GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE)
	else:
		client_offer_upgrades.rpc_id(peer_id, upgrade_ids)


func _offer_stat_turn(peer_id: int, leveled_player: Player) -> void:
	var upgrade_ids := PlayerClass.random_upgrade_ids(leveled_player.class_id)
	if upgrade_ids.is_empty():
		_advance_offer(peer_id)
		return
	pending_upgrades[peer_id] = upgrade_ids
	if leveled_player.is_cpu() or _selftest_active():
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
	if leveled_player.is_cpu() or _selftest_active():
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


func _matching_pending_upgrade(peer_id: int, upgrade_id: String) -> String:
	var offered: Array = pending_upgrades.get(peer_id, [])
	if upgrade_id in offered:
		return upgrade_id
	var ability_id := UpgradeCatalog.ability_id_from(upgrade_id)
	var prefixed := "ability:" + ability_id
	if prefixed in offered:
		return prefixed
	if ability_id in offered:
		return ability_id
	return ""


## Mirror a locally-chosen stat upgrade into the HUD so its stats panel can list it.
func _hud_track_upgrade(upgrade_id: String) -> void:
	if hud != null and hud.has_method("record_upgrade"):
		hud.record_upgrade(upgrade_id)


func _apply_upgrade_choice(peer_id: int, upgrade_id: String) -> void:
	var token := _matching_pending_upgrade(peer_id, upgrade_id)
	var player := players.get(peer_id) as Player
	if player == null or token.is_empty():
		return
	if UpgradeCatalog.is_ability_token(token):
		_learn_or_rank_ability(player, UpgradeCatalog.ability_id_from(token))
	else:
		player.apply_upgrade(token)
		if token not in _taken_upgrades:
			_taken_upgrades.append(token)
	pending_upgrades.erase(peer_id)
	_advance_offer(peer_id)


func _on_local_ability_chosen(ability_id: String) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		server_choose_ability.rpc_id(1, ability_id)
	else:
		var local_player := _local_player()
		if local_player == null:
			return
		var token := _matching_pending_upgrade(local_player.owner_peer_id, ability_id)
		if not token.is_empty():
			_apply_upgrade_choice(local_player.owner_peer_id, token)
		else:
			_apply_ability_choice(local_player.owner_peer_id, ability_id)


func _apply_ability_choice(peer_id: int, ability_id: String) -> void:
	var offered: Array = pending_ability_offers.get(peer_id, [])
	var player := players.get(peer_id) as Player
	if player == null or ability_id not in offered:
		return
	_learn_or_rank_ability(player, ability_id)
	pending_ability_offers.erase(peer_id)
	_advance_offer(peer_id)


func _learn_or_rank_ability(player: Player, ability_id: String) -> void:
	var already_known := false
	for entry in player.known_abilities:
		if entry.id == ability_id:
			already_known = true
			break
	if already_known:
		player.upgrade_ability(ability_id)
	else:
		player.learn_ability(ability_id)


func _advance_offer(peer_id: int) -> void:
	queued_upgrade_choices[peer_id] = maxi(0, int(queued_upgrade_choices.get(peer_id, 0)) - 1)
	offer_turn_index[peer_id] = int(offer_turn_index.get(peer_id, 0)) + 1
	_offer_next_upgrade(peer_id)


func _on_restart_requested() -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.OFFLINE:
		get_tree().paused = false
		if GameRuntime.return_to_world_editor:
			get_tree().reload_current_scene()
			return
		get_parent().call_deferred("restart_game")


func _on_leave_requested() -> void:
	if not game_over:
		_persist_run_save()
	get_tree().paused = false
	if GameRuntime.return_to_world_editor:
		GameRuntime.return_to_world_editor = false
		get_tree().change_scene_to_file("res://scenes/world_editor/world_editor.tscn")
		return
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
	# Resolution changes affect the local window, not a specific player entity.
	if command.begins_with("resolution:"):
		_apply_resolution_command(command)
		return
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
		"spawn_boss":
			_dev_spawn_boss()
		"toggle_invulnerable":
			player.set_invulnerable(not player.health.invulnerable)
		"biome_auto":
			if GameRuntime.uses_biomes():
				GameRuntime.unlock_biome_for_wave(maxi(1, current_wave))
				_play_world_flash()
		"add_gold":
			player.add_gold(500)
		"skip_wave":
			_dev_skip_wave()
		"open_cinematic":
			# Test hook: replay the opening crash-landing cinematic on demand.
			_opening_cinematic_playing = false
			play_opening_cinematic()
		"mission_warp":
			# Test hook: run the cinematic ring-of-fire world transition on demand.
			# Record the current (old) biome, advance to the next one, rebuild the
			# arena, then play the ring sweep revealing new world inside / old outside.
			var old_id := GameRuntime.biome_id
			var next_id := (old_id + 1) % 5
			GameRuntime.set_biome(next_id)
			_rebuild_arena()
			_play_mission_warp(current_wave + 1, old_id)
		_:
			if command.begins_with("resolution:"):
				_apply_resolution_command(command)
			elif command.begins_with("biome_") and GameRuntime.uses_biomes():
				GameRuntime.set_biome(int(command.trim_prefix("biome_")))
				_play_world_flash()


func _rebuild_arena() -> void:
	if arena is Arena:
		(arena as Arena).dress_from_runtime_biome()
	_sync_playfield()
	for enemy in enemies.values():
		if enemy is Enemy and is_instance_valid(enemy):
			(enemy as Enemy).refresh_biome_look()


## `on_landed` (if valid) runs right after the rebuild, while the screen is still white, so
## callers can reposition players / drop an arrival explosion before the reveal.
## Boss-defeat "ring sweep" + zoom-to-middle beat.
##
## The ring is a big expanding circle drawn in the world: outside the ring still reads
## as the OLD world (the arena art behind it), inside the ring the new world shows
## through — so it reads as "fire sweeping across the map" from the boss's corpse.
## Simultaneously every local player's camera zooms out to the map centre so the whole
## transition frame is visible.
func _play_boss_ring(center: Vector2) -> void:
	if GameRuntime.is_dedicated_server():
		return
	_last_boss_transition = {
		"center": center,
		"biome_id": GameRuntime.biome_id,
		"biome_name": GameRuntime.biome_name(),
		"t": Time.get_ticks_msec(),
		"source": "boss_death" if _last_boss_ring_source == "boss_death" else "mission_warp",
	}
	_zoom_cameras_to_center()
	var ring := _BossRingSweep.new()
	ring.global_position = center
	add_child(ring)


## Self-test probe hook: report the last boss-defeat ring/zoom transition that ran.
func probe_boss_transition() -> Dictionary:
	var out := _last_boss_transition.duplicate()
	out["ring_live"] = _boss_ring_live_count()
	out["camera_zoom"] = _local_camera_zoom_probe()
	if world_transition != null:
		out["world_transition_active"] = bool(world_transition.is_active())
		out["world_transition_progress"] = float(world_transition.progress)
	return out


func _boss_ring_live_count() -> int:
	var n := 0
	for child in get_children():
		if child is _BossRingSweep:
			n += 1
	return n


func _local_camera_zoom_probe() -> Array:
	var zooms := []
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null or not is_instance_valid(player) or not player.is_local_player:
			continue
		if player.camera == null:
			continue
		zooms.append([snappedf(player.camera.zoom.x, 3), snappedf(player.camera.zoom.y, 3)])
	return zooms


## Zoom every local player's camera out to a wide framing of the map centre for ~2.2s,
## so the boss ring sweep and the world landing both read in a single wide shot.
## Zoom every local player's camera out to the map centre.
## If `hold` is true, stay zoomed out (used by the cinematic world transition, which
## zooms back explicitly via _transition_zoom_back_to_players). Otherwise zoom out,
## hold briefly, then zoom back to the original framing (used by the boss-death ring).
func _zoom_cameras_to_center(hold: bool = false) -> void:
	if GameRuntime.is_dedicated_server():
		return
	var center := Vector2.ZERO
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null or not is_instance_valid(player) or not player.is_local_player:
			continue
		var cam := player.camera
		if cam == null:
			continue
		cam.position_smoothing_enabled = false
		var old_zoom := cam.zoom
		# Zoom far enough out to see the WHOLE map (8400x5600) at once so the
		# center-origin ring sweep reads as "fire consuming the old world".
		var target_zoom := Vector2(0.13, 0.13)
		var start_pos := cam.global_position
		print("[transition] zoom cam out peer=%d old_zoom=%s cam_enabled=%s" % [peer_id, str(old_zoom), str(cam.enabled)])
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(cam, "zoom", target_zoom, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cam, "global_position", center, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if not hold:
			tween.tween_interval(1.4)
			tween.tween_property(cam, "zoom", old_zoom, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(cam, "global_position", start_pos, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _play_world_flash(rebuild: bool = true, on_landed: Callable = Callable()) -> void:
	if GameRuntime.is_dedicated_server() or world_flash == null:
		if rebuild:
			_rebuild_arena()
		if on_landed.is_valid():
			on_landed.call()
		return
	(world_flash as WorldFlash).set_flash_color(Color.WHITE)
	world_flash.visible = true
	world_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(world_flash, "modulate:a", 1.0, 0.12)
	if rebuild:
		tween.tween_callback(_rebuild_arena)
	if on_landed.is_valid():
		tween.tween_callback(on_landed)
	tween.tween_interval(0.08)
	tween.tween_property(world_flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if world_flash != null:
			world_flash.visible = false
	)


## The real "you're traveling to a new world" beat for a boss kill, not the quick white
## wave-bump flash: fade to BLACK, lock every player's controls, rebuild the arena and drop
## them at the new landing spot behind the black screen, hold on the hud's title card
## (see MISSION_WARP_SCREEN_HOLD), then fade back and hand control back. ~4 seconds total,
## versus the old ~1.6s fade-to-white-and-back that read as barely more than a wave bump.
## `old_biome_override` lets a caller (the dev-command test hook) pass the biome the
## arena was just showing BEFORE the caller already advanced GameRuntime.biome_id. In
## normal play the old biome is simply the current one.
func _play_mission_warp(next_wave: int, old_biome_override: int = -1) -> void:
	_last_boss_ring_source = "mission_warp"
	var mission_number := _mission_number_for_wave(next_wave)
	var old_biome := GameRuntime.biome_id if old_biome_override < 0 else old_biome_override
	if GameRuntime.is_dedicated_server():
		_rebuild_arena()
		_trigger_world_landing(mission_number)
		return

	# Cinematic ring-of-fire world transition:
	#   1) lock players + shake
	#   2) zoom every local camera out to the full-map overhead view
	#   3) rebuild the arena to the NEW biome in place (live, underneath)
	#   4) sweep a fire ring across the map; the old biome's ground is overlaid in
	#      world space on top, masked to the OUTSIDE of the ring so the NEW world
	#      reveals itself inside the ring while the OLD world stays outside.
	#   5) zoom the cameras back into the players' new landing spot.
	# No black fade — both worlds are visible at the same time during the sweep,
	# and the game keeps running throughout.
	_set_players_locked(true)
	_shake_cameras(8.0, 0.3)

	# Remember the old biome's ground so the overlay can paint it.
	var old_ground := _biome_ground_color(old_biome)

	# 2) Zoom out to the full map and HOLD there (we zoom back explicitly after the sweep).
	_zoom_cameras_to_center(true)

	# 3) Rebuild the arena to the new biome + drop players at the landing spot.
	_rebuild_arena()
	_trigger_world_landing(mission_number)

	_last_boss_transition = {
		"center": Vector2.ZERO,
		"biome_id": GameRuntime.biome_id,
		"biome_name": GameRuntime.biome_name(),
		"t": Time.get_ticks_msec(),
		"source": "mission_warp",
	}

	# 4) Run the world-space fire-ring reveal. The transition node drives its own
	#    tween and, on `finished`, we zoom back in.
	if world_transition == null:
		_set_players_locked(false)
		return
	var half := (arena as Arena).half_extents() if arena is Arena else Vector2(4200.0, 2800.0)
	if not _mission_warp_connected:
		world_transition.finished.connect(_on_mission_warp_finished)
		_mission_warp_connected = true
	world_transition.begin(old_ground, Vector2.ZERO, _full_map_radius(half), half)


func _on_mission_warp_finished() -> void:
	# 5) Sweep complete: zoom the cameras back in to the players' new position.
	_transition_zoom_back_to_players()
	_set_players_locked(false)


## Guard flag so _play_mission_warp connects the finished signal only once.
var _mission_warp_connected := false


## Map a biome id to a representative ground fill color for the transition overlay.
func _biome_ground_color(biome_id: int) -> Color:
	match biome_id:
		1: return Color(0.18, 0.09, 0.07, 1.0)  # volcano
		2: return Color(0.11, 0.16, 0.22, 1.0)  # ice
		3: return Color(0.09, 0.11, 0.13, 1.0)  # factory
		4: return Color(0.10, 0.12, 0.17, 1.0)  # docks
		_: return Color(0.35, 0.75, 0.30, 1.0)  # grass / default — brightened for visibility


## A ring radius that comfortably covers the full map diagonal so the sweep fully
## reveals the new world.
func _full_map_radius(half: Vector2) -> float:
	return half.length() * 1.05


## Zoom every local player's camera back from the full-map overhead view to a
## comfortable framing around their (new) position. Mirrors the inverse of
## _zoom_cameras_to_center().
func _transition_zoom_back_to_players() -> void:
	if GameRuntime.is_dedicated_server():
		return
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null or not is_instance_valid(player) or not player.is_local_player:
			continue
		var cam := player.camera
		if cam == null:
			continue
		var target_zoom := Vector2(0.5, 0.5)
		var tween := create_tween()
		tween.tween_property(cam, "zoom", target_zoom, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Freezes/frees every local player's movement + abilities for the mission-warp beat above —
## a dedicated flag rather than reusing Player.active (that's the downed/dead state and
## trips other systems that key off it, like revive tracking and the landmark buff check).
func _set_players_locked(locked: bool) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		return
	for player in players.values():
		if is_instance_valid(player):
			(player as Player).movement_locked = locked


## Mission N = which lap of the biome cycle the run is on — increments forever, unlike
## GameRuntime.biome_id which loops through the 5 biomes and repeats.
func _mission_number_for_wave(wave: int) -> int:
	return (maxi(1, wave) - 1) / GameRuntime.BIOME_CYCLE_WAVES + 1


func _mission_planet_name() -> String:
	var index := clampi(GameRuntime.biome_id, 0, MISSION_PLANET_NAMES.size() - 1)
	return MISSION_PLANET_NAMES[index]


func _mission_planet_tagline() -> String:
	var index := clampi(GameRuntime.biome_id, 0, MISSION_PLANET_TAGLINES.size() - 1)
	return MISSION_PLANET_TAGLINES[index]


## Crater center when the biome has one (grass/volcano); otherwise the nearest legal,
## walkable spot to the origin so every biome has an equivalent "landing pad".
func _landing_position() -> Vector2:
	if not (arena is Arena):
		return Vector2.ZERO
	var landing_arena := arena as Arena
	if landing_arena.crater_feature_active():
		return Vector2.ZERO
	return landing_arena.free_position_near(Vector2.ZERO, 40.0)


## Fans players out around the landing spot the same way _spawn_position_for_peer does at
## match start, so co-op teammates don't stack on top of each other.
func _reposition_players_to_landing(landing: Vector2) -> void:
	if GameRuntime.mode == GameRuntime.RuntimeMode.CLIENT:
		return
	# `landing` itself is already validated walkable (see _landing_position), but fanning
	# co-op players out 72px around it is not — on a biome with narrow/spread-out pads
	# (ice's floes especially) that offset can land off the pad into the void. A solo
	# player got stuck in the water on an ice-world transition from exactly this: slot 0's
	# "offset" is still +72 on the X axis, just never checked against the arena.
	var landing_arena := arena as Arena if arena is Arena else null
	var slot := 0
	for player in players.values():
		if not is_instance_valid(player):
			continue
		var angle := TAU * float(slot) / float(GameRuntime.DEFAULT_MAX_PLAYERS)
		var spot := landing + Vector2.RIGHT.rotated(angle) * 72.0
		if landing_arena != null:
			spot = landing_arena.free_position_near(spot, 40.0)
		(player as Player).global_position = spot
		slot += 1
	_sync_playfield()


## The drop-in beat: reposition everyone at the landing spot, bank a mission banner, and
## detonate an arrival explosion that chunks whatever is already nearby (or wanders in over
## the next couple seconds) through the normal HealthComponent.take_damage() -> defeated
## pipeline, so kills still drop XP/gold the usual way.
func _trigger_world_landing(mission_number: int) -> void:
	if GameRuntime.is_classic():
		return
	# Start / refresh the world's ambient bed whenever a world lands.
	AudioService.set_world_theme(GameRuntime.biome_id)
	if GameRuntime.is_ffa():
		if not GameRuntime.is_dedicated_server():
			hud.announce_mission(mission_number, _mission_planet_name(), _mission_planet_tagline(), MISSION_WARP_CARD_HOLD)
		_play_arrival_explosion(Vector2.ZERO)
		_sync_playfield()
		if GameRuntime.is_server():
			for peer_id in registered_remote_peers.keys():
				client_announce_mission.rpc_id(peer_id, mission_number, _mission_planet_name(), _mission_planet_tagline(), MISSION_WARP_CARD_HOLD)
		return
	var landing := _landing_position()
	_reposition_players_to_landing(landing)
	if not GameRuntime.is_dedicated_server():
		hud.announce_mission(mission_number, _mission_planet_name(), _mission_planet_tagline(), MISSION_WARP_CARD_HOLD)
	_play_arrival_explosion(landing)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_announce_mission.rpc_id(peer_id, mission_number, _mission_planet_name(), _mission_planet_tagline(), MISSION_WARP_CARD_HOLD)


func _play_arrival_explosion(origin: Vector2) -> void:
	_play_explosion_effect(origin, ARRIVAL_EXPLOSION_RADIUS)
	if GameRuntime.is_server():
		for peer_id in registered_remote_peers.keys():
			client_play_explosion.rpc_id(peer_id, origin, ARRIVAL_EXPLOSION_RADIUS)
	if not _landmark_is_authority():
		return
	_arrival_explosion_damage_pass(origin)
	await get_tree().create_timer(ARRIVAL_EXPLOSION_FOLLOWUP_DELAY).timeout
	_arrival_explosion_damage_pass(origin)


## Weak trash only — never one-shots a boss with drop-in flavor damage.
func _arrival_explosion_damage_pass(origin: Vector2) -> void:
	for entity_id in enemies.keys():
		var enemy := enemies[entity_id] as Enemy
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			continue
		if enemy.is_boss:
			continue
		if enemy.global_position.distance_to(origin) > ARRIVAL_EXPLOSION_RADIUS:
			continue
		enemy.health.take_damage(enemy.health.max_health * 4.0 + 9999.0, self)


func _transition_to_biome(next_id: int) -> void:
	if next_id == GameRuntime.biome_id:
		return
	GameRuntime.biome_id = next_id
	_play_world_flash()
	# Each world sounds like its place — crossfade the ambient bed to the new biome.
	AudioService.set_world_theme(next_id)


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
			body.global_position = (arena as Arena).free_position_near(body.global_position, 18.0)


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
	var already: bool = (arena as Arena).crater_unlocked
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


## Self-test helper: spawn a boss of the current biome near the local player so the
## boss-defeat transition (ring sweep + camera zoom) can be triggered on demand.
func _dev_spawn_boss() -> void:
	if game_over:
		return
	var boss_id := EnemyType.boss_for_wave(maxi(1, current_wave))
	var focus := _first_active_player()
	var offset := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 320.0
	var multiplier := wave_director.health_multiplier_for_wave(maxi(1, current_wave))
	_spawn_enemy(offset, boss_id, multiplier)
	if focus == null:
		_spawn_enemy(Vector2.ZERO, boss_id, multiplier)


## Self-test helper: "resolution:<w>x<h>" or "resolution:fullscreen".
func _apply_resolution_command(command: String) -> void:
	if command == "resolution:fullscreen":
		hud.apply_resolution(Vector2.ZERO, true)
		return
	var parts := command.trim_prefix("resolution:").split("x")
	if parts.size() != 2:
		return
	hud.apply_resolution(Vector2(int(parts[0]), int(parts[1])), false)


## Opening crash-landing cinematic (solo + FFA): the world starts zoomed out with no
## crater; a pixel-art ship flies in wobbling, detonates at the centre (one big red
## explosion + crater reveal), then the camera zooms back in to the hero(s) standing
## in the crater. Runs once at match start; wave 1 is gated on it finishing.
## Dev-command `open_cinematic` also triggers it on demand for testing.
func play_opening_cinematic() -> void:
	if _opening_cinematic_playing:
		return
	if GameRuntime.is_dedicated_server():
		# Headless: skip the visual, just make sure the crater is revealed.
		if arena is Arena:
			(arena as Arena).set_crater_unlocked(true)
		_spawn_initial_wave()
		return
	_opening_cinematic_playing = true
	_shake_cameras(4.0, 0.3)
	# Hide the crater while the map is being "dropped" (for grass/volcano where it exists).
	if arena is Arena:
		(arena as Arena).set_crater_unlocked(false)
		(arena as Arena).queue_redraw()
	# Zoom out to the full-map overhead view.
	_zoom_cameras_to_center(true)
	# Build the ship node.
	var half := Vector2(4800.0, 3400.0)
	if arena is Arena:
		half = (arena as Arena).half_extents()
	var start_pos := Vector2(0.0, -1.4 * half.y)  # enter from far above
	_opening_ship = Node2D.new()
	var ship_script: GDScript = load("res://scripts/ship_crash_fx.gd")
	_opening_ship.set_script(ship_script)
	add_child(_opening_ship)
	# Wait a beat for the zoom-out to start settling, then launch the ship.
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(_opening_ship):
		_opening_cinematic_playing = false
		return
	_opening_ship.call("play", start_pos, Vector2.ZERO, _on_opening_impact)
	await _opening_ship.finished
	_opening_cinematic_playing = false
	if is_instance_valid(_opening_ship):
		_opening_ship.queue_free()
	_opening_ship = null
	# Now start the game.
	_spawn_initial_wave()


## Fire on the ship's impact: reveal the crater, shake, and zoom back in to the hero.
func _on_opening_impact() -> void:
	if arena is Arena:
		(arena as Arena).set_crater_unlocked(true)
	_shake_cameras(16.0, 0.6)
	_play_sound("explosion")
	# Zoom back into the crater where the hero(es) are standing.
	_transition_zoom_back_to_players()


## Resizes the window and rescales the local player's camera zoom so the visible
## world area stays constant. `ratio` = new_width / old_width, applied as
## zoom *= ratio.
func _apply_resolution(width: int, height: int) -> void:
	var old_width := maxf(1.0, get_viewport().get_visible_rect().size.x)
	DisplayServer.window_set_size(Vector2i(width, height))
	var ratio := float(width) / old_width
	if absf(ratio - 1.0) > 0.0001:
		await get_tree().process_frame
		var player := _local_player()
		if player != null and player.camera != null:
			var old_zoom: Vector2 = player.camera.zoom
			player.camera.zoom = Vector2(maxf(0.05, old_zoom.x * ratio), maxf(0.05, old_zoom.y * ratio))


## Dev command: jump straight to the next wave. Force-advances regardless of whether we're
## mid-wave or in the intermission breather, so repeated presses walk to the boss wave.
func _dev_skip_wave() -> void:
	if game_over:
		return
	wave_director.force_next_wave()


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
			if not snapshot_player.active and not GameRuntime.is_ffa():
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



## Collapses the per-physics-frame `_living_enemy_count()` + `_report_wave_pressure()`
## double-scan into a single O(enemies) pass. In co-op the two functions walked the
## `enemies` dict twice per tick; now one shared loop covers both.
func _update_enemy_reports() -> void:
	if GameRuntime.is_rift_clash():
		_report_wave_pressure_rift_clash()
		return
	# Co-op / solo path: one pass, collect both counts.
	var alive_count := 0
	var nearby_count := 0
	var player := _first_active_player()
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var radius_sq := 460.0 * 460.0
	for enemy in enemies.values():
		if not is_instance_valid(enemy):
			continue
		var body := enemy as Enemy
		if body.health == null or body.health.is_dead:
			continue
		alive_count += 1
		if player != null:
			var dist_sq := origin.distance_squared_to(body.global_position)
			if dist_sq <= radius_sq:
				nearby_count += 1
	wave_director.report_enemy_count(alive_count)
	var hp := 1.0
	if player != null and player.health != null and player.health.max_health > 0.0:
		hp = player.health.current_health / player.health.max_health
	wave_director.report_pressure(hp, nearby_count)


func _report_wave_pressure_rift_clash() -> void:
	if GameRuntime.is_rift_clash():
		# FFA runs up to 4 independent WaveDirectors (see team_wave_directors), and this used
		# to run one full O(enemies) scan of the shared pool per team for the alive count plus
		# another for the nearby count — up to 8 scans every physics frame just to report
		# counts. One shared pass (_compute_team_enemy_stats) now does all of it in O(enemies)
		# total, regardless of team count.
		var hero_by_team: Dictionary = {}
		for team_id in team_wave_directors.keys():
			hero_by_team[str(team_id)] = _player_on_team(str(team_id))
		var stats := _compute_team_enemy_stats(hero_by_team, 460.0)
		var alive: Dictionary = stats.get("alive", {})
		var nearby: Dictionary = stats.get("nearby", {})
		for team_id in team_wave_directors.keys():
			var director := team_wave_directors[team_id] as WaveDirector
			var hero: Player = hero_by_team.get(str(team_id))
			var hp := 1.0
			if hero != null and hero.health != null and hero.health.max_health > 0.0:
				hp = hero.health.current_health / hero.health.max_health
			director.report_enemy_count(int(alive.get(str(team_id), 0)))
			director.report_pressure(hp, int(nearby.get(str(team_id), 0)))
		return
	var player := _first_active_player()
	var hp := 1.0
	if player != null and player.health != null and player.health.max_health > 0.0:
		hp = player.health.current_health / player.health.max_health
	wave_director.report_pressure(hp, _nearby_enemy_count(player, 460.0))


func _nearby_enemy_count(player: Player, radius: float) -> int:
	if player == null:
		return 0
	var n := 0
	var origin := player.global_position
	for enemy in enemies.values():
		if not is_instance_valid(enemy):
			continue
		var body := enemy as Enemy
		if body.health != null and body.health.is_dead:
			continue
		if origin.distance_to(body.global_position) <= radius:
			n += 1
	return n


## One pass over the shared enemy pool computing, per team, both the live count and the
## count within `radius` of that team's hero (hero_by_team: team_id -> Player, may hold
## null for a team with no live hero) — see _report_wave_pressure().
func _compute_team_enemy_stats(hero_by_team: Dictionary, radius: float) -> Dictionary:
	var alive: Dictionary = {}
	var nearby: Dictionary = {}
	var radius_sq := radius * radius
	for enemy in enemies.values():
		if not is_instance_valid(enemy):
			continue
		var body := enemy as Enemy
		if body.health != null and body.health.is_dead:
			continue
		var team_id := str(body.team_id)
		alive[team_id] = int(alive.get(team_id, 0)) + 1
		var hero: Player = hero_by_team.get(team_id)
		if hero != null and hero.global_position.distance_squared_to(body.global_position) <= radius_sq:
			nearby[team_id] = int(nearby.get(team_id, 0)) + 1
	return {"alive": alive, "nearby": nearby}


func _selftest_active() -> bool:
	return OS.has_feature("selftest") or "--selftest" in OS.get_cmdline_args()


## Attach the SelfTestDriver child only when a request file exists. Skipping the call
## entirely is the safety: no driver => no weirdness even if the request file lingers.
const _SelfTestDriverScript := preload("res://scripts/selftest_driver.gd")


func _right_selftest_boot() -> void:
	print("[main.gd] SelfTestDriver boot check — request path exists: %s" % FileAccess.file_exists("user://selftest_request.json"))
	var driver := _SelfTestDriverScript.from_request()
	if driver == null:
		return
	add_child(driver)
	print("[main.gd] SelfTestDriver attached")


func _first_active_player() -> Player:
	for player in players.values():
		if is_instance_valid(player) and (player as Player).active:
			return player as Player
	return null


func _player_on_team(team_id: String) -> Player:
	for player_node in players.values():
		var player := player_node as Player
		if player != null and player.team_id == team_id:
			return player
	return null



func _tick_ffa(delta: float) -> void:
	if not GameRuntime.is_ffa() or game_over:
		return
	_ffa_intro_tick(delta)
	_ffa_elapsed += delta
	_ffa_shop_timer += delta
	_ffa_status_timer += delta
	_ffa_bounty_timer += delta
	if _ffa_shop_timer >= FFA_CPU_SHOP_SECONDS:
		_ffa_shop_timer = 0.0
		_cpu_auto_shop(1, 450)
	# Scoreboard only changes on kill / respawn / respawn-timer — throttle to 5 Hz
	# so the per-frame sort + dict allocation cost drops 12× in FFA.
	_ffa_scoreboard_timer += delta
	if hud != null and _ffa_scoreboard_timer >= 0.2:
		_ffa_scoreboard_timer = 0.0
		hud.refresh_ffa_scoreboard(_ffa_scoreboard_rows())
	if _ffa_status_timer >= 2.0:
		_ffa_status_timer = 0.0
		_write_ffa_sim_status()
	if _ffa_bounty_timer >= 6.0:
		_ffa_bounty_timer = 0.0
		_maintain_ffa_bounties()
	var due: Array = []
	for peer_id in _ffa_respawn_in.keys():
		_ffa_respawn_in[peer_id] = float(_ffa_respawn_in[peer_id]) - delta
		var remaining := float(_ffa_respawn_in[peer_id])
		var waiting := players.get(peer_id) as Player
		if waiting != null:
			waiting.set_ffa_respawn(remaining)
		if remaining <= 0.0:
			due.append(peer_id)
	for peer_id in due:
		_ffa_respawn_in.erase(peer_id)
		_respawn_ffa_player(int(peer_id))


## FFA opening sequence. Runs only on the local (OFFLINE/host) side. Phases:
##   1. "gather"  — heroes land in a tight circle at center; movement locked.
##   2. "hold"    — stand still (can't control) for FFA_INTRO_HOLD seconds.
##   3. "walkout" — each hero auto-walks outward in its own direction for FFA_INTRO_WALK
##      (the local player's camera follows, so the map pans as they scatter).
##   4. "settle"  — stand still again for FFA_INTRO_END_HOLD.
##   5. start     — unlock movement and start all team wave directors (creeps begin).
## The team wave directors are deferred (see _ensure_team_wave_director) so no creeps
## spawn during the intro.
func _ffa_intro_tick(delta: float) -> void:
	if not GameRuntime.is_ffa():
		return
	if _ffa_intro_done:
		return
	if _ffa_intro_elapsed < 0.0:
		# First tick: drop everyone into a landing circle at the crater and lock them.
		_start_ffa_intro()
	_ffa_intro_elapsed += delta
	if _ffa_intro_elapsed < FFA_INTRO_HOLD:
		_tick_landing_fx()
		return  # phase 2: standing still, still locked.
	if _ffa_intro_elapsed < FFA_INTRO_HOLD + FFA_INTRO_WALK:
		# phase 3: auto-walk outward. Keep movement_locked=true so the CPU brain and
		# real input can't interfere; animate positions directly instead.
		_drive_ffa_intro_walkout(delta)
		_tick_ffa_countdown()
		return
	if _ffa_intro_elapsed < FFA_INTRO_HOLD + FFA_INTRO_WALK + FFA_INTRO_END_HOLD:
		return  # phase 4: hold still (still locked).
	_finish_ffa_intro()


## Phase 1 setup: position all heroes in a circle around the crater center and lock
## their input so they can't move during the "land and stand" beat.
func _start_ffa_intro() -> void:
	_ffa_intro_elapsed = 0.0
	var center: Vector2 = _landing_position()
	_spawn_landing_fx(center)
	var count := players.size()
	if count == 0:
		_ffa_intro_done = true
		return
	var slot := 0
	for peer_id in players.keys():
		var p := players.get(peer_id) as Player
		if p == null or not is_instance_valid(p):
			continue
		var angle := TAU * float(slot) / float(count)
		var spot: Vector2 = center + Vector2.RIGHT.rotated(angle) * 90.0
		if arena is Arena and (arena as Arena).is_blocked(spot, 28.0):
			spot = center
		p.global_position = spot
		p.movement_locked = true
		# Grant the PVP spawn shield so rival heroes can't one-shot each other on spawn.
		# It lasts FFA_PVP_INVULN_SECONDS and flickers away in its final 2s.
		p.grant_pvp_spawn_protection()
		# Remember the outward direction for the walk-out phase.
		_ffa_intro_walk_dir[peer_id] = Vector2.RIGHT.rotated(angle)
		slot += 1
	if hud != null:
		hud.announce_ffa_intro("ALL HEROES — LANDING")


## Phase 3: animate each hero outward along its remembered direction by setting
## global_position directly (movement stays locked, so the CPU brain / real input can't
## fight it). Facing + z-sort update so the hero faces the walk direction.
func _drive_ffa_intro_walkout(delta: float) -> void:
	var speed := 210.0  # px/s
	# Cinematic walk: move each hero straight outward for the full FFA_INTRO_WALK
	# duration, ignoring obstacles. This guarantees all four cover exactly the same
	# distance (no hero gets stuck on a rock, so the spread stays symmetric).
	for peer_id in _ffa_intro_walk_dir.keys():
		var p := players.get(peer_id) as Player
		if p == null or not is_instance_valid(p):
			continue
		var dir := Vector2(_ffa_intro_walk_dir.get(peer_id, p.facing_direction)).normalized()
		var step := dir * speed * delta
		p.global_position = p.global_position + step
		p.facing_direction = dir
		p._refresh_sort_z()


## Show a 5->1 countdown during the walkout, flashing the current number on the HUD
## so players know when the game is about to start. Each number shows for an equal
## slice of the walkout window.
func _tick_ffa_countdown() -> void:
	if hud == null:
		return
	var walk_elapsed: float = _ffa_intro_elapsed - FFA_INTRO_HOLD
	var frac: float = clampf(walk_elapsed / FFA_INTRO_WALK, 0.0, 1.0)
	var remaining: int = 5 - int(frac * 5.0)  # 5 at start, drops to 0 at end
	remaining = clampi(remaining, 0, 5)
	if remaining != _ffa_countdown_shown:
		_ffa_countdown_shown = remaining
		hud.ffa_countdown_tick(str(remaining) if remaining > 0 else "GO")


## Phase 5: unlock everyone and start the deferred team wave directors so creeps spawn.
func _finish_ffa_intro() -> void:
	_ffa_intro_done = true
	_clear_landing_fx()
	for peer_id in players.keys():
		var p := players.get(peer_id) as Player
		if p == null or not is_instance_valid(p):
			continue
		p.movement_locked = false
		# Aim forward so the bot resumes its normal behavior. Only script the CPU bots —
		# the local offline player must keep reading real input (latching an external
		# command here would freeze its movement after the intro, see set_authority_command).
		if p.simulation_mode == Player.SimulationMode.CPU:
			p.set_authority_command(Vector2.ZERO, p.global_position + p.facing_direction * 100.0, false, false, [false, false, false, false], false)
		else:
			p.clear_external_command()
	for team_id in team_wave_directors.keys():
		var director: WaveDirector = team_wave_directors[team_id]
		if director != null and not director.running:
			var members := 1
			for peer_id in players.keys():
				if RiftClashManager.team_of(int(peer_id)) == int(team_id):
					members += 1
			director.start(maxi(1, members), false)
	if hud != null:
		hud.ffa_countdown_tick("FIGHT!", true)


## Landing beat visual: grass -> expanding blast ring -> crater. Plays during the
## FFA_INTRO_HOLD phase. The node draws in world space at the crater center and fades
## out once the walk-out begins.
func _spawn_landing_fx(center: Vector2) -> void:
	_clear_landing_fx()
	var node := Node2D.new()
	node.name = "FfaLandingFx"
	node.position = center
	node.z_index = -5
	# A _draw-based fx driven by _tick_landing_fx via the elapsed intro timer.
	_landing_fx = node
	actors.add_child(node)
	var t := GDScript.new()
	t.source_code = """
extends Node2D
var progress := 0.0
func _draw() -> void:
	# Crater (dark pit).
	draw_circle(Vector2.ZERO, 46.0, Color(0.10, 0.09, 0.08, 0.9))
	draw_circle(Vector2.ZERO, 34.0, Color(0.05, 0.04, 0.04, 0.95))
	# Blast ring — grows with progress.
	var ring_r: float = 20.0 + progress * 120.0
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(1.0, 0.85, 0.5, 0.5 * (1.0 - progress)), 3.0)
	# Dust specks.
	for i in 10:
		var a: float = float(i) * 0.6283 + progress * 2.0
		var d: float = ring_r * 0.9
		draw_circle(Vector2.from_angle(a) * d, 2.0, Color(0.7, 0.65, 0.5, 0.3 * (1.0 - progress)))
"""
	t.reload(true)
	node.set_script(t)
	# Heroes drop in with a brief scale pop as they "land".
	for peer_id in players.keys():
		var p := players.get(peer_id) as Player
		if p == null or not is_instance_valid(p) or p.sprite == null:
			continue
		var tw := create_tween()
		tw.tween_property(p.sprite, "scale", p.sprite.scale, 0.25).set_trans(Tween.TRANS_QUAD)


## Drive the landing beat: blast ring expands 0->1 across the hold phase, then the
## crater settles and the fx fades.
func _tick_landing_fx() -> void:
	if _landing_fx == null or not is_instance_valid(_landing_fx):
		return
	var t: float = clampf(_ffa_intro_elapsed / FFA_INTRO_HOLD, 0.0, 1.0)
	_landing_fx.set("progress", t)
	_landing_fx.queue_redraw()


func _clear_landing_fx() -> void:
	if _landing_fx != null and is_instance_valid(_landing_fx):
		_landing_fx.queue_free()
	_landing_fx = null


func _on_ffa_player_died(peer_id: int) -> void:
	var fallen := players.get(peer_id) as Player
	if fallen == null:
		return
	var source := fallen.health.last_damage_source
	if source is Player and source != fallen:
		var killer := source as Player
		killer.add_gold(GameRuntime.HERO_KILL_GOLD + fallen.last_death_gold_lost)
		killer.hero_kills = RiftClashManager.record_hero_kill(killer.owner_peer_id)
		# Boss-form: once the boss-holder lands 3 hero kills, they're overpowered —
		# revert to their normal hero so the match stays balanced.
		if killer.in_boss_form:
			print("[boss-form] %s hit %d hero kills, reverting to hero" % [
				RiftClashManager.team_name(killer.team_id),
				killer.boss_form_hero_kills,
			])
			if killer.boss_form_register_hero_kill():
				killer.revert_boss_form()
		print("[ffa] kill %s now %d/%d at %.0fs" % [
			RiftClashManager.team_name(killer.team_id),
			killer.hero_kills,
			GameRuntime.FFA_KILLS_TO_WIN,
			_ffa_elapsed,
		])
		_write_ffa_sim_status()
		if hud != null:
			hud.refresh_ffa_scoreboard(_ffa_scoreboard_rows())
		if RiftClashManager.has_winner():
			_finish_ffa_match()
			return
	_ffa_respawn_in[peer_id] = GameRuntime.FFA_RESPAWN_SECONDS
	if fallen != null:
		fallen.set_ffa_respawn(GameRuntime.FFA_RESPAWN_SECONDS)


func _respawn_ffa_player(peer_id: int) -> void:
	var player := players.get(peer_id) as Player
	if player == null or game_over:
		return
	var home := RiftClashManager.team_anchor(RiftClashManager.team_of(peer_id))
	player.respawn_ffa(home)


func _ffa_bounty_count() -> int:
	var n := 0
	if not is_inside_tree():
		return 0
	for node in get_tree().get_nodes_in_group("ffa_bounty"):
		if is_instance_valid(node):
			n += 1
	return n


func _start_side_quests() -> void:
	if _side_quest_director != null:
		return
	_side_quest_director = SideQuestDirector.new()
	_side_quest_director.name = "SideQuestDirector"
	add_child(_side_quest_director)
	_side_quest_director.setup(self)

	_creep_camp = CreepCampScript.new()
	_creep_camp.name = "CreepCamp"
	add_child(_creep_camp)
	_creep_camp.start(self, arena)

	_recruit_areas = RecruitAreasScript.new()
	_recruit_areas.name = "RecruitAreas"
	add_child(_recruit_areas)
	_recruit_areas.start(self, arena)

	_minigame_area = MinigameAreaScript.new()
	_minigame_area.name = "MinigameArea"
	add_child(_minigame_area)
	_minigame_area.start(self, arena, _recruit_areas)


## Continuous "ghost trickle": lightweight enemy records that stream in from the
## map perimeter toward players, visible as dots on the minimap, and materialize
## into real enemies just off-screen when they reach the camera viewport.
func _start_ghost_waves() -> void:
	if _ghost_waves != null:
		return
	_ghost_waves = GhostWaveSystem.new()
	_ghost_waves.name = "GhostWaves"
	add_child(_ghost_waves)
	_ghost_waves.bind(self)


var _last_side_quest_text := ""


func _refresh_side_quest_hud() -> void:
	if hud == null or _side_quest_director == null:
		return
	var text: String = _side_quest_director.hud_text_for_local()
	if not text.is_empty() and _last_side_quest_text.is_empty():
		hud.show_quest_toast("New side quest: %s" % text)
	_last_side_quest_text = text
	hud.set_side_quest_text(text)


func _maintain_ffa_bounties() -> void:
	if game_over or enemies.size() >= _enemy_cap():
		return
	var missing := FFA_BOUNTY_CAP - _ffa_bounty_count()
	if missing <= 0:
		return
	var spots := _ffa_bounty_spots()
	if spots.is_empty():
		return
	var multiplier := wave_director.health_multiplier_for_wave(maxi(1, current_wave)) * 1.35
	for _i in mini(missing, 3):
		var spot: Vector2 = spots[randi() % spots.size()]
		var type_id := str(FFA_BOUNTY_TYPES[randi() % FFA_BOUNTY_TYPES.size()])
		var enemy := _spawn_enemy_at(spot, type_id, multiplier, 0.92, true)
		if enemy == null:
			continue
		enemy.xp_value = maxi(enemy.xp_value * 3, 48)
		enemy.gold_value = maxi(enemy.gold_value * 3, 18)
		enemy.scale = Vector2(1.22, 1.22)
		enemy.add_to_group("ffa_bounty")


func _ffa_bounty_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var rim := Arena.ffa_creep_rim_radius(28.0) + 70.0
	for index in 6:
		spots.append(Vector2.RIGHT.rotated(TAU * float(index) / 6.0 + 0.4) * rim)
	for shrine in Arena.contested_landmark_spots():
		spots.append(shrine + Vector2.RIGHT.rotated(randf() * TAU) * 160.0)
	if arena is Arena:
		var cleaned: Array[Vector2] = []
		for spot in spots:
			if Arena.ffa_blocks_creeps_from_crater() and spot.length() < Arena.ffa_creep_rim_radius(24.0):
				spot = spot.normalized() * Arena.ffa_creep_rim_radius(24.0)
			cleaned.append((arena as Arena).free_position_near(spot, 24.0))
		return cleaned
	return spots


func _finish_ffa_match() -> void:
	if game_over:
		return
	game_over = true
	_set_ghosts_game_over(true)
	RunSave.clear()
	wave_director.stop()
	for director in team_wave_directors.values():
		if director is WaveDirector:
			(director as WaveDirector).stop()
	var winner_name := RiftClashManager.team_name(RiftClashManager.team_of(RiftClashManager.winner_peer_id))
	print("[ffa] winner %s after %.0fs" % [winner_name, _ffa_elapsed])
	_write_ffa_sim_status()
	_resolve_rift_clash_match()


func _write_ffa_sim_status() -> void:
	if not GameRuntime.is_ffa():
		return
	var heroes: Array = []
	var creeps_in_bowl := 0
	var creeps_on_rim := 0
	var rim := Arena.ffa_creep_rim_radius(20.0)
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or not node is Node2D:
				continue
			var dist := (node as Node2D).global_position.length()
			if dist < Arena.crater_radius():
				creeps_in_bowl += 1
			elif dist < rim + 80.0:
				creeps_on_rim += 1
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null:
			continue
		heroes.append({
			"peer": int(peer_id),
			"team": RiftClashManager.team_name(player.team_id),
			"kills": player.hero_kills,
			"alive": player.active,
			"hp": snappedf(player.health.current_health, 0.1),
			"invuln": snappedf(player.pvp_invuln_timer, 0.1),
			"dist_center": snappedf(player.global_position.length(), 1.0),
		})
	var payload := {
		"elapsed": snappedf(_ffa_elapsed, 0.1),
		"kills_to_win": GameRuntime.FFA_KILLS_TO_WIN,
		"winner": RiftClashManager.winner_peer_id,
		"winner_name": RiftClashManager.team_name(RiftClashManager.team_of(RiftClashManager.winner_peer_id)) if RiftClashManager.has_winner() else "",
		"game_over": game_over,
		"creeps_in_bowl": creeps_in_bowl,
		"creeps_on_rim": creeps_on_rim,
		"heroes": heroes,
	}
	var file := FileAccess.open("user://ffa_sim_status.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()


func _ffa_scoreboard_rows() -> Array:
	var rows: Array = []
	for peer_id in players.keys():
		var player := players[peer_id] as Player
		if player == null:
			continue
		var remaining := float(_ffa_respawn_in.get(peer_id, 0.0))
		rows.append({
			"peer_id": int(peer_id),
			"name": "%s %s" % [RiftClashManager.team_name(player.team_id), RiftClashManager.team_corner_name(player.team_id)],
			"class_id": player.class_id,
			"kills": player.hero_kills,
			"color": RiftClashManager.team_color(player.team_id),
			"alive": player.active,
			"respawn": remaining,
			"local": player.is_local_player,
			"invuln": player.pvp_invuln_timer,
		})
	rows.sort_custom(func(a, b): return int(a.kills) > int(b.kills))
	return rows


func _all_players_dead() -> bool:
	return not players.is_empty() and _first_active_player() == null


class _BossRingSweep:
	extends Node2D
	## Fire-sweep ring for a boss defeat: a bright expanding band. The map behind the
	## ring still reads as the OLD world; the region inside the ring is the NEW world,
	## so the sweep reads as "fire crossing the map" toward the centre.
	var _t := 0.0
	const DURATION := 2.2
	const MAX_RADIUS := 2200.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DURATION:
			queue_free()

	func _draw() -> void:
		var p := clampf(_t / DURATION, 0.0, 1.0)
		var r := p * MAX_RADIUS
		var fade := 1.0 - p
		# Outer hot band — the "fire line".
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1.0, 0.55, 0.15, 0.9 * fade), 46.0, true)
		draw_arc(Vector2.ZERO, r - 30.0, 0.0, TAU, 96, Color(1.0, 0.8, 0.3, 0.7 * fade), 18.0, true)
		# Inner new-world glow (fades as the ring grows).
		draw_circle(Vector2.ZERO, r * 0.98, Color(0.4, 0.7, 1.0, 0.12 * fade))
