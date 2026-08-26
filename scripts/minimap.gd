class_name MiniMap
extends Control

## Reads straight from the "players"/"enemies" groups every frame instead of main.gd feeding
## it state, since both groups already exist for exactly this kind of nearest-target lookup
## (see enemy.gd/player.gd/xp_orb.gd).

const DOT_RADIUS := 2.0
const PLAYER_RADIUS := 4.0
const BOSS_RADIUS := 4.5
const PLAYER_COLOR := Color("6fd6ff")
const LOCAL_PLAYER_COLOR := Color("ffe066")
const SHOP_COLOR := Color("ffc93c")
const ENEMY_COLOR := Color("ff5d5d")
const BOSS_COLOR := Color("ff2a2a")
const BACKGROUND_COLOR := Color(0.06, 0.09, 0.14, 0.78)
const BORDER_COLOR := Color(0.55, 0.72, 0.86, 0.6)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACKGROUND_COLOR, true)
	if GameRuntime.uses_biomes():
		var shop := _to_local(Arena.shop_stand_position())
		draw_circle(shop, 3.5, SHOP_COLOR)
		draw_circle(shop, 3.5, Color(0.2, 0.12, 0.0, 1.0), false, 1.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy_node):
			continue
		var enemy := enemy_node as Enemy
		var point := _to_local(enemy.global_position)
		if enemy.is_boss:
			draw_circle(point, BOSS_RADIUS, BOSS_COLOR)
		else:
			draw_circle(point, DOT_RADIUS, ENEMY_COLOR)
	for player_node in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player_node):
			continue
		var player := player_node as Player
		if not player.active:
			continue
		var point := _to_local(player.global_position)
		var color := LOCAL_PLAYER_COLOR if player.is_local_player else PLAYER_COLOR
		draw_circle(point, PLAYER_RADIUS, color)
		draw_circle(point, PLAYER_RADIUS, Color.BLACK, false, 1.0)
	draw_rect(rect, BORDER_COLOR, false, 2.0)


func _to_local(world_position: Vector2) -> Vector2:
	var normalized := (world_position + Arena.playfield_size() * 0.5) / Arena.playfield_size()
	return Vector2(
		clampf(normalized.x * size.x, 0.0, size.x),
		clampf(normalized.y * size.y, 0.0, size.y)
	)
