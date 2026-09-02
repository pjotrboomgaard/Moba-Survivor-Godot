class_name SummonEntity
extends Node2D

## A short-lived summoned ally spawned by a SUMMON_SPIRIT ability
## (Steam Turret, Voodoo Wards, Toxin Ward, Sapling Turret, Essence Link).
## Anchors in place, spits at the closest enemy in range every few seconds, expires.

signal expired(entity: SummonEntity)

@export var lifetime: float = 12.0
## Per-bolt damage scaled down so the turret reads as "chips health away constantly",
## not as a secondary nuke. The hero's own cadence does the heavy lifting.
@export var power: float = 8.0
## Fast attack cadence — we want to see a stream of bolts, not a slow drip.
@export var attack_interval: float = 0.32
@export var range: float = 380.0
@export var damage_type: int = 0  # PlayerClass.DamageType.PHYSICAL

var ability_id: String = ""
var owner_peer_id: int = 0
var owner_damage_type: int = 0
var tint: Color = Color.WHITE
var time_left: float = 0.0
var attack_timer: float = 0.0
## Explodes when an enemy steps inside `trigger_radius`; set for spider-mine style summons.
var trigger_radius: float = 0.0
var explosion_radius: float = 0.0
## Extra arm time after deploy so mines never pop the instant they land on a pack.
var arm_delay: float = 0.0
## Bosses walking over an armed mine take this many times normal blast damage.
var boss_damage_mult: float = 1.0
## Launch-away impulse applied to every enemy caught by `_explode`; 0 means no displacement.
var explosion_knockback: float = 0.0
var _exploded := false
var _arm_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shadow: Polygon2D = $Shadow


func setup(p_ability_id: String, p_owner_peer_id: int, p_power: float, p_lifetime: float, p_interval: float, p_tint: Color) -> void:
	ability_id = p_ability_id
	owner_peer_id = p_owner_peer_id
	power = p_power
	lifetime = p_lifetime
	attack_interval = p_interval
	tint = p_tint
	time_left = lifetime
	# Materialize grace period: turret pops in with a deploy animation before firing.
	_deploy_timer = 0.45
	_arm_timer = maxf(0.0, arm_delay)
	attack_timer = _deploy_timer + attack_interval * 0.5
	var sprite := _sprite_node()
	sprite.scale = Vector2(0.4, 0.4)
	# Dedicated world bodies for Tobor turret/mines; other summons keep the ability icon.
	var texture := SpriteLibrary.texture_for(_world_sprite_name())
	if texture == null:
		texture = SpriteLibrary.texture_for(ability_id)
	if texture != null:
		sprite.texture = texture
		var body := _body_modulate()
		sprite.modulate = Color(body.r, body.g, body.b, 0.0)


var _deploy_timer: float = 0.0


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		expired.emit(self)
		queue_free()
		return
	# Fade out over the last 2 seconds so it visibly pops instead of vanishing.
	if time_left < 2.0:
		modulate.a = 0.4 + 0.6 * (time_left / 2.0)
	# Deploy animation: pop the sprite up + fade in over the first ~0.45s.
	if _deploy_timer > 0.0:
		_deploy_timer = maxf(0.0, _deploy_timer - delta)
		var t := 1.0 - _deploy_timer / 0.45
		var sprite := _sprite_node()
		sprite.scale = Vector2(0.4 + t * 2.6, 0.4 + t * 2.6)
		sprite.modulate = Color(_body_modulate().r, _body_modulate().g, _body_modulate().b, t)
		if _deploy_timer <= 0.0:
			sprite.scale = Vector2(3.4, 3.4) if _is_mine() else Vector2(3.0, 3.0)
			sprite.modulate = _body_modulate()
	if _is_mine():
		if _arm_timer > 0.0:
			_arm_timer = maxf(0.0, _arm_timer - delta)
		elif _deploy_timer <= 0.0:
			_check_mine_trigger()
	elif _deploy_timer <= 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_interval
			_strike_nearest()
	_update_muzzle_glow()


func _is_mine() -> bool:
	return trigger_radius > 0.0 and not _exploded


func _check_mine_trigger() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) > _overlap_reach(enemy as Node2D):
			continue
		_explode()
		return


func _overlap_reach(enemy: Node2D) -> float:
	var reach := trigger_radius
	if "body_radius" in enemy:
		reach += float(enemy.body_radius) * 0.85
	return reach


func _world_sprite_name() -> String:
	match ability_id:
		"tobor_steam_turret":
			return "tobor_turret_body"
		"tobor_spider_mines":
			return "tobor_mine_body"
		_:
			return ability_id


func _body_modulate() -> Color:
	if _world_sprite_name() != ability_id:
		return Color.WHITE
	return tint


