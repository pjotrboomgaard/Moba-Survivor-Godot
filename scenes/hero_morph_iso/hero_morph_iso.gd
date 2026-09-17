extends Node2D
## Isolated empty-world test for the T4.11 hero-switch morph (white flash + scale
## pop when the player morphs into a newly-bought hero via the beacon / shop).
##
## Empty-world baseline: flat dark background + camera. One real Player node is
## spawned; we call switch_hero() and capture the moment the sprite is at its
## brightest (the white-flash peak) plus a settled frame.
##
## Writes user://selftest_report.json and calls get_tree().quit().

const PlayerScene := preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _player: CharacterBody2D = null
var _captured: Dictionary = {}
var _elapsed := 0.0
var _switched := false


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(0.0, -40.0)
	_camera.zoom = Vector2(2.2, 2.2)
	_camera.make_current()

	# Flat dark background (empty-world baseline).
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	_spawn_player()


func _spawn_player() -> void:
	var p := PlayerScene.instantiate()
	add_child(p)
	_player = p
	# Give it enough HP so it is alive and rendering.
	if p.has_method("apply_class"):
		p.call("apply_class", "tobor")
	p.position = Vector2.ZERO
	# Ensure the sprite is visible.
	if p.has_method("set_sprite_visible"):
		p.call("set_sprite_visible", true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.8 and not _captured.has("before"):
		_snap("before")
	if _elapsed >= 1.2 and not _switched:
		_switched = true
		# Trigger the hero-switch morph (T4.11 _hero_switch_morph).
		_player.call("switch_hero", "arclight")
	if _elapsed >= 1.32 and not _captured.has("flash"):
		_snap("flash")
	if _elapsed >= 2.0 and not _captured.has("after"):
		_snap("after")
	if _elapsed >= 2.8:
		_finish()


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://iso_hero_morph_%s.png" % label
		img.save_png(path)
		_captured[label] = {"label": label, "path": path}
		print("[HeroMorphIso] snap ", label)


func _finish() -> void:
	# Probe the sprite's modulate at settle (should be back to white ~1.0,1,1).
	var mod: Color = Color.WHITE
	var scale: float = 1.0
	if _player != null:
		var sp = _player.get("sprite")
		if sp != null:
			mod = sp.get("modulate")
			scale = sp.get("scale").x
	var class_now := str(_player.get("class_id")) if _player != null else "?"
	var ok := _captured.has("before") and _captured.has("flash") and _captured.has("after") \
		and class_now == "arclight"
	var report := {
		"verdict": "PASS" if ok else "FAIL",
		"mode": "hero_morph",
		"class_after_switch": class_now,
		"sprite_modulate": str(mod),
		"sprite_scale": scale,
		"shots": _captured.values(),
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[HeroMorphIso] verdict=%s class=%s" % [report["verdict"], class_now])
	get_tree().quit()
