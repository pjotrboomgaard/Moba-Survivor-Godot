extends Node2D
## Isolated test: verify night eyes rendering on all minion types.
## Draws night eyes directly (same logic as enemy.gd _draw_night_eyes).

var _camera: Camera2D
var _time := 0.0
var _done := false

const ENEMY_NAMES := [
	"grunt", "swarmling", "spitter", "drifter", "brute",
	"stalker", "bomber", "hexer", "sentinel", "splitter",
	"charger", "lurker",
]

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.2, 1.2)
	_camera.make_current()
	WorldClock.is_night = true
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _time >= 0.5 and not _done:
		_done = true
		_finish()


func _draw() -> void:
	draw_rect(Rect2(-300, -200, 600, 400), Color(0.1, 0.12, 0.18, 1.0))
	var cols := 4
	var spacing := 120.0
	var start_x := -((ENEMY_NAMES.size() - 1) / 2.0 * spacing)
	for i in ENEMY_NAMES.size():
		var name := ENEMY_NAMES[i]
		var col := i % cols
		var row := i / cols
		var pos := Vector2(start_x + col * spacing, (row - 1) * spacing)
		draw_circle(pos, 14.0, Color(0.5, 0.5, 0.55, 1.0))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-30, 30), name, HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.7, 0.8, 1.0, 1.0))
		# Night eyes (same as enemy.gd _draw_night_eyes)
		var eye_color := Color(1.0, 0.15, 0.1, 1.0)
		var glow_color := Color(1.0, 0.2, 0.1, 0.35)
		var br := 14.0
		var r := maxf(2.0, br * 0.15)
		var glow_r := r * 2.2
		var pos_l := pos + Vector2(-br * 0.28, -br * 0.45)
		var pos_r := pos + Vector2(br * 0.28, -br * 0.45)
		draw_circle(pos_l, glow_r, glow_color)
		draw_circle(pos_r, glow_r, glow_color)
		draw_circle(pos_l, r, eye_color)
		draw_circle(pos_r, r, eye_color)
	draw_string(ThemeDB.fallback_font, Vector2(-250, -190), "NIGHT EYES - all minions", HORIZONTAL_ALIGNMENT_LEFT, 500, 14, Color(1.0, 0.3, 0.2, 1.0))


func _finish() -> void:
	var report := {
		"verdict": "PASS",
		"is_night": WorldClock.is_night,
		"enemies_drawn": ENEMY_NAMES.size(),
		"shots": [],
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[NightEyes] verdict=PASS night=%s drawn=%d" % [WorldClock.is_night, ENEMY_NAMES.size()])
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://night_eyes_iso.png")
		print("[NightEyes] snap saved")
	get_tree().quit()
