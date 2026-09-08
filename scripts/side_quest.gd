extends Node2D

const SideQuestArt := preload("res://scripts/side_quest_art.gd")
# StoryNPC is loaded lazily to avoid a circular class-registration issue at project load.
var _StoryNPC_script: GDScript = null

func _story_npc_script() -> GDScript:
	if _StoryNPC_script == null:
		_StoryNPC_script = load("res://scripts/story_npc.gd")
	return _StoryNPC_script

signal completed(quest: Node2D)

const PIXEL_ZOOM := 3.6
const CATCH_RADIUS := 30.0
const TOUCH_RADIUS := 36.0
const STAND_RADIUS := 78.0
const SMASH_RADIUS := 52.0
const FLEE_RANGE := 210.0

var spec: Dictionary = {}
var owner_peer_id := 1
var kind := ""

func get_kind() -> String:
	return kind


func get_seek_position() -> Vector2:
	return seek_position
var hud_line := ""
var seek_position := Vector2.ZERO

var _main: Node = null
var _mode := ""
var _art_id := "shard"
var _anim := false
var _need := 1
var _have := 0
var _stand := 0.0
var _stand_need := 2.4
var _smash_hp := 3
var _smash_cd := 0.0
var _clock := 0.0
var _frame := 0
var _done := false
var _chase: Node2D = null
var _chase_vel := Vector2.RIGHT
var _chase_speed := 210.0
var _markers: Array[Node2D] = []
var _visited: Array[bool] = []
var _enemy: Node2D = null
var _ring_color := Color(1.0, 0.86, 0.35, 0.85)
var _story_npc: Node2D = null
var _rescue_creeps: Array[Node2D] = []
var _dance_moves: Array[Vector2] = []
var _dance_index := 0
var _dance_timer := 0.0
var _dance_duration := 10.0
var _dance_match_window := 2.0
var _dancer: Node2D = null
var _dance_footprints: Array[Node2D] = []
var _footprint_deadline: Array[float] = []


func configure(owner_id: int, next_spec: Dictionary) -> void:
	owner_peer_id = owner_id
	spec = next_spec.duplicate(true)
	kind = str(spec.get("id", "quest"))
	_mode = str(spec.get("mode", "collect"))
	_art_id = str(spec.get("art", "shard"))
	_anim = bool(spec.get("anim", false))
	_need = maxi(1, int(spec.get("count", 1)))
	_smash_hp = maxi(1, int(spec.get("hits", 3)))
	_stand_need = float(spec.get("stand", 2.4))
	_chase_speed = float(spec.get("speed", 210.0))
	hud_line = str(spec.get("title", "Side quest"))
	z_as_relative = false
	z_index = 18
	add_to_group("side_quest")


func begin(main: Node) -> void:
	_main = main
	var origin := _outskirts_origin()
	global_position = origin
	seek_position = origin
	match _mode:
		"chase":
			_spawn_chase(origin)
		"kill":
			_spawn_marked(origin)
		"visit":
			_spawn_visits(origin)
		"rescue":
			_spawn_rescue(origin)
		"dance":
			_spawn_dance(origin)
		_:
			_spawn_cluster(origin)
	_refresh_hud_line()
	var player := _owner()
	if player != null and player.is_local_player and _main.has_method("_landmark_flash"):
		_main._landmark_flash(hud_line, Color("ffe14a"))
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	if _anim and int(_clock * 8.0) != _frame:
		_frame = int(_clock * 8.0)
		_refresh_anim_frames()
	var player := _owner()
	if player == null or not player.active or player.health.is_dead:
		return
	match _mode:
		"chase":
			_tick_chase(delta, player)
		"collect":
			_tick_collect(player)
		"smash":
			_tick_smash(delta, player)
		"stand":
			_tick_stand(delta, player)
		"visit":
			_tick_visit(player)
		"kill":
			_tick_kill()
		"rescue":
			_tick_rescue(delta, player)
		"dance":
			_tick_dance(delta, player)


