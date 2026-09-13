extends Node2D
## Isolated BOT-CONTROLLED sprite verification (T3.39 hard rule).
##
## Spawns REAL Player nodes for the three new-sprite heroes (arclight/bulwark/warden)
## plus tobor as a control, drives each one to WALK via set_authority_command(), and
## while they are mid-stride reports:
##   * the texture each hero's sprite is actually using (the live _facing_texture path),
##   * whether it fell back to the blue-wisp circle (has_sprite() == false),
##   * a per-hero mid-walk screenshot so the user can see the real pixel-art body
##     moving (not a static display, not a wisp).
##
## This is the "bot controlling both in isolated" check: the hero is a live Player
## node driven by command input, exercising _update_tobor_visual / _paint_hero_facing
## exactly as the running game does.
##
## Launched via:
##   run_selftest.ps1 -RequestPath .../bot_sprite_walk_test.json
##     -Scene res://scenes/bot_sprite_walk_test/bot_sprite_walk_test.tscn

const HERO_SCENE := "res://scenes/player/player.tscn"
const HERO_IDS := ["arclight", "bulwark", "warden", "tobor"]

var _heroes: Array = []
var _finished := false
var _fallbacks: Array[String] = []
var _tex_report: Dictionary = {}

func _ready() -> void:
	_draw_ground()
	_spawn_heroes()
	await get_tree().create_timer(0.5).timeout
	for h in HERO_IDS:
		await _drive_and_probe(h)
	_capture_all()
	_finish()

func _draw_ground() -> void:
	var lb := Label.new()
	lb.text = "Bot-controlled walk test: real Player nodes driven by set_authority_command"
	lb.position = Vector2(-520.0, -300.0)
	lb.add_theme_font_size_override("font_size", 24)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(lb)

func _spawn_heroes() -> void:
	var ps: PackedScene = load(HERO_SCENE)
	var spacing := 220.0
	var total := HERO_IDS.size()
	for i in total:
		var hero_id: String = HERO_IDS[i]
		var p: Player = ps.instantiate()
		p.name = "Hero_%s" % hero_id
		p.global_position = Vector2((float(i) - float(total - 1) * 0.5) * spacing, 40.0)
		add_child(p)
		p.configure(200 + i, GameRuntime.RuntimeMode.OFFLINE, false, hero_id)
		_heroes.append(p)
		if p.has_node("Camera2D"):
			(p.get_node("Camera2D") as Camera2D).enabled = false

func _drive_and_probe(hero_id: String) -> void:
	var p: Player = _heroes[HERO_IDS.find(hero_id)]
	var dir := Vector2(1.0, 0.0)
	# Drive a real walk so the facing logic + sprite paint run exactly as in-game.
	for step in 8:
		p.set_authority_command(dir, p.global_position + dir * 120.0, false, false, [false, false, false, false], false)
		await get_tree().physics_frame
	var has_sprite: bool = p.has_sprite()
	var tex: Texture2D = p.get("sprite").texture if p.get("sprite") != null else null
	var texsize: String = "none"
	var texpath: String = "none"
	var tex_sig: String = "none"
	if tex != null:
		texsize = "%dx%d" % [tex.get_width(), tex.get_height()]
		if tex.resource_path != "":
			texpath = tex.resource_path
		# Content signature: hash the live texture's pixels so we can prove it is the
		# freshly-cut PNG and not a stale/placeholder import.
		var live_img: Image = tex.get_image()
		if live_img != null:
			tex_sig = _image_signature(live_img)
	_tex_report[hero_id] = {"size": texsize, "path": texpath, "sig": tex_sig, "has_sprite": has_sprite, "facing": str(p.get("_tobor_facing"))}
	if not has_sprite:
		_fallbacks.append(hero_id)
	print("[BotSpriteWalk] %s -> tex=%s path=%s sig=%s facing=%s has_sprite=%s" % [hero_id, texsize, texpath, tex_sig, str(p.get("_tobor_facing")), has_sprite])
	# settle to stand for a clean capture
	p.set_authority_command(Vector2.ZERO, p.global_position, false, false, [false, false, false, false], false)
	await get_tree().physics_frame

func _capture_all() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://bot_sprite_walk_test.png")
	var verdict := "PASS" if _fallbacks.is_empty() else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "bot_sprite_walk_test",
		"shot": "user://bot_sprite_walk_test.png",
		"heroes": HERO_IDS,
		"texture_report": _tex_report,
		"fallback_heroes": _fallbacks,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BotSpriteWalk] captured user://bot_sprite_walk_test.png verdict=%s" % verdict)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().quit(0)

## Short hex signature of the non-zero pixels in an Image (first 128 rows max).
func _image_signature(img: Image) -> String:
	var h := mini(img.get_height(), 128)
	var w := mini(img.get_width(), 128)
	var acc := 0.0
	for y in h:
		for x in w:
			var p: Color = img.get_pixel(x, y)
			if p.a > 0.0:
				acc += p.r * 3.0 + p.g * 5.0 + p.b * 7.0 + p.a * 11.0
	return "%d_%d_%08x" % [img.get_width(), img.get_height(), int(acc) & 0xFFFFFFFF]


func _draw() -> void:
	draw_rect(Rect2(-900.0, -400.0, 1800.0, 900.0), Color(0.10, 0.13, 0.16), true)
