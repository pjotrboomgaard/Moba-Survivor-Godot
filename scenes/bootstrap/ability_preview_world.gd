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
const LightningScene := preload("res://scenes/effects/lightning_effect.tscn")
const AbilityVfxScene := preload("res://scenes/effects/ability_vfx.tscn")

## Mirror of main.gd's VECTOR_ONLY_KIT_IDS so the preview shows the same vector
## cast animations the real game renders (not the generic pixel-art burst).
const VECTOR_ONLY_KIT_IDS := {
	"tobor_steam_keg": PlayerClass.EffectStyle.BLAST,
	"tobor_spider_mines": PlayerClass.EffectStyle.BURST,
	"tobor_steam_turret": PlayerClass.EffectStyle.BURST,
	"tobor_energy_field": PlayerClass.EffectStyle.BURST,
	"arclight_blast_of_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_chain_lightning": PlayerClass.EffectStyle.BOLT,
	"arclight_thundergods_wrath": PlayerClass.EffectStyle.BURST,
	"bulwark_fissure": PlayerClass.EffectStyle.BLAST,
	"bulwark_heavyweight": PlayerClass.EffectStyle.BURST,
	"bulwark_echo_slam": PlayerClass.EffectStyle.BURST,
	"warden_tongue_tied": PlayerClass.EffectStyle.BOLT,
	"warden_thorn_volley": PlayerClass.EffectStyle.BOLT,
	"warden_life_drain": PlayerClass.EffectStyle.WAVE,
	"warden_voodoo_wards": PlayerClass.EffectStyle.BURST,
	"frostbinder_ice_spike": PlayerClass.EffectStyle.BOLT,
	"frostbinder_frost_nova": PlayerClass.EffectStyle.BURST,
	"frostbinder_glacial_cone": PlayerClass.EffectStyle.ARC,
	"cinder_dragon_fire": PlayerClass.EffectStyle.BLAST,
	"cinder_fiery_assault": PlayerClass.EffectStyle.BURST,
	"cinder_pillar_of_flame": PlayerClass.EffectStyle.BURST,
	"pyra_sticky_bomb": PlayerClass.EffectStyle.BLAST,
	"pyra_boom_dust": PlayerClass.EffectStyle.BURST,
	"pyra_air_strike": PlayerClass.EffectStyle.BURST,
	"slag_boulder_hurl": PlayerClass.EffectStyle.BLAST,
	"slag_volcanic_touch": PlayerClass.EffectStyle.BURST,
	"slag_eruption": PlayerClass.EffectStyle.BURST,
	"ember_entangle": PlayerClass.EffectStyle.WAVE,
	"ember_firebomb": PlayerClass.EffectStyle.BLAST,
	"ember_unbreakable": PlayerClass.EffectStyle.BURST,
	"thorn_poison_spray": PlayerClass.EffectStyle.ARC,
	"thorn_toxin_ward": PlayerClass.EffectStyle.BURST,
	"thorn_toxicity": PlayerClass.EffectStyle.WAVE,
	"thorn_poison_burst": PlayerClass.EffectStyle.BURST,
	"willow_forsaken_shot": PlayerClass.EffectStyle.BOLT,
	"willow_wall_of_roots": PlayerClass.EffectStyle.BURST,
	"stump_natures_rally": PlayerClass.EffectStyle.BURST,
	"stump_overgrowth": PlayerClass.EffectStyle.BURST,
	"sage_petal_dance": PlayerClass.EffectStyle.ARC,
	"sage_volatile_pod": PlayerClass.EffectStyle.BLAST,
	"sage_charm": PlayerClass.EffectStyle.BURST,
	"volt_gust": PlayerClass.EffectStyle.ARC,
	"volt_plasma_bolt": PlayerClass.EffectStyle.BOLT,
	"volt_typhoon": PlayerClass.EffectStyle.BURST,
	"nebula_arcane_bolt": PlayerClass.EffectStyle.BOLT,
	"nebula_curse_of_ages": PlayerClass.EffectStyle.BURST,
	"nebula_chronofield": PlayerClass.EffectStyle.BURST,
	"astral_ghastly_touch": PlayerClass.EffectStyle.BOLT,
	"astral_moonfall": PlayerClass.EffectStyle.BURST,
	"astral_as_one": PlayerClass.EffectStyle.BURST,
	"rime_ice_imprisonment": PlayerClass.EffectStyle.BURST,
	"rime_chilling_touch": PlayerClass.EffectStyle.BURST,
	"rime_freezing_field": PlayerClass.EffectStyle.BURST,
}

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
		# Zoomed out 2x from the earlier 0.7 so ability radii (rings, bolts, area
		# effects) have room to read in the small panel instead of running off-frame.
		cam.zoom = Vector2(0.35, 0.35)
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
	# Fill the panel's bottom area: stretch the preview world to the full slot so it
	# reads as a wide banner pinned to the bottom rather than a small thumbnail.
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_tex.grow_vertical = Control.GROW_DIRECTION_END
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
	ground.name = "StageGround"
	ground.set_meta("preview_stage", true)
	ground.set_script(_make_ground_script())
	_world.add_child(ground)


