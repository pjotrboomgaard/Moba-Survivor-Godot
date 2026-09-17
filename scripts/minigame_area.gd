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


## Canonical minigame registry: index -> (script path, accent color, display name).
## The editor's "Minigame Trigger" tool and this runtime share this ordering so a
## placed trigger's `minigame_index` maps to the right game.
const MINIGAMES := [
	{"script": "res://scripts/minigame_treasure_dash.gd", "accent": "8fae6a", "name": "Treasure Dash"},
	{"script": "res://scripts/minigame_keg_toss.gd", "accent": "5ad4ff", "name": "Keg Toss"},
	{"script": "res://scripts/minigame_whack.gd", "accent": "7dbb5a", "name": "Whack-a-Creep"},
	{"script": "res://scripts/minigame_rps.gd", "accent": "ff9a3d", "name": "Rock-Paper-Creep"},
	{"script": "res://scripts/minigame_dance_disco.gd", "accent": "b44dff", "name": "Dance Disco"},
	{"script": "res://scripts/minigame_gem_relay.gd", "accent": "2ee0c0", "name": "Gem Relay"},
	{"script": "res://scripts/minigame_keg_toss_pro.gd", "accent": "3fb0e0", "name": "Keg Toss Pro"},
	{"script": "res://scripts/minigame_whack_rush.gd", "accent": "3fa84a", "name": "Whack Rush"},
	{"script": "res://scripts/minigame_creep_tag.gd", "accent": "c07bff", "name": "Creep Tag"},
	{"script": "res://scripts/minigame_treasure_dash2.gd", "accent": "e0c05a", "name": "Treasure Dash 2"},
	{"script": "res://scripts/minigame_ring_roll.gd", "accent": "4de0f0", "name": "Ring Roll"},
	{"script": "res://scripts/minigame_creep_pinball.gd", "accent": "f0a04d", "name": "Creep Pinball"},
	{"script": "res://scripts/minigame_balloon_pop.gd", "accent": "f05090", "name": "Balloon Pop"},
	{"script": "res://scripts/minigame_slime_splat.gd", "accent": "40e080", "name": "Slime Splat"},
	{"script": "res://scripts/minigame_crystal_catch.gd", "accent": "a080f0", "name": "Crystal Catch"},
	{"script": "res://scripts/minigame_crate_stack.gd", "accent": "7dbb5a", "name": "Crate Stack"},
]


## User-placed minigame triggers read from the arena (placed in the world editor).
## Each entry: {"index": int, "pos": Vector2}. When non-empty, these override the
## default corner/edge placement so the user's custom layout is respected.
var _user_triggers: Array = []


func start(main_node: Node, arena_node: Node2D, recruit_areas: Node) -> void:
	_main = main_node
	_arena = arena_node
	_recruit_areas = recruit_areas
	if _main == null or _arena == null:
		push_warning("MinigameArea: main or arena null, disabled.")
		return
	_apply_layout()
	_enabled = true


## Re-collect user-placed triggers from the arena and re-spawn the minigames.
## Public test hook: lets a dev command place new MinigameTrigger nodes mid-game
## and force a re-layout without a full scene reload.
func rescan_triggers() -> void:
	if _main == null or _arena == null:
		return
	_apply_layout()


## Free all currently-spawned minigames so a re-layout starts clean.
func _clear_games() -> void:
	for g in _games:
		if g != null and is_instance_valid(g):
			g.queue_free()
	_games = []


