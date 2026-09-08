extends Node

## Shadow verifier: attached to the running main scene by the self-test boot.
## After a short wait, prints shadow info for every obstacle and a WorldClock
## snapshot. Does not quit — the SelfTestDriver handles that.

const WAIT_SECONDS := 8.0

var _elapsed := 0.0
var _done := false


func _ready() -> void:
	print("[ShadowVerify] attached, waiting %d s for obstacles to settle" % WAIT_SECONDS)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < WAIT_SECONDS:
		return
	_done = true
	_verify()


func _verify() -> void:
	print("[ShadowVerify] ==== shadow inspection t=%.1f ====" % _elapsed)
	var obstacles := get_tree().get_nodes_in_group("obstacles")
	print("[ShadowVerify] obstacles in group=%d" % obstacles.size())
	var shadow_count := 0
	var tree_shadow_count := 0
	var rock_shadow_count := 0
	var zero_alpha := 0
	var bad_z := 0
	for obs in obstacles:
		if obs == null:
			continue
		# Find the Shadow child by name.
		var shadow: CanvasItem = null
		for child in obs.get_children():
			if child.name == "Shadow" and child is CanvasItem:
				shadow = child as CanvasItem
				break
		if shadow == null:
			continue
		shadow_count += 1
		var mod_alpha := float(shadow.modulate.a)
		var z_rel := bool(shadow.z_as_relative)
		var z_idx := int(shadow.z_index)
		var parent_z := int((obs as CanvasItem).z_index)
		var sprite_shadow: Sprite2D = shadow as Sprite2D
		var has_tex := sprite_shadow != null and sprite_shadow.texture != null
		var tex_size := sprite_shadow.texture.get_size() if has_tex else Vector2.ZERO
		var sprite_id := ""
		if obs.has_method("get"):
			var sid: Variant = obs.get("sprite_id")
			sprite_id = str(sid) if sid != null else ""
		var is_tree := sprite_id.contains("tree")
		if is_tree:
			tree_shadow_count += 1
		else:
			rock_shadow_count += 1
		if mod_alpha <= 0.01:
			zero_alpha += 1
		if not z_rel or z_idx < 0:
			bad_z += 1
		print("[ShadowVerify]  obs=%s tree=%s z_rel=%s z=%d parent_z=%d alpha=%.3f tex=%s size=%s" % [
			obs.name, str(is_tree), str(z_rel), z_idx, parent_z, mod_alpha, str(has_tex), str(tex_size),
		])
	print("[ShadowVerify] summary: shadows=%d trees=%d rocks=%d zero_alpha=%d bad_z=%d" % [
		shadow_count, tree_shadow_count, rock_shadow_count, zero_alpha, bad_z,
	])
	var wc: Variant = load("res://scripts/world_clock.gd")
	if wc != null:
		print("[ShadowVerify] WorldClock: sun_dir=%s alpha=%.3f stretch=%.3f revision=%d" % [
			str(wc.sun_dir), float(wc.shadow_alpha), float(wc.shadow_stretch), int(wc.revision),
		])
