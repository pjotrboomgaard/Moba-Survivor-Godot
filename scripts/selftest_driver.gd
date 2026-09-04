class_name SelfTestDriver
extends Node

## Filesystem-driven self-test runner: reads a JSON request from user://selftest_request.json,
## autonomously plays the game (spawn enemies, walk, cast abilities at aim points), captures
## screenshots at requested times, then writes user://selftest_report.json and quits.
##
## The harness only activates in OFFLINE runs of main.tscn (GatedRunner / verify steps skip
## multiplayer). Each event key is a "t" in seconds since driver start; the driver runs
## on _process so real gameplay paths and animation frames are exercised end-to-end.

var report_out := "user://selftest_report.json"
var request_path := "user://selftest_request.json"

var _events: Array[Dictionary] = []
var _elapsed := 0.0
var _host_main: Node = null
var _player: Player = null
var _enemies: Array[Node] = []
var _walk_target: Variant = null  # Vector2 or null while a walk_to is in flight
var _walk_deadline := 0.0  # give up if the player hasn't reached by then
var _shots_taken: Array[Dictionary] = []
var _active_effects: Array[Dictionary] = []
var _last_slot_tapped: int = -1
var _requested_hero: String = ""
var _casts: Array[Dictionary] = []
var _errors: Array[String] = []
var _expected_casts: Array[String] = []
var _survival := false
var _survival_duration := 1100.0
var _until_wave := 20
var _danger_hp := 0.42
var _recover_hp := 0.56
var _hp_samples: Array[Dictionary] = []
var _min_hp_frac := 1.0
var _max_hp_frac := 0.0
var _min_hp_late := 1.0
var _beaten_wave := 0
var _last_hp_sample_t := -10.0
var _wave_snaps: Dictionary = {}
var _landmark_saves := 0
var _holding_landmark := false
var _survival_ai_cd := 0.0
var _cast_burst_cd := 0.0
var _pressure_boosts := 0
var _died := false
var _verdict := ""
var _hp_before_landmark := 1.0
var _finished := false
var _survival_cast_i := 0
var _confirm_due: Array[Dictionary] = []
var _shop_buys: Array[Dictionary] = []
var _shop_trip := false
var _want_shop := false
var _heal_commit := false
var _landmark_kite_until := 0.0
var _last_lm_effect := ""


static func from_request(path: String = "user://selftest_request.json") -> SelfTestDriver:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var driver := SelfTestDriver.new()
	# JSON.parse_string returns a loosely-typed Array; rebuild as Array[Dictionary] per-entry.
	var raw_events: Variant = (parsed as Dictionary).get("events", [])
	if raw_events is Array:
		for entry in raw_events:
			if entry is Dictionary:
				driver._events.append(entry as Dictionary)
	var expected: Variant = (parsed as Dictionary).get("expected_casts", [])
	if expected is Array:
		for id in expected:
			driver._expected_casts.append(str(id))
	# Sort ascending on t so we just pop from the front.
	driver._events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	# Optional: override the hero the driver will swap to before firing (bypasses saved profile).
	var hero_req := str((parsed as Dictionary).get("hero", ""))
	if not hero_req.is_empty():
		driver._requested_hero = hero_req
	if str((parsed as Dictionary).get("mode", "")) == "solo_survival":
		driver._survival = true
		driver._survival_duration = float((parsed as Dictionary).get("duration", 1100.0))
		driver._until_wave = int((parsed as Dictionary).get("until_wave", 20))
		driver._danger_hp = float((parsed as Dictionary).get("danger_hp", 0.42))
		driver._recover_hp = float((parsed as Dictionary).get("recover_hp", 0.56))
	return driver


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[SelfTestDriver] _ready() start, parent=%s" % get_parent().name if get_parent() else "null")
	_host_main = get_parent()
	# Self-tests need audible/audio-observable behavior regardless of the user's saved
	# prefs: SFX must be on so sound_probe entries can see a player firing.
	AudioService.sfx_enabled = true
	GameRuntime.fill_cpu_allies = false
	GameRuntime.biome_locked = false
	if _host_main == null:
		push_warning("[SelfTestDriver] No parent; shutting down")
		queue_free()
		return
	_player = _host_main._local_player()
	print("[SelfTestDriver] local player=%s" % (_player.class_id if _player else "null"))
	if _player == null:
		await get_tree().create_timer(1.0).timeout
		_player = _host_main._local_player()
		print("[SelfTestDriver] local player after wait=%s" % (_player.class_id if _player else "null"))
	if _player != null and not _requested_hero.is_empty() and PlayerClass.is_valid_id(_requested_hero):
		print("[SelfTestDriver] swapping hero → %s (was %s)" % [_requested_hero, _player.class_id])
		_player.apply_class(_requested_hero)
	if _player != null and not _player.ability_cast.is_connected(_on_player_ability_cast):
		_player.ability_cast.connect(_on_player_ability_cast)
	_bind_landmark_saves()
	if _survival and _host_main != null and _host_main.get("wave_director") != null:
		var director: WaveDirector = _host_main.wave_director
		if not director.intermission_started.is_connected(_on_survival_intermission):
			director.intermission_started.connect(_on_survival_intermission)


func _on_player_ability_cast(ability_id: String, _effect_style: int, _points: PackedVector2Array) -> void:
	_casts.append({"t": _elapsed, "ability_id": ability_id})


## Snapshot helper: resize report paths and create one directory per run.
static func make_output_dir(request_name: String) -> String:
	var root := ProjectSettings.globalize_path("user://")
	var dir := "%s/selftest_%s_%d" % [root, request_name.get_file().get_basename(), Time.get_ticks_msec()]
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


## Push an input event. The local player is OFFLINE and reads InputService (physical
## action state) in _physics_process — so we press the real ability_N action here rather
## than routing through set_authority_command (which OFFLINE ignores). The press spans one
## full physics frame so Player's `held && !was_held` edge detector sees a genuine tap.
const _SLOT_ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4"]


