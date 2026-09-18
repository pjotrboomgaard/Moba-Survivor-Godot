extends Node2D
## Isolated empty-world test for camp-creep recruit behavior changes (2026-09-18).
##
## Empty-world baseline: flat dark background + camera. No arena, no grass, no HUD.
##
## Scenario:
##   1. Spawn 12 recruited camp creeps, each already at a distinct position on
##      the follow ring around a fake owner (a Node2D in the "players" group).
##   2. Watch them for 3.5 seconds.
##   3. Verify: creeps stay near the owner (orbit + separation keep them in a
##      loose ring), don't all collapse to the same point, and the idle bob is
##      animating (sprite.position.y changes between two consecutive samples).
##
## Writes user://selftest_report.json and quits.

var _camera: Camera2D
var _elapsed := 0.0
var _creeps: Array[Enemy] = []
var _owner: Node2D = null
var _bob_samples: Array[float] = []
var _phase_samples: Array[float] = []

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const CREEP_COUNT := 12
const OWNER_POS := Vector2(0.0, 0.0)
const RADIUS := 70.0
const SAMPLE_INTERVAL := 0.15
const LATE_T := 3.5

var _last_sample_t := 0.0
var _last_screenshot_path := ""

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = OWNER_POS
	_camera.zoom = Vector2(1.1, 1.1)
	_camera.make_current()

	# Dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	# Fake owner: a bare Node2D at the origin, in the "players" group so the
	# recruit's _find_nearest_hostile() skips it (treats it as an ally), letting
	# the follow-orbit path actually run.
	_owner = Node2D.new()
	_owner.name = "Owner"
	_owner.global_position = OWNER_POS
	add_child(_owner)
	_owner.add_to_group("players")

	# Spawn creeps around the follow ring (one slot per creep so the BEFORE
	# state is "evenly spaced", and the AFTER state should also be "evenly
	# spaced" — the test verifies they STAY spread, not all collapse together).
	for i in CREEP_COUNT:
		var angle: float = TAU * float(i) / float(CREEP_COUNT)
		var e := ENEMY_SCENE.instantiate() as Enemy
		e.name = "Recruit_%d" % int(randi_range(0, 9999))
		e.add_to_group("enemies")
		add_child(e)
		e.global_position = OWNER_POS + Vector2(cos(angle), sin(angle)) * RADIUS
		e.configure(8000 + int(randi_range(0, 9999)), true, "grunt", 1.0, 1.0)
		e.is_camp_creep = true
		e.is_camp_recruit = true
		e.recruit_owner = _owner
		e.recruit_sprite = "grunt_recruit_orange"
		e._apply_sprite()
		e.contact_damage = 6.0
		e.projectile_damage = 0.0
		e.taunt_immune = false
		_creeps.append(e)

func _process(delta: float) -> void:
	_elapsed += delta
	# Sample a representative creep's sprite.position.y and recruit bob phase
	# periodically to confirm the idle bob is actually animating.
	if _elapsed - _last_sample_t >= SAMPLE_INTERVAL:
		_last_sample_t = _elapsed
		if _creeps.size() > 0:
			var e: Enemy = _creeps[0]
			if e != null and is_instance_valid(e):
				_phase_samples.append(e._recruit_bob_phase)
				if e.sprite != null:
					_bob_samples.append(e.sprite.position.y)
	if _elapsed >= LATE_T:
		_finish()

func _finish() -> void:
	_capture()
	# Measure the spread: how many distinct positions among the creeps.
	var positions: Array = []
	for e in _creeps:
		if e != null and is_instance_valid(e):
			positions.append(e.global_position)
	var distinct := 0
	for i in positions.size():
		var dup := false
		for j in positions.size():
			if i == j:
				continue
			if positions[i].distance_to(positions[j]) < 12.0:
				dup = true
				break
		if not dup:
			distinct += 1
	# Distance from owner: should be near the follow radius (70), not 0.
	var max_dist := 0.0
	var avg_dist := 0.0
	for p in positions:
		var d: float = p.distance_to(OWNER_POS)
		max_dist = maxf(max_dist, d)
		avg_dist += d
	if positions.size() > 0:
		avg_dist /= float(positions.size())
	# Bob animation: sample min/max of sprite.position.y over the run. The bob
	# drives sprite.position.y = sin(phase) * 1.5, so a range > 0.5 across the
	# run means the phase advanced and the sprite is animating.
	var bob_range := 0.0
	if _bob_samples.size() >= 2:
		var mn := _bob_samples[0]
		var mx := _bob_samples[0]
		for v in _bob_samples:
			mn = minf(mn, v)
			mx = maxf(mx, v)
		bob_range = mx - mn
	# Phase range: the bob phase should advance by ~3 rad/s over 3s = ~9 rad.
	var phase_range := 0.0
	if _phase_samples.size() >= 2:
		var mn_p := _phase_samples[0]
		var mx_p := _phase_samples[0]
		for v in _phase_samples:
			mn_p = minf(mn_p, v)
			mx_p = maxf(mx_p, v)
		phase_range = mx_p - mn_p
	# The bob is considered "animating" if EITHER the phase advanced OR the
	# sprite.position.y range is > 0.5 (the sprite is the authoritative signal
	# because it's what actually renders on screen).
	var bob_animating := (phase_range > 1.0) or (bob_range > 0.5)
	var verdict := "PASS" if distinct >= 8 and avg_dist > 30.0 and avg_dist < 140.0 and bob_animating else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "recruit_iso_test",
		"creep_count": positions.size(),
		"distinct_positions": distinct,
		"avg_dist_from_owner": avg_dist,
		"max_dist_from_owner": max_dist,
		"bob_range": bob_range,
		"phase_range": phase_range,
		"bob_samples_count": _bob_samples.size(),
	}
	# Add screenshot path so the runner copies it to results.
	var screenshot_path := _last_screenshot_path
	if screenshot_path != "":
		report["screenshot"] = screenshot_path
		report["path"] = screenshot_path
	_write_report(report)
	get_tree().quit()

func _capture() -> void:
	var img := get_viewport().get_texture().get_image()
	var out_dir := SelfTestDriver.make_output_dir("selftest_run")
	var fname := out_dir.path_join("iso_recruit_ring.png")
	if img:
		img.save_png(fname)
		# Build a user:// relative path the runner can resolve.
		var user_root := ProjectSettings.globalize_path("user://")
		while user_root.ends_with("/") or user_root.ends_with("\\"):
			user_root = user_root.left(user_root.length() - 1)
		var rel := ""
		if fname.begins_with(user_root):
			rel = fname.substr(user_root.length())
		rel = rel.replace("\\", "/")
		while rel.begins_with("/"):
			rel = rel.substr(1)
		_last_screenshot_path = "user://" + rel
		print("[RecruitIso] captured ring -> ", _last_screenshot_path)

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[RecruitIso] verdict=", str(report.get("verdict", "")))
