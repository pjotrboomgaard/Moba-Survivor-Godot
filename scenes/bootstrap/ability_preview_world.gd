class_name AbilityPreviewWorld
extends Control
## Rendered ability preview: a real SubViewport running a mini game world where a
## hero bot casts the hovered ability on 3 standing creeps. Shows the ACTUAL in-game
## hero sprite, creeps, and ability VFX (not a hand-drawn mimicry), on a loop.
##
## Structure (see .tscn):
##   AbilityPreviewRoot (this Control)
##     SubViewport  -> World (Node2D, holds hero + creeps)
##
## A SubViewport that is a child of the tree renders into the main viewport at its
## position/size automatically (not top-level), so it shows up right under the
## ability text in the hover card.
##
## The host (bootstrap) calls `.reload(hero_class_id, ability_slot)` on hover:
##   ability_slot 0..3 maps to Q/E/D/R; -1 = LMB primary; -2 = RMB secondary.

@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _world: Node2D = $SubViewport/World

## TextureRect that actually blits the SubViewport into the main window. A bare
## SubViewport node does NOT render to the parent canvas — you need a
## SubViewportTexture wrapped in a CanvasItem. Created at runtime here.
var _preview_tex: TextureRect = null

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var hero_class_id := "arclight"
var ability_slot := 0

var _hero: Player = null
var _creeps: Array[Enemy] = []
var _phase := "idle"   # prep -> casting -> recover -> loop
var _phase_time := 0.0
var _running := false

const PREP_DURATION := 0.5
const CAST_DURATION := 1.5
const RECOVER_DURATION := 1.0
const CREEP_COUNT := 3
const CREEP_START_X := 150.0
const HERO_X := -60.0

func _ready() -> void:
	# Add a Camera2D inside the SubViewport so the action (hero at x=-60, creeps at
	# x=150) is framed nicely in the small preview window. The camera centers on the
	# midpoint between hero and creeps.
	if _world != null:
		var cam := Camera2D.new()
		cam.name = "PreviewCam"
		cam.position = Vector2((HERO_X + CREEP_START_X) * 0.5, 0.0)
		cam.zoom = Vector2(0.7, 0.7)
		cam.limit_left = -400
		cam.limit_top = -400
		cam.limit_right = 400
		cam.limit_bottom = 400
		_world.add_child(cam)
		cam.make_current()
	# Size the SubViewport to a sensible default; _update_preview_viewport resizes.
	if _sub_viewport != null:
		_sub_viewport.size = Vector2i(360, 200)
	_ensure_preview_rect()
	_build_stage()


## A bare SubViewport child does not reliably blit into the main window when it is
## nested inside a Control layout. Wrap it in a SubViewportTexture shown by a
## TextureRect so the mini world is guaranteed to render under the ability text.
func _ensure_preview_rect() -> void:
	if _preview_tex != null and is_instance_valid(_preview_tex):
		return
	if _sub_viewport == null:
		return
	var svp_tex := _sub_viewport.get_texture()
	_preview_tex = TextureRect.new()
	_preview_tex.name = "PreviewRect"
	_preview_tex.texture = svp_tex
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preview_tex)