func _explode() -> void:
	_exploded = true
	_muzzle_t = 0.4
	AudioService.play("explosion")
	var blast := explosion_radius if explosion_radius > 0.0 else trigger_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var n := enemy as Node2D
		if global_position.distance_to(n.global_position) > blast:
			continue
		var dmg := power
		if n is Enemy and (n as Enemy).is_boss and boss_damage_mult > 1.0:
			dmg *= boss_damage_mult
		if n.has_method("vulnerability_multiplier"):
			dmg *= n.vulnerability_multiplier()
		var health := n.get_node_or_null("HealthComponent")
		if health != null and health.has_method("take_damage"):
			health.take_damage(dmg, self)
		if explosion_knockback > 0.0 and n.has_method("apply_knockback"):
			var push_dir := global_position.direction_to(n.global_position)
			if push_dir.length_squared() <= 0.0:
				push_dir = Vector2.RIGHT
			n.apply_knockback(push_dir * explosion_knockback)
	expired.emit(self)
	queue_free()


var _muzzle_t: float = 0.0


## Track recoil flash for the fire-cycle; ticked in _strike_nearest.
func _update_muzzle_glow() -> void:
	if _muzzle_t > 0.0:
		_muzzle_t = maxf(0.0, _muzzle_t - 0.016)
	queue_redraw()


func _draw() -> void:
	# Ground plate under the sprite — makes the turret read "planted" rather than floating.
	var plate := PackedVector2Array()
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI / 4.0
		plate.append(Vector2(cos(a), sin(a)) * 12.0 + Vector2(0, 8))
	draw_colored_polygon(plate, Color(0.0, 0.0, 0.0, 0.35))
	if _is_mine() or (trigger_radius > 0.0 and _exploded):
		var armed := _arm_timer <= 0.0 and _deploy_timer <= 0.0
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
		var ring_color := Color(1.0, 0.35, 0.12, 0.55 * pulse) if armed else Color(0.95, 0.75, 0.2, 0.28 + 0.18 * pulse)
		draw_arc(Vector2.ZERO, trigger_radius, 0.0, TAU, 28, ring_color, 2.0 if armed else 1.4, true)
		if not armed:
			draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.3, 0.45))
	# Muzzle burst on top of the sprite while we're firing.
	if _muzzle_t > 0.0:
		var glow := _muzzle_t * 4.0
		for ring in 3:
			var r := 6.0 + float(ring) * 5.0
			var alpha := glow * (1.0 - float(ring) * 0.3)
			draw_arc(Vector2(0, -14), r, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, alpha * 0.7), 2.0, true)
		draw_circle(Vector2(0, -14), 3.0 * glow, Color(1.0, 1.0, 1.1, glow * 0.9))


func _strike_nearest() -> void:
	var best: Node2D = null
	var best_dist := range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var n := enemy as Node2D
		var dist := global_position.distance_to(n.global_position)
		if dist < best_dist:
			best = n
			best_dist = dist
	if best == null:
		return
	# Muzzle flash + a fat visible bolt so you can tell the turret is actually shooting.
	_muzzle_t = 0.32
	_flash(best)
	var health := best.get_node_or_null("HealthComponent")
	if health != null and health.has_method("take_damage"):
		health.take_damage(power, self)


func _flash(target: Node2D) -> void:
	var from_pos := global_position + Vector2(0, -14)
	var to_pos := target.global_position + Vector2(0, -8)
	# Outer glow — fat, low alpha.
	var outer := Line2D.new()
	outer.default_color = Color(tint.r, tint.g, tint.b, 0.55)
	outer.width = 7.0
	outer.add_point(from_pos)
	outer.add_point(to_pos)
	outer.z_index = 480
	get_tree().current_scene.add_child(outer)
	# Hot core — thin, bright.
	var core := Line2D.new()
	core.default_color = Color(1.0, 1.0, 0.95, 0.95)
	core.width = 2.4
	core.add_point(from_pos)
	core.add_point(to_pos)
	core.z_index = 481
	get_tree().current_scene.add_child(core)
	# Tiny impact star at the landing point.
	var burst := Line2D.new()
	burst.default_color = Color(tint.r, tint.g, tint.b, 0.8)
	burst.width = 3.0
	burst.z_index = 482
	for k in 4:
		var a := TAU * float(k) / 4.0
		burst.add_point(to_pos + Vector2(cos(a), sin(a)) * 1.0)
		burst.add_point(to_pos + Vector2(cos(a), sin(a)) * 9.0)
	get_tree().current_scene.add_child(burst)
	# Fade all three out together; the outer lingers a hair longer so you can read the path.
	for pair in [[outer, 0.20], [core, 0.14], [burst, 0.10]]:
		var target_line: Line2D = pair[0]
		var fade_time: float = pair[1]
		var tw := target_line.create_tween()
		tw.tween_property(target_line, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(target_line.queue_free)


func _on_area_entered(area: Area2D) -> void:
	# Bestiary idle behavior: pass through other actors; future pass could add collision.
	pass


## Resolves the Sprite2D whether called before or after @onready/_ready ran.
func _sprite_node() -> Sprite2D:
	return _sprite if is_instance_valid(_sprite) else get_node("Sprite2D") as Sprite2D
