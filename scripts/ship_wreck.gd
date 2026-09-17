class_name ShipWreck
extends Node2D
## T4.7 / T4.8 / T4.10 (2026-09-17): the crashed-ship wreck at the crater.
##
## The 1024x1024 PNG is split into 5 vertical slices, each rendered as a
## Sprite2D with a region_rect. Between slices there is a walkable gap (~60 px).
## Each slice has its own StaticBody2D that blocks movement but leaves the gaps
## open. Parts are depth-sorted by Y (painter's algorithm) so the player walks
## BEHIND parts with larger Y and IN FRONT of parts with smaller Y — same as trees.
##
## The wreck also carries the shop: it starts in the "crash" state (locked,
## only "Repurpose" available) and can morph into the "shop" state (T4.9-T4.11).
##
## T4.10 morph (start_repurpose_morph): each part holds TWO sprites overlaid in
## the same region — a crash sprite (back) and a shop sprite (front). The morph
## crossfades them through 3 phases:
##   Phase 1 (0.00–0.40): crash colour -> white silhouette
##   Phase 2 (0.40–0.60): white silhouette pivot (both white, shop fades in on top)
##   Phase 3 (0.60–1.00): shop white silhouette -> full-colour shop, crash fades out

signal repurpose_morph_done

const WorldClock := preload("res://scripts/world_clock.gd")

## The two ship PNGs: crashed-ship (wreck) and unlocked-shop (post-repurpose).
const CRASH_SPRITE := "res://SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
const SHOP_SPRITE := "res://SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

## World scale: each part's visual footprint width. 5 parts span the wreck with
## walkable gaps between them.
const PART_WIDTH_WORLD := 300.0
## Extra horizontal space between adjacent parts (the walkable gap).
const GAP := 60.0

## Morph duration in seconds.
const MORPH_DURATION := 1.8

## 5 large parts, left to right. Each:
##   region = [x0, y0, w, h] in normalized (0..1) source-uv space
##   x_off  = horizontal offset in part-widths from centre (with gaps)
##   y_off  = vertical offset in part-widths (negative = up)
const PARTS: Array[Dictionary] = [
	{"region": [0.04, 0.20, 0.30, 0.55], "x_off": -1.0, "y_off": 0.10},
	{"region": [0.24, 0.12, 0.22, 0.62], "x_off": -0.5, "y_off": -0.05},
	{"region": [0.44, 0.08, 0.22, 0.70], "x_off": 0.0,  "y_off": -0.10},
	{"region": [0.64, 0.12, 0.22, 0.62], "x_off": 0.5,  "y_off": -0.05},
	{"region": [0.66, 0.20, 0.30, 0.55], "x_off": 1.0,  "y_off": 0.10},
]

var _wreck_center := Vector2.ZERO
var _tex_crash: Texture2D = null
var _tex_shop: Texture2D = null
var _parts: Array[Node2D] = []
## Which sprite the wreck currently shows: "crash" or "shop".
var current_state := "crash"
## World position to interact (press B) — the shop "door" point, at the true
## crater centre so the player stands in front of the wreck.
var interact_point := Vector2.ZERO
## T4.10: morph progress (0.0 = crash state, 1.0 = shop state).
var morph_progress := 0.0
var _morphing := false


func _ready() -> void:
	_tex_crash = load(CRASH_SPRITE) as Texture2D
	_tex_shop = load(SHOP_SPRITE) as Texture2D
	set_process(true)


## Place the 5-part wreck centred at `center` (world coords). `slightly_above`
## shifts the visual centre up so the wreck sits a bit above the map middle.
func place(center: Vector2, state: String = "crash", slightly_above_px: float = 120.0) -> void:
	_wreck_center = center + Vector2(0.0, -slightly_above_px)
	interact_point = center
	current_state = state
	morph_progress = 1.0 if state == "shop" else 0.0
	_build_parts()
	_apply_static_state()


func _process(delta: float) -> void:
	if not _morphing:
		return
	morph_progress = minf(1.0, morph_progress + delta / MORPH_DURATION)
	_update_morph_visuals()
	if morph_progress >= 1.0:
		_morphing = false
		current_state = "shop"
		_apply_static_state()
		repurpose_morph_done.emit()


## T4.10: play the morph transition: crash ship -> white silhouette -> shop.
func start_repurpose_morph() -> void:
	if _morphing or current_state == "shop":
		return
	_morphing = true
	morph_progress = 0.0


## T4.10: switch the wreck's art instantly to the unlocked-shop sprite.
func switch_to_shop() -> void:
	current_state = "shop"
	morph_progress = 1.0
	_morphing = false
	_build_parts()
	_apply_static_state()


## T4.10: switch back to the crashed-ship sprite.
func switch_to_crash() -> void:
	current_state = "crash"
	morph_progress = 0.0
	_morphing = false
	_build_parts()
	_apply_static_state()


## Apply the static (non-morphing) sprite visibility/colour for the current state.
func _apply_static_state() -> void:
	for i in _parts.size():
		var part: Node2D = _parts[i]
		var crash_spr: Sprite2D = part.get_node_or_null("Sprite")
		var shop_spr: Sprite2D = part.get_node_or_null("SpriteShop")
		if crash_spr == null:
			continue
		var is_shop := current_state == "shop"
		crash_spr.visible = not is_shop
		crash_spr.modulate = Color.WHITE
		if shop_spr != null:
			shop_spr.visible = is_shop
			shop_spr.modulate = Color.WHITE