## Keep the SubViewport sized to this Control so the mini world fills the panel's
## preview area (and scales with the window).
func _update_viewport_size() -> void:
	if _sub_viewport == null:
		return
	var s := size
	_sub_viewport.size = Vector2i(maxi(8, int(s.x)), maxi(8, int(s.y)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_size()


func _build_stage() -> void:
	# A subtle ground so the world reads as a place, without clutter.
	var ground := Node2D.new()
	ground.set_script(_make_ground_script())
	_world.add_child(ground)


func _make_ground_script() -> GDScript:
	var text := """
extends Node2D
func _draw() -> void:
	draw_circle(Vector2(45.0, 0.0), 200.0, Color(0.05, 0.06, 0.09, 0.9))
	draw_circle(Vector2(45.0, 0.0), 150.0, Color(0.09, 0.10, 0.13, 0.6))
"""
	var script := GDScript.new()
	script.source_code = text
	script.reload(true)
	return script


func reload(next_hero_class: String, next_slot: int) -> void:
	hero_class_id = next_hero_class
	ability_slot = next_slot
	_running = true
	_restart()


func start() -> void:
	_running = true
	_restart()


func _restart() -> void:
	_clear_world()
	_spawn_hero()
	_spawn_creeps()
	_phase = "prep"
	_phase_time = 0.0


func _clear_world() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.queue_free()
	_hero = null
	for c in _creeps:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_creeps.clear()


func _spawn_hero() -> void:
	var p := PlayerScene.instantiate() as Player
	_world.add_child(p)
	_hero = p
	# OFFLINE mode with latched external commands -> the bot's brain does NOT override
	# our scripted casting. Non-local -> its Camera2D is disabled; the SubViewport
	# frames the action.
	p.configure(0, Player.SimulationMode.OFFLINE, false, hero_class_id)
	p.global_position = Vector2(HERO_X, 0.0)
	if p.camera != null:
		p.camera.enabled = false
	p.set_authority_command(Vector2.ZERO, Vector2(CREEP_START_X, 0.0), false, false, [false, false, false, false], false)
	p.health.current_health = p.health.max_health


func _spawn_creeps() -> void:
	_creeps.clear()
	var type_id := EnemyType.DEFAULT_TYPE_ID
	for i in CREEP_COUNT:
		var e := EnemyScene.instantiate() as Enemy
		_world.add_child(e)
		e.configure(300 + i, true, type_id, 1.0, 0.0)
		e.global_position = Vector2(CREEP_START_X, -60.0 + 60.0 * float(i))
		_freeze_creep(e)
		_creeps.append(e)


## Stand a creep still: zero its speed so it doesn't wander off-frame. We keep its
## physics on so it still renders its HP bar, flashes on hit, and (realistically) can
## fight back a little. The hero's HP is re-topped each loop so it never dies.
func _freeze_creep(e: Enemy) -> void:
	e.movement_speed = 0.0
	e.speed_cap = 0.0
	e.velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _running or _hero == null:
		return
	_phase_time += delta
	match _phase:
		"prep":
			_aim_at_creeps()
			if _phase_time >= PREP_DURATION:
				_phase = "casting"
				_phase_time = 0.0
				_do_cast()
		"casting":
			if _phase_time >= CAST_DURATION:
				_phase = "recover"
				_phase_time = 0.0
				_reset_creeps()
		"recover":
			if _phase_time >= RECOVER_DURATION:
				_phase = "prep"
				_phase_time = 0.0


func _aim_at_creeps() -> void:
	if _hero == null or _creeps.is_empty():
		return
	var mid := _creeps[_creeps.size() / 2]
	if mid == null:
		return
	var attack := ability_slot == -1
	var secondary := ability_slot == -2
	_hero.set_authority_command(Vector2.ZERO, mid.global_position, attack, false, [false, false, false, false], secondary)


func _do_cast() -> void:
	if _hero == null:
		return
	_aim_at_creeps()
	# Clear cooldowns so the cast always lands for the loop.
	_hero.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	_hero.secondary_cooldown = 0.0
	match ability_slot:
		-1:  # LMB: hold the primary attack.
			_hero.command_attack = true
		-2:  # RMB: fire the secondary.
			_hero.command_secondary = true
		_:   # Q/E/D/R kit ability: tap to arm + confirm.
			_hero.scripted_tap_ability(ability_slot)
			_hero.scripted_tap_ability(ability_slot)


func _reset_creeps() -> void:
	for c in _creeps:
		if c == null or not is_instance_valid(c):
			continue
		c.health.current_health = c.health.max_health
		c.global_position = Vector2(CREEP_START_X, c.global_position.y)
		_freeze_creep(c)
	if _hero != null:
		_hero.health.current_health = _hero.health.max_health
