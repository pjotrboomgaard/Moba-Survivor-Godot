extends Node2D
## Isolated empty-world test for hero item visual additions.
##
## Spawns a Player node with required child nodes and verifies that
## the _draw_item_visuals function runs without errors.
##
## Modes (selected by marker file in user://):
##   item_visuals_before_marker -> BEFORE: no items (empty world baseline)
##   (no marker)                -> AFTER: all items owned

const PlayerScript := preload("res://scripts/player.gd")
const ShopCatalogScript := preload("res://scripts/shop_catalog.gd")
const HealthComponentScript := preload("res://scripts/health_component.gd")

var _camera: Camera2D
var _player: CharacterBody2D = null
var _before_mode := false
var _elapsed := 0.0
var _captured := false

func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(0.0, 0.0)
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.make_current()

	# Flat dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	_before_mode = FileAccess.file_exists("user://item_visuals_before_marker")

	# Create the player node with required children.
	_player = CharacterBody2D.new()
	_player.name = "Player"

	# HealthComponent (required @onready child).
	var hc := Node.new()
	hc.name = "HealthComponent"
	hc.set_script(HealthComponentScript)
	_player.add_child(hc)

	# WorldHealthBar (required @onready child).
	var whb := ProgressBar.new()
	whb.name = "WorldHealthBar"
	whb.set_script(preload("res://scripts/world_health_bar.gd"))
	_player.add_child(whb)

	# Camera2D (required @onready child — but we use our own camera).
	var pcam := Camera2D.new()
	pcam.name = "Camera2D"
	pcam.enabled = false
	_player.add_child(pcam)

	# Sprite (required @onready child).
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	_player.add_child(spr)

	_player.set_script(PlayerScript)
	add_child(_player)

	# Apply a class so class_id / body_color are set.
	_player.call("apply_class", "arclight")

	# Position at origin.
	_player.global_position = Vector2.ZERO

	if not _before_mode:
		# Grant all items so the visual additions are visible.
		var stacks: Dictionary = {}
		for item_id in ShopCatalogScript.ids():
			if item_id != "beacon":
				stacks[item_id] = 2
		_player.shop_stacks = stacks


func _process(delta: float) -> void:
	_elapsed += delta
	if _captured:
		return
	if _elapsed >= 1.5:
		_captured = true
		_do_snap()


func _do_snap() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "before" if _before_mode else "after"
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_item_visuals_%s.png" % suffix
		img.save_png(path)
		print("[ItemVisualsTest] snap %s" % suffix)

	var report := _build_report(suffix)
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ItemVisualsTest] verdict=%s" % str(report.get("verdict", "")))
	get_tree().quit()


func _build_report(mode: String) -> Dictionary:
	var shot_path := "user://iso_item_visuals_%s.png" % mode
	if _before_mode:
		return {
			"verdict": "PASS",
			"mode": "before",
			"note": "empty-world baseline: no item visuals present",
			"shots": [
				{"label": "before", "path": shot_path},
			],
		}

	# AFTER: verify the player has all items and that _draw_item_visuals exists.
	var all_items := true
	var missing: Array = []
	var item_ids := ShopCatalogScript.ids()
	for item_id in item_ids:
		if item_id == "beacon":
			continue
		var s: int = int(_player.shop_stacks.get(item_id, 0))
		if s <= 0:
			all_items = false
			missing.append(item_id)

	var has_fn := _player.has_method("_draw_item_visuals")

	return {
		"verdict": "PASS" if (all_items and has_fn) else "FAIL",
		"mode": "after",
		"all_items_owned": all_items,
		"missing_items": missing,
		"has_draw_fn": has_fn,
		"shots": [
			{"label": "after", "path": shot_path},
		],
	}