func _update_morph_visuals() -> void:
	# T4.10 morph, 3 phases across morph_progress 0..1:
	#   Phase 1 (0.00–0.40): crashed-ship colour fades toward a white silhouette.
	#   Phase 2 (0.40–0.60): white silhouette holds; shop sprite crossfades in on top.
	#   Phase 3 (0.60–1.00): shop white silhouette resolves into full colour; crash fades out.
	var p := morph_progress
	# Compute phase alphas.
	var crash_alpha: float
	var shop_alpha: float

	if p < 0.40:
		# Phase 1: crash colour -> white, shop not visible yet.
		crash_alpha = 1.0
		shop_alpha = 0.0
	elif p < 0.60:
		# Phase 2: both white, shop crossfading in on top.
		crash_alpha = 1.0
		shop_alpha = (p - 0.40) / 0.20
	else:
		# Phase 3: shop white -> full colour, crash fades out.
		crash_alpha = maxf(0.0, 1.0 - (p - 0.60) / 0.40)
		shop_alpha = 1.0

	for i in _parts.size():
		var part: Node2D = _parts[i]
		var crash_spr: Sprite2D = part.get_node_or_null("Sprite")
		var shop_spr: Sprite2D = part.get_node_or_null("SpriteShop")
		if crash_spr == null:
			continue
		# Crash sprite: fades out (alpha) as the shop sprite fades in.
		crash_spr.visible = crash_alpha > 0.01
		crash_spr.modulate = Color(1.0, 1.0, 1.0, crash_alpha)
		# Shop sprite: crossfades in. During the white-pivot window it is shown at
		# full alpha with a white tint so the silhouette reads as a solid shape.
		if shop_spr != null:
			shop_spr.visible = shop_alpha > 0.01
			shop_spr.modulate = Color(1.0, 1.0, 1.0, shop_alpha)


func _build_parts() -> void:
	for p in _parts:
		if is_instance_valid(p):
			p.queue_free()
	_parts.clear()

	if _tex_crash == null and _tex_shop == null:
		push_error("[ShipWreck] no textures loaded")
		return

	var world_h := PART_WIDTH_WORLD

	for i in PARTS.size():
		var part: Dictionary = PARTS[i]
		var body := Node2D.new()
		body.name = "WreckPart%d" % i
		add_child(body)

		# Collision body: rect collider narrower than the art, leaving walkable
		# gaps between adjacent parts.
		var col := StaticBody2D.new()
		col.name = "Body"
		body.add_child(col)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var collider_w := PART_WIDTH_WORLD * 0.55
		var collider_h := PART_WIDTH_WORLD * 0.5
		rect.size = Vector2(collider_w, collider_h)
		cs.shape = rect
		col.add_child(cs)
		col.collision_layer = 16  # movement-blocking layer (same as rocks/trees)
		col.collision_mask = 0

		var region: Array = part.region

		# Crash sprite (back layer) — only shown when current_state == "crash".
		if _tex_crash != null:
			var crash_spr := Sprite2D.new()
			crash_spr.name = "Sprite"
			crash_spr.texture = _tex_crash
			crash_spr.region_enabled = true
			crash_spr.region_rect = _region_rect(region, _tex_crash)
			var sx := PART_WIDTH_WORLD / crash_spr.region_rect.size.x
			var sy := world_h / crash_spr.region_rect.size.y
			crash_spr.scale = Vector2(sx, sy)
			crash_spr.centered = true
			crash_spr.z_as_relative = true
			body.add_child(crash_spr)

		# Shop sprite (front layer) — only shown when current_state == "shop".
		if _tex_shop != null:
			var shop_spr := Sprite2D.new()
			shop_spr.name = "SpriteShop"
			shop_spr.texture = _tex_shop
			shop_spr.region_enabled = true
			shop_spr.region_rect = _region_rect(region, _tex_shop)
			var sx := PART_WIDTH_WORLD / shop_spr.region_rect.size.x
			var sy := world_h / shop_spr.region_rect.size.y
			shop_spr.scale = Vector2(sx, sy)
			shop_spr.centered = true
			shop_spr.z_as_relative = true
			body.add_child(shop_spr)

		# Position: x offset from wreck centre (with gap spacing), y baseline offset.
		var x_off: float = part.x_off * (PART_WIDTH_WORLD + GAP)
		var y_off: float = part.y_off * world_h
		body.global_position = _wreck_center + Vector2(x_off, y_off)

		# Painter's-algorithm depth sort (same as trees/rocks): larger Y renders on
		# top, so the player paints over parts behind them and is occluded by
		# parts in front — the requested walk-behind / walk-in-front behaviour.
		body.z_as_relative = false
		body.z_index = WorldClock.depth_z(body.global_position.y)
		col.z_index = body.z_index

		_parts.append(body)


func _region_rect(region: Array, tex: Texture2D) -> Rect2:
	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	return Rect2(
		region[0] * tex_w, region[1] * tex_h,
		region[2] * tex_w, region[3] * tex_h
	)


## Refresh z-indices after the world clock's depth revision changes.
func refresh_depth() -> void:
	for p in _parts:
		if is_instance_valid(p):
			p.z_index = WorldClock.depth_z(p.global_position.y)
