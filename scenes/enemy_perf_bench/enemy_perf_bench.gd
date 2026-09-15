extends Node2D
## T3.92 perf benchmark (isolated): spawn N real Enemy nodes clustered around a real
## Player in an EMPTY world (no arena, no HUD, no grass, no projectiles) and measure
## average FPS + proc_ms over a 5s window. This is the authoritative "before" baseline.
##
## The enemy scene runs its full _physics_process: target lookup, movement, separation,
## contact attack. With N on-screen enemies this measures the real CPU cost.
##
## Writes user://perf_report.json (enemies, avg_fps, avg_proc_ms) + screenshots, then quits.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://perf_report.json"
var _shots: Array = []
var _captured := {}

const ENEMY_COUNT := 90
var _player: Node2D = null
var _enemies: Array = []
var _fps_samples: Array = []
var _proc_samples: Array = []

const CAPTURES: Array = [
    [1.0, "perf_iso_before"],
    [2.5, "perf_iso_mid"],
    [4.5, "perf_iso_after"],
]


func _ready() -> void:
    _camera = $Camera2D
    _camera.global_position = Vector2.ZERO
    _camera.zoom = Vector2(0.55, 0.55)
    _run_dir = "user://perf_run_%d" % int(Time.get_unix_time_from_system())
    DirAccess.make_dir_recursive_absolute(_run_dir)

    _player = PLAYER_SCENE.instantiate()
    _player.name = "BenchPlayer"
    _player.global_position = Vector2.ZERO
    add_child(_player)
    _player.active = true

    # Cluster N enemies in a ring (all on-screen within the camera view).
    var n := ENEMY_COUNT
    for i in n:
        var ang := (float(i) / float(n)) * TAU
        var ring := (i % 5)
        var radius := 90.0 + float(ring) * 55.0
        var e: Node2D = ENEMY_SCENE.instantiate()
        e.name = "BenchEnemy_%d" % i
        e.global_position = Vector2(cos(ang), sin(ang)) * radius
        add_child(e)
        # Authoritative = server-side, so full AI (target + movement + separation) runs.
        if e.has_method("configure"):
            e.configure(i + 1, true, "grub", 1.0, 1.0)
        _enemies.append(e)
    print("[Perf] spawned %d enemies around player" % _enemies.size())


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed > 0.6:
        _fps_samples.append(Engine.get_frames_per_second())
        _proc_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
    _capture_due()
    if _elapsed > 5.2 and not _done:
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
    print("[Perf] snap %s fps=%.0f" % [label, _avg_fps()])
    return path


func _avg_fps() -> float:
    if _fps_samples.is_empty():
        return 0.0
    var s := 0.0
    for v in _fps_samples:
        s += float(v)
    return s / float(_fps_samples.size())


func _avg_proc_ms() -> float:
    if _proc_samples.is_empty():
        return 0.0
    var s := 0.0
    for v in _proc_samples:
        s += float(v)
    return s / float(_proc_samples.size())


func _live_count() -> int:
    var live := 0
    for e in _enemies:
        if is_instance_valid(e):
            live += 1
    return live


func _draw() -> void:
    # Empty-world baseline (dark plane, no grass/HUD/props).
    draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.04, 0.04, 0.07), true)
    draw_string(ThemeDB.fallback_font, Vector2(-460, -246),
        "PERF BENCH: %d enemies on-screen  fps=%.0f" % [_live_count(), _avg_fps()],
        HORIZONTAL_ALIGNMENT_LEFT, 920, 14, Color(0.7, 0.9, 0.7))


func _finish() -> void:
    if _done:
        return
    _done = true
    var live := _live_count()
    var fps := _avg_fps()
    var proc_ms := _avg_proc_ms()
    # The benchmark records the measurement; PASS = engine stayed usable (>30fps) AND
    # the enemies are all alive (none were freed / crashed).
    var verdict := "PASS" if (fps >= 30.0 and live >= ENEMY_COUNT) else "FAIL"
    var report := {
        "verdict": verdict,
        "scene": "enemy_perf_bench",
        "enemies_target": ENEMY_COUNT,
        "enemies_live": live,
        "avg_fps": round(fps),
        "avg_proc_ms": round(proc_ms),
        "fps_samples": _fps_samples.size(),
        "shots": _shots,
    }
    var f := FileAccess.open(_report_path, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(report, "  "))
        f.close()
    print("PERF_BENCH SUMMARY verdict=%s fps=%.1f proc_ms=%.2f live=%d" % [verdict, fps, proc_ms, live])
    get_tree().quit(0 if verdict == "PASS" else 1)
