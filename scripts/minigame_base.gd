extends Node2D

## Base for the village minigames. Each corner of the arena hosts one; the
## player (or a CPU ally that walked in) calls `interact()` to start it, plays
## for `DURATION`, and on finish the owner earns gold + XP through the same
## path kills use (`player.add_gold` / `player.add_xp`).
##
## Subclasses must override `_reset()`, `on_input_event(event)`, `bot_tick(delta)`,
## `_update_delta(delta)`, and `_draw_body()` to keep each minigame to ~100-200
## lines while sharing the lifecycle + UI banner/ring plumbing.
## No class_name to avoid circular dependency with Player at parse time.

signal finished(owner_player: Player, score: int, rewards: Dictionary)

const DURATION: float = 15.0
const REWARD_GOLD := 30
const REWARD_XP := 25

var owner_player: Player = null
var active := false
var finished_flag := false
var score := 0
var timer: float = DURATION
var area_index := 0
var accent := Color("8fae6a")
var display_name := "Minigame"

var _input_buffer: Array[InputEvent] = []
var _banner_alpha := 0.0
var _finished_flash := 0.0
var _ui_layer: CanvasLayer = null
var _ui_label: Label = null

func start(owner_player: Player, index: int = -1, accent_color: Color = Color.WHITE) -> void:
	owner_player = owner_player
	area_index = index if index >= 0 else area_index
	accent = accent_color
	active = true
	finished_flag = false
	score = 0
	timer = DURATION
	_input_buffer.clear()
	_banner_alpha = 1.0
	_finished_flash = 0.0
	_reset()
	_update_ui_label()
	queue_redraw()


func _update_ui_label() -> void:
	if _ui_label == null:
		return
	if active:
		_ui_label.visible = true
		_ui_label.text = "%s  |  Score: %d  |  %.1fs" % [display_name.to_upper(), score, timer]
		_ui_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	else:
		_ui_label.visible = false


func stop() -> void:
	if not active:
		return
	active = false
	_finish_with_reward()


## Public entry point: the player/bot "pops" the minigame. Subclasses do NOT
## re-implement this; they hook into `on_input_event` + `bot_tick`.
func interact() -> void:
	if not active or owner_player == null:
		return
	# A short grace window: subclass can veto via `_veto_interact`.
	if _veto_interact():
		return
	queue_redraw()


## Called by MinigameArea once the player is within interact range; returns
## true to consume the input and forward to the minigame, false to let the
## event fall through to normal gameplay input.
func is_interactable() -> bool:
	return active and not finished_flag


## Called by MinigameArea each frame with the player's movement vector (for
## movement-based games like Treasure Dash) plus a flag whether the player is
## currently on the local (human) side.
func player_input_move(move: Vector2) -> void:
	if not active:
		return
	_update_delta(get_process_delta_time())


## Bot path: CpuBrain calls this every frame while the bot is inside the
## active minigame. Subclasses pick a move/aim/attack for the bot.
func bot_tick(_delta: float) -> Dictionary:
	return {"move": Vector2.ZERO, "attack": false, "interact": false}


func _ready() -> void:
	# Build a screen-space UI overlay so the minigame banner is always visible
	# when active, regardless of camera position.
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "MinigameUI"
	_ui_layer.layer = 90
	add_child(_ui_layer)
	_ui_label = Label.new()
	_ui_label.name = "Banner"
	_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_label.add_theme_font_size_override("font_size", 28)
	_ui_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	# Position in screen-space: top-center. Use explicit position/size.
	_ui_label.position = Vector2(360, 30)
	_ui_label.size = Vector2(520, 50)
	_ui_label.visible = false
	_ui_layer.add_child(_ui_label)


func _veto_interact() -> bool:
	return false


func _reset() -> void:
	pass


func _update_delta(_delta: float) -> void:
	pass


func on_input_event(event: InputEvent) -> void:
	_input_buffer.append(event)


func _draw() -> void:
	# Always draw the idle/active ring so the corner reads as a minigame spot.
	if not active:
		_draw_idle_ring()
		return
	_draw_active_ring()
	_draw_banner()
	_draw_body()


func _draw_idle_ring() -> void:
	draw_circle(Vector2.ZERO, 60.0, Color(accent.r, accent.g, accent.b, 0.08))
	draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.20), 2.0)