func _owner() -> Node2D:
	if _main == null:
		return null
	var found: Variant = _main.players.get(owner_peer_id)
	return found as Node2D


func _outskirts_origin() -> Vector2:
	var arena: Arena = _main.arena as Arena if _main != null else null
	var player := _owner()
	var slot := 0
	if player != null and not player.team_id.is_empty():
		slot = int(player.team_id)
	elif player != null:
		slot = maxi(0, int(_main.players.keys().find(owner_peer_id)))
	var base := Vector2.ZERO
	if arena != null:
		base = arena.corner_spawn(slot)
	var gr: Node = _main.get_tree().root.get_node_or_null("GameRuntime")
	var rcm: Node = _main.get_tree().root.get_node_or_null("RiftClashManager")
	if gr != null and gr.is_ffa() and rcm != null:
		base = rcm.team_anchor(slot)
	var away := base
	if away.length() < 80.0:
		away = Vector2.RIGHT.rotated(float(slot) * TAU * 0.25 + 0.4) * 900.0
	else:
		away = away * 1.18
	away += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 220.0)
	if arena != null:
		if arena.crater_contains(away, 48.0):
			away = away.normalized() * (arena.crater_radius() + 160.0) if away.length() > 1.0 else Vector2(720, -520)
		if away.distance_to(Arena.shop_stand_position()) < 140.0 + 80.0:
			away += Vector2(180.0, 90.0)
		away = arena.free_position_near(away, 22.0)
		var half := arena.half_extents() - Vector2(80.0, 80.0)
		away.x = clampf(away.x, -half.x, half.x)
		away.y = clampf(away.y, -half.y, half.y)
	return away


func _spawn_sprite(art: String, at: Vector2, zoom: float = PIXEL_ZOOM) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = SideQuestArt.texture(art, 0)
	sprite.centered = true
	sprite.scale = Vector2(zoom, zoom)
	sprite.z_as_relative = false
	sprite.z_index = 19
	sprite.global_position = at
	add_child(sprite)
	return sprite


func _spawn_chase(origin: Vector2) -> void:
	_chase = Node2D.new()
	_chase.z_as_relative = false
	_chase.z_index = 20
	add_child(_chase)
	_chase.global_position = origin
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = SideQuestArt.texture(_art_id, 0)
	sprite.centered = true
	sprite.scale = Vector2(PIXEL_ZOOM + 0.8, PIXEL_ZOOM + 0.8)
	_chase.add_child(sprite)
	seek_position = origin


func _spawn_cluster(origin: Vector2) -> void:
	var arena: Arena = _main.arena as Arena if _main != null else null
	var n := _need if _mode == "collect" else 1
	for i in n:
		var at := origin + Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(1, n)) + randf()) * (18.0 + float(i) * 22.0)
		if arena != null:
			at = arena.free_position_near(at, 16.0)
		var sprite := _spawn_sprite(_art_id, at)
		_markers.append(sprite)
		_visited.append(false)
	seek_position = origin


func _spawn_visits(origin: Vector2) -> void:
	var arena: Arena = _main.arena as Arena if _main != null else null
	for i in _need:
		var at := origin + Vector2.RIGHT.rotated(TAU * float(i) / float(_need) + 0.2) * (90.0 + float(i) * 28.0)
		if arena != null:
			at = arena.free_position_near(at, 16.0)
		var sprite := _spawn_sprite(_art_id, at)
		_markers.append(sprite)
		_visited.append(false)
	seek_position = origin