func _inject_input(slot: int) -> void:
	if _player == null or slot < 0:
		return
	# Confirm taps must ignore cooldown — the arm tap has not spent CD yet.
	var pending := int(_player.get("_pending_ability_slot"))
	if pending != slot and slot < _player.ability_cooldowns.size() and float(_player.ability_cooldowns[slot]) > 0.0:
		_active_effects.append({"kind": "cast_skipped", "t": _elapsed, "slot": slot, "reason": "cooldown", "cd_left": _player.ability_cooldowns[slot]})
		return
	_last_slot_tapped = slot
	# Direct tap: InputService is ignored while movement is latched for walk/hold.
	if _player.has_method("scripted_tap_ability"):
		_player.scripted_tap_ability(slot)
		return
	var action: String = _SLOT_ACTIONS[slot]
	Input.action_release(action)
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)


func _event_vec(event: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = event.get(key, fallback)
	if raw is Vector2:
		return raw
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback


func _spawn_at(pos: Vector2, type_id: String = "grunt", hp_mult: float = 1.0, spd_mult: float = 1.0) -> Node:
	var e: Node = null
	if _host_main == null:
		return null
	# _spawn_enemy() on main.gd takes an offset relative to the first active player; easier
	# for the request JSON to be player-relative than absolute world coords.
	var world: Vector2 = pos
	if _player != null:
		world = _player.global_position + pos
	e = _host_main._spawn_enemy(world - (_player.global_position if _player else Vector2.ZERO), type_id, hp_mult, spd_mult) as Node
	if e != null:
		_enemies.append(e)
	return e


func _screenshot(label: String) -> Vector2:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	print("[SelfTestDriver] snap label=%s vp_size=%s cam=%s player=%s enemies=%d" % [
		label, str(vp.get_visible_rect().size),
		str(vp.get_camera_2d().global_position if vp.get_camera_2d() else "none"),
		str(_player.global_position if _player else "null"),
		_enemies.filter(func(e): return is_instance_valid(e)).size(),
	])
	var image := vp.get_texture().get_image()
	var name := "%s_%.3f_%s.png" % [label, _elapsed, str(Time.get_ticks_msec())]
	var out_dir := SelfTestDriver.make_output_dir("selftest_run")
	var path := "%s/%s" % [out_dir, name]
	image.save_png(path)
	_shots_taken.append({"t": _elapsed, "path": path, "label": label})
	return Vector2.ZERO


var _debug_last_tick := 0.0
var _debug_last_phys := 0.0

func _physics_process(_delta: float) -> void:
	if _elapsed - _debug_last_phys >= 5.0:
		print("[std] phys t=%.1f paused=%s" % [_elapsed, str(get_tree().paused)])
		_debug_last_phys = _elapsed

func _process(delta: float) -> void:
	if get_tree().paused:
		_resolve_paused_offers()
		return
	_elapsed += delta
	if _elapsed - _debug_last_tick >= 5.0:
		print("[std] tick t=%.1f wave=%d beaten=%d hp=%.2f xp=%d/%d lv=%d" % [
			_elapsed,
			int(_host_main.get("current_wave") if _host_main else 0),
			_beaten_wave,
			_hp_frac(),
			_player.current_xp if _player else 0,
			_player.xp_required if _player else 0,
			_player.level if _player else 0,
		])
		_debug_last_tick = _elapsed
	if _survival:
		_tick_survival(delta)
		if _beaten_wave >= _until_wave or _elapsed >= _survival_duration:
			_finish_and_quit()
			return
	_tick_walk()
	_flush_confirm_taps()
	if _survival:
		_overlay_combat_hold()
	while not _events.is_empty() and float(_events[0].get("t", 0.0)) <= _elapsed:
		var event: Dictionary = _events.pop_front()
		var kind := str(event.get("kind", ""))
		match kind:
			"aim":
				if _player != null:
					_player.aim_world_position = _event_vec(event, "at", _player.global_position + Vector2.RIGHT * 120.0)
			"cast":
				await _inject_input(int(event.get("slot", 0)))
			"hero":
				# Swap hero mid-run so one request can probe several heroes' banks.
				# Waits several frames so apply_class repopulates known_abilities +
				# cooldowns before the next cast — one frame is too racy for slots [0]->[-1].
				var hero_id := str(event.get("id", ""))
				if _player != null and PlayerClass.is_valid_id(hero_id):
					_player.apply_class(hero_id)
					await get_tree().physics_frame
					await get_tree().physics_frame
					await get_tree().physics_frame
				else:
					_active_effects.append({"kind": "hero", "t": _elapsed, "error": "bad hero id '%s'" % hero_id})
			"spawn":
				_spawn_at(_event_vec(event, "at", Vector2(160, 0)), str(event.get("type", "hound")), float(event.get("hp_mult", 1.0)), float(event.get("spd_mult", 1.0)))
			"snap":
				await _screenshot(str(event.get("label", "snap")))
			"probe":
				_record_probe(str(event.get("label", "probe")))
			"sound_probe":
				_record_sound_probe(str(event.get("label", "")), str(event.get("ability_id", "")))
			"wait":
				await get_tree().create_timer(float(event.get("duration", 0.5))).timeout
			"effect_log":
				_active_effects.append({"kind": "custom", "text": str(event.get("text", "")), "t": _elapsed})
			"walk_to":
				# Player-relative walk target; the driver steers velocity toward it each
				# frame until arrival or until the deadline passes. Settle: stop motion.
				if _player != null:
					var offset: Array = event.get("at", [0.0, 0.0])
					_walk_target = _player.global_position + Vector2(float(offset[0]), float(offset[1]))
					_walk_deadline = _elapsed + float(event.get("timeout", 6.0))
			"walk_stop":
				if _player != null:
					_walk_target = null
					_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], false)
			"teleport":
				# Instant move: used for stand-on-landmark tests where the walk itself is
				# not what we want to verify. `at` is player-relative (use [0,0] + "to" for
				# absolute world coordinates).
				if _player != null:
					if event.has("to"):
						var to_arr: Array = event.get("to")
						_player.global_position = Vector2(float(to_arr[0]), float(to_arr[1]))
					else:
						var off: Array = event.get("at", [0.0, 0.0])
						_player.global_position += Vector2(float(off[0]), float(off[1]))
					_walk_target = null
					_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], false)
			"landmarks":
				_record_landmarks(str(event.get("label", "landmarks")))
			"report":
				_finish_and_quit()


