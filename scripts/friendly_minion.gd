extends Node2D

## A friendly creep summoned as a quest reward. Follows the local player and attacks
## nearby enemies for a limited time. Town pets (wolf/raven/fox) render with their own
## pixel art and are tougher combat companions that can also target enemy heroes and
## other teams' minions.

const LIFETIME := 30.0
const FOLLOW_RADIUS := 90.0
const ATTACK_RANGE := 60.0
const MOVE_SPEED := 320.0
const ATTACK_DAMAGE := 18.0
const ATTACK_INTERVAL := 0.6
const DAMAGE_RADIUS := 44.0

var _main: Node = null
var _life := LIFETIME
var _attack_cd := 0.0
var _sprite: Sprite2D = null
var _owner_peer_id := 1
var _wander_offset := Vector2.ZERO
var _wander_t := 0.0

## Optional animal art id ("wolf"/"raven"/"fox") so town pets render with their
## own pixel art instead of the generic teal circle.
var art_id := ""
## Town pets are tougher combat companions (higher hp + damage) so they can
## actually reach and trade with enemy heroes rather than die on arrival.
var hp := 60.0
var attack_damage: float = ATTACK_DAMAGE
var attack_interval: float = ATTACK_INTERVAL
## Town minions join the owner's team: they can attack enemy heroes and other
## friendly minions. Toggle per-minion so the default dance-reward minions keep
## the legacy enemies-only behaviour.
var can_attack_heroes := false


func _ready() -> void:
	z_as_relative = false
	z_index = 5
	add_to_group("friendly_minion")
	_build_sprite()


func configure(main: Node, owner_peer_id: int, spawn_pos: Vector2) -> void:
	_main = main
	_owner_peer_id = owner_peer_id
	global_position = spawn_pos


## Override the minion's remaining lifetime (town pets stick around longer than
## the default 30s dance-reward minions).
func set_lifetime(seconds: float) -> void:
	_life = seconds


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.z_as_relative = false
	_sprite.z_index = 5
	# Town pets render with their own animal pixel art; everything else keeps the
	# generic teal circle.
	if art_id != "":
		var tex: Texture2D = SideQuestArt.texture(art_id)
		if tex != null:
			_sprite.texture = tex
			_sprite.scale = Vector2.ONE
			add_child(_sprite)
			return
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var c := Vector2(6, 6)
	for y in 12:
		for x in 12:
			var d := Vector2(x - c.x, y - c.y).length()
			if d <= 5:
				img.set_pixel(x, y, Color(0.4, 0.95, 0.85, 1.0))
			elif d <= 5.8:
				img.set_pixel(x, y, Color(0.2, 0.6, 0.55, 0.5))
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.scale = Vector2(3.6, 3.6)
	add_child(_sprite)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _main == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var player := _owner_player()
	if player == null:
		return
	# Wander offset so minions don't stack exactly on the player.
	_wander_t += delta
	if _wander_t > 3.0:
		_wander_t = 0.0
		_wander_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, FOLLOW_RADIUS)
	var target := player.global_position + _wander_offset
	var to_target := target - global_position
	var dist := to_target.length()
	if dist > 4.0:
		var dir := to_target.normalized()
		# Only chase if a bit far; otherwise drift into place.
		var step := MOVE_SPEED if dist > 60.0 else MOVE_SPEED * 0.4
		global_position += dir * step * delta
	# Attack nearest enemy in range.
	if _attack_cd <= 0.0:
		var foe := _nearest_enemy()
		if foe != null and global_position.distance_to(foe.global_position) <= ATTACK_RANGE:
			_hit(foe)


func _owner_player() -> Node2D:
	if _main == null:
		return null
	var players: Dictionary = _main.get("players")
	if players == null:
		return null
	var found = players.get(_owner_peer_id)
	return found as Node2D


func _nearest_enemy() -> Node2D:
	if _main == null:
		return null
	var best: Node2D = null
	var best_d := INF
	var enemies: Dictionary = _main.get("enemies")
	if enemies != null:
		for e in enemies.values():
			if not is_instance_valid(e) or not (e is Node2D):
				continue
			var enemy: Node2D = e
			if bool(enemy.get("is_boss")):
				continue
			var d := global_position.distance_to(enemy.global_position)
			if d < best_d:
				best_d = d
				best = enemy
	# Town minions can also target enemy heroes and other friendly minions.
	if can_attack_heroes:
		var owner := _owner_player()
		for candidate in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(candidate) or not (candidate is Node2D):
				continue
			var p: Node2D = candidate
			if owner != null and p == owner:
				continue
			var p_health: Node = p.get_node_or_null("HealthComponent")
			if p_health == null:
				continue
			var is_dead: bool = bool(p_health.get("is_dead"))
			if is_dead:
				continue
			var d := global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p
		# Also target other teams' friendly minions.
		for candidate in get_tree().get_nodes_in_group("friendly_minion"):
			if not is_instance_valid(candidate) or not (candidate is Node2D):
				continue
			var m: Node2D = candidate
			if m == self:
				continue
			var m_owner_id: Variant = m.get("_owner_peer_id")
			if m_owner_id != null and int(m_owner_id) == _owner_peer_id:
				continue  # don't fight our own team's minions
			var d := global_position.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = m
	return best


func _hit(foe: Node2D) -> void:
	_attack_cd = attack_interval
	var target_health: Node = foe.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("take_damage"):
		target_health.call("take_damage", attack_damage, self)
	else:
		# Some nodes (e.g. other minions) expose take_damage directly instead of
		# carrying a HealthComponent child.
		if foe.has_method("take_damage") and foe != self:
			foe.call("take_damage", attack_damage)


## Take damage from enemy heroes/creeps. Town pets have real HP so they can
## be killed in combat — when they drop to 0 they die and fade.
func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		_die()


func _die() -> void:
	if _sprite != null:
		var fade_tween := create_tween()
		fade_tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
		fade_tween.finished.connect(queue_free)
	# Stop acting immediately.
	_life = 0.0


func _draw() -> void:
	if _sprite == null:
		return
	var pulse := 0.5 + 0.5 * sin(_life * 6.0)
	# Fade out during last 3 seconds.
	var fade := clampf(_life / 3.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.8, 0.7, 0.18 * pulse * fade))
