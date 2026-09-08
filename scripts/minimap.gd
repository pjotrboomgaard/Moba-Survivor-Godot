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
const LANDMARK_WIPE := Color("f4c44a")
const LANDMARK_HEAL := Color("7fd88a")
const LANDMARK_FREEZE := Color("7db8ff")
const ENEMY_COLOR := Color("ff5d5d")
const BOSS_COLOR := Color("ff2a2a")
const QUEST_COLOR := Color("c9a84e")
const TREE_COLOR := Color(0.42, 0.52, 0.42, 0.55)
const ROCK_COLOR := Color(0.52, 0.50, 0.48, 0.45)
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
	for node in get_tree().get_nodes_in_group("landmarks"):
		if not is_instance_valid(node) or not (node is ArenaLandmark):
			continue
		var landmark := node as ArenaLandmark
		var point := _to_local(landmark.global_position)
		var color := LANDMARK_WIPE
		match str(landmark.effect_id):
			"heal_all":
				color = LANDMARK_HEAL
			"freeze_time":
				color = LANDMARK_FREEZE
		draw_circle(point, 3.5, color)
		draw_circle(point, 3.5, Color(0.05, 0.05, 0.08, 1.0), false, 1.0)
	# Water/lava hazard zones: tinted circles/rects so the player can see danger on the minimap.
	var arena_node: Node = get_tree().get_first_node_in_group("arena")
	if arena_node != null and arena_node.has_method("get_hazard_zones"):
		var zones: Array = arena_node.get_hazard_zones()
		var field := Arena.playfield_size()
		var scale := size.x / maxf(1.0, field.x)
		for zone in zones:
			var ztype := str((zone as Dictionary).get("type", "lava"))
			var zcolor: Color
			if ztype == "water":
				zcolor = Color(0.15, 0.45, 0.75, 0.4)
			elif ztype == "lava":
				var biome_kind := str((zone as Dictionary).get("biome_kind", ""))
				if biome_kind == "volcano_lava":
					zcolor = Color(0.98, 0.22, 0.05, 0.55)
				elif biome_kind == "factory_slag":
					zcolor = Color(0.55, 0.5, 0.45, 0.4)
				else:
					zcolor = Color(0.7, 0.35, 0.15, 0.4)
			else:
				zcolor = Color(0.7, 0.35, 0.15, 0.4)
			var zshape := str((zone as Dictionary).get("shape", "circle"))
			if zshape == "circle":
				var zc := Vector2((zone as Dictionary).get("center", Vector2.ZERO))
				var zr := float((zone as Dictionary).get("radius", 30.0))
				draw_circle(_to_local(zc), zr * scale, zcolor)
			else:
				var zr := Rect2((zone as Dictionary).get("rect", Rect2()))
				var tl := _to_local(zr.position)
				draw_rect(Rect2(tl, zr.size * scale), zcolor, true)
	# Trees and rocks: subtle, low-saturation dots so the map reads as terrain without
	# competing with the bright enemy/player markers.
	for obs in get_tree().get_nodes_in_group("obstacles"):
		if not is_instance_valid(obs):
			continue
		var point := _to_local(obs.global_position)
		var is_tree := str(obs.sprite_id).contains("tree")
		var color := TREE_COLOR if is_tree else ROCK_COLOR
		draw_circle(point, 1.8, color)
	# Side quests: gold, slightly bigger than terrain so the player can spot them.
	for quest in get_tree().get_nodes_in_group("side_quest"):
		if not is_instance_valid(quest):
			continue
		var qp := _to_local(quest.global_position)
		draw_circle(qp, 3.0, QUEST_COLOR)
		draw_circle(qp, 3.0, Color(0.15, 0.12, 0.0, 1.0), false, 1.0)
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
		if GameRuntime.is_ffa() and player.team_id != "":
			color = RiftClashManager.team_color(player.team_id)
		draw_circle(point, PLAYER_RADIUS, color)
		draw_circle(point, PLAYER_RADIUS, Color.BLACK, false, 1.0)
	draw_rect(rect, BORDER_COLOR, false, 2.0)


func _to_local(world_position: Vector2) -> Vector2:
	var normalized := (world_position + Arena.playfield_size() * 0.5) / Arena.playfield_size()
	return Vector2(
		clampf(normalized.x * size.x, 0.0, size.x),
		clampf(normalized.y * size.y, 0.0, size.y)
	)
