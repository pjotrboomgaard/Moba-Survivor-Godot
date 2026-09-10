extends Node

func _ready() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(100, 100)
	add_child(sv)
	var label := Label.new()
	label.text = "hi"
	label.position = Vector2(10, 10)
	sv.add_child(label)
	var tr := TextureRect.new()
	# Try assigning the SubViewport directly as texture.
	var ok := true
	var err = tr.set("texture", sv)
	print("assign SubViewport to TextureRect.texture err=", err, " ok=", ok)
	var tr2 := TextureRect.new()
	var err2 = tr2.set("texture", sv)
	print("err2=", err2)
	get_tree().quit()