## Drive the player toward the active walk target. The inner arrival radius is a little
## smaller than the landmark STAND_RADIUS so the standing-still check kicks in. Once we
## arrive we zero the input so `speed < 8.0` is true and the fill ring starts ticking.
func _tick_walk() -> void:
	if _player == null or _walk_target == null:
		return
	var target := _walk_target as Vector2
	var offset := target - _player.global_position
	var dist := offset.length()
	var attack := _survival
	if dist < 30.0 or _elapsed > _walk_deadline:
		_walk_target = null
		_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, attack, false, [false, false, false, false], false)
		return
	_player.set_authority_command(offset.normalized(), _player.aim_world_position, attack, false, [false, false, false, false], false)


## Snapshot every active landmark's gameplay state so the test report can assert against it.
func _record_landmarks(label: String) -> void:
	if _host_main == null:
		return
	var arena: Variant = _host_main.get("arena")
	if arena == null or not (arena is Arena):
		_active_effects.append({"kind": "landmarks", "label": label, "t": _elapsed, "error": "no arena"})
		return
	var list: Array = []
	for landmark in (arena as Arena).landmarks:
		if not (landmark is ArenaLandmark) or not is_instance_valid(landmark):
			continue
		list.append({
			"effect_id": str(landmark.effect_id),
			"hint": landmark._hint,
			"fill": landmark._fill,
			"cooldown": landmark._cooldown,
			"ready": landmark._ready_to_fire,
			"pos": landmark.global_position,
		})
	_active_effects.append({"kind": "landmarks", "label": label, "t": _elapsed, "list": list})


## Emit structured facts (current cooldowns, active summons count, pending slot, last slot
## tapped, how many enemies remain) into the report dict. Agents assert against these later.
func _record_probe(label: String) -> void:
	if _player == null:
		return
	var hp_now := 0.0
	var hp_max := 0.0
	if _player.health != null:
		hp_now = float(_player.health.current_health)
		hp_max = float(_player.health.max_health)
	_active_effects.append({
		"kind": "probe",
		"label": label,
		"t": _elapsed,
		"cds": _player.ability_cooldowns.duplicate() if _player.ability_cooldowns else [],
		"summons": _player.active_summons.size() if _player.get("active_summons") != null else 0,
		"pending_slot": _player._pending_ability_slot,
		"pending_id": _player._pending_ability_id,
		"last_tapped": _last_slot_tapped,
		"enemies_alive": _enemies.filter(func(e): return is_instance_valid(e) and not (e.get("health") == null or e.health.is_dead)).size(),
		"hero": _player.class_id,
		"hp": hp_now,
		"hp_max": hp_max,
		"hp_frac": _hp_frac(),
		"abilities": (_player.known_abilities.duplicate() if _player.known_abilities else []),
		"ffa": _ffa_roster(),
	})


func _ffa_roster() -> Dictionary:
	var heroes: Array = []
	if not is_inside_tree():
		return {"count": 0, "heroes": heroes}
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Player:
			continue
		var player := node as Player
		heroes.append({
			"peer": player.owner_peer_id,
			"team": player.team_id,
			"class": player.class_id,
			"cpu": player.is_cpu(),
			"local": player.is_local_player,
			"pos": [snappedf(player.global_position.x, 1.0), snappedf(player.global_position.y, 1.0)],
			"kills": player.hero_kills,
			"alive": player.active,
		})
	return {
		"enabled": GameRuntime.is_ffa(),
		"all_bots": GameRuntime.ffa_all_bots,
		"count": heroes.size(),
		"heroes": heroes,
		"kills_to_win": GameRuntime.FFA_KILLS_TO_WIN,
		"map": [Arena.playfield_size().x, Arena.playfield_size().y],
	}


## Assert that AudioService actually played the hero bank for a cast. `ability_id` is the
## ability the request just cast; the probe checks AudioService.last_play_ability matches
## it, resolves the ability's hero prefix to the expected `cast_<hero>` bank, and verifies
## the last sound's stream was loaded from that bank (its resource_path contains the bank
## id). Failing entries land in the report with explicit `assert_*: false` fields so the
## runner can spot them without parsing text.
func _record_sound_probe(label: String, ability_id: String) -> void:
	var entry := {"kind": "sound_probe", "label": label, "ability_id": ability_id, "t": _elapsed}
	if ability_id == "":
		entry["error"] = "sound_probe requires ability_id"
		_active_effects.append(entry)
		return
	var prefix := ability_id.split("_")[0]
	var bank := "cast_%s" % prefix
	entry["expected_bank"] = bank
	var last_ability: String = AudioService.last_play_ability
	var last: Dictionary = AudioService.last_play
	var sound_id := str(last.get("sound_id", ""))
	var player: AudioStreamPlayer = last.get("player", null)
	var stream: AudioStream = last.get("stream", null)
	entry["last_play_ability"] = last_ability
	entry["last_play_sound_id"] = sound_id
	entry["stream_path"] = stream.resource_path if stream != null else ""
	entry["player_non_null"] = player != null
	entry["player_was_playing"] = player.playing if player != null else false
	entry["assert_ability_match"] = last_ability == ability_id
	entry["assert_bank_match"] = sound_id == bank
	# Theme takes live in assets/audio/themes/<hero>.wav, not named cast_<hero> — match
	# by hero prefix so the assert covers both synthesized themes and legacy .ogg takes.
	entry["assert_stream_from_bank"] = stream != null and ("themes/%s" % prefix) in stream.resource_path
	entry["assert_player_fired"] = player != null
	entry["ok"] = (entry["assert_ability_match"] and entry["assert_bank_match"]
		and entry["assert_stream_from_bank"] and entry["assert_player_fired"])
	_active_effects.append(entry)


