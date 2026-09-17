class_name ShipWreck
extends Node2D
## T4.7 / T4.8 / T4.10 (2026-09-17): the crashed-ship wreck at the crater.
##
## 2026-09-17 rewrite: the ship is drawn as ONE full transparent image (the
## background has been stripped from the PNG so it composites cleanly over the
## arena). Collision is a set of separate "segment" StaticBody2Ds that sit over
## the solid parts of the ship (nose / hull / tail), leaving walkable GAPS
## between them so the player and creeps can path around the wreck. The wreck
## also carries the shop: it starts in the "crash" state (locked, only
## "Repurpose") and morphs into the "shop" state.
##
## T4.10 morph (start_repurpose_morph): TWO full-image sprites are overlaid —
## a crash sprite (back) and a shop sprite (front). The morph crossfades them
## through 3 phases:
##   Phase 1 (0.00–0.40): crash colour -> white silhouette
##   Phase 2 (0.40–0.60): white silhouette pivot (both white, shop fades in on top)
##   Phase 3 (0.60–1.00): shop white silhouette -> full-colour shop, crash fades out

signal repurpose_morph_done

const WorldClock := preload("res://scripts/world_clock.gd")

## The two ship PNGs: crashed-ship (wreck) and unlocked-shop (post-repurpose).
## Both have had their white background stripped -> transparent.
const CRASH_SPRITE := "res://SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
const SHOP_SPRITE := "res://SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

## World width the full ship image renders at. The PNG is 1280x720; its ship
## content spans x[0.10,0.91] y[0.26,0.79] so the visual ship is ~0.81 wide and
## ~0.53 tall in image space.
const SHIP_WIDTH_WORLD := 620.0

## Collision segments (left to right), each [x0, x1] in normalized image-uv
## space. These are the SOLID parts of the ship that block movement; the gaps
## between them are walkable. Tuned to the ship's structure: nose, main body,
## rear engine.
const COLLISION_SEGMENTS: Array[Array] = [
	[0.10, 0.27],  # nose
	[0.31, 0.57],  # main body / cockpit
	[0.65, 0.83],  # rear engine / tail
]
## Fraction of the image height each collision block covers.
const COLLISION_H_FRACTION := 0.40
## Vertical centre of the collision blocks, in image-uv (0..1).
const COLLISION_Y_CENTER := 0.52

## Morph duration in seconds.
const MORPH_DURATION := 1.8

var _wreck_center := Vector2.ZERO
var _tex_crash: Texture2D = null
var _tex_shop: Texture2D = null
## The full-image crash sprite (back layer).
var _crash_sprite: Sprite2D = null
## The full-image shop sprite (front layer).
var _shop_sprite: Sprite2D = null
## Collision segment nodes (StaticBody2D) — invisible, depth-sorted.
var _colliders: Array[Node2D] = []
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


## Place the wreck centred at `center` (world coords). `slightly_above` shifts
## the visual centre up so the wreck sits a bit above the map middle.
func place(center: Vector2, state: String = "crash", slightly_above_px: float = 120.0) -> void:
	_wreck_center = center + Vector2(0.0, -slightly_above_px)
	interact_point = center
	current_state = state
	morph_progress = 1.0 if state == "shop" else 0.0
	_build()
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
	_apply_static_state()


## T4.10: switch back to the crashed-ship sprite.
func switch_to_crash() -> void:
	current_state = "crash"
	morph_progress = 0.0
	_morphing = false
	_apply_static_state()


## Apply the static (non-morphing) sprite visibility/colour for the current state.
func _apply_static_state() -> void:
	if _crash_sprite == null:
		return
	var is_shop := current_state == "shop"
	_crash_sprite.visible = not is_shop
	_crash_sprite.modulate = Color.WHITE
	if _shop_sprite != null:
		_shop_sprite.visible = is_shop
		_shop_sprite.modulate = Color.WHITE


func _update_morph_visuals() -> void:
	# T4.10 morph, 3 phases across morph_progress 0..1:
	#   Phase 1 (0.00–0.40): crashed-ship colour fades toward a white silhouette.
	#   Phase 2 (0.40–0.60): white silhouette holds; shop sprite crossfades in on top.
	#   Phase 3 (0.60–1.00): shop white silhouette resolves into full colour; crash fades out.
	if _crash_sprite == null:
		return
	var p := morph_progress
	var crash_alpha: float
	var shop_alpha: float
	if p < 0.40:
		crash_alpha = 1.0
		shop_alpha = 0.0
	elif p < 0.60:
		crash_alpha = 1.0
		shop_alpha = (p - 0.40) / 0.20
	else:
		crash_alpha = maxf(0.0, 1.0 - (p - 0.60) / 0.40)
		shop_alpha = 1.0

	_crash_sprite.visible = crash_alpha > 0.01
	_crash_sprite.modulate = Color(1.0, 1.0, 1.0, crash_alpha)
	if _shop_sprite != null:
		_shop_sprite.visible = shop_alpha > 0.01
		_shop_sprite.modulate = Color(1.0, 1.0, 1.0, shop_alpha)


