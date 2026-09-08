class_name WorldClock
extends RefCounted

## Shared day/night clock. Morning and dusk tint the world; night is short and darker.
## Tree shadows stay on the south side of the trunk and only swing with the sun.

const CYCLE_SECONDS := 210.0
const NIGHT_START := 0.78
const NIGHT_END := 0.90

static var time_of_day := 0.18
static var revision := 0
static var sun_dir := Vector2(0.22, 0.86)
static var shadow_stretch := 0.62
static var shadow_alpha := 0.34
static var ambient := Color(1.0, 1.0, 1.0, 1.0)
static var is_night := false
## Night creeps: 1.15x movement speed, 1.5x attack rate (shorter windup/cooldown).
static var night_speed_mult := 1.0
static var night_attack_mult := 1.0


static func tick(delta: float) -> void:
	if GameRuntime.is_classic() or GameRuntime.is_dedicated_server():
		ambient = Color.WHITE
		shadow_alpha = 0.0
		is_night = false
		return
	time_of_day = fposmod(time_of_day + delta / CYCLE_SECONDS, 1.0)
	_refresh()
	revision += 1


static func _refresh() -> void:
	var t := time_of_day
	is_night = t >= NIGHT_START and t < NIGHT_END
	# Sun stays in the southern half of the screen and only swings east/west.
	var day_span := NIGHT_START
	var sun_t := clampf(t / maxf(0.001, day_span), 0.0, 1.0)
	if is_night:
		sun_t = 1.0 if t < (NIGHT_START + NIGHT_END) * 0.5 else 0.0
	var azimuth := lerpf(-0.72, 0.72, sun_t)
	sun_dir = Vector2(sin(azimuth), absf(cos(azimuth)) * 0.72 + 0.28).normalized()
	var noon := 1.0 - absf(sun_t - 0.5) * 2.0
	if is_night:
		shadow_stretch = 0.18
		shadow_alpha = 0.08
		ambient = Color(0.38, 0.44, 0.58, 1.0)
		night_speed_mult = 1.15
		night_attack_mult = 1.5
		return
	night_speed_mult = 1.0
	night_attack_mult = 1.0
	shadow_stretch = lerpf(1.05, 0.38, noon)
	shadow_alpha = lerpf(0.22, 0.40, 1.0 - noon)
	if t < 0.16:
		var k := t / 0.16
		ambient = Color(1.06, 0.88, 0.72, 1.0).lerp(Color(1.0, 0.98, 0.94, 1.0), k)
		shadow_alpha = lerpf(0.18, 0.32, k)
	elif t < 0.55:
		ambient = Color(1.0, 1.0, 1.0, 1.0)
		shadow_alpha = lerpf(0.34, 0.26, noon)
	elif t < 0.70:
		var k := (t - 0.55) / 0.15
		ambient = Color(1.0, 0.96, 0.90, 1.0).lerp(Color(1.08, 0.72, 0.52, 1.0), k)
		shadow_stretch = lerpf(0.5, 1.08, k)
		shadow_alpha = lerpf(0.28, 0.38, k)
	else:
		var k := clampf((t - 0.70) / 0.08, 0.0, 1.0)
		ambient = Color(1.08, 0.72, 0.52, 1.0).lerp(Color(0.46, 0.50, 0.64, 1.0), k)
		shadow_stretch = lerpf(1.08, 0.22, k)
		shadow_alpha = lerpf(0.36, 0.10, k)


static func depth_z(world_y: float, bias: int = 0) -> int:
	return 40 + int(world_y) + bias
