extends Node2D
## Isolated ability verification scene (empty-world baseline).
##
## Spawns one hero + 3 dummy grunts, force-casts each kit slot, captures
## screenshots, and probes enemy state. Writes user://selftest_report.json.
##
## Run via:
##   run_selftest.ps1 -Scene res://scenes/ability_verify_test/ability_verify_test.tscn -Hero <hero_id>

const _PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const _ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")

var _camera: Camera2D
var _player: Node2D = null
var _dummies: Array[Node2D] = []
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _probes: Array = []
var _hero_id := ""
var _events: Array = []
var _event_idx := 0
var _kit_slots: Dictionary = {}
var _enemy_net_id := 1000


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(200, 0)
	_camera.zoom = Vector2(0.9, 0.9)
	_run_dir = "user://ability_verify_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	_hero_id = _resolve_hero_id()
	print("[AbilityVerify] hero=%s" % _hero_id)

	# Build kit slot map from PlayerClass.
	var pc: GDScript = load("res://scripts/player_class.gd")
	var hero_def: Dictionary = pc.by_id(_hero_id)
	if hero_def.is_empty():
		push_error("[AbilityVerify] unknown hero: %s" % _hero_id)
		_finish_with_fail("unknown hero")
		return
	_kit_slots[0] = str(hero_def.get("kit_q", ""))
	_kit_slots[1] = str(hero_def.get("kit_e", ""))
	_kit_slots[2] = str(hero_def.get("kit_r", ""))
	var pool: Array = hero_def.get("ability_pool", [])
	_kit_slots[3] = str(pool[0]) if pool.size() > 0 else ""

	# Spawn hero at origin.
	var p: Node2D = _PLAYER_SCENE.instantiate()
	p.position = Vector2.ZERO
	add_child(p)
	_player = p
	p.configure(1, 0, true, _hero_id)
	if p.has_method("_apply_sprite"):
		p._apply_sprite()

	# Spawn 3 dummy grunts.
	var positions: Array[Vector2] = [
		Vector2(200, -80),
		Vector2(260, 80),
		Vector2(320, 0),
	]
	for i in 3:
		var g: Node2D = _ENEMY_SCENE.instantiate()
		g.position = positions[i]
		add_child(g)
		# High HP so abilities don't one-shot the dummies — we want to observe
		# effects (root, slow, burn) not just kills.
		g.configure(_enemy_net_id, true, "grunt", 10.0, 0.5)
		_dummies.append(g)
		_enemy_net_id += 1

	# Build default events: cast each of 4 slots with before/after snaps + probe.
	_events = _build_default_events()

	await get_tree().process_frame
	await get_tree().process_frame
	print("[AbilityVerify] ready hero=%s dummies=%d events=%d" % [_hero_id, _dummies.size(), _events.size()])


func _resolve_hero_id() -> String:
	# From request JSON (written by run_selftest.ps1).
	var rf := FileAccess.open("user://selftest_request.json", FileAccess.READ)
	if rf:
		var text := rf.get_as_text()
		rf.close()
		var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			var d: Dictionary = data
			if d.has("hero"):
				return str(d.hero)
	# From cmdline.
	for i in OS.get_cmdline_args().size():
		var arg: String = OS.get_cmdline_args()[i]
		if arg == "--hero" and i + 1 < OS.get_cmdline_args().size():
			return str(OS.get_cmdline_args()[i + 1])
	return "arclight"


func _build_default_events() -> Array:
	var ev: Array = []
	var t := 0.8
	for slot in 4:
		var ability_id: String = _kit_slots.get(slot, "")
		if ability_id.is_empty():
			continue
		# Before snap.
		ev.append({"t": t, "kind": "snap", "label": "iso_before_slot%d" % slot})
		t += 0.2
		# Aim at the nearest dummy (right side).
		ev.append({"t": t, "kind": "aim", "at": [300, 0]})
		t += 0.2
		# Cast.
		ev.append({"t": t, "kind": "cast", "slot": slot, "ability": ability_id})
		t += 1.8
		# After snap.
		ev.append({"t": t, "kind": "snap", "label": "iso_after_slot%d" % slot})
		t += 0.3
		# Probe.
		ev.append({"t": t, "kind": "probe", "label": "probe_slot%d" % slot})
		t += 0.8
	# Final report.
	ev.append({"t": t + 0.5, "kind": "report"})
	return ev


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta

	while _event_idx < _events.size():
		var ev: Dictionary = _events[_event_idx]
		var ev_t: float = float(ev.get("t", 0.0))
		if _elapsed < ev_t:
			break
		var kind: String = str(ev.get("kind", ""))
		match kind:
			"snap":
				_snap(str(ev.get("label", "snap")))
			"aim":
				var at: Array = ev.get("at", [300, 0])
				if _player and is_instance_valid(_player):
					_player.aim_world_position = Vector2(float(at[0]), float(at[1]))
					_player.facing_direction = Vector2.RIGHT
			"cast":
				_do_cast(int(ev.get("slot", 0)), str(ev.get("ability", "")))
			"probe":
				_do_probe(str(ev.get("label", "probe")))
			"report":
				_finish()
				return
		_event_idx += 1


