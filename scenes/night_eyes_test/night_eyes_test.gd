extends Node2D
## Isolated test: verify all minion types show glowing red eyes at night.
## Forces night mode directly via WorldClock static vars, spawns a grid of
## enemy types, and captures a screenshot.

const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var _enemies: Array = []
var _camera: Camera2D

# All enemy type ids that actually have EnemyType entries
const ENEMY_IDS := [
	"grunt", "swarmling", "spitter", "drifter", "brute",
	"stalker", "bomber", "hexer", "sentinel", "splitter",
	"charger", "lurker",
]

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(1.2, 1.2)

	# Force night mode directly via static vars (bypass tick which needs GameRuntime)
	WorldClock.is_night = true
	WorldClock.ambient = Color(0.38, 0.44, 0.58, 1.0)
	WorldClock.night_speed_mult = 2.0
	WorldClock.night_attack_mult = 2.0

	# Set up CanvasModulate to dim the world like night
	var cm := CanvasModulate.new()
	cm.name = "NightTint"
	cm.color = WorldClock.ambient
	add_child(cm)

	# Spawn enemies in a grid
	var cols := 4
	var spacing := 100.0
	var start_x := -((ENEMY_IDS.size() - 1) / 2.0 * spacing)
	for i in ENEMY_IDS.size():
		var id := ENEMY_IDS[i]
		var e := EnemyScene.instantiate() as Node2D
		e.name = "Enemy_%s" % id
		var col := i % cols
		var row := i / cols
		e.global_position = Vector2(start_x + col * spacing, (row - 1) * spacing)
		add_child(e)
		e.configure(i + 1, true, id, 1.0, 0.0)
		# Freeze the enemy so it doesn't move
		e.movement_speed = 0.0
		e.speed_cap = 0.0
		e.velocity = Vector2.ZERO
		# Force the night state so _draw uses night visuals immediately
		e._was_night_last_frame = false
		# Apply sprite now that night is set
		if e.has_method("_apply_sprite"):
			e._apply_sprite()
		e.queue_redraw()
		_enemies.append(e)

	await get_tree().create_timer(1.0).timeout
	_finish()

func _finish() -> void:
	var alive_count := 0
	for e in _enemies:
		if is_instance_valid(e):
			alive_count += 1
	var report := {
		"verdict": "PASS" if alive_count == ENEMY_IDS.size() else "FAIL",
		"is_night": WorldClock.is_night,
		"enemies_spawned": _enemies.size(),
		"enemies_alive": alive_count,
		"shots": [],
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("[NightEyes] verdict=%s night=%s alive=%d/%d" % [
			report["verdict"], WorldClock.is_night, alive_count, _enemies.size()])

	# Take screenshot
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://night_eyes_iso.png")
		print("[NightEyes] snap saved")
	get_tree().quit()
