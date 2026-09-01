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
	return driver


func _ready() -> void:
	print("[SelfTestDriver] _ready() start, parent=%s" % get_parent().name if get_parent() else "null")
	_host_main = get_parent()
	# Self-tests need audible/audio-observable behavior regardless of the user's saved
	# prefs: SFX must be on so sound_probe entries can see a player firing.
	AudioService.sfx_enabled = true
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
	if _player == null or slot < 0 or slot >= _SLOT_ACTIONS.size():
		return
	if slot < _player.ability_cooldowns.size() and float(_player.ability_cooldowns[slot]) > 0.0:
		_active_effects.append({"kind": "cast_skipped", "t": _elapsed, "slot": slot, "reason": "cooldown", "cd_left": _player.ability_cooldowns[slot]})
		return
	var action: String = _SLOT_ACTIONS[slot]
	Input.action_release(action)
	await get_tree().physics_frame
	Input.action_press(action)
	_last_slot_tapped = slot
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
	if _elapsed - _debug_last_phys >= 0.5:
		print("[std] phys t=%.2f mode=%s paused=%s" % [_elapsed, str(get_tree().root.process_mode), str(get_tree().paused)])
		_debug_last_phys = _elapsed

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed - _debug_last_tick >= 0.5:
		print("[std] tick t=%.2f events=%d" % [_elapsed, _events.size()])
		_debug_last_tick = _elapsed
	_tick_walk()
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
	if dist < 30.0 or _elapsed > _walk_deadline:
		_walk_target = null
		_player.set_authority_command(Vector2.ZERO, _player.aim_world_position, false, false, [false, false, false, false], false)
		return
	_player.set_authority_command(offset.normalized(), _player.aim_world_position, false, false, [false, false, false, false], false)


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
		"abilities": (_player.known_abilities.duplicate() if _player.known_abilities else []),
	})


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


func _finish_and_quit() -> void:
	for expected_id in _expected_casts:
		var found := false
		for cast in _casts:
			if str(cast.get("ability_id", "")) == expected_id:
				found = true
				break
		if not found:
			_errors.append("expected cast never fired: %s" % expected_id)
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
		},
	}
	var file := FileAccess.open(report_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[SelfTestDriver] report → %s" % report_out)
	get_tree().quit(0)
