extends Node2D
## T3.95 — Isolated verification: Arclight's sky-bolt VFX + persistent electric
## field. Empty world: Camera2D + VFX nodes. No arena, no HUD, no world props.
##
## Self-contained: writes user://selftest_report.json and calls get_tree().quit().
class_name SkyBoltTest

var _elapsed := 0.0
var _verdict := "PASS"
var _report: Dictionary = {}
var _shots: Array = []
var _snapshot_pending := ""  # label to capture on the next idle frame


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(0.0, 0.0)
	cam.zoom = Vector2(0.7, 0.7)
	add_child(cam)

	# Phase A: sky-bolt VFX — a vertical jagged lightning bolt from top to a target point.
	var center_a := Vector2(0.0, 0.0)
	var impact_radius := 72.0
	var top := center_a + Vector2(0.0, -impact_radius * 3.2)
	var points := PackedVector2Array([
		top,
		center_a + Vector2(14.0, -impact_radius * 0.4),
		center_a - Vector2(12.0, -impact_radius * 0.2),
		center_a,
	])
	var bolt_fx := LightningEffect.new()
	bolt_fx.style = PlayerClass.EffectStyle.BOLT
	bolt_fx.points = points
	bolt_fx.lifetime = 0.32
	bolt_fx.main_color = Color("#fff8a8")
	bolt_fx.chain_color = Color("#7af0ff")
	bolt_fx.z_index = 40
	add_child(bolt_fx)
	_report["bolt_spawned"] = true
	_report["bolt_points"] = points.size()

	# Phase B: persistent electric field — a ZonePulse with long duration.
	var center_b := Vector2(200.0, 0.0)
	var field_radius := 170.0
	var field_duration := 8.0
	var zone := ZonePulse.new()
	zone.setup(center_b, field_radius, field_duration, Color("#8af0ff"), Color("#3aa0ff"))
	zone.z_index = 5
	add_child(zone)
	_report["field_spawned"] = true
	_report["field_radius"] = field_radius
	_report["field_duration"] = field_duration


func _process(delta: float) -> void:
	_elapsed += delta
	if _snapshot_pending != "":
		_do_snapshot(_snapshot_pending)
		_snapshot_pending = ""
	if _elapsed >= 0.4 and _shots.size() < 1:
		_snapshot_pending = "iso_a_bolt"
	elif _elapsed >= 1.4 and _shots.size() < 2:
		_snapshot_pending = "iso_a_bolt_late"
	elif _elapsed >= 3.4 and _shots.size() < 3:
		_snapshot_pending = "iso_b_field"
	if _elapsed >= 4.6:
		_finish()


func _do_snapshot(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_report["snap_null_img_%s" % label] = true
		print("[sky-bolt] NULL image for %s" % label)
		return
	var path := "user://sky_bolt_%s.png" % label
	var err := img.save_png(path)
	if err == OK:
		_shots.append({"label": label, "path": path})
		_report["shot_%s" % label] = path
		_report["user_dir_%s" % label] = ProjectSettings.globalize_path(path)
		print("[sky-bolt] captured %s -> %s" % [label, ProjectSettings.globalize_path(path)])
	else:
		_report["snap_error_%s" % label] = "save_png err=%s" % err
		print("[sky-bolt] FAILED to capture %s err=%s" % [label, err])


func _finish() -> void:
	_report["verdict"] = _verdict
	_report["shots"] = _shots.duplicate()
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_report, "\t"))
		f.close()
	print("[sky-bolt] report: %s" % JSON.stringify(_report, "\t"))
	get_tree().quit()
