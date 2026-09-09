extends Node

var _failures: Array[String] = []

func _ready() -> void:
	print("[split_test] Start")
	_check_enctype("splitter")
	_check_enctype("splitter_small")
	_check_enctype("splitter_tiny")
	_check_split_chain_depth("splitter")
	_check_split_chain_depth("splitter_small")
	_check_split_chain_depth("splitter_tiny")
	_check_speed_increase()
	_check_size_decrease()
	_check_sprite_exists()
	_check_biome_fit("splitter_small")
	_check_biome_fit("splitter_tiny")
	if _failures.is_empty():
		print("[split_test] PASS: all split chain checks passed")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[split_test] FAIL: " + f)
		get_tree().quit(1)


func _check_enctype(id: String) -> void:
	if not EnemyType.is_valid_id(id):
		_failures.append("EnemyType %s not found" % id)


func _check_split_chain_depth(id: String) -> void:
	var death_spawn: String = str(EnemyType.field(id, "death_spawn_id"))
	var death_count: int = int(EnemyType.field(id, "death_spawn_count"))
	if id == "splitter":
		if death_spawn != "splitter_small":
			_failures.append("splitter.death_spawn_id = %s, expected splitter_small" % death_spawn)
		if death_count < 2:
			_failures.append("splitter.death_spawn_count = %d, expected >= 2" % death_count)
	elif id == "splitter_small":
		if death_spawn != "splitter_tiny":
			_failures.append("splitter_small.death_spawn_id = %s, expected splitter_tiny" % death_spawn)
		if death_count < 2:
			_failures.append("splitter_small.death_spawn_count = %d, expected >= 2" % death_count)
	elif id == "splitter_tiny":
		if not death_spawn.is_empty():
			_failures.append("splitter_tiny.death_spawn_id = %s, expected empty" % death_spawn)


func _check_speed_increase() -> void:
	var s1 := float(EnemyType.field("splitter", "movement_speed"))
	var s2 := float(EnemyType.field("splitter_small", "movement_speed"))
	var s3 := float(EnemyType.field("splitter_tiny", "movement_speed"))
	if s2 <= s1:
		_failures.append("splitter_small speed %f not > splitter speed %f" % [s2, s1])
	if s3 <= s2:
		_failures.append("splitter_tiny speed %f not > splitter_small speed %f" % [s3, s2])


func _check_size_decrease() -> void:
	var r1 := float(EnemyType.field("splitter", "radius"))
	var r2 := float(EnemyType.field("splitter_small", "radius"))
	var r3 := float(EnemyType.field("splitter_tiny", "radius"))
	if r2 >= r1:
		_failures.append("splitter_small radius %f not < splitter radius %f" % [r2, r1])
	if r3 >= r2:
		_failures.append("splitter_tiny radius %f not < splitter_small radius %f" % [r3, r2])


func _check_sprite_exists() -> void:
	for name in ["splitter_small", "splitter_tiny", "splitter"]:
		var tex := SpriteLibrary.texture_for(name)
		if tex == null:
			_failures.append("Sprite %s missing" % name)


func _check_biome_fit(id: String) -> void:
	for biome in range(0, 5):
		GameRuntime.set_biome(biome)
		var fitted := EnemyType.fit_to_biome(id)
		if fitted != id:
			_failures.append("fit_to_biome(%s, biome=%d) returned %s" % [id, biome, fitted])
	GameRuntime.set_biome(0)
