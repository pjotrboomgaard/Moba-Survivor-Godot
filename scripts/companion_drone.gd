class_name CompanionDrone
extends Node2D

## Level-up familiar: orbits the hero and either chips enemies or shoves them.

enum Kind {
	GUN,
	PUSH,
	EMBER,
	THORN,
	SPARK,
	GALE,
	VINE,
	HEAT,
	FROST,
	LASER,
	SHIELD,
}

const KIND_FOR_UPGRADE := {
	"gun_drone": Kind.GUN,
	"push_drone": Kind.PUSH,
	"ember_sprite": Kind.EMBER,
	"thorn_sprite": Kind.THORN,
	"spark_sprite": Kind.SPARK,
	"gale_push": Kind.GALE,
	"vine_tether": Kind.VINE,
	"heat_gust": Kind.HEAT,
	"frost_drone": Kind.FROST,
	"laser_drone": Kind.LASER,
	"shield_drone": Kind.SHIELD,
}

var kind: Kind = Kind.GUN
var owner_player: Player = null
var rank := 1
var _orbit := 0.0
var _cooldown := 0.0
## Independent throttle so the drone-fire SFX can't stack into noise even if several
## companions fire on the same frame.
var _fire_sfx_cooldown := 0.0
var _slot := 0


func setup(p_owner: Player, upgrade_id: String, slot: int) -> void:
	owner_player = p_owner
	kind = int(KIND_FOR_UPGRADE.get(upgrade_id, Kind.GUN))
	_slot = slot
	_orbit = TAU * float(slot) / 3.0
	z_index = 6


func _process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player) or not owner_player.active:
		queue_free()
		return
	_orbit += delta * 2.2
	var radius := 42.0 + float(_slot) * 10.0
	global_position = owner_player.global_position + Vector2(cos(_orbit), sin(_orbit)) * radius
	_cooldown = maxf(0.0, _cooldown - delta)
	_fire_sfx_cooldown = maxf(0.0, _fire_sfx_cooldown - delta)
	if _cooldown <= 0.0:
		_fire()
	queue_redraw()


func _fire() -> void:
	## P1.5d: drones are stronger — faster fire cadence and noticeably more damage.
	var interval := maxf(0.22, 0.58 - 0.07 * float(rank - 1))
	var power := (10.0 + 4.0 * float(rank)) * (owner_player.damage_dealt_multiplier if owner_player != null else 1.0)
	match kind:
		Kind.GUN, Kind.EMBER, Kind.THORN, Kind.SPARK, Kind.FROST, Kind.LASER:
			var reach := 380.0 + 30.0 * float(rank) if kind == Kind.LASER else 300.0 + 22.0 * float(rank)
			var target := _nearest_enemy(reach)
			if target == null:
				return
			_cooldown = interval * (0.72 if kind == Kind.LASER else 1.0)
			# Audible presence: each shotting familiar fires a short, quiet zap so the
			# drone is not silent. Throttled to the fire cycle so a swarm of drones
			# never turns into a wall of noise.
			if _fire_sfx_cooldown <= 0.0:
				_fire_sfx_cooldown = 0.22
				SoundDirector.play("drone_fire", global_position)
			owner_player._damage_enemy(target, power * (1.15 if kind == Kind.LASER else 1.0))
			if kind == Kind.SPARK and target.has_method("apply_slow"):
				target.apply_slow(0.85, 0.4)
			if kind == Kind.FROST and target.has_method("apply_slow"):
				target.apply_slow(0.62, 0.85)
		Kind.SHIELD:
			_cooldown = interval + 1.15
			if owner_player.health != null and owner_player.health.has_method("add_shield"):
				owner_player.health.add_shield(10.0 + 4.0 * float(rank), 2.4)
		Kind.PUSH, Kind.GALE, Kind.HEAT:
			_cooldown = interval + 0.35
			for enemy in owner_player._enemies_in_radius(global_position, 70.0 + 8.0 * float(rank)):
				if enemy.has_method("apply_knockback"):
					var push := global_position.direction_to(enemy.global_position)
					if push.length_squared() <= 0.0:
						push = Vector2.RIGHT
					enemy.apply_knockback(push * (220.0 + 40.0 * float(rank)))
				if kind == Kind.HEAT:
					owner_player._damage_enemy(enemy, power * 0.55)
		Kind.VINE:
			_cooldown = interval + 0.2
			for enemy in owner_player._enemies_in_radius(global_position, 86.0 + 10.0 * float(rank)):
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.55, 0.9)
				owner_player._damage_enemy(enemy, power * 0.45)


