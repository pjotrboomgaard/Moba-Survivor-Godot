extends SceneTree

## Generates semi-isometric town building pixel art as 32x32 PNGs in assets/sprites/.
## Run: godot --headless --path . -s res://tools/gen_town_art.gd

const OUTPUT_DIR := "res://assets/sprites"

func _init() -> void:
	var out := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_write_house()
	_write_shop()
	_write_church()
	_write_well()
	quit(0)


func _save(path: String, img: Image) -> void:
	img.save_png(path)
	print("Wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])


# Palette helper: fill a rectangle in the image.
func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in h:
		for dx in w:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)


func _save2(img: Image, name: String) -> void:
	_save("%s/%s.png" % [OUTPUT_DIR, name], img)


# --- Semi-iso house: gabled roof, front wall, side wall, door ---
func _write_house() -> void:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Colors
	var roof := Color("8b4a2a")
	var roof_hi := Color("a85d38")
	var wall_f := Color("d4a76a")
	var wall_s := Color("9c6b3e")
	var door := Color("3a2510")
	var win := Color("f2e8b0")
	# Base footprint (semi-iso: front face lower, side face recedes)
	# Front wall
	_fill(img, 6, 20, 16, 10, wall_f)
	# Side wall (right, darker, receding up)
	_fill(img, 22, 16, 4, 14, wall_s)
	# Gable / roof front triangle
	for i in 8:
		_fill(img, 6 + i, 12 + i, 16 - i * 2, 1, roof)
	# Roof top (the apex strip)
	_fill(img, 14, 10, 8, 2, roof_hi)
	# Roof right slope
	for i in 4:
		_fill(img, 22 + i, 12 + i, 4 - i, 1, roof)
	# Door on front wall
	_fill(img, 12, 22, 5, 8, door)
	_fill(img, 13, 23, 3, 2, Color("5a3a1a"))  # door panel
	# Window on front wall
	_fill(img, 7, 22, 4, 4, win)
	_fill(img, 8, 23, 2, 2, Color("fff5d0"))  # window glint
	# Chimney on roof
	_fill(img, 19, 8, 3, 4, Color("6b4226"))
	_fill(img, 19, 8, 3, 1, Color("8b5a36"))
	_save2(img, "town_house")


# --- Shop: wider base, striped awning, sign ---
func _write_shop() -> void:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wall_f := Color("c8b088")
	var wall_s := Color("8f7552")
	var awning_a := Color("c0392b")
	var awning_b := Color("e8d8a8")
	var sign := Color("f2e8b0")
	var door := Color("3a2510")
	# Front wall
	_fill(img, 4, 20, 20, 10, wall_f)
	# Side wall
	_fill(img, 24, 16, 4, 14, wall_s)
	# Roof strip
	_fill(img, 3, 18, 22, 2, Color("7a5a3a"))
	# Awning (striped) hanging over the front
	for i in 5:
		_fill(img, 5 + i * 4, 19, 4, 3, awning_a if i % 2 == 0 else awning_b)
	# Sign above door
	_fill(img, 11, 21, 8, 3, sign)
	_fill(img, 12, 22, 6, 1, Color("6b5230"))
	# Door
	_fill(img, 13, 25, 5, 5, door)
	# Side window
	_fill(img, 7, 24, 4, 3, Color("f2e8b0"))
	_save2(img, "town_shop")


# --- Church: tall narrow, pointed steeple, cross on top ---
func _write_church() -> void:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wall := Color("e8dcc8")
	var wall_s := Color("b8a888")
	var roof := Color("5a4a3a")
	var steeple := Color("4a3a2a")
	var cross := Color("2a1a0a")
	# Main body
	_fill(img, 10, 16, 12, 14, wall)
	# Side
	_fill(img, 22, 13, 4, 17, wall_s)
	# Gable roof
	for i in 6:
		_fill(img, 10 + i, 10 + i, 12 - i * 2, 1, roof)
	# Steeple (tall spire)
	for i in 6:
		_fill(img, 15 + i, 4 + i, 2 - i + 1, 1, steeple)
	_fill(img, 15, 4, 2, 6, steeple)
	# Cross on top
	_fill(img, 15, 1, 2, 4, cross)
	_fill(img, 14, 2, 4, 1, cross)
	# Door
	_fill(img, 14, 24, 5, 6, Color("3a2a1a"))
	# Stained-glass window
	_fill(img, 12, 19, 4, 4, Color("5a8ad0"))
	_fill(img, 13, 20, 2, 2, Color("9ac8f0"))
	_save2(img, "town_church")


# --- Well: stone circular base, wooden post + roof, bucket ---
func _write_well() -> void:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color("8a8a8a")
	var stone_hi := Color("a8a8a8")
	var wood := Color("6b4a2a")
	var roof := Color("8b5a36")
	# Circular stone base (ring)
	_fill(img, 8, 20, 16, 1, stone_hi)
	_fill(img, 8, 21, 16, 6, stone)
	_fill(img, 10, 22, 12, 1, Color("5a5a5a"))  # inner ring
	# Posts
	_fill(img, 9, 12, 2, 10, wood)
	_fill(img, 21, 12, 2, 10, wood)
	# Roof (gabled)
	for i in 3:
		_fill(img, 8 + i, 9 + i, 16 - i * 2, 1, roof)
	_fill(img, 14, 8, 4, 1, Color("a87a4a"))
	# Crossbar
	_fill(img, 11, 15, 10, 1, wood)
	# Bucket
	_fill(img, 15, 17, 2, 2, Color("4a4a4a"))
	_fill(img, 15, 15, 1, 2, Color("6a6a6a"))  # rope
	_save2(img, "town_well")
