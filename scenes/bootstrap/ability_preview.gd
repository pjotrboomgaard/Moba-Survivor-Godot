class_name AbilityPreview
extends Control

## Ability preview: auto-casting mini-simulation rendered directly in _draw().
## Shows 3 red creeps being hit by the ability effect, with archetype-appropriate
## reactions (pushback, flash, damage, death). Loops automatically; no clicking.
## Uses the real in-game FX frames + the real grunt sprite for fidelity.

const CREEP_COUNT := 3
const CREEP_SPRITE := "grunt"
const LOOP_DURATION := 3.0
const TRAVEL_END_RATIO := 0.45
const IMPACT_RATIO := 0.20

var ability_id := ""
var _arch := -1
var _fx_frames: Array = []
var _creep_tex: Texture2D = null
var _summon_tex: Texture2D = null
var _sim_time := 0.0
var _active := false

# Per-creep sim state. Each: {home, offset, flash, hp}
var _creeps: Array[Dictionary] = []

func _init() -> void:
	custom_minimum_size = Vector2(320, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in CREEP_COUNT:
		var home_x: float = 0.55 + 0.09 * i   # normalized
		_creeps.append({
			"home": Vector2(home_x, 0.5),
			"offset": Vector2.ZERO,
			"flash": 0.0,
			"hp": 1.0,
			"flash_r": 1.0,
			"flash_g": 1.0,
			"flash_b": 1.0,
			"hp_alpha": 1.0,
			"scale": 1.0,
		})

func configure(id: String) -> void:
	ability_id = id
	_arch = _archetype_of(id)
	_load_fx_frames()
	_load_creep_tex()
	_load_summon()
	_reset_all()
	_sim_time = 0.0
	_active = true
	set_process(true)
	queue_redraw()

func deactivate() -> void:
	_active = false
	set_process(false)
	queue_redraw()

func _load_fx_frames() -> void:
	_fx_frames = []
	for i in 6:
		var tex := SpriteLibrary.texture_for("%s_fx%d" % [ability_id, i])
		if tex != null:
			_fx_frames.append(tex)

func _load_creep_tex() -> void:
	_creep_tex = SpriteLibrary.texture_for(CREEP_SPRITE)

func _load_summon() -> void:
	_summon_tex = null
	var spr_name := _summon_sprite_for(ability_id)
	if spr_name.is_empty():
		return
	var tex := SpriteLibrary.texture_for(spr_name)
	if tex == null:
		tex = SpriteLibrary.texture_for(ability_id)
	_summon_tex = tex

func _archetype_of(id: String) -> int:
	var info: Dictionary = PlayerClass.ABILITIES.get(id, {})
	if not info.is_empty() and info.has("archetype"):
		return int(info.get("archetype"))
	return -1

func _summon_sprite_for(id: String) -> String:
	match id:
		"tobor_spider_mines":
			return "tobor_mine_body"
		"tobor_steam_turret":
			return "tobor_turret_body"
		"warden_voodoo_wards":
			return "warden_ward_body"
		_:
			return ""

func _reset_all() -> void:
	for c in _creeps:
		c.offset = Vector2.ZERO
		c.flash = 0.0
		c.hp = 1.0

func _process(_delta: float) -> void:
	if not _active:
		return
	_sim_time += _delta
	if _sim_time >= LOOP_DURATION:
		_sim_time -= LOOP_DURATION
		_reset_all()
	queue_redraw()

func _draw() -> void:
	if ability_id.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	# Backdrop.
	draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.05, 0.08, 1.0))

	var travel_end: float = TRAVEL_END_RATIO * LOOP_DURATION
	var impact_end: float = travel_end + IMPACT_RATIO * LOOP_DURATION
	var t: float = _sim_time

	# --- FX frame ---
	var fx_pos := Vector2(w * 0.15, h * 0.5)
	var fx_frame: Texture2D = null
	if not _fx_frames.is_empty():
		if t < travel_end:
			var p: float = t / travel_end
			fx_frame = _fx_frames[int(p * (_fx_frames.size() - 1))]
			fx_pos = Vector2(w * 0.15, h * 0.5).lerp(Vector2(w * 0.58, h * 0.5), p)
		elif t < impact_end:
			fx_frame = _fx_frames[_fx_frames.size() - 1]
			fx_pos = Vector2(w * 0.58, h * 0.5)
		if fx_frame != null:
			var fw: float = 40.0
			var fh: float = 40.0
			draw_texture_rect(fx_frame, Rect2(fx_pos - Vector2(fw, fh) * 0.5, Vector2(fw, fh)), false)

	# --- Summon (for SUMMON_SPIRIT during impact) ---
	if _arch == PlayerClass.Archetype.SUMMON_SPIRIT and t >= travel_end and _summon_tex != null:
		var sp := Vector2(w * 0.38, h * 0.5)
		var sw := 34.0
		var sh := 34.0
		draw_texture_rect(_summon_tex, Rect2(sp - Vector2(sw, sh) * 0.5, Vector2(sw, sh)), false)

	# --- Creeps ---
	var creep_w: float = 22.0
	var creep_h: float = 30.0
	for i in _creeps.size():
		var c: Dictionary = _creeps[i]
		var home := Vector2(c.home.x, c.home.y)
		home.x = home.x * w
		home.y = home.y * h
		var pos: Vector2 = home + c.offset * w
		var mod: Color = Color.WHITE
		var scale_s: float = 1.0

		if t >= travel_end and t < impact_end:
			var p: float = (t - travel_end) / (impact_end - travel_end)
			_apply_impact(i, p)
		elif t >= impact_end:
			var p: float = clampf((t - impact_end) / (LOOP_DURATION - impact_end), 0.0, 1.0)
			_apply_recover(i, p)

		# Recompute visual state after applying sim step.
		mod = Color(c.flash_r, c.flash_g, c.flash_b, c.hp_alpha)
		scale_s = float(c.scale)

		var rw: float = creep_w * scale_s
		var rh: float = creep_h * scale_s
		if _creep_tex != null:
			draw_texture_rect(_creep_tex, Rect2(pos - Vector2(rw, rh) * 0.5, Vector2(rw, rh)), false, mod)
		else:
			draw_rect(Rect2(pos - Vector2(11, 15) * 0.5, Vector2(22, 30)), Color(0.75, 0.2, 0.2, c.hp_alpha), true)

	# --- Damage numbers (small "-N" above creeps during impact) ---
	if t >= travel_end and t < impact_end:
		var p: float = (t - travel_end) / (impact_end - travel_end)
		var font := ThemeDB.fallback_font
		for i in _creeps.size():
			var c: Dictionary = _creeps[i]
			if int(c.hp) < 1 or c.hp < 0.9:
				var home := Vector2(c.home.x, c.home.y)
				home.x = home.x * w
				home.y = home.y * h
				var pos: Vector2 = home + c.offset * w + Vector2(0, -22 - 10.0 * p)
				draw_string(font, pos, "-1", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.35, 0.35, 1.0 - p * 0.5))

	# --- Border + status ---
	draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.18, 0.25, 1.0), false, 1.0)
	var status := "Auto-casting…" if _active else "Preview"
	var font := ThemeDB.fallback_font
	var fs := 10
	var tw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, int(w), fs).x
	draw_string(font, Vector2((w - tw) * 0.5, h - 4), status, HORIZONTAL_ALIGNMENT_CENTER, int(w), fs, Color(0.5, 0.65, 0.75, 0.9))

