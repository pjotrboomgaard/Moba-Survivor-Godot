extends Node
## In-game menu verify for the Joule (arclight) animated menu background.
## Boots the real bootstrap scene, selects Joule, waits for the AnimatedSprite2D
## menu video to start playing, then captures 3 screenshots to confirm the
## animated background is visible in the live menu.
##
## Run: Godot --script res://tools/selftest/menu_joule_video.gd --path <project>

const REPORT_PATH := "user://menu_joule_video_report.json"
const SHOT_DIR := "user://"

var _shots: Array = []
var _anim_found := false
var _anim_frame_at_shots: Array = []

func _ready() -> void:
	print("[MenuJoule] booting bootstrap…")
	var scene := load("res://scenes/bootstrap/bootstrap.tscn")
	if scene == null:
		_fail("could not load bootstrap.tscn")
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)

	await get_tree().create_timer(1.5).timeout

	# Select Joule (arclight) via PlayerProfile + re-render the menu.
	PlayerProfile.select_class("arclight")
	if root.has_method("_refresh_class_selection"):
		root._refresh_class_selection()
	elif root.has_method("_apply_hero_backdrop"):
		root._apply_hero_backdrop()

	# Give the animated background a few seconds to start playing + advance frames.
	await get_tree().create_timer(2.5).timeout

	# Probe for the AnimatedSprite2D we added in bootstrap.
	var anim: Node = root.find_child("JouleMenuVideo", true, false)
	_anim_found = anim != null
	if anim != null:
		print("[MenuJoule] found JouleMenuVideo, frame=", anim.frame, " playing=", anim.playing)

	_shot("joule_menu_v1")
	await get_tree().create_timer(0.8).timeout
	_shot("joule_menu_v2")
	await get_tree().create_timer(0.8).timeout
	_shot("joule_menu_v3")

	var report := {
		"verdict": "PASS" if (_anim_found and _shots.size() == 3) else "FAIL",
		"hero": "arclight",
		"animated_background_found": _anim_found,
		"screenshots": _shots,
		"note": "menu should show the animated 'I keep you' video background behind the Joule hero card",
	}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuJoule] report -> ", REPORT_PATH, " anim_found=", _anim_found)
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var path := SHOT_DIR + "menu_joule_" + label + ".png"
	img.save_png(path)
	_shots.append({"label": label, "path": path})
	print("[MenuJoule] snap ", label, " -> ", path)


func _fail(msg: String) -> void:
	var report := {"verdict": "FAIL", "error": msg, "screenshots": _shots}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuJoule] FAIL: ", msg)
	get_tree().quit()
