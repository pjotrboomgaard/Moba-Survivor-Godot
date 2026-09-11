extends Node2D

## Places one minigame at each of the 4 recruit-area corners (reusing the same
## positions as RecruitAreas), manages which is active, and exposes
## `nearest_minigame(pos)` + `start_minigame(index, owner_player)`.
##
## Each minigame is a child Node2D (subclass of minigame_base) positioned at the
## corresponding recruit-area corner.

const _BaseScript := preload("res://scripts/minigame_base.gd")

var _main: Node = null
var _arena: Node2D = null
var _recruit_areas: Node = null
var _games: Array = []
var _enabled := false


func start(main_node: Node, arena_node: Node2D, recruit_areas: Node) -> void:
	_main = main_node
	_arena = arena_node
	_recruit_areas = recruit_areas
	if _main == null or _arena == null:
		push_warning("MinigameArea: main or arena null, disabled.")
		return

	# Build positions matching recruit_areas.
	var half: Vector2 = _arena.half_extents()
	if half.x < 80.0 or half.y < 80.0:
		half = Vector2(2360.0, 1560.0) * 0.5
	var positions: Array[Vector2] = []
	# Same corner mapping as recruit_areas AREAS:
	# 0=Town(-1,-1), 1=Lagoon(-1,1), 2=Forest(1,-1), 3=Scorch(1,1)
	var corners := [Vector2(-1.0,-1.0), Vector2(-1.0,1.0), Vector2(1.0,-1.0), Vector2(1.0,1.0)]
	for c in corners:
		positions.append(Vector2(c.x * half.x * 0.60, c.y * half.y * 0.60))

	# Create the 4 minigames.
	_spawn_minigame(0, positions[0], Color("8fae6a"), "Treasure Dash")
	_spawn_minigame(1, positions[1], Color("5ad4ff"), "Keg Toss")
	_spawn_minigame(2, positions[2], Color("7dbb5a"), "Whack-a-Creep")
	_spawn_minigame(3, positions[3], Color("ff9a3d"), "Rock-Paper-Creep")

	_enabled = true


func _spawn_minigame(index: int, pos: Vector2, accent: Color, name: String) -> void:
	var script: GDScript
	match index:
		0:
			script = load("res://scripts/minigame_treasure_dash.gd")
		1:
			script = load("res://scripts/minigame_keg_toss.gd")
		2:
			script = load("res://scripts/minigame_whack.gd")
		3:
			script = load("res://scripts/minigame_rps.gd")
		_:
			return
	if script == null:
		push_warning("MinigameArea: could not load script for index %d" % index)
		_games.append(null)
		return
	var game: Node2D = script.new()
	game.name = "Minigame_%d" % index
	add_child(game)
	game.position = pos
	game.set("display_name", name)
	game.set("accent", accent)
	game.set("area_index", index)
	_games.append(game)


## Get a single minigame by index (for probes).
func get_minigame(index: int) -> Node:
	if index < 0 or index >= _games.size():
		return null
	return _games[index]


## Get all minigames as an array.
func all_minigames() -> Array:
	return _games


## Returns the nearest minigame to `pos`, or null if none.
func nearest_minigame(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for i in _games.size():
		var g: Node2D = _games[i]
		if g == null or not is_instance_valid(g):
			continue
		var d := pos.distance_to(g.global_position)
		if d < best_d:
			best_d = d
			best = g
	return best


## Start the minigame at `index` for `owner_player`. Returns the minigame node or null.
func start_minigame(index: int, owner_player: Player) -> Node2D:
	if index < 0 or index >= _games.size():
		return null
	var g: Node2D = _games[index]
	if g == null or not is_instance_valid(g):
		return null
	if not bool(g.get("active")):
		g.call("start", owner_player, index, g.get("accent"))
	return g


## Returns the active minigame (if any) that `pos` is within `radius` of.
func active_minigame_at(pos: Vector2, radius: float = 100.0) -> Node2D:
	for g in _games:
		if g == null or not is_instance_valid(g):
			continue
		if bool(g.get("active")) and pos.distance_to(g.global_position) <= radius:
			return g
	return null


## For the CpuBrain: find the nearest idle minigame that the bot can claim.
func nearest_idle_minigame(from_pos: Vector2) -> Dictionary:
	var best_index := -1
	var best_d := INF
	for i in _games.size():
		var g: Node2D = _games[i]
		if g == null or not is_instance_valid(g):
			continue
		if bool(g.get("active")):
			continue
		var d := from_pos.distance_to(g.global_position)
		if d < best_d:
			best_d = d
			best_index = i
	if best_index < 0:
		return {"index": -1, "pos": Vector2.ZERO, "active": false}
	var g: Node2D = _games[best_index]
	return {"index": best_index, "pos": g.global_position, "active": false}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_main = null
		_arena = null
		_recruit_areas = null