func _spawn_marked(origin: Vector2) -> void:
	if _main == null or not _main.has_method("_spawn_enemy_at"):
		_mode = "smash"
		_art_id = "dummy"
		_spawn_cluster(origin)
		return
	_enemy = _main._spawn_enemy_at(origin, "grunt", 0.72, 0.88, true)
	if _enemy == null:
		_mode = "smash"
		_art_id = "dummy"
		_spawn_cluster(origin)
		return
	_enemy.scale = Vector2(1.28, 1.28)
	_enemy.xp_value = maxi(_enemy.xp_value * 2, 28)
	_enemy.gold_value = maxi(_enemy.gold_value * 2, 12)
	_enemy.add_to_group("side_quest_mark")
	var mark := _spawn_sprite("marked", origin, 4.2)
	_markers.append(mark)
	seek_position = origin


func _refresh_anim_frames() -> void:
	var tex := SideQuestArt.texture(_art_id, _frame)
	if _chase != null:
		for child in _chase.get_children():
			if child is Sprite2D:
				(child as Sprite2D).texture = tex
		return
	for marker in _markers:
		if marker is Sprite2D:
			(marker as Sprite2D).texture = tex


func _tick_chase(delta: float, player: Node2D) -> void:
	if _chase == null:
		return
	var pos: Vector2 = _chase.global_position
	var to_player := player.global_position - pos
	var dist := to_player.length()
	if dist < CATCH_RADIUS:
		_finish()
		return
	if dist < FLEE_RANGE and dist > 0.01:
		var flee := -to_player.normalized()
		_chase_vel = _chase_vel.lerp(flee, 0.18).normalized()
		pos += _chase_vel * _chase_speed * delta
	else:
		_chase_vel = _chase_vel.rotated(sin(_clock * 3.0) * 0.04)
		pos += _chase_vel * (_chase_speed * 0.22) * delta
	var arena: Arena = _main.arena as Arena if _main != null else null
	if arena != null:
		var half := arena.half_extents() - Vector2(40.0, 40.0)
		pos.x = clampf(pos.x, -half.x, half.x)
		pos.y = clampf(pos.y, -half.y, half.y)
		if arena.crater_contains(pos, 8.0):
			pos = pos.normalized() * (arena.crater_radius() + 40.0)
	_chase.global_position = pos
	seek_position = pos


func _tick_collect(player: Node2D) -> void:
	for i in _markers.size():
		if _visited[i]:
			continue
		var marker := _markers[i]
		if not is_instance_valid(marker):
			continue
		if player.global_position.distance_to(marker.global_position) <= TOUCH_RADIUS:
			_visited[i] = true
			marker.visible = false
			_have += 1
			_refresh_hud_line()
	_update_seek_unvisited()
	if _have >= _need:
		_finish()


func _tick_smash(delta: float, player: Node2D) -> void:
	_smash_cd = maxf(0.0, _smash_cd - delta)
	if _markers.is_empty() or not is_instance_valid(_markers[0]):
		return
	var target: Node2D = _markers[0]
	seek_position = target.global_position
	if player.global_position.distance_to(target.global_position) > SMASH_RADIUS:
		return
	var swinging: bool = float(player.attack_cooldown) > float(player.attack_interval) * 0.55
	if swinging and _smash_cd <= 0.0:
		_smash_hp -= 1
		_smash_cd = 0.28
		target.modulate = Color(1.4, 1.1, 1.0, 1.0)
		_have = int(spec.get("hits", 3)) - _smash_hp
		_refresh_hud_line()
		if _smash_hp <= 0:
			_finish()


func _tick_stand(delta: float, player: Node2D) -> void:
	var center := global_position
	if not _markers.is_empty() and is_instance_valid(_markers[0]):
		center = _markers[0].global_position
	seek_position = center
	if player.global_position.distance_to(center) <= STAND_RADIUS:
		_stand += delta
		_have = mini(_need, int(ceil(_stand)))
		_refresh_hud_line()
		if _stand >= _stand_need:
			_finish()
	else:
		_stand = maxf(0.0, _stand - delta * 0.65)
	queue_redraw()


