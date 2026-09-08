extends Node2D

## A story NPC (kid, villager, etc.) that runs around the map, gets attacked by creeps,
## and needs the player to save them. Has a health bar, can die, and rewards the player
## on rescue.

signal rescued(npc: Node2D)
signal died(npc: Node2D)

const PIXEL_ZOOM := 3.6
const ATTACK_RANGE := 80.0
const FLEE_RANGE := 260.0
const WANDER_SPEED := 120.0
const FLEE_SPEED := 200.0

var npc_type := "kid"
var max_health := 60.0
var health := 60.0
var is_rescued := false
var is_dead := false
var _main: Node = null
var _sprite: Sprite2D = null
var _health_bar: ProgressBar = null
var _attacker: Enemy = null
var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _alive := true


func _ready() -> void:
	z_as_relative = false
	z_index = 6
	add_to_group("story_npc")
	add_to_group("players")
	_build_visuals()
	_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)


func configure(npc_kind: String, npc_health: float, main: Node) -> void:
	npc_type = npc_kind
	max_health = npc_health
	health = npc_health
	_main = main
	_build_visuals()
	queue_redraw()


func _build_visuals() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if _health_bar != null:
		_health_bar.queue_free()
		_health_bar = null

	# Body: a simple colored circle (kid = smaller, villager = bigger)
	var body_size := 10.0 if npc_type == "kid" else 14.0
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.z_as_relative = false
	_sprite.z_index = 7
	# Use a generated circle texture
	var sz := int(body_size * 2)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(body_size, body_size)
	var color := Color(1.0, 0.85, 0.55) if npc_type == "kid" else Color(0.65, 0.85, 0.65)
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x - center.x, y - center.y).length()
			if d <= body_size:
				img.set_pixel(x, y, color)
			elif d <= body_size + 1:
				img.set_pixel(x, y, Color(0.2, 0.15, 0.1, 0.5))
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.scale = Vector2(PIXEL_ZOOM * 0.5, PIXEL_ZOOM * 0.5)
	add_child(_sprite)

	# Health bar above the NPC
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.z_as_relative = false
	_health_bar.z_index = 8
	_health_bar.position = Vector2(-18, -28)
	_health_bar.size = Vector2(36, 6)
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(36, 6)
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.15, 0.1, 0.1, 0.8)
	var style_fill := StyleBoxFlat.new()
	style_fill.bg_color = Color(0.4, 0.9, 0.4, 1.0)
	_health_bar.add_theme_stylebox_override("background", style_bg)
	_health_bar.add_theme_stylebox_override("fill", style_fill)
	_health_bar.max_value = max_health
	_health_bar.value = health
	add_child(_health_bar)


func _process(delta: float) -> void:
	if is_dead or is_rescued:
		return
	if _main == null:
		return

	# Find nearest enemy
	_update_target()

	# Movement: flee from enemies, wander otherwise
	var pos := global_position
	var target_pos := global_position
	if _attacker != null and _attacker.global_position.distance_to(pos) < FLEE_RANGE:
		var flee_dir := pos.direction_to(Vector2.ZERO)
		# Flee away from attacker
		flee_dir = (pos - _attacker.global_position).normalized()
		pos += flee_dir * FLEE_SPEED * delta
	elif _wander_timer <= 0.0:
		_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
		_wander_timer = randf_range(2.0, 5.0)
	else:
		_wander_timer -= delta
		pos += _wander_dir * WANDER_SPEED * delta

	# Clamp to arena
	if _main != null and _main.get("arena") is Arena:
		var arena := _main.arena as Arena
		var half := arena.half_extents() - Vector2(60.0, 60.0)
		pos.x = clampf(pos.x, -half.x, half.x)
		pos.y = clampf(pos.y, -half.y, half.y)

	global_position = pos

	# Update health bar
	if _health_bar != null:
		_health_bar.value = health
		var frac := health / max_health
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.4, 0.9, 0.4, 1.0) if frac > 0.5 else Color(0.9, 0.7, 0.2, 1.0) if frac > 0.25 else Color(0.9, 0.3, 0.2, 1.0)
		_health_bar.add_theme_stylebox_override("fill", fill)


func _update_target() -> void:
	var nearest: Enemy = null
	var nearest_d := INF
	if _main == null:
		return
	var enemies: Dictionary = _main.get("enemies")
	if enemies == null:
		return
	for e in enemies.values():
		if not is_instance_valid(e) or not (e is Enemy):
			continue
		var enemy := e as Enemy
		if enemy.is_boss:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < ATTACK_RANGE:
			# Enemy is attacking us
			health -= enemy.contact_damage * 0.5
			_attacker = enemy
		if d < nearest_d:
			nearest_d = d
			nearest = enemy
	# Check player proximity (rescue)
	var player := _local_player()
	if player != null and player.global_position.distance_to(global_position) < 60.0:
		is_rescued = true
		_on_rescued()
	if health <= 0.0 and not is_dead:
		is_dead = true
		_on_died()


func _local_player() -> Player:
	if _main == null:
		return null
	var players: Dictionary = _main.get("players")
	if players == null:
		return null
	for p in players.values():
		if is_instance_valid(p) and (p as Player).is_local_player:
			return p as Player
	return null


func _on_rescued() -> void:


func _on_rescued() -> void:
	# Happy jump animation
	if _sprite != null:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", _sprite.scale * 1.5, 0.3)
		tween.tween_property(_sprite, "scale", _sprite.scale, 0.3)
	# Reward
	var player := _local_player()
	if player != null:
		var gold_reward := 50 if npc_type == "kid" else 35
		var xp_reward := 40 if npc_type == "kid" else 30
		player.add_gold(gold_reward)
		player.add_xp(xp_reward)
		# Show reward text
		_show_reward_text(player, gold_reward, xp_reward)
	rescued.emit(self)
	# Fade out
	if _sprite != null:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate:a", 0.0, 1.5)
		tween.tween_property(_health_bar, "modulate:a", 0.0, 1.5)
		tween.tween_callback(queue_free)


func _on_died() -> void:
	# Death animation: shrink and fade
	if _sprite != null:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", _sprite.scale * 0.3, 0.5)
		tween.tween_property(_sprite, "modulate:a", 0.0, 0.5)
		if _health_bar != null:
			tween.parallel().tween_property(_health_bar, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	died.emit(self)


func _show_reward_text(player: Node2D, gold: int, xp: int) -> void:
	# Create a floating text label
	var label := Label.new()
	label.text = "+%d gold + %d XP" % [gold, xp]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	label.position = Vector2(0, -40)
	label.z_index = 20
	_main.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60.0, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)