func _bind_landmark_saves() -> void:
	if _host_main == null or not (_host_main.get("arena") is Arena):
		return
	var arena := _host_main.arena as Arena
	if arena.has_signal("landmarks_changed") and not arena.landmarks_changed.is_connected(_on_landmarks_changed):
		arena.landmarks_changed.connect(_on_landmarks_changed)
	_on_landmarks_changed()


func _on_landmarks_changed() -> void:
	if _host_main == null or not (_host_main.get("arena") is Arena):
		return
	for landmark in (_host_main.arena as Arena).landmarks:
		if landmark is ArenaLandmark and is_instance_valid(landmark):
			if not landmark.triggered.is_connected(_on_survival_landmark):
				landmark.triggered.connect(_on_survival_landmark)


func _on_survival_landmark(pos: Vector2) -> void:
	_landmark_saves += 1
	_heal_commit = false
	_holding_landmark = false
	_landmark_kite_until = _elapsed + 8.0
	if _host_main != null and _host_main.get("arena") is Arena:
		for landmark in (_host_main.arena as Arena).landmarks:
			if landmark is ArenaLandmark and is_instance_valid(landmark) and landmark.global_position.distance_to(pos) < 80.0:
				_last_lm_effect = str(landmark.effect_id)
				break
	_active_effects.append({"kind": "landmark_save", "t": _elapsed, "hp": _hp_frac(), "saves": _landmark_saves})


func _hp_frac() -> float:
	if _player == null or _player.health == null:
		return 1.0
	var mx := maxf(_player.health.max_health, 1.0)
	return clampf(_player.health.current_health / mx, 0.0, 1.0)


func _alive_enemies() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if get_tree() == null:
		return out
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var n := node as Node2D
		var health: Variant = n.get("health")
		if health != null and bool(health.get("is_dead")):
			continue
		out.append(n)
	return out


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	if _player == null:
		return null
	for enemy in _alive_enemies():
		var d := _player.global_position.distance_to(enemy.global_position)
		if enemy is Enemy and (enemy as Enemy).is_boss:
			d *= 0.12
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _landmark_ready(lm: ArenaLandmark) -> bool:
	return lm != null and is_instance_valid(lm) and lm._cooldown <= 0.05 and lm._ready_to_fire


func _landmark_by_effect(effect_id: String) -> ArenaLandmark:
	if _host_main == null or not (_host_main.get("arena") is Arena) or _player == null:
		return null
	var best: ArenaLandmark = null
	var best_d := INF
	for landmark in (_host_main.arena as Arena).landmarks:
		if not (landmark is ArenaLandmark) or not is_instance_valid(landmark):
			continue
		var lm := landmark as ArenaLandmark
		if str(lm.effect_id) != effect_id:
			continue
		var d := _player.global_position.distance_to(lm.global_position)
		if d < best_d:
			best_d = d
			best = lm
	return best


func _nearest_landmark() -> ArenaLandmark:
	return _landmark_by_effect("heal_all")


func _shop_position() -> Vector2:
	return Arena.shop_stand_position()


func _cheapest_affordable_item() -> String:
	if _player == null:
		return ""
	var best_id := ""
	var best_price := 1 << 30
	for item in ShopCatalog.items_for(_player.class_id):
		var item_id := str(item.id)
		if not _player.can_afford(item_id):
			continue
		var price := ShopCatalog.price_for(item_id, _player.stacks_of(item_id))
		if price < best_price:
			best_price = price
			best_id = item_id
	return best_id


func _preferred_affordable_item() -> String:
	if _player == null:
		return ""
	if _player.stacks_of(ShopCatalog.ACTIVE_ITEM_ID) <= 0:
		if _player.can_afford(ShopCatalog.ACTIVE_ITEM_ID):
			return ShopCatalog.ACTIVE_ITEM_ID
		return ""
	var order: Array[String] = ["sjaal", "benen", "hoverboard", "romp", "armen", "antenne"]
	for item_id in order:
		if _player.can_afford(item_id) and _player.stacks_of(item_id) <= 0:
			return item_id
	return _cheapest_affordable_item()


func _try_buy_at_shop() -> void:
	if _player == null:
		return
	var in_break := _host_main != null and _host_main.get("wave_director") != null and float(_host_main.wave_director.intermission_timer) > 0.0
	if not in_break and _player.global_position.distance_to(_shop_position()) > Arena.SHOP_STAND_INTERACT_RADIUS:
		return
	var bought_any := false
	while true:
		var item_id := _preferred_affordable_item()
		if item_id.is_empty():
			break
		var paid := ShopCatalog.price_for(item_id, _player.stacks_of(item_id))
		if not _player.buy(item_id):
			break
		bought_any = true
		_shop_buys.append({"t": _elapsed, "item": item_id, "gold_left": _player.gold, "paid": paid})
		_active_effects.append({"kind": "shop_buy", "t": _elapsed, "item": item_id, "gold_left": _player.gold})
		print("[SelfTestDriver] bought %s gold_left=%d" % [item_id, _player.gold])
	_want_shop = not _preferred_affordable_item().is_empty() and _shop_buys.size() < 8
	_shop_trip = _want_shop
	if bought_any and not _want_shop and _host_main != null and _host_main.get("wave_director") != null and _host_main.wave_director.intermission_timer > 0.0:
		_host_main.wave_director.skip_intermission()