func _tick_visit(player: Node2D) -> void:
	for i in _markers.size():
		if _visited[i]:
			continue
		var marker := _markers[i]
		if not is_instance_valid(marker):
			continue
		if player.global_position.distance_to(marker.global_position) <= TOUCH_RADIUS + 8.0:
			_visited[i] = true
			marker.modulate = Color(0.45, 0.45, 0.45, 0.7)
			_have += 1
			_refresh_hud_line()
	_update_seek_unvisited()
	if _have >= _need:
		_finish()


func _tick_kill() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		_finish()
		return
	seek_position = _enemy.global_position
	if not _markers.is_empty() and is_instance_valid(_markers[0]):
		_markers[0].global_position = _enemy.global_position + Vector2(0.0, -42.0)


func _update_seek_unvisited() -> void:
	for i in _markers.size():
		if _visited[i]:
			continue
		if is_instance_valid(_markers[i]):
			seek_position = _markers[i].global_position
			return


## Rescue mode: spawn a StoryNPC (kid/villager) that gets attacked by creeps.
## The quest completes when the player reaches the NPC within 60px and the NPC survives.
## The NPC rewards the player with gold/XP on rescue.
func _spawn_rescue(origin: Vector2) -> void:
	# Spawn the StoryNPC at the origin
	var npc: Node2D = _story_npc_script().new()
	npc.global_position = origin
	if _main != null:
		_main.add_child(npc)
	npc.configure(str(spec.get("npc", "kid")), float(spec.get("npc_health", 60.0)), _main)
	npc.rescued.connect(func(_n: Node2D) -> void:
		_finish()
	)
	_story_npc = npc
	seek_position = origin

	# Spawn 2-3 hostiles near the NPC to create the "creeps attacking" scene
	var arena: Arena = _main.arena as Arena if _main != null else null
	var hostile_count := int(spec.get("hostiles", 3))
	for i in hostile_count:
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)
		var pos := origin + offset
		if arena != null:
			pos = arena.free_position_near(pos, 20.0)
		var creep: Node2D = null
		if _main.has_method("_spawn_enemy_at"):
			creep = _main._spawn_enemy_at(pos, "grunt", 0.5, 0.6, false)
		if creep != null:
			creep.add_to_group("story_quest_creature")
			_rescue_creeps.append(creep)


func _tick_rescue(delta: float, player: Node2D) -> void:
	if _story_npc == null or not is_instance_valid(_story_npc):
		_finish()
		return
	seek_position = _story_npc.global_position
	# Quest completes when the player is within 60px and the NPC is still alive
	var dist := player.global_position.distance_to(_story_npc.global_position)
	if dist <= 60.0:
		# Player is close enough — the NPC's own _process will handle rescue
		_have = 1
		_refresh_hud_line()
	# If all creeps are dead and the NPC is alive, complete
	var alive_creeps := 0
	for c in _rescue_creeps:
		if is_instance_valid(c):
			alive_creeps += 1
	if alive_creeps == 0 and is_instance_valid(_story_npc) and not _story_npc.is_dead:
		_finish()


## Dance mode: a dancer NPC performs a sequence of quick directional moves. The player must
## follow the dancer's movement pattern for the duration. Touching the footprints the dancer
## leaves behind counts as matching the move. Reward: a wave of friendly minions.
func _spawn_dance(origin: Vector2) -> void:
	_dance_moves.clear()
	var dir := randf_range(0.0, TAU)
	var base := origin
	for i in 8:
		dir += randf_range(0.6, 1.4)
		var step := Vector2.RIGHT.rotated(dir) * randf_range(30.0, 60.0)
		base += step
		_dance_moves.append(base)
	_dance_index = 0
	_dance_timer = 0.0
	_dance_duration = 10.0
	_need = 8

	_dancer = Node2D.new()
	_dancer.name = "Dancer"
	_dancer.z_as_relative = false
	_dancer.z_index = 19
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = SideQuestArt.texture("marked", 0)
	sprite.centered = true
	sprite.scale = Vector2(PIXEL_ZOOM + 0.4, PIXEL_ZOOM + 0.4)
	_dancer.add_child(sprite)
	_dancer.modulate = Color(1.0, 0.75, 0.4, 1.0)
	_dancer.global_position = _dance_moves[0]
	add_child(_dancer)
	seek_position = _dance_moves[0]


