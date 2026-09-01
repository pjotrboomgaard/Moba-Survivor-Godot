extends SceneTree

## Headless probe: instantiate arena and report obstacle counts, sprite health,
## collision health, and which sprite key was actually resolved per biome.

const ARENA_SCENE := "res://scenes/arena/arena.tscn"
const BIOME_IDS := [0, 1, 2, 3, 4]


func _initialize() -> void:
	print("PROBE _initialize called")
	_run()


func _init() -> void:
	print("PROBE _init called")


func _run() -> void:
	print("=== ROCKS PROBE ===")
	print("GameRuntime exists: ", GameRuntime != null)
	print("is_classic(): ", GameRuntime.is_classic())
	print("uses_biomes(): ", GameRuntime.uses_biomes())
	print("game_mode: ", GameRuntime.game_mode)

	for biome_id in BIOME_IDS:
		_probe_biome(biome_id)

	print("=== DONE ===")
	quit()


func _probe_biome(biome_id: int) -> void:
	print("")
	print("--- BIOME ", biome_id, " (", GameRuntime.BIOME_KEYS[biome_id], ") ---")
	GameRuntime.biome_id = biome_id
	GameRuntime.biome_locked = true
	GameRuntime.biome_from_cli = true

	# Fresh cache per biome so SpriteLibrary doesn't return a stale hit.
	SpriteLibrary._cache.clear()

	var arena_packed: PackedScene = load(ARENA_SCENE)
	if arena_packed == null:
		print("  FAIL: could not load ", ARENA_SCENE)
		return
	var arena := arena_packed.instantiate()
	root.add_child(arena)

	var obstacles_found := 0
	var with_sprite := 0
	var with_collision := 0
	var positions: Array[Vector2] = []
	var sprite_names: Dictionary = {}

	for child in arena.get_children():
		if child is Obstacle:
			obstacles_found += 1
			if child.has_sprite():
				with_sprite += 1
				var tex := child.sprite.texture
				var path := tex.resource_path if tex != null else "(null)"
				var base := path.get_file().get_basename() if not path.is_empty() else "(no path)"
				sprite_names[base] = int(sprite_names.get(base, 0)) + 1
			if child.collision != null and child.collision.shape != null:
				with_collision += 1
			if positions.size() < 5:
				positions.append(child.global_position)

	print("  walk_pads: ", arena.walk_pads.size())
	print("  obstacles total: ", obstacles_found)
	print("  with sprite texture: ", with_sprite)
	print("  with collision shape: ", with_collision)
	print("  sprite histogram: ", sprite_names)
	print("  first positions: ", positions)

	for name in ["rock_small", "rock_large", "boulder", "spire"]:
		var texture := SpriteLibrary.texture_for(name)
		var resolved := "(null)"
		if texture != null:
			resolved = texture.resource_path.get_file().get_basename()
			if resolved.is_empty():
				resolved = "(inline, no path)"
		print("  texture_for('", name, "') -> ", resolved)

	arena.queue_free()

	GameRuntime.biome_locked = false
	GameRuntime.biome_from_cli = false
