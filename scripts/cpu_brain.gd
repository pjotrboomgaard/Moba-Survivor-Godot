class_name CpuBrain
extends RefCounted

## Offline co-op stand-in. Fills move/aim/attack so a CPU hero plays its role
## without reading the local player's WASD. Movement is smoothed and held in a
## wide comfort band so allies don't jitter every physics frame.

const MOVE_SCALE := 0.46
const TARGET_LOCK_SEC := 1.25
const SMOOTH_RATE := 2.4
const FORMATION_HOLD := 88.0
const TANK_HOLD := 58.0
const KITE_NEAR := 130.0
const KITE_FAR_PAD := 110.0


static func think(player: Player, delta: float = 0.016) -> Dictionary:
	var result := {
		"move": Vector2.ZERO,
		"aim": player.global_position + player.facing_direction * 80.0,
		"attack": false,
		"ability": false,
		"secondary": false,
		"ability_slots": [true, true, true, true],
	}
	if player == null:
		return result
	if not player.active or player.health.is_dead:
		player.cpu_smoothed_move = Vector2.ZERO
		return result

	var downed := _downed_ally(player)
	if downed != null:
		result.aim = downed.global_position
		result.move = _smooth_move(player, _steer_towards(player.global_position, downed.global_position, 28.0), delta)
		return result

	var enemy := _locked_enemy(player, delta)
	var ally := _human_ally(player)
	if enemy == null:
		if ally != null:
			result.move = _smooth_move(player, _steer_towards(player.global_position, ally.global_position, 110.0), delta)
			result.aim = ally.global_position
		else:
			result.move = _smooth_move(player, Vector2.ZERO, delta)
		return result

	result.attack = true
	result.aim = enemy.global_position
	var distance := player.global_position.distance_to(enemy.global_position)
	if distance < 90.0 and player.has_active_item():
		result.ability = true
	if player.secondary_cooldown <= 0.0:
		var ally_hurt := ally != null and ally.health.current_health < ally.health.max_health * 0.85
		result.secondary = ally_hurt or distance < 210.0
		if ally_hurt:
			result.aim = ally.global_position

	var desired := _desired_move(player, enemy, ally, distance)
	result.move = _smooth_move(player, desired, delta)
	return result


static func _desired_move(player: Player, enemy: Node2D, ally: Player, distance: float) -> Vector2:
	var home := _formation_home(player, ally, enemy)
	var home_gap := player.global_position.distance_to(home)
	if home_gap > FORMATION_HOLD * 1.7:
		return _steer_towards(player.global_position, home, FORMATION_HOLD)

	match player.weapon_kind:
		PlayerClass.Weapon.CONE_SLAM:
			return _steer_towards(player.global_position, enemy.global_position, TANK_HOLD)
		PlayerClass.Weapon.MENDING_BOLT:
			if home_gap > FORMATION_HOLD:
				return _steer_towards(player.global_position, home, FORMATION_HOLD)
			return Vector2.ZERO
		_:
			var ideal := player.attack_range * 0.55
			if distance > ideal + KITE_FAR_PAD:
				return player.global_position.direction_to(enemy.global_position)
			if distance < KITE_NEAR:
				return enemy.global_position.direction_to(player.global_position) * 0.55
			if home_gap > FORMATION_HOLD:
				return _steer_towards(player.global_position, home, FORMATION_HOLD)
			return Vector2.ZERO


static func _formation_home(player: Player, ally: Player, enemy: Node2D) -> Vector2:
	var anchor := ally.global_position if ally != null else player.global_position
	var toward := player.facing_direction
	if enemy != null:
		toward = anchor.direction_to(enemy.global_position)
	if toward.length_squared() <= 0.0:
		toward = Vector2.RIGHT
	var side := toward.orthogonal()
	match player.class_id:
		"bulwark":
			return anchor + toward * 72.0
		"arclight":
			return anchor + toward * 36.0 + side * 108.0
		"tobor":
			return anchor + toward * 24.0 - side * 118.0
		"warden":
			return anchor - toward * 48.0 + side * 86.0
		_:
			return anchor + side * 90.0


static func _locked_enemy(player: Player, delta: float) -> Node2D:
	player.cpu_lock_timer = maxf(0.0, player.cpu_lock_timer - delta)
	var locked := player.cpu_lock_target
	if is_instance_valid(locked) and locked is Node2D:
		if locked.has_method("is_damageable") and not locked.is_damageable():
			locked = null
		elif player.cpu_lock_timer > 0.0:
			return locked as Node2D
	var next_enemy := _nearest_enemy(player)
	player.cpu_lock_target = next_enemy
	player.cpu_lock_timer = TARGET_LOCK_SEC
	return next_enemy


static func _smooth_move(player: Player, desired: Vector2, delta: float) -> Vector2:
	var target := desired.limit_length(1.0) * MOVE_SCALE
	var blend := clampf(SMOOTH_RATE * delta, 0.12, 0.35)
	player.cpu_smoothed_move = player.cpu_smoothed_move.lerp(target, blend)
	if target.length_squared() <= 0.0001 and player.cpu_smoothed_move.length_squared() < 0.01:
		player.cpu_smoothed_move = Vector2.ZERO
	return player.cpu_smoothed_move


static func _steer_towards(from: Vector2, to: Vector2, hold_distance: float) -> Vector2:
	if from.distance_to(to) <= hold_distance:
		return Vector2.ZERO
	return from.direction_to(to)


static func _nearest_enemy(player: Player) -> Node2D:
	if not player.is_inside_tree():
		return null
	var best: Node2D
	var best_dist := INF
	for candidate in player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		var dist := player.global_position.distance_squared_to((candidate as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = candidate as Node2D
	return best


static func _human_ally(player: Player) -> Player:
	if not player.is_inside_tree():
		return null
	var best: Player
	var best_hp := INF
	for candidate in player.get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var ally := candidate as Player
		if ally == player or ally.is_cpu() or not ally.active or ally.health.is_dead:
			continue
		if ally.health.current_health < best_hp:
			best_hp = ally.health.current_health
			best = ally
	return best


static func _downed_ally(player: Player) -> Player:
	if not player.is_inside_tree():
		return null
	var best: Player
	var best_dist := INF
	for candidate in player.get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var ally := candidate as Player
		if ally == player or ally.active or not ally.health.is_dead:
			continue
		var dist := player.global_position.distance_squared_to(ally.global_position)
		if dist < best_dist:
			best_dist = dist
			best = ally
	return best
