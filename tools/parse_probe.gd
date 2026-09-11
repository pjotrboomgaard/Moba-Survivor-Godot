extends SceneTree

func _init():
	var p: String = "res://scripts/player.gd"
	var fs := FileAccess.open(p, FileAccess.READ)
	if fs == null:
		print("MISSING")
		quit(1)
		return
	var code: String = fs.get_as_text()
	fs.close()
	var s := GDScript.new()
	s.source_code = code
	var err: int = s.reload(true)
	if err != OK:
		print("FAIL line=", s.get_parse_error_line(), " msg=", s.get_parse_error_message())
	else:
		print("OK")
	quit(0)