func _nearest_enemy(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var dist := global_position.distance_to((enemy as Node2D).global_position)
		if dist < best_d:
			best = enemy
			best_d = dist
	return best


func _draw() -> void:
	var fill := _fill()
	var dark := fill.darkened(0.55)
	var accent := Color(0.08, 0.08, 0.1, 0.9)
	# Bigger body so it clearly reads as a drone, not a dot. Grows with rank.
	var r := 9.0 + float(rank) * 0.6
	# Drop shadow underneath (on the ground, offset down).
	var sh := r * 0.78
	draw_circle(Vector2(0.0, sh), r * 0.85, Color(0.0, 0.0, 0.0, 0.26))
	draw_circle(Vector2(0.0, sh - 1.0), r * 0.7, Color(0.0, 0.0, 0.0, 0.18))
	# Rotors: four spinning propellers (two front, two back) on little arms, like a quad.
	var spin := fmod(Time.get_ticks_msec() * 0.025 + _orbit, TAU)
	var rotor_pos := [
		Vector2(-r * 0.95, -r * 0.55), Vector2(r * 0.95, -r * 0.55),
		Vector2(-r * 0.95, r * 0.45), Vector2(r * 0.95, r * 0.45),
	]
	for rp in rotor_pos:
		var blade := Vector2(cos(spin), sin(spin)) * r * 0.5
		# Rotor disc (blurry spinning prop).
		draw_circle(rp, r * 0.5, Color(0.75, 0.78, 0.85, 0.28))
		draw_line(rp - blade, rp + blade, Color(0.25, 0.27, 0.33, 0.85), 2.0)
		draw_circle(rp, 1.8, Color(0.3, 0.32, 0.4, 0.95))
		# Arm connecting rotor to body.
		draw_line(rp, Vector2(rp.x * 0.4, rp.y * 0.4), accent, 2.0)
	# Main body: rounded hull with a lighter top and darker base.
	var body_w := r * 0.95
	var body_h := r * 0.7
	var body := Rect2(-body_w, -body_h, body_w * 2.0, body_h * 2.0)
	draw_rect(body, dark)
	draw_rect(Rect2(body.position + Vector2(1.0, 1.0), body.size - Vector2(2.0, 2.0)), fill)
	# Top highlight band.
	draw_rect(Rect2(-body_w + 1.0, -body_h + 1.0, body_w * 2.0 - 2.0, r * 0.3), fill.lightened(0.35))
	# Cockpit / sensor light (pulses).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + _orbit)
	draw_circle(Vector2(0.0, -r * 0.15), r * 0.3, Color(1.0, 1.0, 1.0, 0.55 + 0.4 * pulse))
	# Kind-specific emblem dot.
	draw_circle(Vector2(0.0, r * 0.2), r * 0.18, _fill().lightened(0.2))
	# Rank pips on the body.
	for i in rank:
		draw_rect(Rect2(r * 0.5 + float(i) * 4.0, -r * 0.1, 2.5, 2.5), Color(1.0, 0.9, 0.5, 0.95))


func _fill() -> Color:
	match kind:
		Kind.GUN:
			return Color("d8c46a")
		Kind.PUSH:
			return Color("8ab0c8")
		Kind.EMBER, Kind.HEAT:
			return Color("ff7a29")
		Kind.THORN, Kind.VINE:
			return Color("6aa83c")
		Kind.SPARK, Kind.GALE:
			return Color("7fd4ff")
		Kind.FROST:
			return Color("a8e6ff")
		Kind.LASER:
			return Color("ff4a4a")
		Kind.SHIELD:
			return Color("6aa8ff")
		_:
			return Color("ffe08c")
