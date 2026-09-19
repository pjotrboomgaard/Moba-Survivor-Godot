extends SceneTree
## Probe: does a full-rect Control with MOUSE_FILTER_STOP receive gui_input
## events when pushed through viewport.push_input? (The menu editor's capture
## layer relies on exactly this path for real OS mouse clicks.)

var _hits: Array = []

class _Capture extends Control:
	var hits: Array
	var owner_ref
	func _init(hits_arr) -> void:
		hits = hits_arr
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)
		gui_input.connect(_on_gui_input.bind(hits_arr))
	func _on_gui_input(ev: InputEvent) -> void:
		hits.append(str(ev))

func _initialize() -> void:
	var root := Node.new()
	root.name = "Root"
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	root.add_child(vp)

	var capture := _Capture.new(_hits)
	vp.add_child(capture)

	# Force a layout pass so the control's rect is computed.
	await process_frame
	await process_frame

	print("PROBE capture rect=", str(capture.get_rect()))
	print("PROBE capture visible=", capture.visible)
	print("PROBE capture mouse_filter=", capture.mouse_filter)

	# Push a real mouse-button event through the viewport pipeline
	# (closest headless approximation of a physical OS click).
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = Vector2(640, 360)
	ev.global_position = Vector2(640, 360)
	ev.pressed = true
	vp.push_input(ev)

	await process_frame
	await process_frame

	print("PROBE hits=", _hits.size())
	for h in _hits:
		print("PROBE hit: ", h)

	quit(0 if _hits.size() > 0 else 1)
