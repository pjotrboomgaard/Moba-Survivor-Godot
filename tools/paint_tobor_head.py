"""One-off painter: chunky pixel-art Tobor head matching ref image/toborhead.png."""
from __future__ import annotations

from PIL import Image

W, H = 48, 60
CX = 24

P = {
	"o": (22, 20, 18, 255),
	"n": (255, 122, 30, 255),
	"r": (196, 58, 12, 255),
	"y": (255, 200, 90, 255),
	"N": (255, 154, 58, 255),
	"s": (168, 176, 184, 255),
	"S": (210, 218, 224, 255),
	"m": (90, 100, 108, 255),
	"w": (242, 240, 234, 255),
	"u": (214, 210, 200, 255),
	"d": (176, 170, 160, 255),
	"k": (18, 16, 14, 255),
	"e": (240, 210, 74, 255),
	"E": (201, 168, 48, 255),
	"b": (42, 154, 170, 255),
	"B": (120, 210, 220, 255),
	"t": (216, 220, 224, 255),
}


def paint() -> Image.Image:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	px = img.load()

	def put(x: int, y: int, c: tuple) -> None:
		if 0 <= x < W and 0 <= y < H:
			px[x, y] = c

	def ellipse(cx: float, cy: float, rx: float, ry: float, color: tuple, hi: tuple | None = None) -> None:
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				dx = (x + 0.5 - cx) / rx
				dy = (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					put(x, y, hi if hi and dx < -0.12 else color)

	# Siren dome
	ellipse(CX, 8.2, 8.4, 7.6, P["n"], P["N"])
	put(CX - 3, 5, P["y"])
	put(CX - 2, 5, P["y"])
	put(CX - 3, 6, P["y"])
	put(CX, 8, P["y"])
	put(CX - 1, 8, P["y"])
	put(CX + 1, 8, P["E"])

	# Metal collar
	for y in range(14, 18):
		half = 9 if y in (15, 16) else 8
		for x in range(CX - half, CX + half + 1):
			color = P["m"] if y in (14, 17) else (P["S"] if x < CX else P["s"])
			put(x, y, color)
		put(CX - half, y, P["o"])
		put(CX + half, y, P["o"])

	# White cone
	for y in range(18, 45):
		t = (y - 18) / 26.0
		half = int(9 + t * 7)
		for x in range(CX - half, CX + half + 1):
			if x <= CX - half or x >= CX + half:
				put(x, y, P["o"])
			elif x < CX - 3:
				put(x, y, P["w"])
			elif x > CX + 4:
				put(x, y, P["d"])
			else:
				put(x, y, P["u"])

	def eye(ex: int, ey: int) -> None:
		ellipse(ex, ey, 5.6, 5.6, P["k"])
		for y in range(ey - 3, ey + 4):
			for x in range(ex - 3, ex + 4):
				put(x, y, P["e"] if x <= ex else P["E"])
		for x in range(ex - 3, ex + 4):
			put(x, ey, P["k"])
		for y in range(ey - 7, ey + 8):
			for x in range(ex - 7, ex + 8):
				d2 = (x + 0.5 - ex) ** 2 + (y + 0.5 - ey) ** 2
				if 26 <= d2 <= 36:
					put(x, y, P["o"])

	eye(CX - 7, 32)
	eye(CX + 7, 32)

	for sx in (CX - 7, CX + 7):
		put(sx, 39, P["t"])
		put(sx + 1, 39, P["s"])
		put(sx, 40, P["s"])
		put(sx + 1, 40, P["m"])

	# Orange chin
	for y in range(45, 56):
		t = (y - 45) / 10.0
		half = int(16 + t * 2)
		for x in range(CX - half, CX + half + 1):
			if x <= CX - half or x >= CX + half:
				put(x, y, P["o"])
			elif y in (45, 55):
				put(x, y, P["r"])
			elif x < CX:
				put(x, y, P["N"])
			else:
				put(x, y, P["n"])

	put(CX, 48, P["B"])
	put(CX - 1, 48, P["b"])
	put(CX + 1, 48, P["b"])
	put(CX - 1, 49, P["b"])
	put(CX, 49, P["b"])
	put(CX + 1, 49, P["b"])
	put(CX, 50, P["b"])
	for x in range(CX - 5, CX + 6):
		put(x, 52, P["k"])
		put(x, 53, P["k"])

	# Silhouette outline
	out = img.copy()
	op = out.load()
	for y in range(H):
		for x in range(W):
			if px[x, y][3] < 1:
				for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
					nx, ny = x + dx, y + dy
					if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 0:
						op[x, y] = P["o"]
						break
	return out


if __name__ == "__main__":
	art = paint()
	chunky = art.resize((art.size[0] * 2, art.size[1] * 2), Image.Resampling.NEAREST)
	chunky.save("assets/sprites/tobor_head.png")
	art.resize((art.size[0] * 6, art.size[1] * 6), Image.Resampling.NEAREST).save("ref image/_head_px_preview.png")
	print(chunky.size)