func _on_survival_intermission(next_wave: int, _seconds: float) -> void:
	_beaten_wave = maxi(_beaten_wave, next_wave - 1)
	print("[SelfTestDriver] beaten wave %d (next=%d) hp=%.2f" % [_beaten_wave, next_wave, _hp_frac()])
	if _beaten_wave >= _until_wave:
		_finish_and_quit()


func _maybe_snap_wave(wave: int) -> void:
	if wave in [5, 10, 15, 20] and not bool(_wave_snaps.get(wave, false)):
		_wave_snaps[wave] = true
		_active_effects.append({"kind": "wave_mark", "wave": wave, "t": _elapsed, "hp": _hp_frac(), "gold": _player.gold if _player != null else 0})
		print("[SelfTestDriver] wave %d mark hp=%.2f gold=%d saves=%d" % [wave, _hp_frac(), _player.gold if _player != null else 0, _landmark_saves])


func _pace_intermission() -> void:
	if _host_main == null or _host_main.get("wave_director") == null:
		return
	var director: WaveDirector = _host_main.wave_director
	if director.intermission_timer <= 0.0:
		return
	if _hp_frac() < 0.94:
		return
	if _want_shop and _hp_frac() >= 0.70:
		return
	var heal := _landmark_by_effect("heal_all")
	# Spawns drop around the hero. Only start the next wave in the open center so
	# formations don't clamp onto the vent / lava lip.
	if _player != null and _player.global_position.length() > 260.0:
		return
	# Don't open a swarm wave with the clutch pad still cooling down.
	if heal != null and not _landmark_ready(heal):
		return
	if director.intermission_timer > 1.4:
		director.skip_intermission()


func _tick_survival(delta: float) -> void:
	if _player == null:
		return
	if _player.health != null and _player.health.is_dead:
		_died = true
		_finish_and_quit()
		return
	var frac := _hp_frac()
	_min_hp_frac = minf(_min_hp_frac, frac)
	_max_hp_frac = maxf(_max_hp_frac, frac)
	var wave := int(_host_main.get("current_wave") if _host_main else 0)
	if wave >= 10:
		_min_hp_late = minf(_min_hp_late, frac)
	if _elapsed - _last_hp_sample_t >= 2.5:
		_last_hp_sample_t = _elapsed
		_hp_samples.append({
			"t": snappedf(_elapsed, 0.01),
			"hp": snappedf(frac, 0.01),
			"wave": wave,
			"enemies": _alive_enemies().size(),
			"gold": _player.gold,
		})
	_maybe_snap_wave(wave)
	_want_shop = _shop_buys.size() < 8 and not _preferred_affordable_item().is_empty()
	var in_break := false
	if _host_main.get("wave_director") != null:
		in_break = float(_host_main.wave_director.intermission_timer) > 0.0
	if in_break and _want_shop:
		_try_buy_at_shop()
	_pace_intermission()
	_survival_ai_cd -= delta
	_cast_burst_cd -= delta
	var heal := _landmark_by_effect("heal_all")
	var freeze := _landmark_by_effect("freeze_time")
	var wipe := _landmark_by_effect("pulse_wipe")
	var foe := _nearest_enemy()
	if foe != null:
		_player.aim_world_position = foe.global_position
	var enemy_n := _alive_enemies().size()
	var nearest_d := _player.global_position.distance_to(foe.global_position) if foe != null else 9999.0
	# Combat: start the pad sprint while there is still HP to cross the last 300px.
	# Intermission: top off so the next wave doesn't open already bleeding.
	var commit_at := 0.36 if wave > 0 and wave % 5 == 0 else (0.60 if wave < 12 else 0.48)
	if in_break and frac < 0.90 and not (wave > 0 and wave % 5 == 0):
		_heal_commit = true
	elif frac <= commit_at:
		_heal_commit = true
	elif frac >= 0.84 or not _landmark_ready(heal):
		_heal_commit = false
	var breaking_off := _elapsed < _landmark_kite_until and frac > 0.40
	var need_heal := (not breaking_off) and _heal_commit and _landmark_ready(heal)
	var boss_up := foe is Enemy and (foe as Enemy).is_boss
	var boss_wave := wave > 0 and wave % 5 == 0
	var need_freeze := (not breaking_off) and _landmark_ready(freeze) and (
		((boss_up or boss_wave) and _last_lm_effect != "freeze_time")
		or (not boss_up and frac <= 0.50 and enemy_n >= 6)
	)
	if in_break and not boss_up:
		need_freeze = false
	if (boss_up or boss_wave) and need_freeze and frac > 0.34:
		need_heal = false
	var need_wipe := (not breaking_off) and _landmark_ready(wipe) and not need_heal and not need_freeze and (
		boss_up or boss_wave or (frac <= 0.50 and enemy_n >= 8)
	)
	var need_shop := (not breaking_off) and _want_shop and in_break and frac >= 0.55 and not need_heal and not need_freeze and not (boss_up and need_wipe)
	var target_lm: ArenaLandmark = null
	if need_heal:
		target_lm = heal
		_shop_trip = false
	elif need_freeze:
		target_lm = freeze
		_shop_trip = false
	elif need_wipe:
		target_lm = wipe
		_shop_trip = false
	if target_lm != null:
		var on_pad := _player.global_position.distance_to(target_lm.global_position) <= 90.0 and not _in_lava()
		if on_pad:
			_holding_landmark = true
			_walk_target = null
			_hp_before_landmark = frac
		else:
			_holding_landmark = false
			_walk_target = target_lm.global_position
			_walk_deadline = _elapsed + 16.0
	elif need_shop:
		_holding_landmark = false
		_shop_trip = true
		var shop_pos := _shop_position()
		if foe != null and nearest_d < 90.0:
			_walk_target = _player.global_position + (_player.global_position - foe.global_position).normalized() * 140.0
			_walk_deadline = _elapsed + 2.0
		elif _player.global_position.distance_to(shop_pos) <= 140.0:
			_walk_target = null
			_try_buy_at_shop()
		else:
			_walk_target = shop_pos
			_walk_deadline = _elapsed + 10.0
	else:
		_holding_landmark = false
		_shop_trip = false
		var orb := _nearest_orb()
		var orb_d := _player.global_position.distance_to(orb.global_position) if orb != null else 9999.0
		if in_break and frac >= 0.90:
			if orb != null and orb_d < 980.0:
				_walk_target = orb.global_position
			else:
				_walk_target = Vector2.ZERO
			_walk_deadline = _elapsed + 8.0
		elif _elapsed < _landmark_kite_until:
			var boss_foe := foe if (foe is Enemy and (foe as Enemy).is_boss) else null
			_walk_target = _kite_boss(boss_foe) if boss_foe != null else _peel_near_heal(heal, foe)
			_walk_deadline = _elapsed + 2.0
		elif frac >= 0.50 and orb != null and orb_d < 720.0 and nearest_d > 130.0:
			_walk_target = orb.global_position
			_walk_deadline = _elapsed + 3.0
		elif foe is Enemy and (foe as Enemy).is_boss:
			_walk_target = _kite_boss(foe)
			_walk_deadline = _elapsed + 2.0
		else:
			_walk_target = _fight_near_heal(heal, foe, wave)
			_walk_deadline = _elapsed + 2.0
	if _in_lava():
		_holding_landmark = false
		_walk_target = _lava_escape()
		_walk_deadline = _elapsed + 2.0
	else:
		var slam_out := _slam_escape()
		if slam_out != Vector2.INF and target_lm == null:
			_holding_landmark = false
			_walk_target = slam_out
			_walk_deadline = _elapsed + 1.4
		elif _walk_target != null:
			_walk_target = _safe_walk(_walk_target as Vector2)
	# Kit Q/E every beat; R (and pool alt) when the clutch window opens.
	if _cast_burst_cd <= 0.0:
		_cast_burst_cd = 0.55
		var slots: Array[int] = []
		if _player.known_abilities.size() > 0:
			slots.append(0)
		if _player.known_abilities.size() > 1:
			slots.append(1)
		if frac <= 0.72 or boss_up or enemy_n >= 5:
			if _player.known_abilities.size() > 2:
				slots.append(2)
			if _player.known_abilities.size() > 3:
				slots.append(3)
		if not slots.is_empty():
			_cast_two_stage(slots[_survival_cast_i % slots.size()])
			_survival_cast_i += 1


