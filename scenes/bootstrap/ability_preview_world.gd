class_name AbilityPreviewWorld
extends Node2D
## A self-contained "mini game world" that renders the REAL in-game hero + creeps
## and has the hero bot auto-cast a chosen ability on them, on a loop. Used as the
## ability-hover preview in the main menu (embedded in a SubViewport so the menu shows
## the actual in-game VFX / hero / creeps rather than a hand-drawn mimicry).
##
## Requirements (per user):
##   * Real in-game hero (bot that casts by itself).
##   * 3 real creeps standing still as targets.
##   * Loops: cast -> VFX plays on creeps -> creeps damaged/knocked -> reset -> repeat.
##   * No background clutter so the effect reads clearly.
##
## The host (bootstrap) sets `.hero_class_id` + `.ability_slot` and calls `.start()`.
## On re-hover it calls `.reload(hero_class_id, ability_slot)`.
##
## Ability slot convention: 0..3 maps to Q/E/D/R kit abilities; -1 = LMB primary;
## -2 = RMB secondary. For LMB/RMB the preview shows the hero performing its
## basic attack / secondary on the creeps.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var hero_class_id := "arclight"
var ability_slot := 0

var _hero: Player = null
var _creeps: Array[Enemy] = []
var _phase := "idle"      # prep -> casting -> recover -> (loop)
var _phase_time := 0.0
var _running := false

# Timings for the loop.
const PREP_DURATION := 0.6
const CAST_DURATION := 1.6
const RECOVER_DURATION := 1.1

const CREEP_COUNT := 3
const CREEP_START_X := 170.0
const HERO_X := -90.0

func _ready() -> void:
	# Nothing here; the host calls start()/reload() to populate.
	pass


func reload(next_hero_class: String, next_slot: int) -> void:
	hero_class_id = next_hero_class
	ability_slot = next_slot
	_restart()


func start() -> void:
	_running = true
	_restart()


## Rebuild the hero + creeps and begin the cast loop.
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


## Spawn the hero in OFFLINE mode with external commands so the bot's brain does NOT
## override our scripted casting. Non-local so its Camera2D is disabled (the host's
## SubViewport camera controls framing).
func _spawn_hero() -> void:
	var p := PlayerScene.instantiate() as Player
	add_child(p)
	_hero = p
	p.configure(0, Player.SimulationMode.OFFLINE, false, hero_class_id)
	p.global_position = Vector2(HERO_X, 0.0)
	if p.camera != null:
		p.camera.enabled = false
	# Latch external commands so OFFLINE polling does not fight us.
	p.set_authority_command(Vector2.ZERO, Vector2(CREEP_START_X, 0.0), false, false, [false, false, false, false], false)
	# Keep full health so the preview never shows a dead hero.
	p.health.current_health = p.health.max_health


## Spawn 3 static creeps in a line to the hero's right as the cast targets.
func _spawn_creeps() -> void:
	_creeps.clear()
	var type_id := EnemyType.DEFAULT_TYPE_ID
	for i in CREEP_COUNT:
		var e := EnemyScene.instantiate() as Enemy
		add_child(e)
		e.configure(300 + i, true, type_id, 1.0, 0.0)
		e.global_position = Vector2(CREEP_START_X, -72.0 + 72.0 * float(i))
		# Stand still: freeze the creep so it doesn't wander off-frame.
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
			# Hero faces the creeps, aims at the middle creep.
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
	# Keep the aim latched on the middle creep; move=0 so the hero stands still.
	var slots := [false, false, false, false]
	var attack := ability_slot == -1
	var secondary := ability_slot == -2
	_hero.set_authority_command(Vector2.ZERO, mid.global_position, attack, false, slots, secondary)


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
			# A second tap confirms targeted abilities (arm then confirm).
			_hero.scripted_tap_ability(ability_slot)


func _reset_creeps() -> void:
	# Re-top the creeps' HP so the loop keeps showing fresh damage.
	for c in _creeps:
		if c == null or not is_instance_valid(c):
			continue
		c.health.current_health = c.health.max_health
		c.global_position = Vector2(CREEP_START_X, c.global_position.y)
		_freeze_creep(c)
	# Restore the hero's health so it never dies mid-preview.
	if _hero != null:
		_hero.health.current_health = _hero.health.max_health


func _draw() -> void:
	# Faint ground grid so the mini-world has spatial reference without clutter.
	var grid_step := 48.0
	var left := -320.0
	var right := 340.0
	var top := -240.0
	var bottom := 240.0
	for gx in range(int(left / grid_step), int(right / grid_step) + 1):
		for gy in range(int(top / grid_step), int(bottom / grid_step) + 1):
			var p := Vector2(gx * grid_step, gy * grid_step)
			draw_line(p, p + Vector2(grid_step, 0.0), Color(1.0, 1.0, 1.0, 0.04), 1.0)
			draw_line(p, p + Vector2(0.0, grid_step), Color(1.0, 1.0, 1.0, 0.04), 1.0)
	# A slightly brighter "stage" ellipse under the action.
	draw_circle(Vector2(40.0, 0.0), 260.0, Color(1.0, 0.95, 0.85, 0.03))
