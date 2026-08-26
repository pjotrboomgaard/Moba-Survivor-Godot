"""Paint SuperMercator gear overlays for every Tobor facing.

Pads the four body sprites so wings, cannons and the skateboard can stick out,
then writes one transparent overlay per shop item per facing.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
GEAR = SPRITES / "tobor_gear"

FACINGS = ("front", "back", "left", "right")
BODY_FILES = {
	"front": "tobor.png",
	"back": "tobor_back.png",
	"left": "tobor_left.png",
	"right": "tobor_right.png",
}

# Extra canvas so shop parts are not clipped.
PAD_X = 96
PAD_TOP = 48
PAD_BOTTOM = 64

N = (218, 93, 35, 255)  # orange
R = (186, 70, 28, 255)
Y = (255, 206, 80, 255)
W = (248, 248, 246, 255)
U = (200, 200, 198, 255)
S = (158, 160, 160, 255)
M = (80, 80, 80, 255)
K = (18, 18, 20, 255)
F = (70, 140, 220, 255)  # board blue
D = (36, 82, 160, 255)
G = (232, 46, 38, 255)  # siren
L = (255, 150, 140, 255)


def bbox(im: Image.Image) -> tuple[int, int, int, int]:
	px = im.load()
	w, h = im.size
	xs: list[int] = []
	ys: list[int] = []
	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= 12:
				xs.append(x)
				ys.append(y)
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def pad_body(im: Image.Image) -> Image.Image:
	w, h = im.size
	canvas = Image.new("RGBA", (w + PAD_X * 2, h + PAD_TOP + PAD_BOTTOM), (0, 0, 0, 0))
	canvas.paste(im, (PAD_X, PAD_TOP), im)
	return canvas


def rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color) -> None:
	x0, y0, x1, y1 = box
	if x1 <= x0 or y1 <= y0:
		return
	draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=color)


def cell(bx0: int, by0: int, bw: int, bh: int, fx: float, fy: float, fw: float, fh: float) -> tuple[int, int, int, int]:
	x0 = int(round(bx0 + fx * bw))
	y0 = int(round(by0 + fy * bh))
	x1 = int(round(bx0 + (fx + fw) * bw))
	y1 = int(round(by0 + (fy + fh) * bh))
	return x0, y0, max(x0 + 1, x1), max(y0 + 1, y1)


def paint_hoverboard(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	if facing in ("left", "right"):
		deck = cell(x0, y0, bw, bh, -0.08, 0.90, 1.16, 0.07)
		rect(draw, deck, F)
		rect(draw, cell(x0, y0, bw, bh, -0.08, 0.90, 1.16, 0.02), D)
		for fx in (0.12, 0.72):
			rect(draw, cell(x0, y0, bw, bh, fx, 0.96, 0.16, 0.05), K)
			rect(draw, cell(x0, y0, bw, bh, fx + 0.04, 0.97, 0.08, 0.03), M)
	else:
		rect(draw, cell(x0, y0, bw, bh, -0.06, 0.90, 1.12, 0.07), F)
		rect(draw, cell(x0, y0, bw, bh, -0.06, 0.90, 1.12, 0.02), D)
		for fx in (0.08, 0.30, 0.58, 0.80):
			rect(draw, cell(x0, y0, bw, bh, fx, 0.96, 0.12, 0.05), K)


def paint_armen(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	if facing == "left":
		rect(draw, cell(x0, y0, bw, bh, -0.38, 0.42, 0.48, 0.16), N)
		rect(draw, cell(x0, y0, bw, bh, -0.38, 0.45, 0.12, 0.10), M)
		rect(draw, cell(x0, y0, bw, bh, -0.34, 0.47, 0.06, 0.06), K)
	elif facing == "right":
		rect(draw, cell(x0, y0, bw, bh, 0.90, 0.42, 0.48, 0.16), N)
		rect(draw, cell(x0, y0, bw, bh, 1.26, 0.45, 0.12, 0.10), M)
		rect(draw, cell(x0, y0, bw, bh, 1.30, 0.47, 0.06, 0.06), K)
	else:
		rect(draw, cell(x0, y0, bw, bh, -0.22, 0.40, 0.22, 0.18), N)
		rect(draw, cell(x0, y0, bw, bh, -0.22, 0.44, 0.08, 0.10), M)
		rect(draw, cell(x0, y0, bw, bh, -0.18, 0.46, 0.04, 0.06), K)
		rect(draw, cell(x0, y0, bw, bh, 1.00, 0.40, 0.22, 0.18), N)
		rect(draw, cell(x0, y0, bw, bh, 1.14, 0.44, 0.08, 0.10), M)
		rect(draw, cell(x0, y0, bw, bh, 1.16, 0.46, 0.04, 0.06), K)


def paint_sjaal(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	if facing == "left":
		rect(draw, cell(x0, y0, bw, bh, 0.55, 0.22, 0.55, 0.12), W)
		rect(draw, cell(x0, y0, bw, bh, 0.70, 0.28, 0.50, 0.16), U)
		rect(draw, cell(x0, y0, bw, bh, 0.88, 0.38, 0.38, 0.18), W)
		rect(draw, cell(x0, y0, bw, bh, 1.05, 0.48, 0.22, 0.14), S)
	elif facing == "right":
		rect(draw, cell(x0, y0, bw, bh, -0.10, 0.22, 0.55, 0.12), W)
		rect(draw, cell(x0, y0, bw, bh, -0.20, 0.28, 0.50, 0.16), U)
		rect(draw, cell(x0, y0, bw, bh, -0.26, 0.38, 0.38, 0.18), W)
		rect(draw, cell(x0, y0, bw, bh, -0.27, 0.48, 0.22, 0.14), S)
	else:
		# Two wings. Back view draws them larger so they read as behind-the-body.
		spread = 0.08 if facing == "front" else 0.02
		rect(draw, cell(x0, y0, bw, bh, -0.28 + spread, 0.22, 0.28, 0.12), W)
		rect(draw, cell(x0, y0, bw, bh, -0.38, 0.30, 0.32, 0.16), U)
		rect(draw, cell(x0, y0, bw, bh, -0.42, 0.42, 0.28, 0.16), W)
		rect(draw, cell(x0, y0, bw, bh, 1.00 - spread, 0.22, 0.28, 0.12), W)
		rect(draw, cell(x0, y0, bw, bh, 1.06, 0.30, 0.32, 0.16), U)
		rect(draw, cell(x0, y0, bw, bh, 1.14, 0.42, 0.28, 0.16), W)


def paint_romp(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	if facing == "left":
		rect(draw, cell(x0, y0, bw, bh, 0.58, 0.28, 0.28, 0.38), S)
		rect(draw, cell(x0, y0, bw, bh, 0.62, 0.32, 0.20, 0.30), M)
		rect(draw, cell(x0, y0, bw, bh, 0.66, 0.64, 0.12, 0.10), Y)
		rect(draw, cell(x0, y0, bw, bh, 0.68, 0.70, 0.08, 0.08), N)
	elif facing == "right":
		rect(draw, cell(x0, y0, bw, bh, 0.14, 0.28, 0.28, 0.38), S)
		rect(draw, cell(x0, y0, bw, bh, 0.18, 0.32, 0.20, 0.30), M)
		rect(draw, cell(x0, y0, bw, bh, 0.22, 0.64, 0.12, 0.10), Y)
		rect(draw, cell(x0, y0, bw, bh, 0.24, 0.70, 0.08, 0.08), N)
	elif facing == "back":
		rect(draw, cell(x0, y0, bw, bh, 0.22, 0.28, 0.22, 0.40), S)
		rect(draw, cell(x0, y0, bw, bh, 0.56, 0.28, 0.22, 0.40), S)
		rect(draw, cell(x0, y0, bw, bh, 0.26, 0.32, 0.14, 0.30), M)
		rect(draw, cell(x0, y0, bw, bh, 0.60, 0.32, 0.14, 0.30), M)
		rect(draw, cell(x0, y0, bw, bh, 0.28, 0.66, 0.10, 0.10), Y)
		rect(draw, cell(x0, y0, bw, bh, 0.62, 0.66, 0.10, 0.10), Y)
	else:
		rect(draw, cell(x0, y0, bw, bh, 0.18, 0.30, 0.16, 0.22), S)
		rect(draw, cell(x0, y0, bw, bh, 0.66, 0.30, 0.16, 0.22), S)
		rect(draw, cell(x0, y0, bw, bh, 0.22, 0.50, 0.08, 0.08), Y)
		rect(draw, cell(x0, y0, bw, bh, 0.70, 0.50, 0.08, 0.08), Y)


def paint_antenne(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	if facing == "left":
		rect(draw, cell(x0, y0, bw, bh, -0.28, 0.38, 0.34, 0.12), S)
		rect(draw, cell(x0, y0, bw, bh, -0.34, 0.48, 0.22, 0.18), M)
		rect(draw, cell(x0, y0, bw, bh, -0.40, 0.62, 0.16, 0.10), S)
		rect(draw, cell(x0, y0, bw, bh, -0.36, 0.66, 0.06, 0.08), K)
	elif facing == "right":
		rect(draw, cell(x0, y0, bw, bh, 0.94, 0.38, 0.34, 0.12), S)
		rect(draw, cell(x0, y0, bw, bh, 1.12, 0.48, 0.22, 0.18), M)
		rect(draw, cell(x0, y0, bw, bh, 1.24, 0.62, 0.16, 0.10), S)
		rect(draw, cell(x0, y0, bw, bh, 1.30, 0.66, 0.06, 0.08), K)
	else:
		rect(draw, cell(x0, y0, bw, bh, -0.18, 0.36, 0.20, 0.12), S)
		rect(draw, cell(x0, y0, bw, bh, -0.22, 0.46, 0.16, 0.20), M)
		rect(draw, cell(x0, y0, bw, bh, -0.24, 0.64, 0.12, 0.10), S)
		rect(draw, cell(x0, y0, bw, bh, 0.98, 0.36, 0.20, 0.12), S)
		rect(draw, cell(x0, y0, bw, bh, 1.06, 0.46, 0.16, 0.20), M)
		rect(draw, cell(x0, y0, bw, bh, 1.12, 0.64, 0.12, 0.10), S)


def paint_benen(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	arms = {
		"front": [(-0.30, 0.34, 0.22, 0.08), (-0.36, 0.48, 0.24, 0.08), (-0.28, 0.62, 0.20, 0.08),
			(1.08, 0.34, 0.22, 0.08), (1.12, 0.48, 0.24, 0.08), (1.08, 0.62, 0.20, 0.08)],
		"back": [(-0.32, 0.32, 0.24, 0.08), (-0.38, 0.46, 0.26, 0.08), (-0.30, 0.60, 0.22, 0.08),
			(1.08, 0.32, 0.24, 0.08), (1.12, 0.46, 0.26, 0.08), (1.08, 0.60, 0.22, 0.08)],
		"left": [(-0.34, 0.36, 0.28, 0.08), (-0.38, 0.50, 0.30, 0.08), (0.90, 0.40, 0.28, 0.08)],
		"right": [(1.06, 0.36, 0.28, 0.08), (1.08, 0.50, 0.30, 0.08), (-0.18, 0.40, 0.28, 0.08)],
	}[facing]
	for fx, fy, fw, fh in arms:
		rect(draw, cell(x0, y0, bw, bh, fx, fy, fw, fh), N)
		claw_x = fx if fx < 0.5 else fx + fw - 0.06
		rect(draw, cell(x0, y0, bw, bh, claw_x, fy + 0.01, 0.06, 0.06), S)


def paint_sirene(draw: ImageDraw.ImageDraw, facing: str, body: tuple[int, int, int, int]) -> None:
	x0, y0, x1, y1 = body
	bw, bh = x1 - x0, y1 - y0
	# Brighter, taller dome + shoulder lamp so buying Sirene is visible on the already-red cap.
	if facing == "left":
		rect(draw, cell(x0, y0, bw, bh, 0.38, -0.06, 0.22, 0.10), G)
		rect(draw, cell(x0, y0, bw, bh, 0.42, -0.04, 0.10, 0.04), L)
		rect(draw, cell(x0, y0, bw, bh, 0.18, 0.34, 0.10, 0.08), N)
		rect(draw, cell(x0, y0, bw, bh, 0.20, 0.36, 0.06, 0.04), Y)
	elif facing == "right":
		rect(draw, cell(x0, y0, bw, bh, 0.40, -0.06, 0.22, 0.10), G)
		rect(draw, cell(x0, y0, bw, bh, 0.48, -0.04, 0.10, 0.04), L)
		rect(draw, cell(x0, y0, bw, bh, 0.72, 0.34, 0.10, 0.08), N)
		rect(draw, cell(x0, y0, bw, bh, 0.74, 0.36, 0.06, 0.04), Y)
	else:
		rect(draw, cell(x0, y0, bw, bh, 0.40, -0.07, 0.20, 0.10), G)
		rect(draw, cell(x0, y0, bw, bh, 0.44, -0.05, 0.08, 0.04), L)
		rect(draw, cell(x0, y0, bw, bh, 0.72, 0.32, 0.10, 0.08), N)
		rect(draw, cell(x0, y0, bw, bh, 0.74, 0.34, 0.06, 0.04), Y)


PAINTERS = {
	"hoverboard": paint_hoverboard,
	"armen": paint_armen,
	"sjaal": paint_sjaal,
	"romp": paint_romp,
	"antenne": paint_antenne,
	"benen": paint_benen,
	"sirene": paint_sirene,
}

ICON_PAINT = {
	"hoverboard": lambda d: (rect(d, (1, 10, 15, 13), F), rect(d, (2, 13, 5, 16), K), rect(d, (11, 13, 14, 16), K)),
	"armen": lambda d: (rect(d, (1, 5, 7, 11), N), rect(d, (1, 6, 3, 10), M), rect(d, (9, 5, 15, 11), N), rect(d, (13, 6, 15, 10), M)),
	"sjaal": lambda d: (rect(d, (0, 3, 6, 12), W), rect(d, (10, 3, 16, 12), W), rect(d, (2, 6, 5, 10), U), rect(d, (11, 6, 14, 10), U)),
	"romp": lambda d: (rect(d, (3, 2, 7, 13), S), rect(d, (9, 2, 13, 13), S), rect(d, (4, 12, 6, 15), Y), rect(d, (10, 12, 12, 15), Y)),
	"antenne": lambda d: (rect(d, (1, 3, 6, 8), S), rect(d, (1, 8, 5, 14), M), rect(d, (10, 3, 15, 8), S), rect(d, (11, 8, 15, 14), M)),
	"benen": lambda d: (rect(d, (0, 4, 6, 7), N), rect(d, (0, 9, 6, 12), N), rect(d, (10, 4, 16, 7), N), rect(d, (10, 9, 16, 12), N)),
	"sirene": lambda d: (rect(d, (5, 1, 11, 7), G), rect(d, (6, 2, 8, 4), L), rect(d, (4, 7, 12, 9), S)),
}


def main() -> None:
	bodies: dict[str, Image.Image] = {}
	boxes: dict[str, tuple[int, int, int, int]] = {}
	for facing, name in BODY_FILES.items():
		src = Image.open(SPRITES / name).convert("RGBA")
		padded = src if src.size[0] > 400 else pad_body(src)
		padded.save(SPRITES / name)
		bodies[facing] = padded
		boxes[facing] = bbox(padded)
		print(facing, padded.size, "body", boxes[facing])

	GEAR.mkdir(parents=True, exist_ok=True)
	for item_id, painter in PAINTERS.items():
		for facing in FACINGS:
			im = Image.new("RGBA", bodies[facing].size, (0, 0, 0, 0))
			draw = ImageDraw.Draw(im)
			painter(draw, facing, boxes[facing])
			path = GEAR / ("%s_%s.png" % (item_id, facing))
			im.save(path)

	for item_id, painter in ICON_PAINT.items():
		icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
		painter(ImageDraw.Draw(icon))
		icon.save(SPRITES / ("tobor_icon_%s.png" % item_id))
	print("wrote", len(PAINTERS) * len(FACINGS), "gear overlays and", len(ICON_PAINT), "icons")


if __name__ == "__main__":
	main()
