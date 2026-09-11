extends SceneTree

func _init() -> void:
	for idx in 5:
		var path := "res://scripts/minigame_%s.gd" % ["treasure_dash","keg_toss","whack","rps","dance_disco"][idx]
		var s: Variant = load(path)
		print("[CHECK] index=%d path=%s load=%s" % [idx, path, (s != null)])
	quit()