func _make_ground_script() -> GDScript:
	# The SubViewport has transparent_bg=true, so anything not painted is fully
	# transparent — the menu panel background shows through. We draw a very faint
	# disc just so the scene reads as "a place", but keep alpha low enough that
	# the black box effect is gone.
	var text := """
extends Node2D
func _draw() -> void:
	var center := Vector2(45.0, 0.0)
	# Soft arena floor — moderate alpha so it reads as a place but isn't a solid
	# black box. The menu panel's own background still shows through the edges.
	draw_circle(center, 240.0, Color(0.10, 0.14, 0.18, 0.45))
	draw_circle(center, 140.0, Color(0.12, 0.16, 0.20, 0.25))
	draw_arc(center, 160.0, 0.0, TAU, 48, Color(0.5, 0.7, 0.9, 0.08), 1.5, true)
"""
	var script := GDScript.new()
	script.source_code = text
	script.reload(true)
	return script


func reload(next_hero_class: String, next_slot: int) -> void:
	hero_class_id = next_hero_class
	ability_slot = next_slot
	_running = true
	SoundDirector.preview_muted = true
	_restart()


func start() -> void:
	_running = true
	SoundDirector.preview_muted = true
	_restart()


## Silence + clear the running preview (called when the menu hover closes).
func stop() -> void:
	_running = false
	SoundDirector.preview_muted = false


func _restart() -> void:
	_clear_world()
	_spawn_hero()
	_spawn_creeps()
	_phase = "prep"
	_phase_time = 0.0


func _clear_world() -> void:
	# Free the tracked hero + creeps explicitly (they may hold pending state /
	# connected signals we want released cleanly).
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	_hero = null
	for c in _creeps:
		if c != null and is_instance_valid(c):
			c.free()
	_creeps.clear()
	# Synchronously free ANY other dynamic children of the preview world (summons,
	# throw projectiles, lightning/burst VFX, stray projectiles, LMB dots) so NOTHING
	# leaks into the next ability's preview when the user hovers a different ability.
	# Keep only the permanent stage: the ground disc and the preview camera.
	# (Copy the child list first — freeing children invalidates the live array.)
	var children := _world.get_children()
	for child in children:
		if child is Camera2D:
			continue
		if child.has_meta("preview_stage"):
			continue
		child.free()



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
	# Route all ability/projectile spawns (summons, lobs, projectiles) INTO this
	# SubViewport's world instead of the main menu scene, so turrets/mines/kegs
	# are visible in the preview.
	p.vfx_parent_override = _world
	p.set_authority_command(Vector2.ZERO, Vector2(CREEP_START_X, 0.0), false, false, [false, false, false, false], false)
	p.health.current_health = p.health.max_health
	# Spawn the vector cast animation + pixel-art VFX INSIDE this SubViewport's
	# world so the preview shows the actual ability animation, not just hero+creeps.
	p.ability_cast.connect(_on_preview_ability_cast)
	# Also mirror LMB (staff_cast) and RMB (secondary_fx) so their real weapon /
	# secondary VFX render inside the preview instead of spawning off-screen in the
	# main menu scene.
	p.staff_cast.connect(_on_preview_staff_cast)
	p.secondary_fx.connect(_on_preview_secondary_fx)


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


