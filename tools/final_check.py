from PIL import Image
import sys

for hero in ["arclight", "bulwark", "warden"]:
	im = Image.open(f"assets/sprites/{hero}.png").convert("RGBA")
	w, h = im.size
	opaque = sum(1 for px in im.getdata() if px[3] > 10)
	xs = [x for y in range(h) for x in range(w) if im.getpixel((x, y))[3] > 10]
	ys = [y for y in range(h) for x in range(w) if im.getpixel((x, y))[3] > 10]
	print(f"{hero}: {opaque} opaque, bbox {min(xs)}..{max(xs)} x {min(ys)}..{max(ys)}")
