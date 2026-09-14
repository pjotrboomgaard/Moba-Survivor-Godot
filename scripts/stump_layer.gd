extends CanvasItem

## Dedicated high-z CanvasItem that renders dead-tree stumps ABOVE the tree
## Obstacle sprites. Trees sit at z ~ depth_z(y) (approx 2000+); the arena's own
## _draw() sits at z=0, so stumps drawn there would be hidden behind a tree that
## is mid-fall. This layer forces stumps on top so a broken tree reads as
## "snapped at the stem" - the stump stays visible on top of the toppled trunk
## until the trunk fully fades and is removed.
##
## T3.75 update: each stump is a CUTOFF of the broken tree's own base sprite
## (bottom ~45% of its texture), not a generic lump, so it reads as the part of
## THAT tree that remained. Stumps also fade in over ~0.4s instead of popping.
##
## The arena owns `_dead_trees: Array[Dictionary]` ({pos, sprite_id, fade}) and
## calls `sync_stumps()` every frame. This node just repaints.

var _stumps: Array[Dictionary] = []
var _crop_cache: Dictionary = {}  # sprite_id -> AtlasTexture (bottom slice)
var _fallback_stump_texture: Texture2D = null


func _ready() -> void:
	# Godot z_index range is -4096..4096; use the max so stumps sit on top of
	# every tree Obstacle sprite (trees sit at z ≈ depth_z(y) ≈ 2000–3000).
	z_index = 4096
	z_as_relative = false


func sync_stumps(stumps: Array[Dictionary]) -> void:
	_stumps = stumps
	queue_redraw()


func _stump_crop_for(sprite_id: String) -> Texture2D:
	if sprite_id.is_empty():
		return null
	if _crop_cache.has(sprite_id):
		return _crop_cache[sprite_id]
	var tex := SpriteLibrary.texture_for(sprite_id)
	if tex == null:
		_crop_cache[sprite_id] = null
		return null
	var w := tex.get_width()
	var h := tex.get_height()
	var slice_h := maxi(4, int(h * 0.45))
	var src_rect := Rect2(0, h - slice_h, w, slice_h)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = src_rect
	_crop_cache[sprite_id] = atlas
	return atlas


func _draw() -> void:
	for entry in _stumps:
		var pos: Vector2 = entry.get("pos", Vector2.ZERO)
		var sprite_id: String = str(entry.get("sprite_id", ""))
		var fade: float = clampf(float(entry.get("fade", 1.0)), 0.0, 1.0)
		_draw_stump(pos, sprite_id, fade)


func _draw_stump(pos: Vector2, sprite_id: String, fade: float) -> void:
	var crop := _stump_crop_for(sprite_id)
	if crop != null:
		# Cutoff of the tree's own base. Anchor so the slice bottom sits at pos.
		var slice_h := 40.0 * 1.8
		draw_texture_rect(
			crop,
			Rect2(pos.x - slice_h * 0.35, pos.y - slice_h, slice_h * 0.7, slice_h),
			false,
			Color(1.0, 1.0, 1.0, fade)
		)
		return
	# Fallback: generic shared stump sprite (if available), else procedural.
	if _fallback_stump_texture == null:
		_fallback_stump_texture = SpriteLibrary.texture_for("dead_tree_stump")
	if _fallback_stump_texture != null:
		var scale_factor := 1.8
		var tex_w := _fallback_stump_texture.get_width() * scale_factor
		var tex_h := _fallback_stump_texture.get_height() * scale_factor
		draw_texture_rect(
			_fallback_stump_texture,
			Rect2(pos.x - tex_w * 0.5, pos.y - tex_h, tex_w, tex_h),
			false,
			Color(1.0, 1.0, 1.0, fade)
		)
		return
	# Procedural charred trunk.
	var trunk := Color(0.12, 0.09, 0.06)
	draw_circle(pos, 16.0, Color(0.05, 0.04, 0.03, 0.55 * fade))
	draw_rect(Rect2(pos.x - 5.0, pos.y - 30.0, 10.0, 32.0), trunk)
	draw_line(Vector2(pos.x, pos.y - 18.0), Vector2(pos.x - 12.0, pos.y - 28.0), trunk, 4.0)
	draw_line(Vector2(pos.x, pos.y - 12.0), Vector2(pos.x + 10.0, pos.y - 22.0), trunk, 3.0)
	draw_circle(pos, 6.0, Color(0.45, 0.18, 0.05, 0.35 * fade))
