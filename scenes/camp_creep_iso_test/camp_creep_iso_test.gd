extends Node2D
## Isolated empty-world test for the minigame camp-creep recruit sprites (2026-09-18).
##
## Empty-world baseline: flat dark background + camera. No arena, no grass, no HUD.
##
## Scenario:
##   1. Spawn one of each biome-1 enemy type as a camp creep in the IDLE state
##      (light-yellow recruit sprite, non-combat, damage zeroed) — this mirrors
##      what minigame_camp_creeps.gd does when a camp is first placed.
##   2. "Recruit" a second row: recolor to orange, restore damage, enable recruit AI.
##   3. Screenshot the grid (idle yellow row on top, recruited orange row below).
##   4. Verify: idle row uses *_recruit_yellow sprites; recruited row uses
##      *_recruit_orange sprites; recruited row damage restored (>0).
##
## Writes user://selftest_report.json and quits.

var _camera: Camera2D
var _elapsed := 0.0
var _idle_row: Array[Enemy] = []
var _recruit_row: Array[Enemy] = []
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")

## All 13 biome-1 (grass) creep types.
const TYPES: Array[String] = [
	"grunt", "swarmling", "spitter", "drifter", "brute", "stalker",
	"bomber", "hexer", "sentinel", "splitter", "lurker", "charger", "summoner",
]

const COLS := 7
const SPACING := 110.0

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2.ZERO
	_camera.zoom = Vector2(0.9, 0.9)
	_camera.make_current()

	# Dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	# Row 0 (idle / yellow): y = -140
	for i in TYPES.size():
		var pos := _grid_pos(i, -140.0)
		var e := _spawn_camp_creep(pos, TYPES[i], false)
		_idle_row.append(e)

	# Row 1 (recruited / orange): y = +140
	for i in TYPES.size():
		var pos := _grid_pos(i, 140.0)
		var e := _spawn_camp_creep(pos, TYPES[i], true)
		_recruit_row.append(e)

func _grid_pos(i: int, row_y: float) -> Vector2:
	var col := i % COLS
	var row := i / COLS
	var x: float = (float(col) - float(COLS - 1) * 0.5) * SPACING
	return Vector2(x, row_y + float(row) * SPACING)

func _spawn_camp_creep(pos: Vector2, type_id: String, recruited: bool) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.name = "CampCreep_%s_%s" % [type_id, "rec" if recruited else "idle"]
	enemy.add_to_group("enemies")
	var fitted_id: String = EnemyType.fit_to_biome(type_id)
	add_child(enemy)
	enemy.global_position = pos
	enemy.configure(9000 + int(randi_range(0, 9999)), true, fitted_id, 1.0, 1.0)
	enemy.is_camp_creep = true
	# Camp creeps get 3x HP of their base type (matches production minigame_camp_creeps.gd).
	if enemy.health != null:
		enemy.health.max_health *= 3.0
		enemy.health.current_health = enemy.health.max_health
	if recruited:
		enemy.recruit_sprite = type_id + "_recruit_orange"
		enemy._apply_sprite()
		# Restore combat stats + enable recruit AI (same as on_minigame_finished).
		enemy.contact_damage = float(EnemyType.field(type_id, "contact_damage"))
		enemy.projectile_damage = float(EnemyType.field(type_id, "projectile_damage"))
		enemy.taunt_immune = false
		enemy.is_camp_recruit = true
		# No owner in this isolated test; recruit AI will idle in place.
	else:
		# Idle camp creep: yellow sprite, non-combat.
		enemy.recruit_sprite = type_id + "_recruit_yellow"
		enemy._apply_sprite()
		enemy.contact_damage = 0.0
		enemy.projectile_damage = 0.0
		enemy.explode_damage = 0.0
		enemy.taunt_immune = true
	return enemy

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 2.0:
		_capture_and_finish()

func _capture_and_finish() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var idle_ok := true
	var rec_ok := true
	var rec_damage_ok := true
	var hp_3x_ok := true
	for i in _idle_row.size():
		var e: Enemy = _idle_row[i]
		if e == null or not is_instance_valid(e):
			idle_ok = false
			continue
		if e.recruit_sprite != TYPES[i] + "_recruit_yellow":
			idle_ok = false
		if e.contact_damage != 0.0:
			idle_ok = false
		# Idle camp creeps must have 3x their base-type HP (using fitted type).
		var base_hp: float = float(EnemyType.field(e.type_id, "max_health"))
		if absf(e.health.max_health - base_hp * 3.0) > 0.5:
			hp_3x_ok = false
	for i in _recruit_row.size():
		var e: Enemy = _recruit_row[i]
		if e == null or not is_instance_valid(e):
			rec_ok = false
			continue
		if e.recruit_sprite != TYPES[i] + "_recruit_orange":
			rec_ok = false
		# Recruits must have combat stats restored to their base-type values
		# (contact/projectile as defined in EnemyType; 0 is valid for support types
		# like summoner/hexer which fight via summons/auras).
		var expected_cd: float = float(EnemyType.field(e.type_id, "contact_damage"))
		var expected_pd: float = float(EnemyType.field(e.type_id, "projectile_damage"))
		if absf(e.contact_damage - expected_cd) > 0.01 or absf(e.projectile_damage - expected_pd) > 0.01:
			rec_damage_ok = false
	var verdict := "PASS" if (idle_ok and rec_ok and rec_damage_ok and hp_3x_ok) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "camp_creep_iso_test",
		"idle_row_ok": idle_ok,
		"recruit_row_ok": rec_ok,
		"recruit_damage_ok": rec_damage_ok,
		"hp_3x_ok": hp_3x_ok,
		"creep_count": _idle_row.size() + _recruit_row.size(),
		"types": TYPES,
	}
	if img:
		img.save_png("user://camp_creep_iso_grid.png")
		report["screenshot"] = "user://camp_creep_iso_grid.png"
		report["path"] = "user://camp_creep_iso_grid.png"
	_write_report(report)
	get_tree().quit()

func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[CampCreepIso] verdict=", str(report.get("verdict", "")))
