extends Node2D

## Simple white spawn bubble. Team color lives on the health / shield bars, not here.

func _ready() -> void:
	z_index = 30
	z_as_relative = true
	set_process(true)


func _process(_delta: float) -> void:
	var host := get_parent() as Player
	visible = host != null and host.active and host.is_pvp_protected()
	if visible:
		queue_redraw()


func _draw() -> void:
	var host := get_parent() as Player
	if host == null or not host.is_pvp_protected():
		return
	if host.pvp_invuln_timer <= GameRuntime.FFA_PVP_SHIELD_FLICKER_SECONDS:
		var beat := 0.10 if host.pvp_invuln_timer <= 2.0 else 0.18
		if fmod(host.pvp_invuln_timer, beat * 2.0) <= beat:
			return
	var pulse := 1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.006)
	var radius := 58.0 * pulse
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.10))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, 0.06))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.88), 2.6, true)
