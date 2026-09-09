extends SceneTree

func _init() -> void:
	var path := "res://scripts/selftest_driver.gd"
	var content := FileAccess.get_file_as_string(path)
	# The current state (after previous patches):
	# 4 tabs: for _i in n:
	# 4 tabs: if _player.boss_form_register_hero_kill():
	# 5 tabs: _player.revert_boss_form()
	# Need:
	# 4 tabs: for _i in n:
	# 5 tabs: if _player.boss_form_register_hero_kill():
	# 6 tabs: _player.revert_boss_form()
	
	# Find the for-loop line
	var marker := "for _i in n:"
	var idx := content.find("\t\t\t\t" + marker)
	if idx < 0:
		print("FAIL: could not find for-loop marker")
		quit()
	
	# Find the if-register line after the for-loop
	var if_marker := "if _player.boss_form_register_hero_kill():"
	var if_idx := content.find(if_marker, idx)
	if if_idx < 0:
		print("FAIL: could not find if-register marker")
		quit()
	
	# Find the start of that line (go back to newline)
	var line_start := content.rfind("\n", if_idx) + 1
	
	# Extract the current line to see its indentation
	var current_line := content.substr(line_start, if_idx - line_start)
	print("Current if line: [%s]" % current_line)
	
	# Replace with correct indentation: 5 tabs for if, 6 tabs for body
	var new_block := "\t\t\t\t\tif _player.boss_form_register_hero_kill():\n\t\t\t\t\t\t_player.revert_boss_form()\n"
	
	# Find the end of the revert_boss_form line
	var revert_marker := "_player.revert_boss_form()"
	var revert_idx := content.find(revert_marker, if_idx)
	if revert_idx < 0:
		print("FAIL: could not find revert_boss_form marker")
		quit()
	var revert_line_end := content.find("\n", revert_idx)
	if revert_line_end < 0:
		revert_line_end = content.length()
	
	# Replace the whole block from the if line to end of revert line
	var before := content.substr(0, line_start)
	var after := content.substr(revert_line_end + 1)
	content = before + new_block + after
	
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	print("OK: fixed bossform_kill handler indentation")
	quit()
