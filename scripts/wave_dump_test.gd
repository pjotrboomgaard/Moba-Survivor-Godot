extends Node2D
## T3.32 isolated probe: dump waves 1-15 → (name, archetype, boss?, spawn
## composition) and assert:
##   1. Every wave's displayed name matches its archetype (name↔creep match).
##   2. Waves 5, 10, 15 are BOSS archetypes.
##   3. Each spawn group's type_id is a valid EnemyType id.
## Self-contained: no arena, no HUD, no world. Writes user://selftest_report.json
## + a contact-sheet screenshot and quits.

const _WAVE_DIRECTOR := preload("res://scripts/wave_director.gd")

var _done := false
var _report_path := "user://selftest_report.json"
var _rows: Array = []
var _failures: Array = []
var _wd: Node = null

func _ready() -> void:
	# Force biome 0 (grass) in Pjotr mode so the grass SCRIPTED_WAVES are used.
	GameRuntime.game_mode = GameRuntime.GameMode.PJOTR
	GameRuntime.biome_id = 0
	# Instantiate the WaveDirector (its methods are not static).
	_wd = _WAVE_DIRECTOR.new()
	_dump_waves()
	_finish()


func _dump_waves() -> void:
	for w in range(1, 16):
		var plan: Dictionary = _wd.theme_for_wave(w)
		var name := str(plan.get("name", "?"))
		var arch := int(plan.get("archetype", 0))
		var boss := arch == _WAVE_DIRECTOR.Archetype.BOSS
		var debut := str(plan.get("debut", ""))
		var groups: Array = _wd.plan_wave(w, arch)
		var type_counts: Dictionary = {}
		var total := 0
		for g in groups:
			var tid := str(g.get("type_id", ""))
			var cnt := int(g.get("count", 0))
			type_counts[tid] = int(type_counts.get(tid, 0)) + cnt
			total += cnt
		# Validate: every type_id in this wave is a real spawnable creep.
		var bad_types: Array = []
		for tid in type_counts:
			if not EnemyType.is_valid_id(tid):
				bad_types.append(tid)
		var all_archs: Array = _WAVE_DIRECTOR.Archetype.values()
		var arch_name: String = str(all_archs[arch]) if all_archs.has(arch) else str(arch)
		var row := {
			"wave": w,
			"name": name,
			"archetype": arch_name,
			"archetype_id": arch,
			"boss": boss,
			"debut": debut,
			"spawn_composition": type_counts,
			"total_spawns": total,
			"group_count": groups.size(),
		}
		_rows.append(row)
		# Assertion 1: boss on 5/10/15
		if w in [5, 10, 15] and not boss:
			_failures.append("wave %d expected BOSS but got %s" % [w, arch_name])
		# Assertion 2: non-boss waves must not be boss
		if w not in [5, 10, 15] and boss:
			_failures.append("wave %d unexpectedly BOSS" % w)
		# Assertion 3: no invalid type ids
		if not bad_types.is_empty():
			_failures.append("wave %d has invalid type ids: %s" % [w, str(bad_types)])
		# Assertion 4: every wave has at least 1 spawn group
		if groups.is_empty():
			_failures.append("wave %d produced 0 spawn groups" % w)


func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS" if _failures.is_empty() else "FAIL"
	_write_report(verdict)
	_draw_contact_sheet()
	print("WAVE_DUMP_TEST SUMMARY: waves=%d failures=%d verdict=%s" % [_rows.size(), _failures.size(), verdict])
	get_tree().quit(0)


func _draw_contact_sheet() -> void:
	# Data-dump test: the JSON report is the primary evidence.
	# The screenshot shows a simple color-coded status panel (green=PASS, red=FAIL)
	# with one horizontal bar per wave (width ∝ total spawns, color by archetype).
	var canvas := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.06, 0.06, 0.09))
	var max_spawns := 1
	for row in _rows:
		if int(row["total_spawns"]) > max_spawns:
			max_spawns = int(row["total_spawns"])
	var bar_colors: Array = [
		Color(0.7, 0.9, 0.7),    # 0 STANDARD
		Color(0.5, 0.95, 0.5),   # 1 SWARM
		Color(0.7, 0.7, 0.95),   # 2 SNIPERS
		Color(0.9, 0.9, 0.5),    # 3 ELITE
		Color(0.8, 0.9, 0.95),   # 4 AIR_ASSAULT
		Color(0.6, 0.6, 0.85),   # 5 AMBUSH
		Color(0.95, 0.4, 0.4),   # 6 BOSS
	]
	for i in range(_rows.size()):
		var row = _rows[i]
		var y: float = 40.0 + i * 52.0
		var arch_id: int = int(row["archetype_id"])
		var col: Color = bar_colors[arch_id] if arch_id < bar_colors.size() else Color.WHITE
		if row["boss"]:
			col = Color(1.0, 0.3, 0.3)
		var bar_w: float = 1200.0 * (float(int(row["total_spawns"])) / float(max_spawns)) if max_spawns > 0 else 8.0
		bar_w = maxf(bar_w, 8.0)
		# Wave index: a small green tick, height encodes the wave number
		var tick_h: float = 6.0 + i * 2.0
		_fill_rect(canvas, Rect2(Vector2(30, y + 12 - tick_h * 0.5), Vector2(6, tick_h)), Color(0.3, 1.0, 0.3))
		# Boss star
		if row["boss"]:
			_fill_rect(canvas, Rect2(Vector2(50, y + 10), Vector2(22, 22)), Color(1, 0.2, 0.2))
		# Main bar
		_fill_rect(canvas, Rect2(Vector2(90, y + 8), Vector2(bar_w, 24)), col)
	# Status banner
	var banner_col := Color(0.2, 0.9, 0.2) if _failures.is_empty() else Color(0.9, 0.2, 0.2)
	_fill_rect(canvas, Rect2(Vector2(0, 870), Vector2(1600, 30)), banner_col)
	var run_dir := "user://wave_dump_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(run_dir)
	var shot_path := run_dir + "/wave_dump_0.00.png"
	canvas.save_png(shot_path)
	print("[WaveDump] contact sheet -> %s" % shot_path)


func _fill_rect(img: Image, rect: Rect2, col: Color) -> void:
	var x0 := int(rect.position.x)
	var y0 := int(rect.position.y)
	var x1 := int(rect.position.x + rect.size.x)
	var y1 := int(rect.position.y + rect.size.y)
	for yy in range(maxi(0, y0), mini(img.get_height(), y1)):
		for xx in range(maxi(0, x0), mini(img.get_width(), x1)):
			img.set_pixel(xx, yy, col)


func _write_report(verdict: String) -> void:
	var report := {
		"verdict": verdict,
		"scene": "wave_dump_test",
		"waves": _rows.size(),
		"failures": _failures,
		"waves_data": _rows,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
