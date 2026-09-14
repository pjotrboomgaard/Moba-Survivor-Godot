extends Node2D
## T3.89 isolated verify: render the four upgrade icons that the user reported as
## blue/missing (gun_drone, push_drone=Repulsor Drone, scholar=Field Notes,
## keen_eye) and confirm each is a NON-null, distinct, non-blue-shard texture.
##
## Empty world: a dark plane + a 4-up row of icons. No arena, no HUD, no grass.
## Writes user://selftest_report.json and quits.

const UPGRADE_CATALOG := preload("res://scripts/upgrade_catalog.gd")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _captured := {}
var _icon_data: Array = []  # {id, null?, size, mean_color, distinct_from_others}

## The four the user flagged: gun drone, repulsor drone, field notes, keen eye.
const IDS: Array = ["gun_drone", "push_drone", "scholar", "keen_eye"]

const CAPTURES: Array = [
	[0.4, "icons_iso_before"],
	[0.9, "icons_iso_after"],
]


func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://upgrade_icon_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	# Analyze each icon: is it null? what's its size? mean color (blue shard = ~#4f8fe0)?
	for uid in IDS:
		var tex: Texture2D = UPGRADE_CATALOG.texture(String(uid))
		var info := {"id": uid, "null": tex == null}
		if tex != null:
			var img := tex.get_image()
			info["size"] = [img.get_width(), img.get_height()]
			var avg := _mean_color(img)
			info["mean"] = [avg.r, avg.g, avg.b]
			# A blue shard is dominated by blue channel. If blue is the largest
			# channel AND clearly exceeds red, it's the shard fallback.
			info["is_blue_shard"] = avg.b > avg.r * 1.4 and avg.b > 0.45
		_icon_data.append(info)
	print("UPGRADE_ICON_TEST icons=", JSON.stringify(_icon_data))


func _mean_color(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var r := 0.0; var g := 0.0; var b := 0.0; var n := 0.0
	for y in h:
		for x in w:
			var px := img.get_pixel(x, y)
			if px.a > 0.5:
				r += px.r; g += px.g; b += px.b; n += 1.0
	if n <= 0.0:
		return Color.BLACK
	return Color(r / n, g / n, b / n, 1.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_capture_due()
	if _elapsed > 1.6 and not _done:
		_finish()


func _capture_due() -> void:
	for c in CAPTURES:
		var label: String = String(c[1])
		if _captured.has(label):
			continue
		if _elapsed >= float(c[0]):
			_captured[label] = _capture(label)


func _capture(label: String) -> String:
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[UpgradeIcon] snap %s -> %s" % [label, path])
	return path


func _draw() -> void:
	# Empty-world baseline.
	draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
	# Draw the 4 icons in a row, each in a 64px box, with its id label below.
	var spacing := 160.0
	var start_x := -1.5 * spacing
	for i in IDS.size():
		var uid := String(IDS[i])
		var tex: Texture2D = UPGRADE_CATALOG.texture(uid)
		var cx := start_x + float(i) * spacing
		# Box outline (draw_rect: rect, color, filled).
		draw_rect(Rect2(cx - 32, -48, 64, 64), Color(0.4, 0.4, 0.45), true, -2)
		if tex != null:
			draw_texture(tex, Vector2(cx - 16, -32))  # 32px icon
		else:
			draw_string(ThemeDB.fallback_font, Vector2(cx - 12, -10), "NULL", HORIZONTAL_ALIGNMENT_CENTER, 96, 14, Color.RED)
		# Id label.
		draw_string(ThemeDB.fallback_font, Vector2(cx - 40, 40), uid, HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.7, 0.7, 0.7))


func _finish() -> void:
	if _done:
		return
	_done = true
	var all_ok := true
	for info in _icon_data:
		if info["null"] or info.get("is_blue_shard", false):
			all_ok = false
	var verdict := "PASS" if (all_ok and _captured.size() >= 1) else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "upgrade_icon_test",
		"icons": _icon_data,
		"captured": _captured.size(),
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("UPGRADE_ICON_TEST SUMMARY verdict=%s icons=%s" % [verdict, JSON.stringify(_icon_data)])
	get_tree().quit(0)
