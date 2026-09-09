extends Node2D

## Docks biome booby traps:
## - CANNON: periodic projectile volley that hits both creeps and nearby enemy heroes.
##   Fires its own projectiles (custom Area2D) so a single shell damages both groups.
## - SPIKE_PLATE: pressure plate that deals burst damage to anyone standing on it
##   when triggered, then recharges.

enum TrapKind { CANNON, SPIKE_PLATE }

var kind: TrapKind = TrapKind.CANNON
var active := false
var trap_timer := 0.0

# Cannon config
const CANNON_FIRE_INTERVAL := 3.8
const CANNON_PROJECTILE_SPEED := 440.0
const CANNON_PROJECTILE_DAMAGE := 20.0
const CANNON_RANGE := 520.0
const CANNON_TELEGRAPH := 0.7
const CANNON_PROJECTILE_COUNT := 3
const CANNON_PROJECTILE_LIFETIME := 2.2

# Spike plate config
const SPIKE_DAMAGE := 30.0
const SPIKE_TRIGGER_RADIUS := 34.0
const SPIKE_RECHARGE_TIME := 5.0
var spike_armed := true
var spike_timer := 0.0

var _trigger_area: Area2D = null
var _cannon_sprite: Sprite2D = null
var _spike_sprite: Sprite2D = null
var _telegraphing := false
var _telegraph_t := 0.0


func _ready() -> void:
	match kind:
		TrapKind.CANNON:
			_build_cannon()
		TrapKind.SPIKE_PLATE:
			_build_spike_plate()


func configure_as_cannon() -> void:
	kind = TrapKind.CANNON
	active = true
	trap_timer = randf_range(1.5, CANNON_FIRE_INTERVAL)


func configure_as_spike_plate() -> void:
	kind = TrapKind.SPIKE_PLATE
	active = true
	spike_armed = true
	spike_timer = 0.0


func _build_cannon() -> void:
	_cannon_sprite = Sprite2D.new()
	_cannon_sprite.texture = _cannon_texture()
	_cannon_sprite.z_index = 8
	_cannon_sprite.z_as_relative = false
	add_child(_cannon_sprite)
	add_to_group("docks_booby_trap")
	add_to_group("docks_cannon")


func _build_spike_plate() -> void:
	_spike_sprite = Sprite2D.new()
	_spike_sprite.texture = _spike_plate_texture()
	_spike_sprite.z_index = 2
	_spike_sprite.z_as_relative = false
	add_child(_spike_sprite)
	_trigger_area = Area2D.new()
	_trigger_area.collision_layer = 0
	# Players (layer 2, bit 1) + Enemies (layer 3, bit 2)
	_trigger_area.collision_mask = 2 | 4
	var shape := CircleShape2D.new()
	shape.radius = SPIKE_TRIGGER_RADIUS
	var collider := CollisionShape2D.new()
	collider.shape = shape
	_trigger_area.add_child(collider)
	_trigger_area.body_entered.connect(_on_body_entered)
	add_child(_trigger_area)
	add_to_group("docks_booby_trap")
	add_to_group("docks_spike_plate")


func _physics_process(delta: float) -> void:
	if not active:
		return
	match kind:
		TrapKind.CANNON:
			_process_cannon(delta)
		TrapKind.SPIKE_PLATE:
			_process_spike_plate(delta)


func _process_cannon(delta: float) -> void:
	if _telegraphing:
		_telegraph_t -= delta
		if _cannon_sprite != null:
			_cannon_sprite.modulate = Color(1.6, 1.2, 0.8)
		if _telegraph_t <= 0.0:
			_telegraphing = false
			if _cannon_sprite != null:
				_cannon_sprite.modulate = Color.WHITE
			_fire_cannon()
		return
	trap_timer -= delta
	if trap_timer <= 0.0:
		var target := _find_nearest_target(CANNON_RANGE)
		if target != null:
			_telegraphing = true
			_telegraph_t = CANNON_TELEGRAPH
			# Rotate barrel toward target
			if _cannon_sprite != null:
				var dir := global_position.direction_to(target.global_position)
				_cannon_sprite.rotation = dir.angle() + PI * 0.5
		else:
			trap_timer = 0.5


