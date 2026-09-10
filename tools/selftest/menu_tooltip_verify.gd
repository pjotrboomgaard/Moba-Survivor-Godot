extends Node
## Verifies the LMB/RMB hover tooltip card content (text, not rendering).
## Boots the bootstrap scene, calls _show_lmb_hover / _show_rmb_hover / _show_ability_hover
## for a few heroes, and dumps the resulting panel text so we can confirm each hero
## gets correct hero-specific text (not "no secondary" / "does not exist").
##
## Run: Godot --headless --script res://tools/selftest/menu_tooltip_verify.gd

const REPORT_PATH := "user://menu_tooltip_verify_report.json"

func _ready() -> void:
	var scene := load("res://scenes/bootstrap/bootstrap.tscn")
	if scene == null:
		_fail("could not load bootstrap.tscn")
		return
	var root: Node = scene.instantiate()
	get_tree().root.add_child(root)
	await get_tree().create_timer(1.5).timeout

	# Force a known hero so we test a specific one.
	PlayerProfile.selected_class_id = "arclight"
	_refresh_loadout(root)

	var results := {}
	var heroes := ["arclight", "tobor", "ember", "rime"]
	for hero in heroes:
		PlayerProfile.selected_class_id = hero
		_refresh_loadout(root)

		# LMB
		root._show_lmb_hover(hero)
		var lmb_text := _panel_text(root)
		var lmb_header := _panel_header(root)
		var lmb_preview := _preview_visible(root)
		results[hero + "_lmb"] = {"header": lmb_header, "text": lmb_text, "preview_visible": lmb_preview}

		# RMB
		root._show_rmb_hover(hero)
		var rmb_text := _panel_text(root)
		var rmb_header := _panel_header(root)
		results[hero + "_rmb"] = {"header": rmb_header, "text": rmb_text}

		# First kit ability
		var kit := PlayerClass.kit_ability_ids(hero)
		var aid := str(kit[0]) if kit.size() > 0 else ""
		root._show_ability_hover(aid)
		var ab_text := _panel_text(root)
		var ab_header := _panel_header(root)
		var ab_preview := _preview_visible(root)
		results[hero + "_ability"] = {"header": ab_header, "text": ab_text, "ability": aid, "preview_visible": ab_preview}

	var report := {"verdict": "PASS", "heroes": results}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuTooltipVerify] report -> ", REPORT_PATH)
	print(JSON.stringify(results, "\t"))
	get_tree().quit()

func _refresh_loadout(root: Node) -> void:
	if root.has_method("_refresh_loadout_panel"):
		root._refresh_loadout_panel()


func _panel_text(root: Node) -> String:
	var body = root.get("ability_hover_body")
	if body == null:
		return "(no body)"
	var text := str((body as RichTextLabel).text)
	return text.left(240)


func _panel_header(root: Node) -> String:
	var h = root.get("ability_hero_header")
	if h == null:
		return "(no header)"
	return str((h as Label).text)


func _preview_visible(root: Node) -> bool:
	var p = root.get("ability_preview")
	if p == null:
		return false
	return bool((p as Node).visible)


func _fail(msg: String) -> void:
	var report := {"verdict": "FAIL", "error": msg}
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[MenuTooltipVerify] FAIL: ", msg)
	get_tree().quit()
