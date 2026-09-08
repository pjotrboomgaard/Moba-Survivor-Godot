extends SceneTree

## Generates three small 16x16 pixel-art icons for the boss-form abilities
## (slam / cross / volley) so the HUD can show dedicated boss icons.

func _init() -> void:
	_gen("bossform_slam", _slam_rows())
	_gen("bossform_cross", _cross_rows())
	_gen("bossform_volley", _volley_rows())
	quit()


func _gen(name: String, rows: Array) -> void:
	var w := 16
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			if y < rows.size() and x < str(rows[y]).length():
				var ch := str(rows[y])[x]
				if ch == "o":
					c = Color(0.1, 0.08, 0.1)
				elif ch == "r":
					c = Color(0.91, 0.34, 0.16)
				elif ch == "y":
					c = Color(1.0, 0.89, 0.29)
				elif ch == "w":
					c = Color(0.95, 0.95, 0.94)
				elif ch == "p":
					c = Color(0.77, 0.37, 0.78)
				elif ch == "k":
					c = Color(0.79, 0.64, 0.15)
				elif ch == "b":
					c = Color(0.31, 0.56, 0.88)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var up := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var sx := int(x / 4)
			var sy := int(y / 4)
			up.set_pixel(x, y, tex.get_image().get_pixel(sx, sy))
	up.save_png("res://assets/sprites/%s.png" % name)
	print("[gen_bossform_icons] wrote res://assets/sprites/%s.png" % name)


func _slam_rows() -> Array:
	return [
		"................",
		"......rrrr......",
		".....ryyyyy.....",
		"....rywwwyr.....",
		"....rywyywr.....",
		"....rywyywr.....",
		"....rywwwyr.....",
		".....ryyyyy.....",
		"......rrrr......",
		"....rr....rr....",
		"...rr......rr...",
		"...rr......rr...",
		"...rr......rr...",
		"...rr......rr...",
		"................",
		"................",
	]


func _cross_rows() -> Array:
	return [
		"................",
		"......rrrr......",
		"....rryyyyrr....",
		"...rywwwwwwyr...",
		"...rywyyyywyr...",
		"...rywyyyywyr...",
		"...rywwwwwwyr...",
		"....rryyyyrr....",
		"......rrrr......",
		"....rr....rr....",
		"...rr......rr...",
		"...rr......rr...",
		"...rr......rr...",
		"...rr......rr...",
		"................",
		"................",
	]


func _volley_rows() -> Array:
	return [
		"................",
		"......rrrr......",
		"....rryyyyrr....",
		"...rwwyyyywwr...",
		"...ryyppppyyr...",
		"...ryyyyyyyyrr..",
		"...ryyppppyyr...",
		"...rwwyyyywwr...",
		"....rryyyyrr....",
		"......rrrr......",
		"....rr....rr....",
		"...rr......rr...",
		"...rr......rr...",
		"...rr......rr...",
		"................",
		"................",
	]