## Build the full-image sprites + collision segments. Idempotent: frees any
## existing nodes first so it can be called from place()/switch_*.
func _build() -> void:
	# Free previous sprites/colliders.
	for n in [_crash_sprite, _shop_sprite]:
		if is_instance_valid(n):
			n.queue_free()
	for n in _colliders:
		if is_instance_valid(n):
			n.queue_free()
	_colliders.clear()
	_crash_sprite = null
	_shop_sprite = null

	if _tex_crash == null and _tex_shop == null:
		push_error("[ShipWreck] no textures loaded")
		return

	var tex_w := 1280.0
	var tex_h := 720.0
	if _tex_crash != null:
		tex_w = float(_tex_crash.get_width())
		tex_h = float(_tex_crash.get_height())
	var scale := SHIP_WIDTH_WORLD / tex_w

	# Full crash sprite (back layer).
	_crash_sprite = _make_full_sprite("ShipCrashSprite", _tex_crash, scale)
	# Full shop sprite (front layer), drawn on top of the crash sprite.
	_shop_sprite = _make_full_sprite("ShipShopSprite", _tex_shop, scale)

	# Collision segments: invisible StaticBody2D blocks over the solid parts of
	# the ship, with walkable gaps between them. Each is placed at the wreck
	# centre with a per-segment x offset (image-uv -> world).
	var seg_idx := 0
	for seg in COLLISION_SEGMENTS:
		var x0: float = seg[0]
		var x1: float = seg[1]
		var cx_norm: float = (x0 + x1) * 0.5
		var w_norm: float = x1 - x0
		# World position of the segment centre (relative to wreck centre).
		var x_world := (cx_norm - 0.5) * SHIP_WIDTH_WORLD
		var y_world := (COLLISION_Y_CENTER - 0.5) * SHIP_WIDTH_WORLD * (tex_h / tex_w)
		var seg_body := StaticBody2D.new()
		seg_body.name = "WreckCollide%d" % seg_idx
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var collider_w := w_norm * SHIP_WIDTH_WORLD * 0.92
		var collider_h := COLLISION_H_FRACTION * SHIP_WIDTH_WORLD * (tex_h / tex_w)
		rect.size = Vector2(collider_w, collider_h)
		cs.shape = rect
		seg_body.add_child(cs)
		seg_body.collision_layer = 16  # movement-blocking layer (same as rocks/trees)
		seg_body.collision_mask = 0
		seg_body.global_position = _wreck_center + Vector2(x_world, y_world)
		# Depth-sort the collider so it participates in the painter's algorithm
		# like the ship body (larger Y renders on top).
		seg_body.z_as_relative = false
		seg_body.z_index = WorldClock.depth_z(seg_body.global_position.y)
		add_child(seg_body)
		_colliders.append(seg_body)
		seg_idx += 1


## Make a full-image Sprite2D centred on the wreck centre, scaled to world size.
func _make_full_sprite(node_name: String, tex: Texture2D, scale: float) -> Sprite2D:
	if tex == null:
		return null
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.texture = tex
	sp.scale = Vector2(scale, scale)
	sp.centered = true
	sp.global_position = _wreck_center
	# Painter's-algorithm depth: the ship sits in the crater, so use the wreck
	# centre's depth. Lying flat on the ground -> lower z than standing players
	# in front of it.
	sp.z_as_relative = false
	sp.z_index = WorldClock.depth_z(_wreck_center.y)
	add_child(sp)
	return sp


## Refresh z-indices after the world clock's depth revision changes.
func refresh_depth() -> void:
	if _crash_sprite != null:
		_crash_sprite.z_index = WorldClock.depth_z(_wreck_center.y)
	if _shop_sprite != null:
		_shop_sprite.z_index = WorldClock.depth_z(_wreck_center.y)
	for c in _colliders:
		if is_instance_valid(c):
			c.z_index = WorldClock.depth_z(c.global_position.y)
