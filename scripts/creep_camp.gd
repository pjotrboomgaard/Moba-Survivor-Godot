extends Node2D

## Tougher creep camp spawner (HoN-style). Spawned by main.gd after arena/player setup.
## No class_name on purpose: keep the global script-class registry clean.
##
## T3.58: In biome 6 "Creep Camps", this spawns many varied aggressive camps
## (sentinel/ranged/mixed) with XP scaling and randomized positions. In other
## biomes, it keeps the original 3-camp behavior.

const RESPAWN_INTERVAL := 120.0  # 2-minute respawn (was 45s)
const SQUAD_SIZE := 3
const MAX_ALIVE_PER_CAMP := 2
const CAMP_JITTER := 46.0
const MARKER_Z_INDEX := 3800  # above the compressed depth_z range (max ~3500) so camp rings stay visible, within Godot's 4096 cap

## Original 3-camp setup for non-Creep-Camps biomes.
const CAMP_COUNT := 3
const CAMP_ROSTERS: Array[String] = ["brute", "sentinel", "stalker"]
const CAMP_ACCENT_COLORS: Array[Color] = [
	Color("ff4d4d"),  # camp 0: red (brute)
	Color("4d9fff"),  # camp 1: blue (sentinel)
	Color("c45ec8"),  # camp 2: purple (stalker)
]
const HEALTH_RANGE := [2.0, 4.0]
const SPEED_RANGE := [0.8, 1.2]

## T3.58: Creep Camps biome (6) settings.
const CREEP_CAMPS_BIOME_ID := 6
const CREEP_CAMPS_COUNT := 10
## Camp behavior types: "sentinel" (hold position, return when provoked),
## "ranged" (keep distance, dodge, shoot projectiles), "mixed" (2-3 type mix).
const CREEP_CAMPS_TYPES: Array[String] = ["sentinel", "ranged", "mixed"]
## Camp types that can appear in the Creep Camps biome.
const CREEP_CAMPS_ROSTER_POOL: Array[Array] = [
	["brute", "sentinel"],
	["swarmling", "splitter"],
	["hexer", "brute"],
	["stalker", "hexer", "lurker"],
	["bomber", "swarmling"],
	["sentinel", "bomber"],
	["lurker", "stalker", "swarmling"],
]
## XP multiplier for camp kills in Creep Camps biome (2-3× regular).
const CREEP_CAMPS_XP_MULT := 2.5

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

	if _is_creep_camps_biome():
		_camp_positions = _build_creep_camps_positions()
		_build_markers()
		_respawn_creep_camps()
	else:
		_camp_positions = _build_camp_positions()
		_build_markers()
		_respawn_camps()
	_enabled = true

func _process(delta: float) -> void:
	if not _enabled:
		return
	_spawn_timer += delta
	if _spawn_timer >= RESPAWN_INTERVAL:
		_spawn_timer = 0.0
		if _is_creep_camps_biome():
			_respawn_creep_camps()
		else:
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

## T3.58: Returns true when the current biome is the dedicated "Creep Camps" test world.
func _is_creep_camps_biome() -> bool:
	return GameRuntime.biome_id == CREEP_CAMPS_BIOME_ID and GameRuntime.uses_biomes()

## T3.58: Randomly scatter 7 camp positions across the playfield, avoiding the
## central crater and the 4 recruitment-area corners.
func _build_creep_camps_positions() -> Array[Vector2]:
	var half: Vector2 = _arena.half_extents()
	var out: Array[Vector2] = []
	var attempts := 0
	while out.size() < CREEP_CAMPS_COUNT and attempts < 200:
		attempts += 1
		var pos := Vector2(
			randf_range(-half.x * 0.85, half.x * 0.85),
			randf_range(-half.y * 0.85, half.y * 0.85),
		)
		# Keep away from the central crater.
		if pos.length() < 500.0:
			continue
		# Keep away from the 4 recruitment-area corners.
		var too_close := false
		for rx in [-1.0, 1.0]:
			for ry in [-1.0, 1.0]:
				var corner := Vector2(rx * half.x * 0.60, ry * half.y * 0.60)
				if pos.distance_to(corner) < 400.0:
					too_close = true
		if too_close:
			continue
		# Keep camps well spread from each other.
		for existing in out:
			if pos.distance_to(existing) < 600.0:
				too_close = true
		if too_close:
			continue
		out.append(pos)
	# If we couldn't place enough, fill remaining with deterministic offsets.
	var idx := out.size()
	while out.size() < CREEP_CAMPS_COUNT:
		var angle := TAU * float(idx) / float(CREEP_CAMPS_COUNT) + randf_range(-0.3, 0.3)
		var dist := randf_range(half.x * 0.35, half.x * 0.7)
		out.append(Vector2.from_angle(angle) * dist)
		idx += 1
	return out