func _find_nearest_target(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := max_range * max_range
	# Creeps
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var h = enemy.get("health")
		if h != null and h.is_dead:
			continue
		var d_sq: float = global_position.distance_squared_to(enemy.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = enemy
	# In FFA, also consider rival heroes
	if GameRuntime.is_ffa():
		for player in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(player):
				continue
			if not player.get("active"):
				continue
			var p_h = player.get("health")
			if p_h != null and p_h.is_dead:
				continue
			var d_sq: float = global_position.distance_squared_to(player.global_position)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = player
	return best


func _fire_cannon() -> void:
	var target := _find_nearest_target(CANNON_RANGE)
	if target == null:
		trap_timer = CANNON_FIRE_INTERVAL
		return
	var base_dir: Vector2 = global_position.direction_to(target.global_position)
	for i in CANNON_PROJECTILE_COUNT:
		var spread := deg_to_rad(14.0) * (float(i) - float(CANNON_PROJECTILE_COUNT - 1) * 0.5)
		var dir := base_dir.rotated(spread)
		_spawn_cannon_projectile(dir)
	if not GameRuntime.is_dedicated_server():
		SoundDirector.play("charge", global_position)
	trap_timer = CANNON_FIRE_INTERVAL


## Spawn a custom shell that hits BOTH enemies and players. The shared
## SurvivorProjectile only targets one group, so the cannon gets its own tiny
## Area2D with a hit-set guard.
func _spawn_cannon_projectile(dir: Vector2) -> void:
	var proj := Area2D.new()
	proj.name = "CannonShell"
	# Shell lives on its own layer; nothing else collides with it physically.
	proj.collision_layer = 0
	# Detect Players (bit 1) + Enemies (bit 2).
	proj.collision_mask = 2 | 4
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var col := CollisionShape2D.new()
	col.shape = shape
	proj.add_child(col)
	var spr := Sprite2D.new()
	spr.texture = _cannon_ball_texture()
	spr.z_index = 12
	spr.z_as_relative = false
	proj.add_child(spr)
	var parent := get_parent()
	if parent != null:
		parent.add_child(proj)
	proj.global_position = global_position + dir * 36.0
	proj.set_meta("velocity", dir * CANNON_PROJECTILE_SPEED)
	proj.set_meta("damage", CANNON_PROJECTILE_DAMAGE)
	proj.set_meta("life", CANNON_PROJECTILE_LIFETIME)
	proj.set_meta("hit_ids", {})
	proj.body_entered.connect(_on_shell_body_entered)
	# Lifetime expiry
	proj.process_mode = Node.PROCESS_MODE_PAUSABLE
	var _t := get_tree().create_timer(CANNON_PROJECTILE_LIFETIME)
	_t.timeout.connect(func() -> void:
		if is_instance_valid(proj):
			proj.queue_free()
	)


func _on_shell_body_entered(body: Node2D) -> void:
	var proj := body.get_parent()
	if proj == null or not is_instance_valid(proj):
		return
	var meta_hit: Dictionary = proj.get_meta("hit_ids", {})
	if meta_hit.has(body.get_instance_id()):
		return
	var dmg: float = float(proj.get_meta("damage", CANNON_PROJECTILE_DAMAGE))
	var h = body.get("health")
	if h != null and not h.is_dead:
		h.take_damage(dmg)
		meta_hit[body.get_instance_id()] = true
		proj.set_meta("hit_ids", meta_hit)
	proj.queue_free()


func _process_spike_plate(delta: float) -> void:
	if not spike_armed:
		spike_timer -= delta
		if spike_timer <= 0.0:
			spike_armed = true
			_apply_spike_visual(true)


func _on_body_entered(body: Node2D) -> void:
	if kind != TrapKind.SPIKE_PLATE:
		return
	if not spike_armed:
		return
	spike_armed = false
	spike_timer = SPIKE_RECHARGE_TIME
	# Damage everything standing on the plate — creeps and players alike.
	var r_sq := (SPIKE_TRIGGER_RADIUS + 12.0) * (SPIKE_TRIGGER_RADIUS + 12.0)
	for entity in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(entity):
			continue
		var h = entity.get("health")
		if h != null and not h.is_dead:
			if global_position.distance_squared_to(entity.global_position) < r_sq:
				h.take_damage(SPIKE_DAMAGE)
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player):
			continue
		if not player.get("active"):
			continue
		if player.health.is_dead:
			continue
		if global_position.distance_squared_to(player.global_position) < r_sq:
			player.health.take_damage(SPIKE_DAMAGE)
	_apply_spike_visual(false)
	if not GameRuntime.is_dedicated_server():
		SoundDirector.play("dash", global_position)


func _apply_spike_visual(armed: bool) -> void:
	if _spike_sprite == null:
		return
	if armed:
		_spike_sprite.texture = _spike_plate_texture()
		_spike_sprite.modulate = Color.WHITE
	else:
		_spike_sprite.texture = _spike_active_texture()
		_spike_sprite.modulate = Color(1.4, 0.9, 0.9)


# --- Texture generation ---

func _cannon_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	# Base platform
	for y in range(20, 32):
		for x in range(4, 28):
			img.set_pixel(x, y, Color("4a3a2a"))
	# Barrel (pointing up in texture; rotation handles aim)
	for y in range(8, 20):
		for x in range(10, 22):
			img.set_pixel(x, y, Color("3a3a4a"))
	# Barrel highlight
	for y in range(10, 16):
		for x in range(12, 15):
			img.set_pixel(x, y, Color("5a5a6a"))
	# Muzzle
	for y in range(4, 8):
		for x in range(13, 19):
			img.set_pixel(x, y, Color("2a2a3a"))
	# Rivets
	for x in [8, 23]:
		for y in [14, 18]:
			img.set_pixel(x, y, Color("7a7a8a"))
	# Base plate
	for x in range(6, 26):
		img.set_pixel(x, 30, Color("5a4a3a"))
		img.set_pixel(x, 31, Color("3a2a1a"))
	return ImageTexture.create_from_image(img)


func _cannon_ball_texture() -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var c := Vector2(6, 6)
	for y in 12:
		for x in 12:
			var d := Vector2(x - c.x, y - c.y).length()
			if d < 5.0:
				img.set_pixel(x, y, Color("1a1a2a"))
			elif d < 5.5:
				img.set_pixel(x, y, Color("3a3a5a"))
	return ImageTexture.create_from_image(img)


func _spike_plate_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	# Flat plate
	for y in range(8, 20):
		for x in range(4, 20):
			img.set_pixel(x, y, Color("6a5a4a"))
	# Pressure button
	for y in range(10, 18):
		for x in range(8, 16):
			img.set_pixel(x, y, Color("8a7a6a"))
	# Warning stripes
	for x in range(4, 20, 4):
		img.set_pixel(x, 8, Color("ffaa00"))
		img.set_pixel(x, 19, Color("ffaa00"))
	# Edge highlight
	for x in range(4, 20):
		img.set_pixel(x, 7, Color("4a3a2a"))
		img.set_pixel(x, 20, Color("4a3a2a"))
	return ImageTexture.create_from_image(img)


func _spike_active_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	# Plate
	for y in range(8, 20):
		for x in range(4, 20):
			img.set_pixel(x, y, Color("5a4a3a"))
	# Spikes rising
	for x in range(5, 19, 3):
		for y in range(2, 10):
			img.set_pixel(x, y, Color("c0c0d0"))
			img.set_pixel(x + 1, y, Color("a0a0b0"))
	# Tips
	for x in range(5, 19, 3):
		img.set_pixel(x, 1, Color("e0e0f0"))
	# Edge
	for x in range(4, 20):
		img.set_pixel(x, 7, Color("4a3a2a"))
	return ImageTexture.create_from_image(img)
