class_name ShipCrashFx
extends Node2D
## Opening cinematic: a pixel-art spaceship seen FROM BEHIND (engines glowing,
## exhaust plumes) flies fast from off-screen toward the map centre, wobbling as it
## goes, then detonates in one big red explosion. After the explosion the crater is
## revealed and the game continues.
##
## main.gd flow (opening):
##   1. cameras zoomed out to full map
##   2. ship_crash.play(start_pos, target_pos, on_impact)  -> emits impact + finished
##   3. on_impact: arena reveals the crater, explosion FX play, cameras zoom in.
##
## The ship is drawn procedurally as pixel-art (blocky body + twin engine glow +
## exhaust plume) so no external sprite asset is required.

signal impact
signal finished

var active := false
var _t := 0.0
var _pos := Vector2.ZERO
var _start := Vector2.ZERO
var _target := Vector2.ZERO
var _travel_time := 1.6       # seconds to cross the map
var _explode_time := 0.0
var _exploded := false
var _explosion_done := false
var _explosion_t := 0.0
var _on_impact: Callable = Callable()
var _explosion: Node2D = null

## Total travel time in seconds (faster = shorter).
var travel_time := 1.6
## How far off-screen the ship starts (relative to map half-extents).
const START_FACTOR := 1.4


func _ready() -> void:
	# Above obstacles (depth z ~2000-5400) so the ship + explosion paint on top.
	z_as_relative = false
	z_index = 4095
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


## Kick off the crash. `start` is the off-screen entry point, `target` the impact
## point (map centre). `on_impact` is called the moment the ship reaches the target.
func play(start: Vector2, target: Vector2, on_impact: Callable) -> void:
	if active:
		return
	active = true
	_start = start
	_target = target
	_pos = start
	_t = 0.0
	_exploded = false
	_explosion_done = false
	_explosion_t = 0.0
	_on_impact = on_impact
	travel_time = _travel_time
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	if not _exploded:
		# Travel: fast, eased slightly so it accelerates into impact.
		_t += delta
		var p := clampf(_t / travel_time, 0.0, 1.0)
		var eased := p * p * (3.0 - 2.0 * p)  # smoothstep — accelerates then eases
		_pos = _start.lerp(_target, eased)
		# Wobble: small sinusoidal offset that grows as it approaches.
		var wobble := sin(_t * 14.0) * (6.0 + p * 10.0)
		global_position = _pos + Vector2(0.0, wobble) * 0.5 + Vector2(wobble * 0.4, 0.0)
		queue_redraw()
		if p >= 1.0:
			_explode()
	else:
		# Explosion: hold the shockwave for a beat, then finish.
		_explosion_t += delta
		if _explosion_t >= 1.8:
			active = false
			visible = false
			_explosion_done = true
			queue_redraw()
			finished.emit()
		else:
			queue_redraw()


func _explode() -> void:
	_exploded = true
	_pos = _target
	global_position = _target
	if _on_impact.is_valid():
		_on_impact.call()
	_explosion_t = 0.0
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	if not _exploded:
		_draw_ship()
	else:
		_draw_explosion()


