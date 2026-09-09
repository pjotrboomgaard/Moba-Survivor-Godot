extends SceneTree

func _init() -> void:
	var path := "res://scripts/selftest_driver.gd"
	var lines: Array = FileAccess.get_file_as_string(path).split("\n")
	# Line 408 (index 407) should be 5 tabs, line 409 (index 408) should be 6 tabs
	var l408 := lines[407]
	var l409 := lines[408]
	print("L408 raw: [%s]" % l408)
	print("L409 raw: [%s]" % l409)
	var expected408 := "\t\t\t\t\tif _player.boss_form_register_hero_kill():"
	var expected409 := "\t\t\t\t\t\t_player.revert_boss_form()"
	if l408 != expected408:
		lines[407] = expected408
		print("Fixed L408")
	else:
		print("L408 OK")
	if l409 != expected409:
		lines[408] = expected409
		print("Fixed L409")
	else:
		print("L409 OK")
	var out := "\n".join(lines)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("DONE")
	quit()
