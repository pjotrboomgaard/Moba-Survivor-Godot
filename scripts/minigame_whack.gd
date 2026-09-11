extends "res://scripts/minigame_base.gd"

## Whack-a-Creep — Forest corner (1,-1).
## 3x3 grid of cells. Creeps pop up on a random cell for a short window; hit the
## right cell (keys 1-9 or click) before it vanishes. Combo scoring.

const GRID := 3
const CELLS: Array[Vector2] = [
	Vector2(-48.0, -30.0), Vector2(0.0, -30.0), Vector2(48.0, -30.0),
	Vector2(-48.0, 6.0),  Vector2(0.0, 6.0),  Vector2(48.0, 6.0),
	Vector2(-48.0, 42.0), Vector2(0.0, 42.0), Vector2(48.0, 42.0),
]
const CREEP_LIFE := 1.6  # seconds a creep stays visible
const SPAWN_INTERVAL := 1.2  # new creep every N seconds
const CELL_SIZE := 38.0

var _active_cell := -1
var _creep_timer := 0.0
var _spawn_timer := 0.0
var _combo := 0
var _max_combo := 0
var _flash_cell := -1
var _flash_result := 0  # 1 = hit, -1 = miss


func _reset() -> void:
	_active_cell = -1
	_creep_timer = 0.0
	_spawn_timer = 0.0
	_combo = 0
	_max_combo = 0
	_flash_cell = -1
	_flash_result = 0
	_next_creature()


func _update_delta(delta: float) -> void:
	if not active:
		return
	_spawn_timer += delta
	_flash_cell = -1
	# Spawn a new creep
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_next_creature()
	# Decay active creep
	if _active_cell >= 0:
		_creep_timer += delta
		if _creep_timer >= CREEP_LIFE:
			# Missed
			_combo = 0
			_active_cell = -1


func _next_creature() -> void:
	var cell := randi() % GRID
	_active_cell = cell
	_creep_timer = 0.0


func on_input_event(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed:
		var k: int = event.keycode
		# Map 1-9 to cells 0-8 (main row only; numpad support omitted for simplicity)
		if k >= KEY_1 and k <= KEY_9:
			_try_hit(int(k - KEY_1))
	elif event is InputEventMouseButton and event.pressed:
		# Map click position to grid cell
		var local := get_global_mouse_position() - global_position
		var hit := _cell_at(local)
		if hit >= 0:
			_try_hit(hit)


func _cell_at(pos: Vector2) -> int:
	for i in CELLS.size():
		if absf(pos.x - CELLS[i].x) <= CELL_SIZE * 0.5 and absf(pos.y - CELLS[i].y) <= CELL_SIZE * 0.5:
			return i
	return -1


func _try_hit(cell: int) -> void:
	if cell < 0 or cell >= GRID * GRID:
		return
	if cell == _active_cell:
		# Hit!
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var points := 10 + (_combo - 1) * 5  # combo bonus
		score += points
		_flash_cell = cell
		_flash_result = 1
		_active_cell = -1
		AudioService.play("minigame_whack")
		_vfx_burst(Color(0.6, 0.9, 0.4), 40.0, 140.0)
	else:
		_combo = 0
		_flash_cell = cell
		_flash_result = -1
		AudioService.play("sfx_shield")
	queue_redraw()


func bot_tick(delta: float) -> Dictionary:
	if not active:
		return {"move": Vector2.ZERO, "attack": false, "interact": false}
	# Bot hits the active cell when the creep is in the middle of its visible window
	if _active_cell >= 0 and _creep_timer > 0.3 and _creep_timer < 0.8:
		_try_hit(_active_cell)
		_active_cell = -1  # prevent double-hit
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func _draw_body() -> void:
	# Draw grid
	for i in GRID * GRID:
		var c: Vector2 = CELLS[i]
		# Cell background
		var is_active := (i == _active_cell)
		var col: Color = Color(0.2, 0.4, 0.15, 0.3) if not is_active else Color(0.5, 0.8, 0.3, 0.5)
		draw_rect(Rect2(c.x - CELL_SIZE * 0.45, c.y - CELL_SIZE * 0.45, CELL_SIZE * 0.9, CELL_SIZE * 0.9), col)
		# Key hint
		var key_label := str(i + 1)
		draw_string(ThemeDB.fallback_font, c + Vector2(-8.0, 10.0), key_label,
			HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color(0.7, 0.9, 0.5, 0.5))
	# Active creep
	if _active_cell >= 0:
		var c: Vector2 = CELLS[_active_cell]
		# Creep body (simple blob)
		var bounce := 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.012)
		draw_circle(c, 14.0 * bounce, Color(0.6, 0.8, 0.4, 0.95))
		draw_circle(c + Vector2(0.0, -4.0), 8.0 * bounce, Color(0.8, 1.0, 0.6, 0.9))
		# Eyes
		draw_circle(c + Vector2(-5.0, -3.0), 2.5, Color(0.1, 0.1, 0.1, 0.9))
		draw_circle(c + Vector2(5.0, -3.0), 2.5, Color(0.1, 0.1, 0.1, 0.9))
		# Timer arc around creep
		var frac := clampf(_creep_timer / CREEP_LIFE, 0.0, 1.0)
		draw_arc(c, 22.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, Color(1.0, 0.8, 0.3, 0.7), 2.0)
	# Flash result
	if _flash_cell >= 0 and _flash_result != 0:
		var c: Vector2 = CELLS[_flash_cell]
		var col: Color = Color(0.5, 1.0, 0.5, 0.6) if _flash_result > 0 else Color(1.0, 0.4, 0.4, 0.6)
		draw_rect(Rect2(c.x - CELL_SIZE * 0.5, c.y - CELL_SIZE * 0.5, CELL_SIZE, CELL_SIZE), col)
	# Combo display
	if _combo > 1:
		var color := Color(1.0, 0.9, 0.3, 0.95)
		draw_string(ThemeDB.fallback_font, Vector2(60.0, -20.0), "x%d COMBO!" % _combo,
			HORIZONTAL_ALIGNMENT_LEFT, 160, 16, color)
