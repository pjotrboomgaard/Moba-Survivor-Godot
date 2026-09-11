extends "res://scripts/minigame_base.gd"
## KEG TOSS PRO (lagoon): throw kegs at 3 moving barrels on a track.
##
## Three barrels slide back and forth along a horizontal track near the top of
## the arena. The player throws a keg upward (LMB / key 1); the keg travels up
## and scores on a barrel hit. Combo builds on hits, resets on misses. Creeps
## join as "keepers" at the sides. 40s.
##
## Bot: moves to align under the nearest barrel, throws when aligned.

const PRO_DURATION := 40.0
const TRACK_Y := -120.0
const TRACK_HALF := 160.0
const BARREL_RADIUS := 22.0
const KEG_SPEED := 520.0
const KEG_RADIUS := 10.0
const THROW_CD := 0.55
const TARGET_COUNT := 3

var _barrels: Array[Dictionary] = []
var _kegs: Array[Dictionary] = []
var _creeps: Array[Dictionary] = []
var _combo := 0
var _max_combo := 0
var _throw_cd := 0.0


func _reset() -> void:
	timer = PRO_DURATION
	_barrels.clear()
	_kegs.clear()
	_creeps.clear()
	_combo = 0
	_max_combo = 0
	_throw_cd = 0.0
	score = 0
	for i in TARGET_COUNT:
		_barrels.append({
			"pos": Vector2.ZERO,
			"offset": float(i) / float(TARGET_COUNT),
			"speed": randf_range(1.1, 1.8),
			"phase": randf() * TAU,
		})
	_spawn_creeps()


func _spawn_creeps() -> void:
	var side_x := 220.0
	var palette := [Color(0.2, 0.8, 0.7), Color(0.3, 0.6, 0.9)]
	for i in 4:
		var y := randf_range(-100.0, 100.0)
		var side := -1.0 if i < 2 else 1.0
		_creeps.append({
			"pos": Vector2(side * side_x, y),
			"color": palette[i % 2],
			"bob": randf() * TAU,
		})


func _throw_keg(from_pos: Vector2) -> void:
	_kegs.append({
		"pos": from_pos + Vector2(0.0, -20.0),
		"vel": Vector2(0.0, -KEG_SPEED),
		"alive": true,
	})
	_throw_cd = THROW_CD
	_combo_pending = false


var _combo_pending := false


func _update_delta(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	# Move barrels along track.
	var t := Time.get_ticks_msec() * 0.001
	for b in _barrels:
		var speed: float = b.get("speed", 1.5)
		var phase: float = b.get("phase", 0.0)
		var off: float = b.get("offset", 0.0)
		var base_pos := sin(t * speed + phase + off * TAU) * (TRACK_HALF - 30.0)
		b["pos"] = Vector2(base_pos, TRACK_Y)

	# Move kgs; check hits.
	var alive: Array[Dictionary] = []
	for kg in _kegs:
		var kp: Vector2 = kg.get("pos", Vector2.ZERO) + kg.get("vel", Vector2.ZERO) * delta
		var hit := false
		for b in _barrels:
			var bp: Vector2 = b.get("pos", Vector2.ZERO)
			if kp.distance_to(bp) < BARREL_RADIUS + KEG_RADIUS:
				hit = true
				_combo += 1
				_max_combo = maxi(_max_combo, _combo)
				score += 20 * maxi(1, _combo)
				if _combo >= 3 and _creeps.size() < 12:
					_add_keeper()
				break
		if hit or kp.y < TRACK_Y - 60.0:
			if not hit:
				_combo = 0
			continue
		kg["pos"] = kp
		alive.append(kg)
	_kegs = alive

	for c in _creeps:
		c["bob"] = float(c.get("bob", 0.0)) + delta * 3.5
	queue_redraw()


func _add_keeper() -> void:
	var a := randf() * TAU
	_creeps.append({
		"pos": Vector2.from_angle(a) * 230.0,
		"color": Color(randf_range(0.3, 0.9), 0.7, randf_range(0.3, 0.8)),
		"bob": randf() * TAU,
	})


func _try_throw() -> void:
	if _throw_cd > 0.0:
		return
	if owner_player != null and is_instance_valid(owner_player):
		_throw_keg(owner_player.global_position - global_position)


func bot_tick(delta: float) -> Dictionary:
	if not active or owner_player == null:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	var rel := owner_player.global_position - global_position
	# Find the barrel whose projected position is nearest the hero's x.
	var best_barrel: Vector2 = Vector2.ZERO
	var best_xd := 99999.0
	for b in _barrels:
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		var xd := absf(bp.x - rel.x)
		if xd < best_xd:
			best_xd = xd
			best_barrel = bp
	var to_align := Vector2(best_barrel.x, 60.0) - rel
	var move := to_align.normalized() if to_align.length() > 8.0 else Vector2.ZERO
	var attack := false
	# Throw when well aligned and cooldown ready.
	if _throw_cd <= 0.0 and absf(best_barrel.x - rel.x) < 18.0:
		_try_throw()
		attack = true
	return {"move": move, "attack": attack, "interact": false}


func on_input_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_try_throw()


func _draw_body() -> void:
	# Lagoon floor (water-ish)
	draw_circle(Vector2.ZERO, 240.0, Color(0.1, 0.3, 0.4, 0.5))
	draw_arc(Vector2.ZERO, 240.0, 0.0, TAU, 48, Color(0.3, 0.7, 0.8, 0.4), 3.0)

	# Track
	draw_line(Vector2(-TRACK_HALF, TRACK_Y), Vector2(TRACK_HALF, TRACK_Y),
		Color(0.6, 0.5, 0.3, 0.5), 3.0)

	# Barrels
	for b in _barrels:
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		draw_circle(bp, BARREL_RADIUS, Color(0.6, 0.4, 0.2, 0.95))
		draw_circle(bp, BARREL_RADIUS * 0.55, Color(0.8, 0.6, 0.3, 0.9))

	# Kegs in flight
	for kg in _kegs:
		var kp: Vector2 = kg.get("pos", Vector2.ZERO)
		draw_circle(kp, KEG_RADIUS, Color(0.9, 0.7, 0.3, 0.95))

	# Creeps
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var bob := sin(float(c.get("bob", 0.0))) * 3.0
		draw_circle(cp + Vector2(0.0, bob), 11.0, cc)
		draw_circle(cp + Vector2(0.0, bob) + Vector2(0.0, -5.0), 4.0, Color(1.0, 1.0, 1.0, 0.6))

	# Player marker
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_circle(rel, 14.0, Color(0.4, 0.8, 1.0, 0.95))

	# Combo
	if _combo > 1:
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -260.0),
			"COMBO x%d" % _combo, HORIZONTAL_ALIGNMENT_CENTER, 80, 15,
			Color(1.0, 0.9, 0.3, 0.9))


func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		var combo_bonus := _max_combo * 8
		var crowd_bonus := _creeps.size() * 5
		owner_player.add_gold(REWARD_GOLD + int(score * 0.15) + combo_bonus + crowd_bonus)
		owner_player.add_xp(REWARD_XP + combo_bonus)
	AudioService.play("minigame_win")
	_emit_finished()