## T3.58: Spawn camps for the Creep Camps biome with randomized rosters and
## behavior types. Camp stats scale with the current wave.
func _respawn_creep_camps() -> void:
	_update_alive_counts()
	var wave := _current_wave()
	# Scale health/damage with wave: base 2.0–4.0 × (1 + wave * 0.15).
	var wave_scale := 1.0 + float(wave) * 0.15
	var hp_lo := HEALTH_RANGE[0] * wave_scale
	var hp_hi := HEALTH_RANGE[1] * wave_scale
	var spd_lo := SPEED_RANGE[0]
	var spd_hi := SPEED_RANGE[1]
	for i in _camp_positions.size():
		var alive := int(_camp_alive_counts.get(i, 0))
		if alive >= MAX_ALIVE_PER_CAMP:
			continue
		var missing := maxi(1, SQUAD_SIZE - alive)
		# Pick a roster and behavior type for this camp (stable per camp index).
		var roster: Array = CREEP_CAMPS_ROSTER_POOL[i % CREEP_CAMPS_ROSTER_POOL.size()]
		var camp_type: String = CREEP_CAMPS_TYPES[i % CREEP_CAMPS_TYPES.size()]
		for _slot in missing:
			var pos := _camp_positions[i] + Vector2(
				randf_range(-CAMP_JITTER, CAMP_JITTER),
				randf_range(-CAMP_JITTER, CAMP_JITTER),
			)
			# Pick a creep type from the camp's roster.
			var type_id: String = roster[randi() % roster.size()]
			var health_mult := randf_range(hp_lo, hp_hi)
			var speed_mult := randf_range(spd_lo, spd_hi)
			var is_ranged: bool = camp_type == "ranged"
			# camp_guardian=true: tanky, holds position, emits slam pulse.
			# For ranged camps, we use a higher speed_mult so they kite.
			if is_ranged:
				speed_mult = randf_range(1.0, 1.4)
			var enemy: Variant = _main._spawn_enemy_at(pos, type_id, health_mult, speed_mult, false, true)
			if enemy != null and enemy.has_method("set_meta"):
				# Tag the enemy so main.gd can grant 2-3× XP on kill.
				enemy.set_meta("camp_xp_mult", CREEP_CAMPS_XP_MULT)
				enemy.set_meta("camp_type", camp_type)
				enemy.set_meta("camp_index", i)
				# Sentinel camps: leash back to camp position if player goes too far.
				if camp_type == "sentinel" and enemy.has_method("set_meta"):
					enemy.set_meta("sentinel_home", _camp_positions[i])
			_camp_alive_counts[i] = int(_camp_alive_counts.get(i, 0)) + 1


## T3.58: Current wave number (used to scale camp stats).
func _current_wave() -> int:
	var wave_dir: Variant = _main.get("wave_director")
	if wave_dir != null:
		var w: Variant = wave_dir.get("wave")
		if w != null:
			return maxi(1, int(w))
	return 1

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
			# Camp 0 = brute (red), camp 1 = sentinel (blue), camp 2 = stalker (purple),
			# camp 3 = lurker (gold).
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
	# Biome-aware tint: camp markers glow with the world's signature color so
	# each world's camps read distinctly (volcano = ember orange, ice = cyan,
	# factory = steel blue, docks = amber, grass = leafy green).
	var biome_tint := _biome_tint()
	for i in _camp_positions.size():
		var accent: Color = CAMP_ACCENT_COLORS[i % CAMP_ACCENT_COLORS.size()]
		# Blend the camp's base accent with the biome tint (40% biome) so the
		# camp shape stays identifiable but the world reads through.
		accent = accent.lerp(biome_tint, 0.4)
		var spr := Sprite2D.new()
		spr.texture = _make_camp_marker_texture(i, accent)
		spr.position = _camp_positions[i]
		spr.z_index = MARKER_Z_INDEX
		spr.z_as_relative = false
		spr.modulate = Color.WHITE
		add_child(spr)
		_camp_markers.append(spr)


## Signature glow color per biome so camp markers read as "this world's camp".
func _biome_tint() -> Color:
	if not GameRuntime.uses_biomes():
		return Color("7dbb5a")  # grass: leafy green
	match GameRuntime.biome_id:
		1:
			return Color("ff7a29")  # volcano: ember orange
		2:
			return Color("5ad4ff")  # ice: cyan
		3:
			return Color("5a70a8")  # factory: steel blue
		4:
			return Color("d4a017")  # docks: amber
		_:
			return Color("7dbb5a")


## Each camp gets a subtle, small ground-pad indicator: a thin ring around the
## camp centre plus a tiny accent dot, tinted by the camp's accent color. Kept
## small and low-opacity so it reads as a "you can raid this camp" hint on the
## ground rather than a large floating pixel-art blob (per user request: remove
## the big pixel art under the creep camps).
func _make_camp_marker_texture(_camp_index: int, accent: Color) -> ImageTexture:
	var size := 44
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var p := Vector2(x - c, y - c)
			var d := p.length()
			var a := 0.0
			# Thin ground ring (the camp "pad").
			if d <= 18.0 and d >= 15.0:
				a = 0.30
			# Tiny accent centre dot.
			elif d <= 3.0:
				a = 0.55
			if a > 0.0:
				var col := accent.lerp(Color.WHITE, 0.25)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_main = null
		_arena = null
