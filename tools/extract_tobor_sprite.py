"""Crop Tobor from the screenshot and key out the slate background."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "ref image" / "Screenshot 2026-08-26 162751.png"
OUT_DIR = ROOT / "assets" / "sprites"

BG = (33, 58, 84)
THRESH = 38


def is_bg(p):
	return abs(p[0] - BG[0]) + abs(p[1] - BG[1]) + abs(p[2] - BG[2]) <= THRESH


def crop_keyed(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	px = im.load()
	w, h = im.size
	xs, ys = [], []
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if is_bg((r, g, b)):
				px[x, y] = (0, 0, 0, 0)
			else:
				xs.append(x)
				ys.append(y)
	if not xs:
		return im
	box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
	return im.crop(box)


def make_back(front: Image.Image) -> Image.Image:
	"""Paint over face (yellow eyes, black mouth, blue button) so it reads as the back."""
	img = front.copy()
	px = img.load()
	w, h = img.size
	whites, oranges = [], []
	yellows = []
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 40:
				continue
			if r > 200 and g > 200 and b > 190:
				whites.append((r, g, b))
			elif r > 160 and g < 120 and b < 90:
				oranges.append((r, g, b))
			elif r > 170 and g > 140 and b < 90:
				yellows.append((x, y))
	white = whites[len(whites) // 2] if whites else (230, 230, 225)
	orange = oranges[len(oranges) // 2] if oranges else (220, 90, 40)
	if yellows:
		min_x = min(p[0] for p in yellows) - 3
		max_x = max(p[0] for p in yellows) + 3
		min_y = min(p[1] for p in yellows) - 3
		max_y = max(p[1] for p in yellows) + 3
		for y in range(max(0, min_y), min(h, max_y + 1)):
			for x in range(max(0, min_x), min(w, max_x + 1)):
				r, g, b, a = px[x, y]
				if a < 40:
					continue
				px[x, y] = (*white, a)
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 40:
				continue
			# cyan/blue button
			if b > r + 15 and b > g and b > 110:
				px[x, y] = (*orange, a)
			# mouth slot on the orange band
			elif r < 55 and g < 55 and b < 55 and y > int(h * 0.52) and y < int(h * 0.78):
				px[x, y] = (*orange, a)
	return img


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	front = crop_keyed(Image.open(SRC))
	back = make_back(front)
	front_path = OUT_DIR / "tobor.png"
	back_path = OUT_DIR / "tobor_back.png"
	front.save(front_path)
	back.save(back_path)
	print("front", front.size, "->", front_path)
	print("back", back.size, "->", back_path)


if __name__ == "__main__":
	main()
