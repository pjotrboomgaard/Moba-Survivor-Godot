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
}

var kind: Kind = Kind.GUN
var owner_player: Player = null
var rank := 1
var _orbit := 0.0
var _cooldown := 0.0
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
	if _cooldown <= 0.0:
		_fire()
	queue_redraw()


func _fire() -> void:
	var interval := maxf(0.28, 0.72 - 0.08 * float(rank - 1))
	var power := (7.0 + 3.0 * float(rank)) * (owner_player.damage_dealt_multiplier if owner_player != null else 1.0)
	match kind:
		Kind.GUN, Kind.EMBER, Kind.THORN, Kind.SPARK:
			var target := _nearest_enemy(260.0 + 20.0 * float(rank))
			if target == null:
				return
			_cooldown = interval
			owner_player._damage_enemy(target, power)
			if kind == Kind.SPARK and target.has_method("apply_slow"):
				target.apply_slow(0.85, 0.4)
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
	draw_circle(Vector2.ZERO, 7.0 + float(rank), Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 5.5 + float(rank) * 0.4, fill)
	draw_circle(Vector2.ZERO, 2.2, Color(1.0, 1.0, 1.0, 0.85))


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
		_:
			return Color("ffe08c")
