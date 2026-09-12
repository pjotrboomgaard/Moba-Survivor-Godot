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
	# Lagoon floor (water-ish) — a chunky square panel.
	var floor_half := 230.0
	draw_rect(Rect2(Vector2(-floor_half, -floor_half), Vector2(floor_half * 2.0, floor_half * 2.0)), Color(0.1, 0.3, 0.4, 0.5))
	# Track — a chunky horizontal bar.
	var track_col := Color(0.6, 0.5, 0.3, 0.5)
	var seg_w := 16.0
	var nseg := int(ceil((TRACK_HALF * 2.0) / seg_w))
	for s in nseg:
		var sx := -TRACK_HALF + s * seg_w
		draw_rect(Rect2(sx, TRACK_Y - 2.0, minf(seg_w - 2.0, TRACK_HALF * 2.0 - (s * seg_w)), 4.0), track_col)

	# Barrels — chunky wooden barrels (body + 3 horizontal bands + top lid).
	for b in _barrels:
		var bp: Vector2 = b.get("pos", Vector2.ZERO)
		var br := BARREL_RADIUS
		draw_rect(Rect2(bp + Vector2(-br * 0.8, -br), Vector2(br * 1.6, br * 2.0)), Color(0.6, 0.4, 0.2, 0.95))
		# Bands (3 horizontal dark strips).
		var band_col := Color(0.4, 0.25, 0.12, 0.9)
		draw_rect(Rect2(bp + Vector2(-br * 0.8, -br * 0.6), Vector2(br * 1.6, 4.0)), band_col)
		draw_rect(Rect2(bp + Vector2(-br * 0.8, -2.0), Vector2(br * 1.6, 4.0)), band_col)
		draw_rect(Rect2(bp + Vector2(-br * 0.8, br * 0.6 - 4.0), Vector2(br * 1.6, 4.0)), band_col)
		# Top lid.
		draw_rect(Rect2(bp + Vector2(-br * 0.6, -br - 4.0), Vector2(br * 1.2, 5.0)), Color(0.8, 0.6, 0.3, 0.9))

	# Kegs in flight — chunky square kegs.
	for kg in _kegs:
		var kp: Vector2 = kg.get("pos", Vector2.ZERO)
		draw_rect(Rect2(kp + Vector2(-KEG_RADIUS, -KEG_RADIUS), Vector2(KEG_RADIUS * 2.0, KEG_RADIUS * 2.0)), Color(0.9, 0.7, 0.3, 0.95))
		draw_rect(Rect2(kp + Vector2(-KEG_RADIUS * 0.5, -KEG_RADIUS * 0.5), Vector2(KEG_RADIUS, KEG_RADIUS)), Color(0.7, 0.5, 0.2, 0.6))

	# Creeps — blocky body + head + eyes.
	for c in _creeps:
		var cp: Vector2 = c.get("pos", Vector2.ZERO)
		var cc: Color = c.get("color", Color.WHITE)
		var bob := sin(float(c.get("bob", 0.0))) * 3.0
		var cb := cp + Vector2(0.0, bob)
		draw_rect(Rect2(cb + Vector2(-9.0, -4.0), Vector2(18.0, 18.0)), cc)
		draw_rect(Rect2(cb + Vector2(-6.0, -16.0), Vector2(12.0, 12.0)), cc.lightened(0.2))
		draw_rect(Rect2(cb + Vector2(-4.0, -12.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(cb + Vector2(2.0, -12.0), Vector2(3.0, 3.0)), Color(0.1, 0.1, 0.15))

	# Player marker — chunky square.
	if owner_player != null and is_instance_valid(owner_player):
		var rel := owner_player.global_position - global_position
		draw_rect(Rect2(rel + Vector2(-13.0, -13.0), Vector2(26.0, 26.0)), Color(0.4, 0.8, 1.0, 0.95))
		draw_rect(Rect2(rel + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), Color(0.4, 0.8, 1.0, 0.5))

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