func _tick_dance(delta: float, player: Node2D) -> void:
	_dance_timer += delta
	var move_time := _dance_duration / float(maxi(1, _dance_moves.size()))
	var seg := int(_dance_timer / move_time)
	if seg < _dance_moves.size():
		var t := (_dance_timer - float(seg) * move_time) / move_time
		var from := _dance_moves[0] if seg == 0 else _dance_moves[seg - 1]
		var to := _dance_moves[seg]
		_dancer.global_position = from.lerp(to, clampf(t, 0.0, 1.0))
		seek_position = _dancer.global_position
		if _dance_index <= seg and _dance_index < _dance_moves.size():
			var at := _dance_moves[_dance_index]
			var marker := _spawn_sprite("marked", at, 3.2)
			_dance_footprints.append(marker)
			_footprint_deadline.append(_clock + 2.5)
			_dance_index += 1
	else:
		seek_position = _dancer.global_position

	for i in _dance_footprints.size():
		var fp := _dance_footprints[i]
		if not is_instance_valid(fp) or fp.visible == false:
			continue
		if _clock > _footprint_deadline[i]:
			continue
		if player.global_position.distance_to(fp.global_position) <= TOUCH_RADIUS:
			_have += 1
			fp.modulate = Color(0.5, 1.0, 0.7, 1.0)
			fp.visible = false
			_refresh_hud_line()

	if _have >= _need:
		_spawn_dance_reward(player)
		_finish()
	elif _dance_timer >= _dance_duration:
		_finish()


func _spawn_dance_reward(player: Node2D) -> void:
	var main := _main
	if main == null or main.get("actors") == null:
		return
	var actors: Node = main.get("actors")
	var MinionScript: Variant = load("res://scripts/friendly_minion.gd")
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var offset := Vector2.RIGHT.rotated(angle) * 40.0
		var pos := player.global_position + offset
		var minion: Node2D = MinionScript.new()
		actors.add_child(minion)
		minion.global_position = pos
		if minion.has_method("configure"):
			minion.configure(main, player.owner_peer_id, pos)
	if main.has_method("_landmark_flash"):
		main._landmark_flash("Dance reward: 5 friendly minions!", Color("7fffd4"))


func _refresh_hud_line() -> void:
	var title := str(spec.get("title", "Side quest"))
	match _mode:
		"collect", "visit":
			hud_line = "%s  %d/%d" % [title, _have, _need]
		"smash":
			hud_line = "%s  %d hits left" % [title, maxi(0, _smash_hp)]
		"stand":
			hud_line = "%s  %.1fs" % [title, maxf(0.0, _stand_need - _stand)]
		"rescue":
			var alive := 0
			for c in _rescue_creeps:
				if is_instance_valid(c):
					alive += 1
			hud_line = "%s  (%d creeps)" % [title, alive]
		"dance":
			hud_line = "%s  %d/%d moves" % [title, _have, _need]
		_:
			hud_line = title
	if _main != null and _main.has_method("_refresh_side_quest_hud"):
		_main._refresh_side_quest_hud()


func _finish() -> void:
	if _done:
		return
	_done = true
	completed.emit(self)


func _draw() -> void:
	if _done or _mode != "stand":
		return
	var center := Vector2.ZERO
	if not _markers.is_empty() and is_instance_valid(_markers[0]):
		center = to_local(_markers[0].global_position)
	var pulse := 0.55 + 0.25 * sin(_clock * 4.0)
	var ring := _ring_color
	ring.a = pulse
	draw_arc(center, STAND_RADIUS, 0.0, TAU, 32, ring, 3.0, true)