func _apply_layout() -> void:
	# Clear any existing games first so re-layout (e.g. rescan_triggers) does
	# not accumulate duplicates.
	_clear_games()
	# User-placed minigame triggers (from the world editor) override the default
	# layout. The editor stores MinigameTrigger nodes in the arena under the
	# "minigame_trigger" group; we collect their positions + types here.
	_user_triggers = []
	if _arena != null:
		for node in _arena.get_tree().get_nodes_in_group("minigame_trigger"):
			if node is Node2D and node.has_method("to_dict"):
				var d: Dictionary = node.to_dict()
				var p: Array = d.get("pos", [0.0, 0.0])
				_user_triggers.append({
					"index": int(d.get("index", 0)),
					"pos": Vector2(float(p[0]), float(p[1])),
				})

	if _user_triggers.size() > 0:
		# Custom layout: spawn only at user-placed trigger positions.
		for entry in _user_triggers:
			var idx := int(entry.get("index", 0))
			var spec: Dictionary = _minigame_spec(idx)
			if spec.is_empty():
				continue
			var pos: Vector2 = entry.get("pos", Vector2.ZERO) as Vector2
			_spawn_minigame(idx, pos, Color(spec.get("accent", "ffffff")), str(spec.get("name", "Minigame")))
		# Hide the placeholder trigger markers so they don't clutter gameplay.
		_hide_user_triggers()
	else:
		# Default layout (no user triggers): build positions matching recruit_areas.
		var half: Vector2 = _arena.half_extents()
		if half.x < 80.0 or half.y < 80.0:
			half = Vector2(2360.0, 1560.0) * 0.5
		var positions: Array[Vector2] = []
		# Same corner mapping as recruit_areas AREAS:
		# 0=Town(-1,-1), 1=Lagoon(-1,1), 2=Forest(1,-1), 3=Scorch(1,1)
		var corners := [Vector2(-1.0,-1.0), Vector2(-1.0,1.0), Vector2(1.0,-1.0), Vector2(1.0,1.0)]
		for c in corners:
			positions.append(Vector2(c.x * half.x * 0.60, c.y * half.y * 0.60))

		# Create the minigames: 4 at corners + 1 at center + 3 at mid-edges.
		_spawn_minigame(0, positions[0], Color("8fae6a"), "Treasure Dash")
		_spawn_minigame(1, positions[1], Color("5ad4ff"), "Keg Toss")
		_spawn_minigame(2, positions[2], Color("7dbb5a"), "Whack-a-Creep")
		_spawn_minigame(3, positions[3], Color("ff9a3d"), "Rock-Paper-Creep")
		# Dance Disco at arena center
		_spawn_minigame(4, Vector2.ZERO, Color("b44dff"), "Dance Disco")
		# 5 new minigames at mid-edges + inner ring (lagoon/forest/mountain/town themed)
		_spawn_minigame(5, Vector2.ZERO + Vector2(-half.x * 0.35, -half.y * 0.55), Color("2ee0c0"), "Gem Relay")
		_spawn_minigame(6, Vector2.ZERO + Vector2(half.x * 0.45, half.y * 0.45), Color("3fb0e0"), "Keg Toss Pro")
		_spawn_minigame(7, Vector2.ZERO + Vector2(half.x * 0.55, -half.y * 0.35), Color("3fa84a"), "Whack Rush")
		_spawn_minigame(8, Vector2.ZERO + Vector2(-half.x * 0.55, half.y * 0.25), Color("c07bff"), "Creep Tag")
		_spawn_minigame(9, Vector2.ZERO + Vector2(half.x * 0.35, half.y * 0.55), Color("e0c05a"), "Treasure Dash 2")
		# 3 more minigames at remaining spots
		_spawn_minigame(10, Vector2.ZERO + Vector2(-half.x * 0.35, half.y * 0.55), Color("4de0f0"), "Ring Roll")
		_spawn_minigame(11, Vector2.ZERO + Vector2(half.x * 0.35, -half.y * 0.55), Color("f0a04d"), "Creep Pinball")
		_spawn_minigame(12, Vector2.ZERO + Vector2(0.0, half.y * 0.65), Color("f05090"), "Balloon Pop")
		_spawn_minigame(13, Vector2.ZERO + Vector2(-half.x * 0.45, -half.y * 0.45), Color("40e080"), "Slime Splat")
		_spawn_minigame(14, Vector2.ZERO + Vector2(half.x * 0.50, half.y * 0.30), Color("a080f0"), "Crystal Catch")
		_spawn_minigame(15, Vector2.ZERO + Vector2(-half.x * 0.50, half.y * 0.35), Color("7dbb5a"), "Crate Stack")


## Look up a minigame's spec (script/accent/name) by index. Empty dict if out of range.
func _minigame_spec(index: int) -> Dictionary:
	if index < 0 or index >= MINIGAMES.size():
		return {}
	return MINIGAMES[index]


## Hide the placeholder MinigameTrigger marker nodes once their minigames have
## spawned (so the rings don't clutter the live arena).
func _hide_user_triggers() -> void:
	if _main == null:
		return
	for node in _main.get_tree().get_nodes_in_group("minigame_trigger"):
		if node is Node2D and "visible" in node:
			node.visible = false


func _spawn_minigame(index: int, pos: Vector2, accent: Color, name: String) -> void:
	var spec: Dictionary = _minigame_spec(index)
	if spec.is_empty():
		push_warning("MinigameArea: no registry entry for index %d" % index)
		_games.append(null)
		return
	var script: GDScript = load(str(spec.get("script", "")))
	if script == null:
		push_warning("MinigameArea: could not load script for index %d" % index)
		_games.append(null)
		return
	var game: Node2D = script.new()
	game.name = "Minigame_%d" % index
	add_child(game)
	game.position = pos
	game.z_index = 4000
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
		# Use direct method call so the typed Player param binds correctly.
		(g as Node).call("start", owner_player, index, g.get("accent"))
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
