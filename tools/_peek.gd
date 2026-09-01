extends SceneTree
func _init() -> void:
	GameRuntime.biome_id = 3
	var t = SpriteLibrary.texture_for("drone")
	print("drone tex = ", t, " size=", (t.get_width() if t != null else -1))
	print("biome_id = ", GameRuntime.biome_id, " biome_key=", GameRuntime.biome_key())
	print("uses_biomes = ", GameRuntime.uses_biomes())
	print("is_valid drone = ", EnemyType.is_valid_id("drone"))
	quit(0)