## Mirror of main.gd._play_ability_effect, but spawns INSIDE the preview SubViewport
## so the user actually sees the vector cast animation + pixel-art burst.
func _on_preview_ability_cast(ability_id: String, effect_style: int, points: PackedVector2Array) -> void:
	var class_prefix := ability_id.split("_")[0]
	var class_data := PlayerClass.by_id(class_prefix)
	if class_data.is_empty():
		return
	var vector_only := VECTOR_ONLY_KIT_IDS.has(ability_id)
	var kit_style := KitFxLibrary.kit_visual(ability_id)
	var primary_color := Color(class_data.effect_color)
	var secondary_color := Color(class_data.effect_secondary)
	if not kit_style.is_empty():
		primary_color = Color(str(kit_style.get("primary_color", class_data.effect_color)))
		secondary_color = Color(str(kit_style.get("secondary_color", class_data.effect_secondary)))
	if ability_id != "stump_overgrowth":
		var flash := LightningScene.instantiate() as LightningEffect
		flash.style = VECTOR_ONLY_KIT_IDS.get(ability_id, effect_style)
		flash.main_color = primary_color
		flash.chain_color = secondary_color
		if flash.style == PlayerClass.EffectStyle.BLAST:
			flash.lifetime = 0.22
		elif flash.style == PlayerClass.EffectStyle.BURST:
			flash.lifetime = clampf(0.28 + (points[1].x if points.size() >= 2 else 80.0) / 1400.0, 0.28, 0.55)
		elif flash.style == PlayerClass.EffectStyle.TELEPORT:
			var dist := 0.0
			if points.size() >= 2 and points[1] is Vector2:
				dist = points[0].distance_to(points[1])
			flash.lifetime = clampf(0.28 + dist / 1600.0, 0.28, 0.52)
		else:
			flash.lifetime = clampf(0.14 + (points[1].x if points.size() >= 2 else 80.0) / 900.0, 0.14, 0.42)
		flash.points = points
		KitFxLibrary.apply_to_lightning(flash, ability_id)
		_world.add_child(flash)
		if not vector_only:
			var vfx := AbilityVfxScene.instantiate() as AbilityVfx
			vfx.configure(ability_id, effect_style, points)
			_world.add_child(vfx)


## LMB weapon blast VFX inside the preview SubViewport (mirror of main.gd).
func _on_preview_staff_cast(_effect_kind: String, points: PackedVector2Array) -> void:
	var class_data := PlayerClass.by_id(_effect_kind)
	if class_data.is_empty():
		return
	var effect := LightningScene.instantiate() as LightningEffect
	effect.style = int(class_data.effect_style)
	effect.main_color = Color(class_data.effect_color)
	effect.chain_color = Color(class_data.effect_secondary)
	if effect.style == PlayerClass.EffectStyle.BLAST:
		effect.lifetime = 0.28
		effect.draw_mode = "simple_circle"
	effect.points = points
	_world.add_child(effect)


## RMB secondary VFX inside the preview SubViewport (mirror of main.gd._play_secondary_fx).
func _on_preview_secondary_fx(class_id: String, style: int, points: PackedVector2Array) -> void:
	var class_data := PlayerClass.by_id(class_id)
	if class_data.is_empty():
		return
	var effect := LightningScene.instantiate() as LightningEffect
	effect.style = style
	effect.main_color = Color(class_data.effect_color)
	effect.chain_color = Color(class_data.effect_secondary)
	if style == PlayerClass.EffectStyle.BLAST or style == PlayerClass.EffectStyle.BURST:
		effect.lifetime = 0.48
	elif style == PlayerClass.EffectStyle.TELEPORT:
		effect.lifetime = 0.42
	else:
		effect.lifetime = 0.4
	var kit_style := KitFxLibrary.kit_visual("%s_%s" % [class_id, str(class_data.get("secondary", ""))])
	if not kit_style.is_empty():
		var primary := str(kit_style.get("primary_color", ""))
		var secondary := str(kit_style.get("secondary_color", ""))
		if primary != "":
			effect.main_color = Color(primary)
		if secondary != "":
			effect.chain_color = Color(secondary)
		effect.ribbon_count = int(kit_style.get("ribbon_count", effect.ribbon_count))
		effect.pulse_count = int(kit_style.get("pulse_count", effect.pulse_count))
		var style_tag := str(kit_style.get("style", ""))
		if style_tag != "":
			effect.style_tag = style_tag
	effect.points = points
	_world.add_child(effect)


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
	# Make sure the hero is facing the aim point so weapon blasts fly toward the
	# creeps (several weapon casts use facing_direction for their impact point).
	if _creeps.size() >= 1:
		var mid := _creeps[_creeps.size() / 2]
		if mid != null:
			_hero.aim_world_position = mid.global_position
			var dir := (_hero.global_position.position_to(mid.global_position))
			if dir.length_squared() > 0.0:
				_hero.facing_direction = dir.normalized()
	# Clear cooldowns so the cast always lands for the loop.
	_hero.ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	_hero.secondary_cooldown = 0.0
	# Attack charge full + zeroed out so the LMB blast is at full strength and lands
	# immediately rather than starting a charged wind-up.
	_hero.attack_charge = 0.0
	_hero.attack_cooldown = 0.0
	match ability_slot:
		-1:  # LMB: fire the real primary attack directly (real weapon VFX).
			_hero._perform_attack()
		-2:  # RMB: fire the real secondary directly (real secondary VFX).
			_hero._cast_secondary()
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
