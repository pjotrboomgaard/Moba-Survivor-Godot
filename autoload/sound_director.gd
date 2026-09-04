extends Node

## Camera-aware combat SFX gate. Off-screen explosions, casts, and hits stay silent so
## four FFA bots don't stack every boom at once. UI and stingers with no world position
## still play through AudioService unchanged.

const EDGE_DUCK_DB := -10.0
const DEFAULT_MARGIN := 96.0


func is_on_screen(world_pos: Vector2, margin: float = DEFAULT_MARGIN) -> bool:
	var viewport := get_tree().root
	var screen_pos := viewport.get_canvas_transform() * world_pos
	return viewport.get_visible_rect().grow(margin).has_point(screen_pos)


func play(sound_id: String, world_position: Variant = null) -> AudioStreamPlayer:
	if world_position is Vector2 and not is_on_screen(world_position):
		return null
	var player := AudioService.play(sound_id)
	if player != null and world_position is Vector2:
		player.volume_db += _edge_duck_db(world_position)
	return player


func play_ability(ability_id: String, world_position: Variant = null) -> AudioStreamPlayer:
	if world_position is Vector2 and not is_on_screen(world_position):
		return null
	var player := AudioService.play_ability(ability_id)
	if player != null and world_position is Vector2:
		player.volume_db += _edge_duck_db(world_position)
	return player


func _edge_duck_db(world_pos: Vector2) -> float:
	var viewport := get_tree().root
	var screen_pos := viewport.get_canvas_transform() * world_pos
	var rect := viewport.get_visible_rect()
	var half := rect.size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return 0.0
	var center := rect.get_center()
	var nx := absf(screen_pos.x - center.x) / half.x
	var ny := absf(screen_pos.y - center.y) / half.y
	return lerpf(0.0, EDGE_DUCK_DB, clampf(maxf(nx, ny), 0.0, 1.0))