# --- Sim state helpers (mutate the _creeps dictionaries) ---

func _apply_impact(idx: int, p: float) -> void:
	var c: Dictionary = _creeps[idx]
	var cx: float = c.home.x
	match _arch:
		PlayerClass.Archetype.NUKE_BOLT, PlayerClass.Archetype.CHAIN_NUKE:
			c.offset = Vector2(0.018 * (1.0 - p), 0.0)
			c.flash = 1.0 - p
			c.hp = 1.0 - p
			_set_creed_color(c, Color(1.0, 0.3 + 0.7 * (1.0 - c.flash), 0.3 + 0.7 * (1.0 - c.flash), 1.0))
			c.scale = 1.0 + 0.2 * c.flash
		PlayerClass.Archetype.RADIUS_BURST:
			var dir_v: Vector2 = Vector2(cx - 0.55, 0.0).normalized()
			c.offset = dir_v * 0.04 * (1.0 - p)
			c.flash = 1.0 - p
			c.hp = 1.0 - p
			_set_creed_color(c, Color(1.0, 0.3, 0.3, 1.0))
			c.scale = 1.15 - 0.15 * p
		PlayerClass.Archetype.CONE_BURST:
			c.offset = Vector2(0.03 * (1.0 - p), 0.0)
			c.flash = 1.0 - p
			c.hp = 1.0 - p
			_set_creed_color(c, Color(1.0, 0.4, 0.4, 1.0))
			c.scale = 1.1
		PlayerClass.Archetype.PUSH_PULL_BURST:
			var dir_v: Vector2 = Vector2(cx - 0.35, 0.0).normalized()
			c.offset = dir_v * 0.06 * (1.0 - p)
			c.flash = 0.5 * (1.0 - p)
			_set_creed_color(c, Color(0.7, 0.9, 1.0, 1.0))
			c.scale = 1.0
		PlayerClass.Archetype.DASH_STRIKE:
			c.offset = Vector2(0.024 * (1.0 - p), 0.0)
			c.flash = 1.0 - p
			c.hp = 1.0 - p
			_set_creed_color(c, Color(1.0, 0.35, 0.35, 1.0))
			c.scale = 1.05
		PlayerClass.Archetype.SUMMON_SPIRIT:
			c.flash = 0.6 * (1.0 - p)
			c.hp = 1.0 - 0.5 * p
			_set_creed_color(c, Color(1.0, 0.5, 0.5, 1.0))
			c.scale = 1.0
		PlayerClass.Archetype.ZONE_CHANNEL:
			c.flash = 0.7
			c.hp = 1.0 - p
			_set_creed_color(c, Color(1.0, 0.45, 0.35, 1.0))
			c.scale = 1.0
		PlayerClass.Archetype.ATTACK_FURY:
			var flicker: float = 0.5 + 0.5 * sin(t_safe() * 20.0)
			c.flash = flicker
			c.hp = 1.0 - p * 0.7
			_set_creed_color(c, Color(1.0, 0.4, 0.4, 1.0))
			c.scale = 1.0
		PlayerClass.Archetype.SPAWN_WALL:
			c.offset = Vector2(-0.024 * (1.0 - p), 0.0)
			c.flash = 0.4
			_set_creed_color(c, Color(0.8, 0.9, 1.0, 1.0))
			c.scale = 1.0
		_:
			c.flash = 0.5 * (1.0 - p)
			_set_creed_color(c, Color(1.0, 0.5, 0.5, 1.0))
			c.scale = 1.0
	_refresh_hp_alpha(c)

func _apply_recover(idx: int, p: float) -> void:
	var c: Dictionary = _creeps[idx]
	c.offset = c.offset.lerp(Vector2.ZERO, p)
	c.flash *= (1.0 - p)
	if c.hp < 1.0:
		c.hp = minf(1.0, c.hp + p * 0.8)
	_set_creed_color(c, Color.WHITE)
	c.scale = 1.0
	_refresh_hp_alpha(c)

func _set_creed_color(c: Dictionary, col: Color) -> void:
	c.flash_r = col.r
	c.flash_g = col.g
	c.flash_b = col.b

func _refresh_hp_alpha(c: Dictionary) -> void:
	if c.hp <= 0.05:
		c.hp_alpha = maxf(0.0, c.hp / 0.05)
	else:
		c.hp_alpha = 1.0

func t_safe() -> float:
	return _sim_time
