extends Node2D
## T3.57 — Isolated test for the Neutral Creep Camp world.
##
## This test scene verifies the core recruit-creep loop in an empty world:
##   1. Four neutral camp areas in the corners (same as recruit_areas.gd).
##   2. Neutral creeps idle-wobble in place at each camp.
##   3. When a hero approaches a camp, the creeps get excited (jump up/down).
##   4. After a "minigame" (standing in the camp for BOND_SECONDS), the creeps
##      are recruited: they become allies and follow the hero.
##
## Screenshots are captured at each phase:
##   - "idle": creeps wobbling at all 4 camps
##   - "approach": hero near one camp, creeps excited
##   - "recruited": creeps following the hero
##
## The report JSON records:
##   - wobble_offsets: sampled sprite offsets during idle (expect small oscillation)
##   - excited_offsets: sampled sprite offsets during approach (expect larger oscillation)
##   - follow_positions: sampled recruit positions relative to hero (expect close)
##   - verdict: PASS/FAIL

const BOND_SECONDS := 3.0
const BOND_RADIUS := 170.0
const CREEPS_PER_AREA := 3
const IDLE_WOBBLE_AMP := 6.0
const EXCITED_WOBBLE_AMP := 14.0
const FOLLOW_RANGE := 40.0
const FOLLOW_MIN_DIST := 20.0

var _hero: CharacterBody2D = null
var _camp_positions: Array[Vector2] = []
var _camp_sprites: Array = []  # Array of Array<Sprite2D>
var _recruited: Array = []     # recruited minion sprites
var _phase := "idle"
var _bond_timer := 0.0
var _results: Array = []
var _screenshot_count := 0
var _time := 0.0
var _sample_accum := 0.0
var _wobble_samples: Array[float] = []
var _excited_samples: Array[float] = []
var _follow_samples: Array[float] = []
var _sample_count := 0
var _cam: Camera2D = null
var _report := {}

func _ready() -> void:
	randomize()
	# Empty grass background.
	var canvas := Node2D.new()
	canvas.name = "Ground"
	add_child(canvas)
	# We'll just use the default dark background; the Node2D is a placeholder.

	# Build the 4 camp positions in the corners.
	_camp_positions = [
		Vector2(-300, -200),
		Vector2(-300,  200),
		Vector2( 300, -200),
		Vector2( 300,  200),
	]
	_build_camps()

	# Spawn a test hero (Arclight) in the center.
	_spawn_hero()

	# Camera following the hero.
	_cam = Camera2D.new()
	_cam.name = "Cam"
	add_child(_cam)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 4.0
	_cam.make_current()

	# Start the timeline.
	_phase = "idle"
	await get_tree().create_timer(1.5).timeout
	_snapshot("idle")
	_phase = "approach"
	# Walk hero toward camp 0 (top-left).
	_move_hero_to(_camp_positions[0])
	await get_tree().create_timer(2.0).timeout
	_snapshot("approach")
	# Stand in the camp for BOND_SECONDS to trigger recruitment.
	_phase = "bonding"
	await get_tree().create_timer(BOND_SECONDS + 0.5).timeout
	_phase = "following"
	# Walk hero to center to see creeps follow.
	_move_hero_to(Vector2(0, 0))
	await get_tree().create_timer(1.5).timeout
	_snapshot("following")
	# Move to camp 2 (bottom-right) to see creeps still following.
	_move_hero_to(_camp_positions[2])
	await get_tree().create_timer(1.5).timeout
	_snapshot("following2")

	_finish()


func _draw_ground(_node: Node2D) -> void:
	# Placeholder — the test scene has a simple dark background.
	pass


func _build_camps() -> void:
	var accent_colors := [
		Color("8fae6a"), Color("5ad4ff"), Color("7dbb5a"), Color("a8c8e0"),
	]
	for i in _camp_positions.size():
		var sprites: Array = []
		for slot in CREEPS_PER_AREA:
			var spr := Sprite2D.new()
			spr.z_as_relative = false
			spr.z_index = 6
			spr.scale = Vector2(2.0, 2.0)
			var base := _camp_positions[i] + Vector2.RIGHT.rotated(slot * 2.4 + i) * 26.0
			spr.position = base
			spr.set_meta("camp_base", base)
			spr.set_meta("camp_index", i)
			spr.set_meta("camp_seed", float(randf() * 10.0))
			spr.set_meta("recruited", false)
			# Simple colored circle as the creep body.
			spr.texture = _make_dot(accent_colors[i], 16)
			# Accent ring underneath.
			var ring := Sprite2D.new()
			ring.z_as_relative = false
			ring.z_index = 5
			ring.position = base
			ring.texture = _make_ring(accent_colors[i], 0.4)
			spr.set_meta("ring", ring)
			add_child(ring)
			add_child(spr)
			sprites.append(spr)
		_camp_sprites.append(sprites)


func _spawn_hero() -> void:
	_hero = CharacterBody2D.new()
	_hero.name = "Hero"
	_hero.collision_layer = 1
	_hero.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	_hero.add_child(shape)
	_hero.position = Vector2(0, 0)
	# Simple hero visual: a blue circle.
	var tex := _make_dot(Color("4488ff"), 14)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.z_index = 10
	_hero.add_child(spr)
	add_child(_hero)


func _make_dot(color: Color, radius: int) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := radius
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d <= radius - 1:
				img.set_pixel(x, y, color)
			elif d <= radius:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 0.4))
	return ImageTexture.create_from_image(img)


