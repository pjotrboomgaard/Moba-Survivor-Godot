extends Node2D
## T4.3 — Isolated verification: early-game wave pacing (too many creeps too fast).
## Dumps budget_for_wave() for waves 1-5 to show the effect of the early-game dampener.
## Writes user://selftest_report.json and calls get_tree().quit().
class_name WavePacingTest

var _report: Dictionary = {}
var _budgets: Dictionary = {}
var _shot_taken := false


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)

	# Build a wave director instance and dump budgets for waves 1-5.
	var wd: WaveDirector = load("res://scripts/wave_director.gd").new()
	_budgets = {}
	for w in [1, 2, 3, 4, 5]:
		_budgets["wave_%d" % w] = wd.budget_for_wave(w)

	# T4.3: early waves (1-3) should be meaningfully lower than the old formula.
	# Old: wave1=(24+7.5)*3=94.5, wave2=(24+15)*3=117, wave3=(24+22.5)*3=139.5
	# New: wave1=94.5*0.5=47.25, wave2=117*0.6=70.2, wave3=139.5*0.75=104.6
	_report["budgets"] = _budgets
	_report["wave1_expected_lt"] = 94.5
	_report["wave2_expected_lt"] = 117.0
	_report["wave3_expected_lt"] = 139.5

	var w1: float = float(_budgets.get("wave_1", 9999.0))
	var w2: float = float(_budgets.get("wave_2", 9999.0))
	var w3: float = float(_budgets.get("wave_3", 9999.0))
	var verdict := "PASS"
	if w1 >= 94.5:
		verdict = "FAIL"
		_report["error"] = "wave1 budget %f not reduced below old 94.5" % w1
	elif w2 >= 117.0:
		verdict = "FAIL"
		_report["error"] = "wave2 budget %f not reduced below old 117.0" % w2
	elif w3 >= 139.5:
		verdict = "FAIL"
		_report["error"] = "wave3 budget %f not reduced below old 139.5" % w3

	# Wave 4+ is unchanged (no dampener): wave4 old = (24+30)*3 = 162.
	var w4: float = float(_budgets.get("wave_4", 0.0))
	_report["wave4_delta_from_162"] = absf(w4 - 162.0)
	_report["verdict"] = verdict

	_report["user_dir"] = ProjectSettings.globalize_path("user://")
	# Defer the screenshot + report write to after the first draw.
	call_deferred("_capture_and_finish")


func _draw() -> void:
	# One colored bar per wave; height proportional to budget.
	# Orange = dampened early waves (1-3), green = full curve (4-5).
	var max_budget: float = 200.0
	var bar_width: float = 70.0
	var gap: float = 25.0
	var origin_x: float = -220.0
	var base_y: float = 120.0
	for i in range(5):
		var key := "wave_%d" % (i + 1)
		var budget: float = float(_budgets.get(key, 0.0))
		var bar_height: float = budget / max_budget * 400.0
		var x: float = origin_x + float(i) * (bar_width + gap)
		var color := Color(1.0, 0.6, 0.2) if i < 3 else Color(0.3, 0.8, 0.3)
		# Ground line
		draw_line(Vector2(x - 10.0, base_y), Vector2(x + bar_width + 10.0, base_y), Color.WHITE, 2.0)
		# Bar (drawn upward from base_y)
		draw_rect(Rect2(x, base_y - bar_height, bar_width, bar_height), color, true)
		# Budget value as a thin marker bar below the base
		var marker_w: float = budget / max_budget * 120.0
		draw_rect(Rect2(x + bar_width * 0.5 - marker_w * 0.5, base_y + 12.0, marker_w, 6.0), Color(0.9, 0.9, 0.3), true)


func _capture_and_finish() -> void:
	# Give the renderer a frame to draw _draw() before capturing.
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://selftest_wave_bars.png")
	_report["screenshot"] = "user://selftest_wave_bars.png"
	_write_report()
	get_tree().quit()


func _write_report() -> void:
	var json := JSON.stringify(_report, "\t")
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
		print("[WavePacingTest] report -> user://selftest_report.json verdict=%s budgets=%s" % [_report["verdict"], str(_report["budgets"])])
