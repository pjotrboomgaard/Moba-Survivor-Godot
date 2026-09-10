class_name AbilityPreviewWorld
extends Node2D
## A self-contained "mini game world" that renders the REAL in-game hero + creeps
## and has the hero bot auto-cast a chosen ability on them, on a loop. Used as the
## ability-hover preview in the main menu (embedded in a SubViewport so the menu shows
## the actual in-game VFX / hero / creeps rather than a hand-drawn mimicry).
##
## Requirements (per user):
##   * Real in-game hero (CPU-simulated, casts by itself).
##   * 3 real creeps standing still as targets.
##   * Loops: cast -> VFX plays on creeps -> creeps get damaged/knocked -> reset -> repeat.
##   * No background clutter so the effect reads clearly.
##
## The host (bootstrap) sets `.hero_class_id` + `.ability_slot` and calls `.start()`.
## On resize/re-hover it calls `.reload(hero_class_id, ability_slot)`.

const PlayerScene := preload("res://scenes/player/player.tscn")
const EnemyScene := preload("res://scenes/enemy/enemy.tscn")

var hero_class_id := "arclight"
var ability_slot := 0  # 0..3 maps to Q/E/D/R; -1 = basic LMB, -2 = secondary RMB

var _hero: Player = null
var _creeps: Array[Enemy] = []
var _cast_timer := 0.0
var _running := false
var _reset_delay := 1.6  # seconds after a cast before the creeps reset & next cast

const CAST_PAUSE := 0.9
const CREEP_HP_MULT := 1.0
const CREEP_COUNT := 3

func _ready() -> void:
	# No camera of our own; the SubViewport host controls framing.
	# Build a subtle floor so the world reads as "a place."
	_build_floor()


func reload(next_hero_class: String, next_slot: int) -> void:
	hero_class_id = next_hero_class
	ability_slot = next_slot
	_restart_world()


func start() -> void:
	_running = true
	_restart_world()


func _restart_world() -> void:
	_clear_world()
	_spawn_hero()
	_spawn_creeps()
	_cast_timer = 0.4
	# Make sure the hero is not dead and has full HP so the loop looks clean.
	if _hero != null:
		_hero.health.current_health = _hero.health.max_health
		_hero.health.is_dead = false
		_hero.active = true


func _clear_world() -> void:
	if _hero != null:
		_hero.queue_free()
		_hero = null
	for c in _creeps:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_creeps.clear()


func _spawn_hero() -> void:
	var p := PlayerScene.instantiate() as Player
	add_child(p)
	_hero = p
	# CPU mode so it drives itself via CpuBrain, but we will override with scripted
	# casts. Non-local so it does NOT enable its own Camera2D or fight the viewport.
	p.configure(0, Player.SimulationMode.CPU, false, hero_class_id)
	p.global_position = Vector2.ZERO
	# Kill the hero's camera so it doesn't grab the SubViewport.
	if p.camera != null:
		p.camera.enabled = false
	# Keep the hero still (we place it, not the brain's wander logic).
	p.movement_locked = true
	# Full health so it never dies mid-preview.
	p.health.current_health = p.health.max_health


func _spawn_creeps() -> void:
	_creeps.clear()
	# Three creeps in a small line ahead of the hero.
	var type_id := EnemyType.DEFAULT_TYPE_ID
	for i in CREEP_COUNT:
		var e := EnemyScene.instantiate() as Enemy
		add_child(e)
		e.configure(100 + i, true, type_id, CREEP_HP_MULT, 0.0)
		e.global_position = Vector2(120.0, -70.0 + 70.0 * float(i))
		# Stand still: freeze the creep so it doesn't wander off-frame.
		_freeze_cree