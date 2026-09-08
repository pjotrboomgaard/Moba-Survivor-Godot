extends Node2D

## Tougher creep camp spawner (HoN-style). Spawned by main.gd after arena/player setup.
## No class_name on purpose: keep the global script-class registry clean.

const RESPAWN_INTERVAL := 120.0  # 2-minute respawn (was 45s)
const SQUAD_SIZE := 3
const MAX_ALIVE_PER_CAMP := 2
const CAMP_JITTER := 46.0
const MARKER_Z_INDEX := 2000  # above the depth_z range (~400+int(y)) so camp rings stay visible

## 3 unique camps, each with its own elite roster, marker art and accent color.
## Each camp guardian is tanky (takes reduced damage), holds position, and emits an
## undodgeable slam pulse, so engaging a camp is a real risk/reward choice.
const CAMP_COUNT := 3
const CAMP_ROSTERS: Array[String] = ["brute", "sentinel", "stalker"]
const CAMP_ACCENT_COLORS: Array[Color] = [
	Color("ff4d4d"),  # camp 0: red (brute)
	Color("4d9fff"),  # camp 1: blue (sentinel)
	Color("c45ec8"),  # camp 2: purple (stalker)
]
const HEALTH_RANGE := [2.0, 4.0]
const SPEED_RANGE := [0.8, 1.2]

var _main: Node = null
var _arena: Node2D = null
var _camp_positions: Array[Vector2] = []
var _camp_markers: Array = []
var _camp_alive_counts: Dictionary = {}
var _spawn_timer := 0.0
var _enabled := false

func start(main_node: Node, arena_node: Node2D) -> void:
	_main = main_node
	_arena = arena_node

	if _main == null or _arena == null:
		push_warning("CreepCamp: main or arena is null, camp spawner disabled.")
		return

	if not _main.has_method("_spawn_enemy_at"):
		push_warning("CreepCamp: main._spawn_enemy_at missing, camp spawner disabled.")
		return

	if not _arena.has_method("half_extents"):
		push_warning("CreepCamp: arena.half_extents missing, camp spawner disabled.")
		return

	_camp_positions = _build_camp_positions()
	_build_markers()

	for i in _camp_positions.size():
		_camp_alive_counts[i] = 0

	# Initial fill so camps aren't empty at game start.
	_respawn_camps()
	_enabled = true

func _process(delta: float) -> void:
	if not _enabled:
		return
	_spawn_timer += delta
	if _spawn_timer >= RESPAWN_INTERVAL:
		_spawn_timer = 0.0
		_respawn_camps()


## Public: return the positions of camps that still have living elites
## (i.e. camps worth fighting). Used by the selftest bot to seek camps.
func active_camp_positions() -> Array[Vector2]:
	if not _enabled:
		return []
	var out: Array[Vector2] = []
	for i in _camp_positions.size():
		var alive := int(_camp_alive_counts.get(i, 0))
		if alive > 0 and alive < MAX_ALIVE_PER_CAMP:
			out.append(_camp_positions[i])
	return out

func _build_camp_positions() -> Array[Vector2]:
	var half: Vector2 = _arena.half_extents()
	if half.x < 80.0 or half.y < 80.0:
		half = Vector2(2360.0, 1560.0) * 0.5
	# 3 fixed camps at distinct corners of the arena, well spread so the
	# player has to choose which one to raid.
	return [
		Vector2(-half.x * 0.55, -half.y * 0.55),
		Vector2( half.x * 0.60, -half.y * 0.30),
		Vector2(-half.x * 0.30,  half.y * 0.55),
	]