## Draw the spaceship viewed from behind: a blocky hull, two glowing engine nozzles,
## and a bright exhaust plume streaming toward the camera (i.e. downward/forward in
## screen space). The ship "faces away" — we see its rear and burning engines.
func _draw_ship() -> void:
	# Hull (blocky, pixel-art look). Centre is 0,0.
	var hull := Color(0.32, 0.35, 0.42)
	var hull_dark := Color(0.20, 0.22, 0.28)
	var hull_light := Color(0.50, 0.55, 0.64)
	# Body — a chunky rounded diamond/keel seen from the back.
	draw_rect(Rect2(-22, -10, 44, 26), hull, true)
	draw_rect(Rect2(-30, -4, 12, 16), hull_dark, true)   # left fin
	draw_rect(Rect2(18, -4, 12, 16), hull_dark, true)    # right fin
	draw_rect(Rect2(-14, -18, 28, 10), hull, true)        # rear top plate
	draw_rect(Rect2(-8, -22, 16, 6), hull_light, true)     # top highlight
	# Rear window / cockpit glint (faint, since we see the back).
	draw_rect(Rect2(-6, -14, 12, 6), Color(0.2, 0.3, 0.5, 0.6), true)
	# Two engine nozzles at the rear (closest to camera -> bottom of sprite).
	var eng := Color(0.15, 0.15, 0.18)
	draw_rect(Rect2(-16, 12, 14, 12), eng, true)
	draw_rect(Rect2(2, 12, 14, 12), eng, true)
	# Engine glow (bright, hot core).
	var glow := Color(0.9, 0.55, 0.2, 0.95)
	var core := Color(1.0, 0.9, 0.6, 1.0)
	for ex in [-9, 9]:
		draw_circle(Vector2(ex, 20), 9.0, glow)
		draw_circle(Vector2(ex, 20), 5.0, core)
	# Exhaust plume: bright streaks flaring toward the camera (downward in screen).
	var plume := Color(1.0, 0.7, 0.3, 0.8)
	for ex in [-9, 9]:
		draw_rect(Rect2(ex - 4, 24, 8, 26), plume, true)
		draw_rect(Rect2(ex - 6, 24, 12, 12), Color(1.0, 0.85, 0.5, 0.95), true)
		# Hot tip of the plume.
		draw_circle(Vector2(ex, 50), 7.0, Color(1.0, 0.9, 0.6, 0.7))
	# Motion: a faint trailing light behind the plume for speed.
	draw_line(Vector2(0, 52), Vector2(0, 92), Color(1.0, 0.8, 0.5, 0.25), 3.0)


## Big red explosion at the impact point. `t` drives the shockwave + flash.
func _draw_explosion() -> void:
	var t := _explosion_t
	# A single big RED blast: a large opaque red core that holds for ~0.5s then
	# expands and fades into a shockwave. The core dominates the frame so the
	# impact reads as "one big red explosion".
	var flash_alpha := clampf(1.3 - t * 0.9, 0.0, 1.0)
	var core_r := 140.0 + t * 380.0
	# Solid red core (opaque while the flash is fresh).
	draw_circle(Vector2.ZERO, core_r, Color(0.95, 0.25, 0.08, flash_alpha))
	# Hot inner core.
	draw_circle(Vector2.ZERO, core_r * 0.6, Color(1.0, 0.6, 0.2, flash_alpha))
	# White-hot flash at the very centre (only in the first ~0.4s).
	var hot_alpha := clampf(1.0 - t * 2.6, 0.0, 1.0)
	draw_circle(Vector2.ZERO, core_r * 0.32, Color(1.0, 0.98, 0.9, hot_alpha))
	# Expanding shockwave ring.
	var ring_r := core_r * 1.15
	var ring_a := clampf(1.0 - t / 1.2, 0.0, 1.0)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(1.0, 0.5, 0.2, ring_a), 34.0, false)
	draw_arc(Vector2.ZERO, ring_r * 0.85, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, ring_a * 0.7), 14.0, false)
	# Debris sparks flung outward.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 40:
		var ang := rng.randf() * TAU
		var d := ring_r * rng.randf_range(0.4, 1.1)
		var sz := rng.randf_range(2.0, 7.0)
		draw_circle(Vector2.from_angle(ang) * d, sz,
			Color(1.0, rng.randf_range(0.5, 0.9), 0.2, ring_a))
	# Smoke puffs that linger after the flash.
	var smoke_a := clampf(0.5 - (t - 0.5) * 0.4, 0.0, 0.5)
	for i in 10:
		var ang := TAU * float(i) / 10.0
		draw_circle(Vector2.from_angle(ang) * (ring_r * 0.6), 18.0 + t * 20.0,
			Color(0.15, 0.13, 0.12, smoke_a))
