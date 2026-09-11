extends SceneTree

func _init() -> void:
	var files := [
		"res://scripts/main.gd",
		"res://scripts/hud.gd",
		"res://scripts/player.gd",
		"res://scripts/wave_director.gd",
		"res://scripts/enemy_type.gd",
		"res://autoload/audio_service.gd",
		"res://autoload/game_runtime.gd",
	]
	var bad := 0
	for path in files:
		var err := load(path)
		var result := ResourceLoader.load(path)
		print("checking ", path, " -> null?=", result == null)
		# Force compile of the script to surface parse errors
		if result is GDScript:
			var compile_err: int = (result as GDScript).reload(true)
			if compile_err != OK:
				print("  PARSE ERROR (", compile_err, ") in ", path)
				bad += 1
	print("done, bad=", bad)
	quit(1 if bad > 0 else 0)