func _respawn_camps() -> void:
	_update_alive_counts()
	for i in _camp_positions.size():
		var alive := int(_camp_alive_counts.get(i, 0))
		if alive >= MAX_ALIVE_PER_CAMP:
			continue
		var missing := maxi(1, SQUAD_SIZE - alive)
		for _slot in missing:
			var pos := _camp_positions[i] + Vector2(
				randf_range(-CAMP_JITTER, CAMP_JITTER),
				randf_range(-CAMP_JITTER, CAMP_JITTER),
			)
			# Each camp has its own unique guardian type (CAMP_ROSTERS[i]).
			# Camp 0 = brute (red), camp 1 = sentinel (blue), camp 2 = stalker (purple).
			var type_id := CAMP_ROSTERS[i % CAMP_ROSTERS.size()]
			var health_mult := randf_range(HEALTH_RANGE[0], HEALTH_RANGE[1])
			var speed_mult := randf_range(SPEED_RANGE[0], SPEED_RANGE[1])
			# camp_guardian=true: tanky (takes 60% dmg), holds position,
			# emits undodgeable slam pulse, doesn't chase past leash radius.
			_main._spawn_enemy_at(pos, type_id, health_mult, speed_mult, false, true)
			_camp_alive_counts[i] = int(_camp_alive_counts.get(i, 0)) + 1

func _update_alive_counts() -> void:
	for i in _camp_positions.size():
		var alive := 0
		var enemies_ref: Variant = _main.get("enemies")
		if enemies_ref is Dictionary:
			for enemy in (enemies_ref as Dictionary).values():
				if not is_instance_valid(enemy):
					continue
				var hp = enemy.get("health")
				if hp == null or hp.get("is_dead"):
					continue
				if enemy.global_position.distance_to(_camp_positions[i]) < 140.0:
					alive += 1
		_camp_alive_counts[i] = alive

func _build_markers() -> void:
	for i in _camp_positions.size():
		var accent: Color = CAMP_ACCENT_COLORS[i % CAMP_ACCENT_COLORS.size()]
		var spr := Sprite2D.new()
		spr.texture = _make_camp_marker_texture(i, accent)
		spr.position = _camp_positions[i]
		spr.z_index = MARKER_Z_INDEX
		spr.z_as_relative = false
		spr.modulate = Color.WHITE
		add_child(spr)
		_camp_markers.append(spr)


## Each camp gets a distinct pixel-art marker: camp 0 = diamond (red/brute),
## camp 1 = square (blue/sentinel), camp 2 = triangle (purple/stalker).
## All sit on a soft radial glow so they read as "camp" from the minimap distance.
func _make_camp_marker_texture(camp_index: int, accent: Color) -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := size / 2.0
	var cy := size / 2.0
	var half := size / 2.0
	for y in size:
		for x in size:
			var p := Vector2(x - cx, y - cy)
			var d := p.length()
			# Soft outer glow (radial).
			var glow_a := 0.0
			if d <= half and d >= half - 10.0:
				glow_a = 0.18
			elif d < half - 10.0:
				glow_a = 0.10
			# Core shape by camp index.
			var core_a := 0.0
			var core_c: Color = accent
			match camp_index % 3:
				0:
					# Diamond: |x - cx| + |y - cy| <= r
					if absf(p.x) + absf(p.y) <= 16.0:
						core_a = 0.95
						core_c = accent.lerp(Color.WHITE, 0.25)
				1:
					# Square with a notch.
					if absf(p.x) <= 14.0 and absf(p.y) <= 14.0:
						core_a = 0.95
						core_c = accent.lerp(Color.WHITE, 0.2)
				2:
					# Upward triangle.
					if p.y >= -14.0 and p.y <= 14.0 and absf(p.x) <= (14.0 - absf(p.y + 14.0) * 0.5):
						core_a = 0.95
						core_c = accent.lerp(Color.WHITE, 0.3)
			var a := maxf(glow_a, core_a)
			if a > 0.0:
				var c: Color = accent if core_a > 0.0 else Color(0.9, 0.8, 1.0, 1.0)
				c = c.lerp(core_c, core_a)
				img.set_pixel(x, y, c if a > 0.5 else Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_main = null
		_arena = null
