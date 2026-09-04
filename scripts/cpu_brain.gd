class_name CpuBrain
extends RefCounted

## Offline co-op stand-in. Fills move/aim/attack so a CPU hero plays its role
## without reading the local player's WASD. Movement is smoothed and held in a
## wide comfort band so allies don't jitter every physics frame.

const MOVE_SCALE := 0.46
const FFA_MOVE_SCALE := 0.92
const TARGET_LOCK_SEC := 1.25
const SMOOTH_RATE := 2.4
const FORMATION_HOLD := 88.0
const TANK_HOLD := 58.0
const KITE_NEAR := 130.0
const KITE_FAR_PAD := 110.0
const FFA_HUNT_RANGE := 2800.0
const FFA_COMMIT_RANGE := 1600.0
const FFA_LANDMARK_HOLD := 120.0

static var _hold_left: Dictionary = {}

enum FfaTactic {
	HUNTER,
	AMBUSHER,
	BULLY,
	SKIRMISHER,
}


static func think(player: Player, delta: float = 0.016) -> Dictionary:
	var result := {
		"move": Vector2.ZERO,
		"aim": player.global_position + player.facing_direction * 80.0,
		"attack": false,
		"ability": false,
		"secondary": false,
		"ability_slots": [true, true, true, true],
		"jump": false,
	}
	if player == null:
		return result
	if not player.active or player.health.is_dead:
		player.cpu_smoothed_move = Vector2.ZERO
		return result
	if GameRuntime.is_ffa():
		return _think_ffa(player, result, delta)

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

	result.attack = _want_attack_hold(player, delta)
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
	return _with_jump(player, result)


static func _think_ffa(player: Player, result: Dictionary, delta: float) -> Dictionary:
	var tactic := _ffa_tactic(player)
	var rival := _pick_hunt_target(player, tactic)
	var creep := _locked_enemy(player, delta)
	var shrine := _contest_landmark(player)
	var home := RiftClashManager.team_anchor(player.team_id)
	var hp := 1.0
	if player.health.max_health > 0.0:
		hp = player.health.current_health / player.health.max_health
	var protected := player.is_pvp_protected()
	var rival_open := rival != null and not rival.is_pvp_protected()
	var panic := 0.14 if tactic == FfaTactic.HUNTER else 0.22
	if tactic == FfaTactic.SKIRMISHER:
		panic = 0.28

	if not protected and hp < panic and rival_open:
		result.aim = rival.global_position
		var flee_to := Vector2.ZERO
		if tactic == FfaTactic.SKIRMISHER and shrine != Vector2.INF:
			flee_to = shrine
		result.move = _smooth_move(player, player.global_position.direction_to(flee_to), delta, FFA_MOVE_SCALE)
		_arm_combat(result, player, rival, player.global_position.distance_to(rival.global_position), delta)
		return _apply_ffa_dodge(player, result, delta)

	if rival_open:
		var gap := player.global_position.distance_to(rival.global_position)
		var hunt := protected or tactic != FfaTactic.AMBUSHER or gap < FFA_COMMIT_RANGE
		if hunt:
			_arm_combat(result, player, rival, gap, delta)
			result.move = _smooth_move(player, _ffa_fight_move(player, rival, tactic, gap), delta, FFA_MOVE_SCALE)
			return _apply_ffa_dodge(player, result, delta)

	if creep != null:
		_arm_combat(result, player, creep, player.global_position.distance_to(creep.global_position), delta)
		result.move = _smooth_move(player, _desired_move(player, creep, null, player.global_position.distance_to(creep.global_position)), delta, FFA_MOVE_SCALE)
		return _apply_ffa_dodge(player, result, delta)

	if tactic == FfaTactic.AMBUSHER:
		var rim := _ffa_crater_rim(player)
		result.move = _smooth_move(player, _steer_towards(player.global_position, rim, FFA_LANDMARK_HOLD), delta, FFA_MOVE_SCALE)
		result.aim = rim
		return _apply_ffa_dodge(player, result, delta)

	if shrine != Vector2.INF:
		result.move = _smooth_move(player, _steer_towards(player.global_position, shrine, 80.0), delta, FFA_MOVE_SCALE)
		result.aim = shrine
		return _apply_ffa_dodge(player, result, delta)
	result.move = _smooth_move(player, _steer_towards(player.global_position, home, 80.0), delta, FFA_MOVE_SCALE)
	result.aim = home
	return _apply_ffa_dodge(player, result, delta)
	return _apply_ffa_dodge(player, result, delta)


