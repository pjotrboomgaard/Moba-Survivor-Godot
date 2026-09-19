extends SceneTree
## One-shot: load the real bootstrap scene, wait a few frames, print the live
## rects of the compact-menu top block, then quit.

func _init() -> void:
	var scene: PackedScene = load("res://scenes/bootstrap/bootstrap.tscn")
	if scene == null:
		print("[diag] bootstrap.tscn not found")
		quit(1)
		return
	var boot := scene.instantiate()
	root.add_child(boot)

	# Give it several frames to build the compact menu.
	var i := 0
	while i < 120:
		i += 1
		await process_frame
		await create_timer(0.05).timeout

	var panel: Node = boot.get_node_or_null("StatusLayer/LobbyPanel")
	var top_block: Node = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout/CompactTopBlock")
	var hero_name: Node = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout/CompactTopBlock/CompactHeroName")
	var start_btn: Node = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout/CompactTopBlock/CompactStartBtn")
	var layout: Node = boot.get_node_or_null("StatusLayer/LobbyPanel/Margin/Layout")

	var out := ""
	out += "viewport=%s\n" % str(root.get_visible_rect().size)
	if panel != null:
		out += "panel rect=%s visible=%s clip=%s\n" % [str(panel.get("rect")), str(panel.get("visible")), str(panel.get("clip_contents"))]
	if layout != null:
		out += "layout rect=%s\n" % str(layout.get("rect"))
		out += "layout children=%d\n" % layout.get_child_count()
		for idx in range(layout.get_child_count()):
			var c: Node = layout.get_child(idx)
			out += "  child%d %-24s visible=%s rect=%s\n" % [idx, c.name, str(c.get("visible")), str(c.get("rect"))]
	if top_block != null:
		out += "topblock visible=%s rect=%s\n" % [str(top_block.get("visible")), str(top_block.get("rect"))]
	if hero_name != null:
		out += "heroname visible=%s text=%r rect=%s\n" % [str(hero_name.get("visible")), str(hero_name.get("text")), str(hero_name.get("rect"))]
	if start_btn != null:
		out += "startbtn visible=%s rect=%s\n" % [str(start_btn.get("visible")), str(start_btn.get("rect"))]

	print("[menu-diag]\n", out)
	var f := FileAccess.open("user://menu_diag_out.txt", FileAccess.WRITE)
	if f:
		f.store_string(out)
		f.close()

	quit(0)
