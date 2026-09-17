extends Node2D
## Isolated minigame-spawn + activation test. Self-contained:
##
##   1. Builds the real MinigameArea (scripts/minigame_area.gd) on a flat void
##      background with a camera framed on the arena. No arena, no grass, no HUD.
##   2. Captures: empty world (before), all 16 minigames spawned (after),
##      a close-up of the center (Dance Disco), and an "started" state showing
##      the active ring + banner.
##   3. Verdict: PASS if all 16 minigames spawn at distinct positions,
##      and start_minigame() on index 4 (Dance Disco) sets active=true.
##
## Launched via:
##   powershell ... run_selftest.ps1 -RequestPath tools/selftest/requests/minigames_iso.json \
##      -Scene res://scenes/minigames_iso/minigames_iso.tscn

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://selftest_report.json"
var _shots: Array = []
var _phase := 0  # state machine to avoid await in _capture_due

const MinigameAreaScript := preload("res://scripts/minigame_area.gd")

var _ma: Node = null
var _games: Array = []
var _all_spawned := false
var _distinct := true
var _dance_active := false

func _ready() -> void:
	_camera = $Camera2D
	_run_dir = "user://minigames_iso_run_%d" % int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(_run_dir)

	# Fake main + fake arena (MinigameArea.start requires valid main + arena).
	var fake_arena := Node2D.new()
	fake_arena.name = "FakeArena"
	fake_arena.set_script(preload("res://scripts/fake_arena.gd"))
	add_child(fake_arena)

	_ma = Node2D.new()
	_ma.name = "MinigameAreaUnderTest"
	_ma.set_script(MinigameAreaScript)
	add_child(_ma)
	_ma.call("start", self, fake_arena, null)

	_games = _ma.call("all_minigames")
	_all_spawned = _games.size() == 16
	for i in _games.size():
		var g: Node = _games[i]
		if g == null:
			_all_spawned = false
	# Check distinct positions.
	if _all_spawned:
		var keys: Array = []
		for i in _games.size():
			var g: Node = _games[i]
			if g != null:
				keys.append(g.global_position)
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				if keys[a] == keys[b]:
					_distinct = false
	print("[MinigamesIso] spawned=%d all_spawned=%s distinct=%s" % [_games.size(), str(_all_spawned), str(_distinct)])

func _process(delta: float) -> void:
	_elapsed += delta
	_tick_phases()
	if _elapsed > 8.0 and not _done:
		_finish()

func _tick_phases() -> void:
	match _phase:
		0:
			if _elapsed >= 0.3:
				_capture("iso_before_spawns")
				_phase = 1
		1:
			if _elapsed >= 0.8:
				_capture("iso_after_spawns")
				_phase = 2
		2:
			if _elapsed >= 1.2:
				# Close-up on center (Dance Disco at 0,0).
				_camera.position = Vector2(0.0, 0.0)
				_camera.zoom = Vector2(1.2, 1.2)
				_phase = 3
		3:
			if _elapsed >= 1.6:
				_capture("iso_center_closeup")
				_phase = 4
		4:
			if _elapsed >= 2.2:
				# Start Dance Disco (index 4) to verify activation.
				_start_dance()
				_phase = 5
		5:
			if _elapsed >= 2.8:
				var g4: Node = _games[4] if _games.size() > 4 else null
				_dance_active = g4 != null and bool(g4.get("active"))
				_capture("iso_dance_started")
				_phase = 6
		6:
			_finish()

var _fake_player: CharacterBody2D = null

func _start_dance() -> void:
	var g = _games[4]
	if g == null:
		print("[MinigamesIso] FAIL: index 4 is null")
		return
	# Instantiate a real Player (from the game's player scene) so the typed
	# Player parameter of minigame_base.start() binds correctly.
	if _fake_player == null:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		_fake_player = player_scene.instantiate() as CharacterBody2D
		_fake_player.name = "FakePlayer"
		add_child(_fake_player)
		_fake_player.position = g.global_position
		_fake_player.simulation_mode = Player.SimulationMode.OFFLINE
		_fake_player.apply_class("tobor")
	_fake_player.global_position = g.global_position
	# Call start() directly on the minigame (typed call avoids .call() type check).
	(g as Node).call("start", _fake_player, 4, g.get("accent"))
	print("[MinigamesIso] dance started: active=%s" % str(g.get("active")))

func _capture(label: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_run_dir, label, "%.2f" % _elapsed]
	img.save_png(path)
	_shots.append({"label": label, "path": path, "t": _elapsed})
	print("[MinigamesIso] snap %s -> %s" % [label, path])

func _finish() -> void:
	if _done:
		return
	_done = true
	var verdict := "PASS"
	if not _all_spawned:
		verdict = "FAIL"
	if not _distinct:
		verdict = "FAIL"
	if _shots.size() < 4:
		verdict = "FAIL"
	if not _dance_active:
		verdict = "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "minigames_iso",
		"games_spawned": _games.size(),
		"all_spawned": _all_spawned,
		"distinct_positions": _distinct,
		"dance_disco_active": _dance_active,
		"shots": _shots,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[MinigamesIso] SUMMARY verdict=%s games=%d all_spawned=%s distinct=%s dance_active=%s" % [
		verdict, _games.size(), str(_all_spawned), str(_distinct), str(_dance_active)])
	get_tree().quit(0)
