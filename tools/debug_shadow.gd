# Godot headless script to inspect tree texture + shadow image
# Run: godot --headless -s tools/debug_shadow.gd
extends SceneTree

func _init():
	var lib = load("res://scripts/sprite_library.gd")
	var tex = lib.texture_for("tree_pine")
	print("tree_pine tex = ", tex)
	if tex != null:
		print("  size = ", tex.get_width(), "x", tex.get_height())
		var img = tex.get_image()
		if img != null:
			var opaque = 0
			var total = img.get_width() * img.get_height()
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.4:
						opaque += 1
			print("  opaque frac = ", float(opaque) / total)
			# corner pixels
			print("  corner(0,0)=", img.get_pixel(0,0), " corner(cw,0)=", img.get_pixel(img.get_width()-1,0))
			print("  center=", img.get_pixel(img.get_width()/2, img.get_height()/2))
	# Build the shadow image the same way arena does and save it
	var w = tex.get_width() if tex != null else 16
	var h = tex.get_height() if tex != null else 20
	var src = tex.get_image() if tex != null else null
	var simg = Image.create(w, h, false, Image.FORMAT_RGBA8)
	if src != null:
		for y in h:
			for x in w:
				if src.get_pixel(x, y).a > 0.4:
					simg.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.55))
	simg.save_png("user://debug_shadow_pine.png")
	# count opaque in shadow
	var so = 0
	for y in h:
		for x in w:
			if simg.get_pixel(x, y).a > 0.1:
				so += 1
	print("shadow opaque pixels = ", so, " of ", w*h)
	quit()
