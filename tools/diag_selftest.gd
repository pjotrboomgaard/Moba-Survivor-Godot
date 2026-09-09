extends SceneTree

func _init() -> void:
	for f in [
		"res://scripts/upgrade_catalog.gd",
		"res://scripts/side_quest.gd",
		"res://scripts/side_quest_art.gd",
		"res://scripts/side_quest_director.gd",
		"res://scripts/selftest_driver.gd",
	]:
		var script: Script = load(f)
		print("%s -> %s" % [f, "OK" if script != null else "FAILED"])
	quit()
