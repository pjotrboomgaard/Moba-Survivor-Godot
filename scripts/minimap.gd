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
	# Teleporter pads: bright paired dots so the player can plan shortcut routes.
	if arena_node != null and arena_node.get("teleporter_pads") != null:
		for pad in arena_node.get("teleporter_pads"):
			var pp := Vector2((pad as Dictionary).get("pos", Vector2.ZERO))
			var pc: Color = (pad as Dictionary).get("color", Color("7ec8ff"))
			draw_circle(_to_local(pp), 3.0, pc)
			draw_circle(_to_local(pp), 3.0, Color(0.05, 0.05, 0.08, 1.0), false, 1.0)
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
		if player == null:
			# Story NPCs (rescue/dance) also live in the "players" group but are not
			# Player nodes; draw them as a distinct accent marker instead of crashing.
			var npc_point := _to_local((player_node as Node2D).global_position)
			draw_circle(npc_point, 2.4, Color(1.0, 0.85, 0.3, 1.0))
			draw_circle(npc_point, 2.4, Color(0.3, 0.2, 0.0, 1.0), false, 1.0)
			continue
		if not player.active:
			continue
		var point := _to_local(player.global_position)
		var color := LOCAL_PLAYER_COLOR if player.is_local_player else PLAYER_COLOR
		if GameRuntime.is_ffa() and player.team_id != "":
			color = RiftClashManager.team_color(player.team_id)
		draw_circle(point, PLAYER_RADIUS, color)
		draw_circle(point, PLAYER_RADIUS, Color.BLACK, false, 1.0)
	# Camera viewport overlay: the portion of the world currently visible in the main
	# camera, drawn as a translucent white rect + brighter border so the player can
	# see "how much of the map am I actually looking at right now".
	_draw_camera_viewport_overlay()
	draw_rect(rect, BORDER_COLOR, false, 2.0)


func _to_local(world_position: Vector2) -> Vector2:
	var normalized := (world_position + Arena.playfield_size() * 0.5) / Arena.playfield_size()
	return Vector2(
		clampf(normalized.x * size.x, 0.0, size.x),
		clampf(normalized.y * size.y, 0.0, size.y)
	)

# Draws a semi-transparent white rectangle showing the area currently visible
# in the main camera viewport. Updated every frame via _process -> queue_redraw().
func _draw_camera_viewport_overlay() -> void:
	var local_player := get_tree().get_first_node_in_group("players")
	if local_player == null or not is_instance_valid(local_player):
		return
	var camera := local_player.get_node_or_null("Camera2D")
	if camera == null or not (camera is Camera2D):
		return
	var cam := camera as Camera2D
	if not cam.enabled:
		return

	# Compute the camera's visible world-space area.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_world_size: Vector2 = viewport_size / (cam.zoom * 2.0)
	# The Camera2D is a child of the player and tracks it, so the player's
	# global_position IS the camera's world center.
	var world_center: Vector2 = (local_player as Node2D).global_position
	# World rect: from top-left corner to bottom-right corner.
	var world_tl: Vector2 = world_center - half_world_size
	var world_br: Vector2 = world_center + half_world_size

	# Transform world corners into minimap-local coordinates.
	var local_tl := _to_local(world_tl)
	var local_br := _to_local(world_br)
	var local_rect := Rect2(Vector2(
		minf(local_tl.x, local_br.x),
		minf(local_tl.y, local_br.y)
	), Vector2(
		absf(local_br.x - local_tl.x),
		absf(local_br.y - local_tl.y)
	))

	# Clamp to the minimap bounds so we don't draw outside (Godot 4 has no
	# Rect2.intersect that returns a Rect2, so clamp manually).
	var clamped_x := clampf(local_rect.position.x, 0.0, size.x)
	var clamped_y := clampf(local_rect.position.y, 0.0, size.y)
	var clamped_right := clampf(local_rect.end.x, 0.0, size.x)
	var clamped_bottom := clampf(local_rect.end.y, 0.0, size.y)
	if clamped_right <= clamped_x or clamped_bottom <= clamped_y:
		return
	local_rect = Rect2(Vector2(clamped_x, clamped_y), Vector2(clamped_right - clamped_x, clamped_bottom - clamped_y))

	draw_rect(local_rect, Color(1, 1, 1, 0.15), true)
	draw_rect(local_rect, Color(1, 1, 1, 0.4), false, 1.5)
