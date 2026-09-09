extends Node

func _ready() -> void:
	var sv := SubViewport.new()
	var tex := SubViewportTexture.new()
	tex.texture = sv
	print("SubViewport and SubViewportTexture both work")