func _do_cast(slot: int, ability_id_override: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var ability_id: String = ability_id_override
	if ability_id.is_empty():
		ability_id = str(_kit_slots.get(slot, ""))
	if ability_id.is_empty():
		print("[AbilityVerify] no ability for slot %d" % slot)
		return

	var pc: GDScript = load("res://scripts/player_class.gd")
	var data: Dictionary = pc.ability_info(ability_id)
	if data.is_empty():
		print("[AbilityVerify] ability %s not in catalog" % ability_id)
		return
	var values: Dictionary = pc.ability_values(ability_id, 1)

	# Clear any movement lock / stun on dummies so the cast is observable.
	for d in _dummies:
		if is_instance_valid(d):
			if d.has_method("clear_movement_lock"):
				d.clear_movement_lock()

	_player.aim_world_position = _player.global_position + Vector2(300, 0)
	_player.facing_direction = Vector2.RIGHT
	_player._cast_known_ability_direct(ability_id, data, values, 0)
	print("[AbilityVerify] cast slot %d → %s" % [slot, ability_id])


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.08).timeout
	var vp: Viewport = get_viewport()
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		print("[AbilityVerify] snap %s: empty image" % label)
		return
	var path := "%s/%s.png" % [_run_dir, label]
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": roundf(_elapsed * 100.0) / 100.0})
	print("[AbilityVerify] snap %s -> %s" % [label, path])


func _do_probe(label: String) -> void:
	var probe := {"label": label, "t": roundf(_elapsed * 100.0) / 100.0, "dummies": []}
	for i in _dummies.size():
		var d: Node2D = _dummies[i]
		if not is_instance_valid(d):
			probe.dummies.append({"idx": i, "alive": false})
			continue
		var hc = d.get_node_or_null("HealthComponent")
		var hp: float = 0.0
		var max_hp: float = 0.0
		if hc:
			hp = float(hc.get("current_health"))
			max_hp = float(hc.get("max_health"))
		var info := {
			"idx": i,
			"alive": d.is_inside_tree() and hp > 0.0,
			"hp": hp,
			"max_hp": max_hp,
			"pos": [roundf(d.global_position.x * 10.0) / 10.0, roundf(d.global_position.y * 10.0) / 10.0],
			"movement_locked": _safe_get_float(d, "movement_lock_timer") > 0.0,
			"stunned": _safe_get_float(d, "stun_timer") > 0.0,
			"slowed": _safe_get_float(d, "slow_timer") > 0.0,
			"poisoned": _safe_get_float(d, "poison_timer") > 0.0,
		}
		probe.dummies.append(info)
	# Probe the player.
	var player_probe := {"alive": is_instance_valid(_player) and _player.is_inside_tree()}
	if is_instance_valid(_player):
		var phc = _player.get_node_or_null("HealthComponent")
		if phc:
			player_probe.hp = float(phc.get("current_health"))
			player_probe.max_hp = float(phc.get("max_health"))
		player_probe.shield = _safe_get_float(_player, "shield_amount")
		player_probe.buff_active = _safe_get_float(_player, "ability_buff_timer") > 0.0
	probe.player = player_probe
	_probes.append(probe)
	print("[AbilityVerify] probe %s" % label)


## Safe float getter — returns 0.0 if the property doesn't exist on the object.
func _safe_get_float(obj: Object, prop: String) -> float:
	if obj == null:
		return 0.0
	# Godot Object.get() returns null for nonexistent properties.
	var val = obj.get(prop)
	if val == null:
		return 0.0
	return float(val)


func _finish() -> void:
	_finish_with_report("PASS")


func _finish_with_fail(reason: String) -> void:
	_done = true
	var report := {
		"verdict": "FAIL",
		"scene": "ability_verify_test",
		"hero": _hero_id,
		"reason": reason,
		"shots": _shots,
		"probes": _probes,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[AbilityVerify] FAIL: %s" % reason)
	get_tree().quit(1)


func _finish_with_report(verdict: String) -> void:
	if _done:
		return
	_done = true
	var report := {
		"verdict": verdict,
		"scene": "ability_verify_test",
		"hero": _hero_id,
		"kit_slots": _kit_slots,
		"shots": _shots,
		"probes": _probes,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[AbilityVerify] SUMMARY verdict=%s hero=%s shots=%d probes=%d" % [verdict, _hero_id, _shots.size(), _probes.size()])
	get_tree().quit(0)


func _draw() -> void:
	# Empty-world baseline: dark plane + crosshair at origin.
	draw_rect(Rect2(Vector2(-640, -360), Vector2(1280, 720)), Color(0.05, 0.05, 0.08), true)
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color(0.35, 0.35, 0.45), 1.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(0.35, 0.35, 0.45), 1.0)
	# Hero label.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-80, -40), "HERO: %s" % _hero_id.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 160, 16, Color(0.9, 0.75, 0.3))
