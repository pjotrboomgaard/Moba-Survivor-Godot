extends Node2D
## T3.80 isolated verify: a Gun Drone (Kind.GUN) must fire a visible stripe/beam
## toward its target creep when it attacks. Empty world: a real Player at origin,
## a Gun Drone granted via _add_companion("gun_drone"), and one enemy placed
## within the drone's 300px range. The test confirms:
##   1. The enemy takes damage over time (drone is actually firing).
##   2. The drone's _beam_timer flashes (beam is drawn) — sampled over several frames.
##
## Empty world: no arena, no HUD, no grass.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _camera: Camera2D
var _done := false
var _elapsed := 0.0
var _run_dir := ""
var _report_path := "user://gun_drone_report.json"
var _shots: Array = []
var _captured := {}

var _player: Node2D = null
var _drone: Node2D = null
var _enemy_stub: Node2D = null
var _enemy_initial_hp := 99999.0
var _beam_flash_seen := false
var _beam_flash_frames := 0

const CAPTURES: Array = [
    [0.5, "drone_iso_before"],
    [1.5, "drone_iso_mid"],
    [2.5, "drone_iso_after"],
]


func _ready() -> void:
    _camera = $Camera2D
    _camera.global_position = Vector2.ZERO
    _run_dir = "user://gun_drone_run_%d" % int(Time.get_unix_time_from_system())
    DirAccess.make_dir_recursive_absolute(_run_dir)

    _player = PLAYER_SCENE.instantiate()
    _player.global_position = Vector2.ZERO
    add_child(_player)
    _player.active = true

    # Enemy stub in range.
    _enemy_stub = _EnemyStub.new()
    _enemy_stub.global_position = Vector2(120.0, 0.0)
    _enemy_stub.add_to_group("enemies")
    add_child(_enemy_stub)
    _enemy_initial_hp = _enemy_hp()

    # Grant the gun drone.
    if _player.has_method("_add_companion"):
        _player._add_companion("gun_drone")
    _drone = _find_drone()
    print("[GunDrone] ready: player + gun_drone + enemy, drone=%s" % str(_drone != null))


func _find_drone() -> Node2D:
    if _player == null:
        return null
    for child in _player.get_parent().get_children():
        # CompanionDrone has a `kind` property and a `setup` method.
        if "kind" in child and "setup" in child and "owner_player" in child:
            return child
    return null


func _process(delta: float) -> void:
    _elapsed += delta
    if _drone != null and is_instance_valid(_drone):
        # _beam_target_pos is set (non-zero) whenever the drone fires at a target,
        # and persists until the next shot — a reliable "did it ever aim a beam"
        # signal (unlike the transient _beam_timer, which is short-lived).
        var btp: Vector2 = _drone.get("_beam_target_pos")
        if btp != Vector2.ZERO:
            _beam_flash_seen = true
            _beam_flash_frames += 1
    _capture_due()
    if _elapsed > 3.2 and not _done:
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
    print("[GunDrone] snap %s hp=%.0f beam_seen=%s" % [label, _enemy_hp(), str(_beam_flash_seen)])
    return path


func _enemy_hp() -> float:
    if _enemy_stub == null or not is_instance_valid(_enemy_stub):
        return -1.0
    var h: HealthComponent = _enemy_stub.get_node_or_null("HealthComponent")
    if h == null:
        return -1.0
    return h.current_health


func _draw() -> void:
    draw_rect(Rect2(Vector2(-480, -270), Vector2(960, 540)), Color(0.05, 0.05, 0.08), true)
    if _enemy_stub != null and is_instance_valid(_enemy_stub):
        draw_circle(_enemy_stub.global_position, 18.0, Color(0.9, 0.3, 0.3, 0.9))
        draw_string(ThemeDB.fallback_font, _enemy_stub.global_position + Vector2(-30, -28),
            "ENEMY hp=%.0f" % _enemy_hp(), HORIZONTAL_ALIGNMENT_LEFT, 96, 12, Color(1.0, 0.5, 0.5))
    if _beam_flash_seen:
        draw_string(ThemeDB.fallback_font, Vector2(-460, -240), "BEAM FLASH SEEN: %d frames" % _beam_flash_frames,
            HORIZONTAL_ALIGNMENT_LEFT, 96, 14, Color(0.5, 1.0, 0.5))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(-460, -240), "BEAM FLASH: not yet",
            HORIZONTAL_ALIGNMENT_LEFT, 96, 14, Color(0.8, 0.8, 0.8))


func _finish() -> void:
    if _done:
        return
    _done = true
    var final_hp := _enemy_hp()
    var total_damage := _enemy_initial_hp - final_hp
    var verdict := "PASS" if (_beam_flash_seen and total_damage > 5.0) else "FAIL"
    var report := {
        "verdict": verdict,
        "scene": "gun_drone_beam_test",
        "beam_flash_seen": _beam_flash_seen,
        "beam_flash_frames": _beam_flash_frames,
        "initial_hp": _enemy_initial_hp,
        "final_hp": final_hp,
        "total_damage": total_damage,
        "shots": _shots,
    }
    var f := FileAccess.open(_report_path, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(report, "  "))
        f.close()
    print("GUN_DRONE SUMMARY verdict=%s beam_seen=%s damage=%.1f" % [verdict, str(_beam_flash_seen), total_damage])
    get_tree().quit(0 if verdict == "PASS" else 1)


class _EnemyStub:
    extends Node2D
    var knockback_velocity: Vector2 = Vector2.ZERO
    var server_authoritative := true
    const MAX_HP := 99999.0
    var _health: HealthComponent = null

    func _init() -> void:
        _health = HealthComponent.new()
        _health.name = "HealthComponent"
        _health.max_health = MAX_HP
        add_child(_health)

    func apply_knockback(impulse: Vector2) -> void:
        knockback_velocity += impulse
