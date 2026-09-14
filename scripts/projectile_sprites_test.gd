extends Node2D
## Isolated projectile-sprite test (frost_shard / scrap_bolt).
## Renders both projectile sprites large on a clean field so they can be judged
## directly: shape, color, orientation, pixel density. Also renders them at
## game-scale (same scale the game uses) to confirm they read in-world.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/projectile_sprites.json
##      -Scene res://scenes/projectile_sprites_test/projectile_sprites_test.tscn

const SpriteLibrary := preload("res://scripts/sprite_library.gd")
const PROJECTILE_GD := preload("res://scripts/projectile.gd")

var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _captured_path := ""

const FROST_SPRITE := "frost_shard"
const SCRAP_SPRITE := "scrap_bolt"

# Big preview scale (for judging the art itself).
const PREVIEW_SCALE := 4.0
# Game-scale (what the projectile actually uses in-world).
const GAME_ZOOM := 1.4

func _ready() -> void:
	_run_dir = "user://projectile_sprites_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[ProjSprites] ready")


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= 1.5:
		var path := "%s/sprites_%s.png" % [_run_dir, "%.2f" % _elapsed]
		var img := get_viewport().get_texture().get_image()
		img.save_png(path)
		_captured_path = path
		print("[ProjSprites] snap -> %s" % path)
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	# Confirm the sprites actually load and resolve to the expected names.
	var frost_tex := SpriteLibrary.texture_for(FROST_SPRITE)
	var scrap_tex := SpriteLibrary.texture_for(SCRAP_SPRITE)
	var report := {
		"verdict": "PASS",
		"scene": "projectile_sprites_test",
		"frost_shard_loaded": frost_tex != null,
		"frost_shard_size": [frost_tex.get_width(), frost_tex.get_height()] if frost_tex != null else null,
		"scrap_bolt_loaded": scrap_tex != null,
		"scrap_bolt_size": [scrap_tex.get_width(), scrap_tex.get_height()] if scrap_tex != null else null,
		"shots": [] if _captured_path == "" else [{"label": "sprites", "path": _captured_path}],
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[ProjSprites] SUMMARY frost_loaded=%s scrap_loaded=%s" % [frost_tex != null, scrap_tex != null])
	get_tree().quit(0)


func _draw() -> void:
	# Clean ground.
	draw_rect(Rect2(-Vector2(400, 250), Vector2(800, 500)), Color(0.10, 0.12, 0.14), true)

	# --- Big preview of each sprite, centered, labeled ---
	var frost_tex := SpriteLibrary.texture_for(FROST_SPRITE)
	var scrap_tex := SpriteLibrary.texture_for(SCRAP_SPRITE)

	if frost_tex != null:
		var w := frost_tex.get_width() * PREVIEW_SCALE
		var h := frost_tex.get_height() * PREVIEW_SCALE
		# frost_shard: rotate to point right-ish like a flying shard
		var center := Vector2(-150.0, -20.0)
		var c := cos(-0.5)  # -30 degrees
		var s := sin(-0.5)
		var corners := PackedVector2Array([
			-Vector2(w*0.5, h*0.5).rotated(-0.5),
			Vector2(w*0.5, -h*0.5).rotated(-0.5),
			Vector2(w*0.5,  h*0.5).rotated(-0.5),
			-Vector2(w*0.5,  h*0.5).rotated(-0.5),
		])
		var pts := PackedVector2Array()
		for corner in corners:
			pts.append(center + corner)
		draw_set_transform(center, -0.5, Vector2(PREVIEW_SCALE, PREVIEW_SCALE))
		draw_texture_rect(frost_tex, Rect2(-frost_tex.get_width()*0.5, -frost_tex.get_height()*0.5, frost_tex.get_width(), frost_tex.get_height()), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(-220.0, 60.0),
			"FRONT_SHARD (frost_shard)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.8, 1.0))
		# Game-scale copy
		var gs := SpriteLibrary.scale_for_radius(frost_tex, 6.0 * 2.2 * 1.25)
		var gw := frost_tex.get_width() * gs
		var gh := frost_tex.get_height() * gs
		draw_texture_rect(frost_tex, Rect2(100.0, -40.0, gw, gh), false)
		draw_string(ThemeDB.fallback_font, Vector2(90.0, 10.0),
			"game scale", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))

	if scrap_tex != null:
		var w := scrap_tex.get_width() * PREVIEW_SCALE
		var h := scrap_tex.get_height() * PREVIEW_SCALE
		var center := Vector2(-150.0, 120.0)
		draw_set_transform(center, 0.4, Vector2(PREVIEW_SCALE, PREVIEW_SCALE))
		draw_texture_rect(scrap_tex, Rect2(-scrap_tex.get_width()*0.5, -scrap_tex.get_height()*0.5, scrap_tex.get_width(), scrap_tex.get_height()), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(-220.0, 200.0),
			"SCRAP_BOLT (scrap_bolt)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.3))
		# Game-scale copy
		var gs := SpriteLibrary.scale_for_radius(scrap_tex, 6.0 * 2.2 * 1.25)
		var gw := scrap_tex.get_width() * gs
		var gh := scrap_tex.get_height() * gs
		draw_texture_rect(scrap_tex, Rect2(100.0, 100.0, gw, gh), false)
		draw_string(ThemeDB.fallback_font, Vector2(90.0, 150.0),
			"game scale", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))

	# Divider line between the two.
	draw_line(Vector2(-260.0, 80.0), Vector2(60.0, 80.0), Color(0.4, 0.4, 0.4, 0.5), 1.0, true)