func _fight_near_heal(heal: ArenaLandmark, foe: Node2D, wave: int) -> Vector2:
	var home := heal.global_position if heal != null and is_instance_valid(heal) else Vector2.ZERO
	var pos := _player.global_position
	var home_d := pos.distance_to(home)
	# Fight in a band ~650px from the vent so a low-HP sprint can outrun the pack.
	var band_in := 280.0
	var band_out := 520.0
	if home_d < band_in and home.length() > 1.0:
		return pos + (pos - home).normalized() * 160.0
	if home_d > band_out and home.length() > 1.0:
		return home + (pos - home).normalized() * ((band_in + band_out) * 0.5)
	if foe == null:
		return pos
	var away := pos - foe.global_position
	var dist := away.length()
	var boss_fight := foe is Enemy and (foe as Enemy).is_boss
	var too_close := 340.0 if boss_fight else (240.0 if wave >= 5 else (200.0 if wave >= 3 else 130.0))
	var kite := Vector2.ZERO
	if boss_fight and ((foe as Enemy).winding_up or (foe as Enemy).charging):
		kite = (away.normalized() if dist > 1.0 else Vector2.RIGHT) * 280.0
	elif dist < too_close:
		kite = (away.normalized() if dist > 1.0 else Vector2.RIGHT) * 220.0
	elif dist > 420.0 and not boss_fight and _alive_enemies().size() < 6:
		kite = -away.normalized() * 70.0
	var tangent := (away.orthogonal().normalized() if dist > 1.0 else Vector2.RIGHT) * 120.0
	if int(floor(_elapsed * 1.4)) % 2 == 1:
		tangent = -tangent
	var candidate := pos + kite + tangent
	var cand_d := candidate.distance_to(home)
	if cand_d < band_in or cand_d > band_out:
		candidate = home + (candidate - home).normalized() * clampf(cand_d, band_in, band_out)
	return candidate


func _kite_boss(foe: Node2D) -> Vector2:
	var pos := _player.global_position
	if foe == null:
		return pos.lerp(Vector2.ZERO, 0.35)
	var away := pos - foe.global_position
	var dist := away.length()
	var from_boss := away.normalized() if dist > 1.0 else Vector2.RIGHT.rotated(_elapsed)
	var hold := 280.0
	var radial := Vector2.ZERO
	if dist < hold:
		radial = from_boss * (hold - dist + 90.0)
	elif dist > hold + 80.0:
		radial = -from_boss * 70.0
	var tangent := from_boss.orthogonal() * 160.0
	if int(floor(_elapsed * 1.15)) % 2 == 1:
		tangent = -tangent
	if foe is Enemy and ((foe as Enemy).winding_up or (foe as Enemy).charging):
		radial = from_boss * 280.0
	var candidate := pos + radial + tangent
	# Stay in the open crater instead of getting pinned on a corner pad.
	if candidate.length() > 420.0:
		candidate = candidate.normalized() * 380.0
	if candidate.length() < 80.0:
		candidate = from_boss * 220.0
	return candidate


func _peel_near_heal(heal: ArenaLandmark, foe: Node2D) -> Vector2:
	var home := heal.global_position if heal != null and is_instance_valid(heal) else Vector2.ZERO
	var pos := _player.global_position
	var kite := Vector2.RIGHT * 80.0
	if foe != null:
		var away := pos - foe.global_position
		if away.length() > 1.0:
			kite = away.normalized() * 140.0
	var candidate := pos + kite
	if home.length() > 1.0:
		var d := candidate.distance_to(home)
		if d < 180.0 or d > 380.0:
			candidate = home + (candidate - home).normalized() * 280.0
	return candidate


