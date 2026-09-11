extends Node2D
## Isolated minigame test scene.
##
## Runs a single minigame as "a whole own game" in a clean, empty arena with
## exactly one hero and NO other factors (no waves, no creeps, no HUD, no shop,
## no other players). Bot control drives the hero automatically.
##
## Usage (via selftest harness):
##   powershell -ExecutionPolicy Bypass -File tools/selftest/run_selftest.ps1 \
##       -RequestPath tools/selftest/requests/<name>.json \
##       -Scene res://scenes/minigame_test/minigame_test.tscn
##
## The request JSON should include a "minigame_index" and "hero" field.
## The scene reads them from user://selftest_request.json, spawns the hero +
## minigame, runs the full duration, writes a report, and quits.

const _BaseScript := preload("res://scripts/minigame_base.gd")
const _DanceDiscoScript := preload("res://scripts/minigame_dance_disco.gd")
const _KegTossScript := preload("res://scripts/minigame_keg_toss.gd")
const _RpsScript := preload("res://scripts/minigame_rps.gd")
const _TreasureDashScript := preload("res://scripts/minigame_treasure_dash.gd")
const _WhackScript := preload("res://scripts/minigame_whack.gd")
const _GemRelayScript := preload("res://scripts/minigame_gem_relay.gd")
const _WhackRushScript := preload("res://scripts/minigame_whack_rush.gd")
const _TreasureDash2Script := preload("res://scripts/minigame_treasure_dash2.gd")
const _CreepTagScript := preload("res://scripts/minigame_creep_tag.gd")
const _KegTossProScript := preload("res://scripts/minigame_keg_toss_pro.gd")

var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

var test_minigame_index: int = 4
var test_hero: String = "tobor"
var test_duration: float = 70.0

var _player: Player = null
var _minigame: Node2D = null
var _elapsed: float = 0.0
var _finished: bool = false
var _log_lines: Array[String] = []
var _min_hp := 999.0


func _ready() -> void:
	GameRuntime.mode = GameRuntime.RuntimeMode.OFFLINE

	# Read the selftest request for minigame_index and hero.
	var req: Dictionary = {}
	if FileAccess.file_exists("user://selftest_request.json"):
		var f := FileAccess.open("user://selftest_request.json", FileAccess.READ)
		if f != null:
			req = JSON.parse_string(f.get_as_text())
			f.close()
	if req != null:
		if req.has("minigame_index"):
			test_minigame_index = req["minigame_index"] as int
		if req.has("hero"):
			test_hero = str(req["hero"])
		if req.has("time_scale"):
			Engine.time_scale = req["time_scale"] as float

	print("MINIGAME_TEST ready: index=%d hero=%s duration=%.0f" % [test_minigame_index, test_hero, test_duration])

	# Spawn the single hero at center.
	var p: Player = player_scene.instantiate()
	p.name = "TestHero"
	p.global_position = Vector2.ZERO
	add_child(p)
	p.configure(1, GameRuntime.RuntimeMode.OFFLINE, true, test_hero)
	_player = p

	# Remove camera limits so the hero can move freely.
	if p.has_node("Camera2D"):
		var cam := p.get_node("Camera2D") as Camera2D
		cam.limit_left = -9999
		cam.limit_top = -9999
		cam.limit_right = 9999
		cam.limit_bottom = 9999

	# Draw a simple ground background.
	var ground := $Ground
	ground.set_script(_load_ground_script())

	# Spawn the minigame at center.
	_spawn_test_minigame()


func _load_ground_script() -> GDScript:
	# Simple procedural ground: dark checkerboard.
	var code := """
extends Node2D
func _draw() -> void:
	for x in range(-8, 9):
		for y in range(-8, 9):
			var col := Color(0.15, 0.15, 0.2) if (x + y) % 2 == 0 else Color(0.18, 0.18, 0.23)
			draw_rect(Rect2(Vector2(x * 80, y * 80), Vector2(80, 80)), col)
	draw_line(Vector2(-640, 0), Vector2(640, 0), Color(0.3, 0.3, 0.4), 2.0)
	draw_line(Vector2(0, -640), Vector2(0, 640), Color(0.3, 0.3, 0.4), 2.0)
"""
	var src := GDScript.new()
	src.source_code = code
	var err := src.reload()
	if err != OK:
		push_error("MINIGAME_TEST ground script compile error: %s" % src.get_last_error_message())
		return _BaseScript  # fallback, won't draw
	return src


