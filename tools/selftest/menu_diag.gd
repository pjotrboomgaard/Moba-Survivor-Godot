extends Node
## Headless diagnostic: load the REAL bootstrap scene, enter the menu editor,
## and report the actual state — whether LobbyPanel/Margin/Layout are found,
## whether mouse filters get set to IGNORE, and whether _editables is
## populated. Writes user://menu_diag_report.json and quits.
##
## Run: Godot --headless --script res://tools/selftest/menu_diag.gd --path <project>

const REPORT := "user://menu_diag_report.json"

func _ready() -> void:
	var scene := load("res://scenes/bootstrap/bootstrap.tscn")
	if scene == null:
		_fail("could not load bootstrap.tscn")
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)
	await get_tree().create_timer(2.0).timeout

	var lobby := root.get_node_or_null("StatusLayer/LobbyPanel")
	var layout := lobby.get_node_or_null("Margin/Layout") if lobby else null
	print("[MenuDiag] lobby=", lobby, " layout=", layout)

	# Find the editor node (added by _setup_menu_editor in bootstrap).
	var editor: Node = null
	for child in root.get_children():
		if child.name == "MenuEditor":
			editor = child
			break
	print("[MenuDiag] editor=", editor)
	if editor == null:
		_fail("MenuEditor node not found under bootstrap root")
		return

	# Grab a sample menu control to watch its mouse_filter.
	var sample: Control = null
	if layout:
		for c in layout.get_children():
			if c is Button:
				sample = c
				break
	print("[MenuDiag] sample control=", sample, " filter_before=", sample.mouse_filter if sample else -1)

	# Enter edit mode.
	editor.toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var filter_after: int = sample.mouse_filter if sample else -1
	var editables: Array = editor._editables
	print("[MenuDiag] filter_after_enter=", filter_after, " editables_count=", editables.size())

	# Try a hit test at the sample control's center.
	var hit: Control = null
	if sample:
		hit = editor._hit_test(sample.get_global_rect().get_center())
	print("[MenuDiag] hit_test(sample.center)=", hit)

	var report := {
		"verdict": "PASS" if (filter_after == 2 and editables.size() > 0 and hit != null) else "FAIL",
		"lobby_found": lobby != null,
		"layout_found": layout != null,
		"editor_found": editor != null,
		"sample_name": sample.name if sample else "none",
		"filter_before": sample.mouse_filter if sample else -1,
		"filter_after_enter": filter_after,
		"editables_count": editables.size(),
		"editables_names": _names(editables),
		"hit_test_result": str(hit.name) if hit else "null",
	}
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuDiag] report -> ", REPORT)
	get_tree().quit()

func _names(arr: Array) -> Array:
	var out := []
	for c in arr:
		out.append(str(c.name))
	return out

func _fail(msg: String) -> void:
	var report := {"verdict": "FAIL", "error": msg}
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuDiag] FAIL: ", msg)
	get_tree().quit()