func _draw_active_ring() -> void:
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.006)
	draw_arc(Vector2.ZERO, 78.0 * pulse, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.85), 3.0)
	draw_circle(Vector2.ZERO, 74.0, Color(accent.r, accent.g, accent.b, 0.06))
	if _finished_flash > 0.0:
		draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 48, Color(1.0, 1.0, 0.4, _finished_flash), 4.0)


func _draw_banner() -> void:
	# Banner: display name + score/timer, drawn above the ring.
	var name_y := -104.0
	var timer_frac := clampf(timer / DURATION, 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-140.0, name_y), display_name,
		HORIZONTAL_ALIGNMENT_CENTER, 280, 22, Color(1.0, 1.0, 1.0, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(-140.0, name_y + 24.0),
		"Score %d" % score, HORIZONTAL_ALIGNMENT_CENTER, 280, 16,
		Color(1.0, 1.0, 0.7, 0.9))
	# Timer bar.
	var bar_w := 200.0
	var bar_h := 5.0
	var bar_x := -bar_w * 0.5
	var bar_y := name_y + 36.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(bar_x, bar_y, bar_w * timer_frac, bar_h),
		Color(accent.r, accent.g, accent.b, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(-140.0, bar_y + 20.0),
		"%.0fs" % timer, HORIZONTAL_ALIGNMENT_CENTER, 280, 13,
		Color(0.9, 0.9, 0.9, 0.8))


func _draw_body() -> void:
	pass


## Selftest/verify flag: when true, `_process` drives `bot_tick` every frame so
## the game plays itself even when the owner is a human (used by minigame_verify
## so a pinned local hero still earns score + reward without keyboard input).
var bot_force := false


func _process(delta: float) -> void:
	if not active:
		return
	_update_delta(delta)
	if bot_force:
		bot_tick(delta)
	timer -= delta
	_banner_alpha = maxf(0.0, _banner_alpha - delta * 0.4)
	_finished_flash = maxf(0.0, _finished_flash - delta * 1.2)
	_update_ui_label()
	if timer <= 0.0:
		_finish_with_reward()
		return
	queue_redraw()


func _finish_with_reward() -> void:
	if finished_flag:
		return
	finished_flag = true
	active = false
	_finished_flash = 1.0
	_update_ui_label()
	if owner_player != null and is_instance_valid(owner_player):
		owner_player.add_gold(REWARD_GOLD)
		owner_player.add_xp(REWARD_XP)
	AudioService.play("minigame_win")
	_vfx_burst(Color(1.0, 0.95, 0.4), 24.0, 200.0)
	_emit_finished()


## Lightweight action VFX: spawn a small one-shot GPUParticles burst at a local
## position with a unique color/count/speed per minigame so each game has a
## distinct visual "pop" on its signature action.
var _vfx: Array = []

func _vfx_burst(color: Color, speed: float = 120.0, lifetime: float = 0.45) -> void:
	var parts := CPUParticles2D.new()
	parts.emitting = true
	parts.one_shot = true
	parts.amount = 14
	parts.lifetime = lifetime
	parts.explosiveness = 1.0
	parts.direction = Vector2.ZERO
	parts.spread = 180.0
	parts.initial_velocity_min = speed * 0.5
	parts.initial_velocity_max = speed
	parts.gravity = Vector2(0.0, 40.0)
	parts.scale_amount_min = 0.8
	parts.scale_amount_max = 1.6
	parts.texture = _make_vfx_texture(color)
	parts.position = Vector2.ZERO
	add_child(parts)
	_vfx.append(parts)
	var timer := get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(parts):
			parts.queue_free()
		_vfx.erase(parts)
	)

static func _make_vfx_texture(color: Color) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length()
			if d <= 3.5:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0 - d / 4.5))
	return ImageTexture.create_from_image(img)


func _emit_finished() -> void:
	finished.emit(owner_player, score, {"gold": REWARD_GOLD, "xp": REWARD_XP})
	if is_inside_tree():
		var main: Node = get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("flash_recruit_joined"):
			main.call("flash_recruit_joined", "%s" % display_name, "earned %d" % REWARD_GOLD, accent)