func _spawn_test_minigame() -> void:
	var root: Node2D = $MinigameRoot
	var script: GDScript
	match test_minigame_index:
		0: script = _TreasureDashScript
		1: script = _KegTossScript
		2: script = _WhackScript
		3: script = _RpsScript
		4: script = _DanceDiscoScript
		5: script = _GemRelayScript
		6: script = _KegTossProScript
		7: script = _WhackRushScript
		8: script = _CreepTagScript
		9: script = _TreasureDash2Script
		10: script = _DanceDiscoScript
		_:
			push_error("MINIGAME_TEST unknown minigame index: %d" % test_minigame_index)
			_finish("ERROR_UNKNOWN_INDEX")
			return

	var game: Node2D = Node2D.new()
	game.set_script(script)
	game.name = "TestMinigame"
	game.position = Vector2.ZERO
	root.add_child(game)
	_minigame = game

	# Start the minigame for the test hero.
	game.call("start", _player, test_minigame_index, Color.WHITE)
	game.set("bot_force", true)
	print("MINIGAME_TEST started: %s" % str(game.get("display_name")))


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta

	# Track min HP.
	if _player != null and is_instance_valid(_player):
		var hp: float = _player.get("health").get("current_health")
		_min_hp = minf(_min_hp, hp)

	# Drive bot movement: read the minigame's last_bot_move (computed by its own
	# _process when bot_force is on) and apply it to the hero's override.
	if _minigame != null and is_instance_valid(_minigame):
		var mg_active: Variant = _minigame.get("active")
		var mg_bot_force: Variant = _minigame.get("bot_force")
		var mg_move: Variant = _minigame.get("last_bot_move")
		if mg_active and mg_bot_force and mg_move != null:
			var move: Vector2 = mg_move as Vector2
			if _player != null and is_instance_valid(_player):
				_player.minigame_move_override = move.limit_length(1.0)
		else:
			if _player != null and is_instance_valid(_player):
				_player.minigame_move_override = Vector2.ZERO

	# Periodic log.
	if Engine.get_process_frames() % 30 == 0:
		var score := -1
		var timer := -1.0
		if _minigame != null and is_instance_valid(_minigame):
			var sv: Variant = _minigame.get("score")
			var tv: Variant = _minigame.get("timer")
			if sv is int:
				score = sv
			elif sv is float:
				score = int(sv)
			if tv is float:
				timer = tv
			elif tv is int:
				timer = float(tv)
		var hero_pos := _player.global_position if _player != null and is_instance_valid(_player) else Vector2.ZERO
		print("MINIGAME_TEST t=%.1f score=%d timer=%.1f hero=(%.0f,%.0f) hp=%.0f" % [
			_elapsed, score, timer, hero_pos.x, hero_pos.y, _min_hp])

	# Check if minigame finished.
	if _minigame != null and is_instance_valid(_minigame) and _minigame.get("finished_flag"):
		_finish("FINISHED")
		return

	# Time out.
	if _elapsed >= test_duration:
		_finish("TIMEOUT")


func _finish(reason: String) -> void:
	if _finished:
		return
	_finished = true

	var score := -1
	var timer := -1.0
	if _minigame != null and is_instance_valid(_minigame):
		var sv: Variant = _minigame.get("score")
		var tv: Variant = _minigame.get("timer")
		if sv is int:
			score = sv
		elif sv is float:
			score = int(sv)
		if tv is float:
			timer = tv
		elif tv is int:
			timer = float(tv)
	var hero_hp := _player.health.current_health if _player and is_instance_valid(_player) and _player.has_node("HealthComponent") else -1.0
	var hero_pos := _player.global_position if _player and is_instance_valid(_player) else Vector2.ZERO
	print("MINIGAME_TEST SUMMARY reason=%s score=%d timer=%.1f hero_hp=%.0f hero_pos=(%.0f,%.0f) min_hp=%.0f" % [
		reason, score, timer, hero_hp, hero_pos.x, hero_pos.y, _min_hp])

	# Capture a screenshot of the final minigame state so the disco visuals can be
	# visually verified (floor, disco ball, dancing bot, joined creeps).
	var shot_path := ""
	if get_viewport() != null:
		shot_path = "user://minigame_test_%d.png" % test_minigame_index
		var img := get_viewport().get_texture().get_image()
		if img != null and img.save_png(shot_path) == OK:
			print("MINIGAME_TEST screenshot saved: %s" % shot_path)

	# Write a selftest-compatible report.
	var report := {
		"minigame_index": test_minigame_index,
		"hero": test_hero,
		"reason": reason,
		"score": score,
		"timer": timer,
		"hero_hp": hero_hp,
		"hero_position": "%s" % str(hero_pos),
		"min_hp": _min_hp,
		"elapsed": _elapsed,
		"screenshot": shot_path,
		"verdict": "PASS_OK" if score > 0 else "FAIL_NO_SCORE",
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("MINIGAME_TEST report written")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