func _make_ring(color: Color, alpha: float) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d <= 12.0 and d >= 10.5:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_time += delta
	var dt := get_process_delta_time()
	_cam.global_position = _hero.global_position

	# Update camp sprite behavior based on phase.
	for i in _camp_sprites.size():
		for spr in _camp_sprites[i]:
			if not is_instance_valid(spr):
				continue
			if bool(spr.get_meta("recruited", false)):
				# Follow the hero.
				var target: Vector2 = _hero.global_position + Vector2.RIGHT.rotated(i * 2.4 + 0.5) * 30.0
				var dist: float = spr.global_position.distance_to(target)
				if dist > 8.0:
					spr.global_position = spr.global_position.move_toward(target, dist * 4.0 * dt)
				var ring: Sprite2D = spr.get_meta("ring")
				if is_instance_valid(ring):
					ring.global_position = spr.global_position
				continue

			var base: Vector2 = spr.get_meta("camp_base", Vector2.ZERO)
			var seed: float = float(spr.get_meta("camp_seed", 0.0))
			var t := _time + seed
			var amp := IDLE_WOBBLE_AMP
			# If hero is within BOND_RADIUS of this camp, creeps get excited.
			var hero_dist := _hero.global_position.distance_to(base)
			if hero_dist < BOND_RADIUS:
				amp = EXCITED_WOBBLE_AMP
				# Bond timer for camp 0 (the one the hero is approaching).
				if i == 0:
					_bond_timer += dt
					if _bond_timer >= BOND_SECONDS:
						_recruit_camp(i)
			var wob := Vector2(sin(t * 1.2), cos(t * 0.9)) * amp
			var excited_jump := 0.0
			if amp > IDLE_WOBBLE_AMP:
				# Excited jumping: add a vertical bounce.
				excited_jump = absf(sin(t * 3.0)) * 8.0
			spr.global_position = base + wob + Vector2(0, -excited_jump)
			var ring2: Sprite2D = spr.get_meta("ring")
			if is_instance_valid(ring2):
				ring2.global_position = base + wob

	# Sample offsets for the report.
	_sample_accum += dt
	if _sample_accum > 0.05 and _hero != null:
		_sample_accum = 0.0
		_sample_count += 1
		# Sample a few camp sprites' vertical offset from their base.
		for spr in _camp_sprites[0]:
			if not is_instance_valid(spr):
				continue
			var base: Vector2 = spr.get_meta("camp_base", Vector2.ZERO)
			var dy: float = spr.global_position.y - base.y
			if _phase == "idle":
				_wobble_samples.append(dy)
			elif _phase == "approach":
				_excited_samples.append(dy)
			elif _phase in ["following", "following2"]:
				_follow_samples.append(_hero.global_position.distance_to(spr.global_position))
		if _sample_count > 60:
			_sample_accum = -1.0  # stop sampling


func _recruit_camp(camp_index: int) -> void:
	if _recruited.has(camp_index):
		return
	_recruited.append(camp_index)
	for spr in _camp_sprites[camp_index]:
		if is_instance_valid(spr):
			spr.set_meta("recruited", true)
	print("[NeutralCampTest] Recruited camp %d (%d creeps)" % [camp_index, CREEPS_PER_AREA])


func _move_hero_to(target: Vector2) -> void:
	# Simple: teleport the hero (no physics for this test).
	_hero.position = target


func _snapshot(label: String) -> void:
	_screenshot_count += 1
	var filename := "user://neutral_camp_test_%s.png" % label
	get_viewport().get_texture().get_image().save_png(filename)
	print("[NeutralCampTest] captured %s" % filename)
	_report[label] = filename


func _finish() -> void:
	# Compute summary stats.
	var idle_min := _min_or_zero(_wobble_samples)
	var idle_max := _max_or_zero(_wobble_samples)
	var excited_min := _min_or_zero(_excited_samples)
	var excited_max := _max_or_zero(_excited_samples)
	var follow_max := _max_or_zero(_follow_samples)
	var follow_min := _min_or_zero(_follow_samples)

	var wobble_ok := idle_min < -1.0 and idle_max > 1.0
	var excited_ok := excited_min < -8.0 or excited_max < -8.0  # excited jumps go negative
	var follow_ok := follow_min < FOLLOW_RANGE
	var recruited_ok := _recruited.size() >= 1

	var passes := wobble_ok and excited_ok and follow_ok and recruited_ok
	_report["wobble"] = {"min": idle_min, "max": idle_max, "samples": _wobble_samples.size()}
	_report["excited"] = {"min": excited_min, "max": excited_max, "samples": _excited_samples.size()}
	_report["follow"] = {"min_dist": follow_min, "max_dist": follow_max, "samples": _follow_samples.size()}
	_report["recruited_camps"] = _recruited.size()
	_report["verdict"] = "PASS" if passes else "FAIL"
	_report["details"] = {
		"wobble_ok": wobble_ok,
		"excited_ok": excited_ok,
		"follow_ok": follow_ok,
		"recruited_ok": recruited_ok,
	}

	var json := JSON.stringify(_report, "  ")
	var f := FileAccess.open("user://neutral_camp_test_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
	print("[NeutralCampTest] verdict=%s shots=%d" % [_report["verdict"], _screenshot_count])
	get_tree().quit(0 if passes else 1)


func _min_or_zero(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var m: float = float(arr[0])
	for v in arr:
		if float(v) < m:
			m = float(v)
	return m


func _max_or_zero(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var m: float = float(arr[0])
	for v in arr:
		if float(v) > m:
			m = float(v)
	return m