func _nearest_orb() -> Node2D:
	if _player == null or get_tree() == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("xp_orbs"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var d := _player.global_position.distance_to((node as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = node as Node2D
	return best


func _arena() -> Arena:
	if _host_main != null and _host_main.get("arena") is Arena:
		return _host_main.arena as Arena
	return null


func _in_lava() -> bool:
	if _player == null:
		return false
	var arena := _arena()
	return arena != null and arena.is_in_hazard(_player.global_position, 16.0)


func _lava_escape() -> Vector2:
	var arena := _arena()
	if arena == null:
		return Vector2.ZERO
	var exit := arena.nearest_hazard_exit(_player.global_position, 40.0)
	return arena.free_position_near(exit, 30.0)


func _safe_walk(target: Vector2) -> Vector2:
	var arena := _arena()
	if arena == null or _player == null:
		return target
	if arena.is_in_hazard(target, 14.0):
		return arena.free_position_near(target, 36.0)
	var from := _player.global_position
	var dist := from.distance_to(target)
	if dist < 1.0:
		return target
	# Sample along the straight-line path (not just the midpoint) so a hazard anywhere
	# along a long walk — routine on the bigger maps — still gets caught.
	var steps := clampi(int(dist / 220.0), 1, 8)
	for i in range(1, steps + 1):
		var sample := from.lerp(target, float(i) / float(steps + 1))
		if not arena.is_in_hazard(sample, 20.0):
			continue
		# Try to step around the hazard rather than just freezing near our current spot.
		var dir := (target - from).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var sides: Array[float] = [1.0, -1.0]
		for side in sides:
			var detour: Vector2 = sample + perp * side * 180.0
			if not arena.is_in_hazard(detour, 20.0):
				return arena.free_position_near(detour, 30.0)
		return arena.free_position_near(arena.nearest_hazard_exit(sample, 40.0), 30.0)
	return target


## Step out of telegraph slam circles before they go live. Returns Vector2.INF when clear.
func _slam_escape() -> Vector2:
	if _player == null or get_tree() == null:
		return Vector2.INF
	var pos := _player.global_position
	var circles: Array[ArenaHazard] = []
	for node in get_tree().get_nodes_in_group("arena_hazards"):
		if not is_instance_valid(node) or not (node is ArenaHazard):
			continue
		var hazard := node as ArenaHazard
		if hazard.kind != ArenaHazard.Kind.CIRCLE:
			continue
		circles.append(hazard)
	if circles.is_empty():
		return Vector2.INF
	var threatened := false
	for hazard in circles:
		if pos.distance_to(hazard.global_position) <= hazard.radius + 28.0:
			threatened = true
			break
	if not threatened:
		return Vector2.INF
	var best_safe := pos
	var best_safe_d := 9999.0
	var best_any := pos
	var best_any_clear := -9999.0
	var radii: Array[float] = [88.0, 108.0, 128.0]
	for dist in radii:
		for index in 20:
			var sample := pos + Vector2.RIGHT.rotated(TAU * float(index) / 20.0) * dist
			var arena := _arena()
			if arena != null and (arena.is_blocked(sample, 18.0) or arena.is_in_hazard(sample, 16.0)):
				continue
			var clear := 9999.0
			for hazard in circles:
				clear = minf(clear, sample.distance_to(hazard.global_position) - hazard.radius)
			if clear > best_any_clear:
				best_any_clear = clear
				best_any = sample
			if clear > 12.0 and sample.distance_to(pos) < best_safe_d:
				best_safe_d = sample.distance_to(pos)
				best_safe = sample
	if best_safe_d < 900.0:
		return best_safe
	if best_any_clear > 0.0:
		return best_any
	return pos + Vector2.RIGHT.rotated(_elapsed * 2.1) * 120.0


func _boss_is_telegraphing() -> bool:
	for enemy in _alive_enemies():
		if enemy is Enemy and (enemy as Enemy).is_boss and ((enemy as Enemy).winding_up or (enemy as Enemy).charging):
			return true
	return false


func _overlay_combat_hold() -> void:
	if _player == null:
		return
	var n := 0
	var nearest := 9999.0
	var boss_near := false
	for enemy in _alive_enemies():
		var d := _player.global_position.distance_to(enemy.global_position)
		nearest = minf(nearest, d)
		if d < 90.0:
			n += 1
		if enemy is Enemy and (enemy as Enemy).is_boss and d < 520.0:
			boss_near = true
	var clustered := n >= 3 and not _holding_landmark
	var use_dash := (
		not _holding_landmark
		and _player.has_active_item()
		and _player.sprint_cooldown <= 0.0
		and (
			clustered
			or (boss_near and _boss_is_telegraphing())
			or (nearest < 160.0 and not boss_near)
		)
	)
	if _holding_landmark:
		# Plant so the pad's stand-still check (velocity < 8) can fire. Basic attack is a
		# stationary hitscan/AOE for every weapon kind (no self-movement), so it's safe to
		# keep firing while filling — only move_input and ability_slots stay zeroed, since
		# some ability kits do include a self-dash that would break the stand-still check.
		_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, true, false, [false, false, false, false], false)
	elif _walk_target == null:
		var strafe := Vector2.RIGHT.rotated(_elapsed * 1.85) * 0.85
		_player.set_authority_command(strafe, _player.aim_world_position, true, use_dash, _player.command_ability_slots, clustered)
	else:
		_player.set_authority_command(_player.command_move, _player.aim_world_position, true, use_dash, _player.command_ability_slots, clustered)


func _ability_id_at(slot: int) -> String:
	if _player == null or slot < 0 or slot >= _player.known_abilities.size():
		return ""
	var entry: Variant = _player.known_abilities[slot]
	if entry is Dictionary:
		return str((entry as Dictionary).get("id", ""))
	return str(entry.get("id", ""))


func _needs_confirm(ability_id: String) -> bool:
	if ability_id.is_empty() or not Player.TARGETED_ABILITIES.has(ability_id):
		return false
	var mode := str(Player.TARGETED_ABILITIES[ability_id])
	return mode != "instant"


func _cast_named(ability_id: String) -> void:
	if _player == null or ability_id.is_empty():
		return
	for slot in _player.known_abilities.size():
		if _ability_id_at(slot) == ability_id:
			_cast_two_stage(slot)
			return


func _cast_two_stage(slot: int) -> void:
	_inject_input(slot)
	if _needs_confirm(_ability_id_at(slot)):
		_confirm_due.append({"slot": slot, "at": _elapsed + 0.14})


func _flush_confirm_taps() -> void:
	if _confirm_due.is_empty():
		return
	var keep: Array[Dictionary] = []
	for item in _confirm_due:
		if float(item.get("at", 0.0)) <= _elapsed:
			_inject_input(int(item.get("slot", 0)))
		else:
			keep.append(item)
	_confirm_due = keep


func _resolve_paused_offers() -> void:
	if _host_main == null or _player == null:
		get_tree().paused = false
		return
	var peer_id := int(_player.owner_peer_id)
	var stats: Variant = _host_main.get("pending_upgrades")
	if stats is Dictionary:
		var offered: Array = (stats as Dictionary).get(peer_id, [])
		if offered.size() > 0 and _host_main.has_method("_apply_upgrade_choice"):
			_host_main._apply_upgrade_choice(peer_id, str(offered[0]))
			return
	var abils: Variant = _host_main.get("pending_ability_offers")
	if abils is Dictionary:
		var offered_ab: Array = (abils as Dictionary).get(peer_id, [])
		if offered_ab.size() > 0 and _host_main.has_method("_apply_ability_choice"):
			_host_main._apply_ability_choice(peer_id, str(offered_ab[0]))
			return
	var hud: Variant = _host_main.get("hud")
	if hud != null and hud.get("shop_panel") != null and hud.shop_panel.visible:
		if hud.has_method("close_shop"):
			hud.close_shop()
	if hud != null and hud.get("upgrade_panel") != null and hud.upgrade_panel.visible:
		hud.upgrade_panel.visible = false
	get_tree().paused = false


func _finish_and_quit() -> void:
	if _finished:
		return
	_finished = true
	for expected_id in _expected_casts:
		var found := false
		for cast in _casts:
			if str(cast.get("ability_id", "")) == expected_id:
				found = true
				break
		if not found:
			_errors.append("expected cast never fired: %s" % expected_id)
	if _survival:
		_score_survival()
	var report := {
		"elapsed": _elapsed,
		"player_class": _player.class_id if _player != null else "",
		"shots": _shots_taken,
		"effects": _active_effects,
		"enemies_spawned": _enemies.size(),
		"hero_position": (_player.global_position if _player != null else Vector2.ZERO),
		"results": {
			"casts": _casts,
			"errors": _errors,
			"verdict": _verdict,
			"died": _died,
			"min_hp": _min_hp_frac,
			"max_hp": _max_hp_frac,
			"landmark_saves": _landmark_saves,
			"cast_count": _casts.size(),
			"shop_buys": _shop_buys,
			"shop_buy_count": _shop_buys.size(),
			"gold": _player.gold if _player != null else 0,
			"pressure_boosts": _pressure_boosts,
			"hp_samples": _hp_samples,
			"wave": int(_host_main.get("current_wave") if _host_main else 0),
			"beaten_wave": _beaten_wave,
			"until_wave": _until_wave,
			"min_hp_late": _min_hp_late,
			"level": _player.level if _player != null else 0,
			"xp": _player.current_xp if _player != null else 0,
		},
	}
	var file := FileAccess.open(report_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[SelfTestDriver] report → %s verdict=%s min_hp=%.2f late=%.2f saves=%d casts=%d buys=%d beaten=%d gold=%d lv=%d" % [report_out, _verdict, _min_hp_frac, _min_hp_late, _landmark_saves, _casts.size(), _shop_buys.size(), _beaten_wave, _player.gold if _player != null else 0, _player.level if _player != null else 0])
	get_tree().quit(0)


func _score_survival() -> void:
	if _died:
		_verdict = "FAIL_TOO_HARD"
		_errors.append("player died at t=%.1f wave=%d min_hp=%.2f" % [_elapsed, int(_host_main.get("current_wave") if _host_main else 0), _min_hp_frac])
		return
	if _beaten_wave < _until_wave:
		_verdict = "FAIL_NO_PROGRESS"
		_errors.append("only beaten wave %d / %d (t=%.0f)" % [_beaten_wave, _until_wave, _elapsed])
		return
	if _casts.is_empty():
		_verdict = "FAIL_NO_ABILITIES"
		_errors.append("never cast an ability")
		return
	if _min_hp_frac > _danger_hp + 0.08:
		_verdict = "FAIL_TOO_EASY"
		_errors.append("min_hp=%.2f never entered danger (<%.2f) — fight was not clutch" % [_min_hp_frac, _danger_hp])
		return
	if _min_hp_late > 0.58 and _until_wave >= 10:
		_verdict = "FAIL_TOO_EASY"
		_errors.append("late-game min_hp=%.2f never went critical after wave 10" % _min_hp_late)
		return
	if _landmark_saves <= 0:
		_verdict = "FAIL_NO_LANDMARK_SAVE"
		_errors.append("HP dipped to %.2f but no landmark fired" % _min_hp_frac)
		return
	if _shop_buys.is_empty():
		_verdict = "FAIL_NO_SHOP"
		_errors.append("never bought an item (gold=%d)" % (_player.gold if _player != null else 0))
		return
	if _min_hp_frac <= 0.08:
		_verdict = "WARN_NEAR_DEATH"
		return
	_verdict = "PASS_CLUTCH"