static func _want_attack_hold(player: Player, delta: float) -> bool:
	if player.attack_cooldown > 0.05:
		return false
	if bool(player.get("_charge_firing")):
		return false
	var id := player.get_instance_id()
	if not _hold_left.has(id):
		var roll := randf()
		if roll < 0.42:
			_hold_left[id] = 0.06
		elif roll < 0.82:
			_hold_left[id] = randf_range(0.7, 1.6)
		else:
			_hold_left[id] = PlayerClass.ATTACK_CHARGE_MAX
	_hold_left[id] = float(_hold_left[id]) - delta
	if float(_hold_left[id]) <= 0.0:
		_hold_left.erase(id)
		return false
	return true


static func _arm_combat(result: Dictionary, player: Player, target: Node2D, gap: float, delta: float = 0.016) -> void:
	result.attack = _want_attack_hold(player, delta)
	result.aim = target.global_position
	result.ability = gap < 480.0 or player.is_pvp_protected()
	result.secondary = gap < 320.0
	result.ability_slots = [gap < 520.0, gap < 420.0, gap < 380.0, gap < 640.0]


static func _apply_ffa_dodge(player: Player, result: Dictionary, delta: float) -> Dictionary:
	if not player.is_inside_tree():
		return result
	var best_center := Vector2.ZERO
	var best_radius := 0.0
	var best_depth := -INF
	for node in player.get_tree().get_nodes_in_group("pending_blasts"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var marker := node as Node2D
		var owner_id := int(marker.get_meta("owner_id", 0))
		var kind := str(marker.get_meta("kind", "blast"))
		if owner_id == player.get_instance_id() and kind == "keg":
			continue
		var radius := float(marker.get_meta("radius", 80.0))
		var dist := player.global_position.distance_to(marker.global_position)
		if dist > radius + 36.0:
			continue
		var depth := radius - dist
		if depth > best_depth:
			best_depth = depth
			best_center = marker.global_position
			best_radius = radius
	if best_depth < -36.0:
		return _with_jump(player, result)
	var away := best_center.direction_to(player.global_position)
	if away.length_squared() <= 0.0:
		away = player.facing_direction.orthogonal()
		if away.length_squared() <= 0.0:
			away = Vector2.RIGHT
	result.move = _smooth_move(player, away, delta, FFA_MOVE_SCALE)
	if best_depth > best_radius * 0.22 or player.global_position.distance_to(best_center) < 56.0:
		result.attack = false
		result.aim = player.global_position
		result.secondary = true
		var slots: Array = result.get("ability_slots", [false, false, false, false])
		if slots.size() >= 1:
			slots[0] = true
		result.ability_slots = slots
	return _with_jump(player, result)


static func _with_jump(player: Player, result: Dictionary) -> Dictionary:
	result["jump"] = false
	if player == null or not player.can_board_jump():
		return result
	var move: Vector2 = result.get("move", Vector2.ZERO)
	if move.length_squared() < 0.04:
		return result
	var arena := Arena.arena_root(player)
	if arena == null:
		return result
	var ahead := player.global_position + move.normalized() * 56.0
	if arena.is_blocked(ahead, 18.0) or arena.is_in_void(ahead, 8.0):
		result.jump = true
	return result


static func _ffa_fight_move(player: Player, rival: Player, tactic: int, gap: float) -> Vector2:
	var toward := player.global_position.direction_to(rival.global_position)
	var side := toward.orthogonal()
	if int(Time.get_ticks_msec() / 420) % 2 == 1:
		side = -side
	var crater_cut := _ffa_cut_through_crater(player, rival, gap)
	match tactic:
		FfaTactic.HUNTER:
			if gap < 78.0:
				return -toward * 0.35 + side * 0.8
			if crater_cut.length_squared() > 0.0:
				return crater_cut + side * 0.18
			return toward + side * 0.22
		FfaTactic.AMBUSHER:
			if gap > 260.0:
				return toward + side * 0.15
			return toward * 0.15 + side
		FfaTactic.BULLY:
			if crater_cut.length_squared() > 0.0 and gap > player.attack_range:
				return crater_cut + side * 0.12
			if gap > player.attack_range * 0.7:
				return toward + side * 0.18
			return toward * 0.5 + side * 0.85
		_:
			var ideal := player.attack_range * 0.62
			if crater_cut.length_squared() > 0.0 and gap > ideal + 140.0:
				return crater_cut + side * 0.35
			if gap > ideal + 70.0:
				return toward + side * 0.45
			if gap < KITE_NEAR:
				return -toward * 0.85 + side * 0.7
			return side
	return toward


static func _ffa_cut_through_crater(player: Player, rival: Player, gap: float) -> Vector2:
	if gap < 520.0:
		return Vector2.ZERO
	var from := player.global_position
	var to := rival.global_position
	if from.length() < Arena.crater_radius() and to.length() < Arena.crater_radius() * 1.4:
		return Vector2.ZERO
	var via := Vector2.ZERO
	if from.length() > Arena.crater_radius() + 40.0:
		via = -from.normalized()
	else:
		via = to
		if via.length_squared() < 1.0:
			via = Vector2.RIGHT
		via = via.normalized()
	return via


static func _ffa_crater_rim(player: Player) -> Vector2:
	var home := RiftClashManager.team_anchor(player.team_id)
	var radial := home
	if radial.length_squared() < 1.0:
		radial = Vector2.RIGHT
	return radial.normalized() * (Arena.crater_radius() + 52.0)


static func _orbit(player: Player, center: Vector2, speed: float) -> Vector2:
	var away := player.global_position - center
	if away.length_squared() < 16.0:
		away = Vector2.RIGHT
	return away.normalized().orthogonal() * speed


static func _ffa_tactic(player: Player) -> int:
	return abs(int(player.team_id)) % 4


static func _pick_hunt_target(player: Player, tactic: int) -> Player:
	var rivals := _rivals(player)
	var pool: Array[Player] = []
	for rival in rivals:
		if not rival.is_pvp_protected():
			pool.append(rival)
	if pool.is_empty():
		return null
	if tactic == FfaTactic.BULLY:
		var weakest: Player = pool[0]
		var worst := 2.0
		for rival in pool:
			var frac := 1.0
			if rival.health.max_health > 0.0:
				frac = rival.health.current_health / rival.health.max_health
			if frac < worst:
				worst = frac
				weakest = rival
		return weakest
	if tactic == FfaTactic.AMBUSHER:
		var shrine := _contest_landmark(player)
		var best: Player = pool[0]
		var best_score := INF
		for rival in pool:
			var score := rival.global_position.distance_squared_to(shrine)
			if score < best_score:
				best_score = score
				best = rival
		return best
	var nearest: Player = pool[0]
	var best_dist := INF
	for rival in pool:
		var dist := player.global_position.distance_squared_to(rival.global_position)
		if dist < best_dist:
			best_dist = dist
			nearest = rival
	return nearest


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


static func _smooth_move(player: Player, desired: Vector2, delta: float, scale: float = MOVE_SCALE) -> Vector2:
	var target := desired.limit_length(1.0) * scale
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
	var best_score := INF
	for candidate in player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		if candidate.has_method("is_damageable") and not candidate.is_damageable():
			continue
		var dist := player.global_position.distance_squared_to((candidate as Node2D).global_position)
		var score := dist
		if candidate.is_in_group("ffa_bounty"):
			score *= 0.38
		if score < best_score:
			best_score = score
			best = candidate as Node2D
	return best


static func _rivals(player: Player) -> Array[Player]:
	var found: Array[Player] = []
	if not player.is_inside_tree():
		return found
	for candidate in player.get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Player:
			continue
		var rival := candidate as Player
		if rival == player or not rival.active or rival.health.is_dead:
			continue
		if rival.team_id == player.team_id:
			continue
		found.append(rival)
	return found


static func _contest_landmark(player: Player) -> Vector2:
	var best := Vector2.INF
	var best_score := INF
	for spot in Arena.contested_landmark_spots():
		var home := RiftClashManager.team_anchor(player.team_id)
		var score := player.global_position.distance_squared_to(spot) * 0.55 + home.distance_squared_to(spot) * 0.45
		if score < best_score:
			best_score = score
			best = spot
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
	if GameRuntime.is_ffa() or not player.is_inside_tree():
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
