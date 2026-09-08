"""Generate 32x32 tree ASCII grids for tobor_world_art.gd."""
from pathlib import Path
import math


def blank() -> list[list[str]]:
	return [["."] * 32 for _ in range(32)]


def put(g, x, y, ch):
	if 0 <= x < 32 and 0 <= y < 32 and ch != ".":
		g[y][x] = ch


def disk(g, cx, cy, rx, ry, ch, hole=0.0):
	for y in range(32):
		for x in range(32):
			nx = (x + 0.5 - cx) / rx
			ny = (y + 0.5 - cy) / ry
			d = nx * nx + ny * ny
			if d <= 1.0 and d >= hole:
				put(g, x, y, ch)


def trunk(g, x0, x1, y0, y1, bark=True):
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			edge = x == x0 or x == x1
			mid = x == (x0 + x1) // 2
			if edge:
				ch = "o" if y >= y1 - 1 else "s"
			elif bark and (y + x) % 3 == 0:
				ch = "s"
			elif mid:
				ch = "t"
			else:
				ch = "t"
			put(g, x, y, ch)
	# roots
	put(g, x0 - 1, y1, "o")
	put(g, x1 + 1, y1, "o")
	put(g, x0, y1, "o")
	put(g, x1, y1, "o")


def clump(g, cx, cy, r):
	disk(g, cx, cy, r, r * 0.82, "m")
	disk(g, cx - 0.8, cy - 0.9, r * 0.62, r * 0.52, "l")
	disk(g, cx - 1.2, cy - 1.6, max(1.2, r * 0.32), max(1.0, r * 0.28), "h")
	disk(g, cx + 1.0, cy + 1.1, max(1.0, r * 0.28), max(0.9, r * 0.24), "g")


def speckle(g, seed=0):
	for y in range(32):
		for x in range(32):
			ch = g[y][x]
			if ch not in "mlhg":
				continue
			n = (x * 7 + y * 13 + seed) % 11
			if n == 0 and ch == "l":
				g[y][x] = "h"
			elif n == 1 and ch == "m":
				g[y][x] = "g"
			elif n == 2 and ch == "h":
				g[y][x] = "l"
			elif n == 3 and ch in "ml" and y > 2:
				# sky holes so the canopy reads as leaves, not a blob
				if abs(x - 16) > 4 or y < 14:
					g[y][x] = "."


def canopy_round(g, cx=16, cy=12):
	# Overlapping leaf puffs (Kenney-style scalloped crown) instead of one ellipse.
	for px, py, r in [
		(cx - 7, cy + 1, 4.2), (cx + 7, cy + 0, 4.0), (cx, cy - 6, 4.4),
		(cx - 4, cy - 4, 4.0), (cx + 4, cy - 4, 3.8), (cx - 6, cy - 1, 3.6),
		(cx + 6, cy - 1, 3.5), (cx - 3, cy + 4, 4.2), (cx + 3, cy + 4, 4.1),
		(cx, cy + 1, 5.2), (cx - 2, cy - 1, 3.4), (cx + 2, cy - 2, 3.2),
		(cx, cy - 3, 3.0), (cx - 8, cy + 3, 3.2), (cx + 8, cy + 3, 3.1),
	]:
		clump(g, px, py, r)
	speckle(g, 3)
	put(g, cx, cy - 9, "h")
	put(g, cx - 9, cy, "h")
	put(g, cx + 9, cy, "h")


def rows_of(g) -> list[str]:
	return ["".join(r) for r in g]


def oak():
	g = blank()
	canopy_round(g)
	trunk(g, 14, 17, 20, 30)
	put(g, 15, 20, "g")
	put(g, 16, 20, "g")
	return rows_of(g)


def pine_tier(g, top, height, half):
	for y in range(top, min(32, top + height)):
		t = (y - top + 1) / float(height)
		w = max(1, int(half * t))
		for x in range(16 - w, 16 + w + 1):
			edge = x == 16 - w or x == 16 + w
			# jagged needles
			if edge and (x + y) % 3 == 0:
				continue
			if abs(x - 16) < w * 0.25:
				ch = "g" if (x + y) % 4 == 0 else "m"
			elif y < top + 2:
				ch = "h"
			elif edge:
				ch = "h" if (x + y) % 2 == 0 else "l"
			else:
				ch = "l" if (x * 3 + y) % 5 else "m"
			put(g, x, y, ch)
		put(g, 16, top, "h")


def pine():
	g = blank()
	pine_tier(g, 2, 7, 4)
	pine_tier(g, 6, 9, 7)
	pine_tier(g, 12, 10, 10)
	trunk(g, 14, 17, 21, 30)
	return rows_of(g)


def dead():
	g = blank()
	trunk(g, 14, 17, 10, 30)
	# broken branches
	for x, y, ch in [
		(18, 12, "t"), (19, 11, "t"), (20, 10, "l"), (21, 10, "h"),
		(13, 14, "t"), (12, 13, "s"), (11, 13, "l"), (10, 12, "h"),
		(18, 16, "t"), (19, 16, "s"), (20, 17, "t"),
		(15, 8, "t"), (15, 7, "l"), (16, 6, "h"), (14, 6, "l"),
	]:
		put(g, x, y, ch)
	put(g, 16, 22, "h")  # ember
	put(g, 15, 24, "w")
	return rows_of(g)


def pipe():
	g = blank()
	# two stacks
	for ox in (10, 18):
		for y in range(8, 28):
			for x in range(ox, ox + 5):
				if x in (ox, ox + 4):
					put(g, x, y, "s")
				elif y % 4 == 0:
					put(g, x, y, "h")
				else:
					put(g, x, y, "m")
		# cap
		for x in range(ox - 1, ox + 6):
			put(g, x, 7, "l")
			put(g, x, 8, "h")
		put(g, ox + 2, 6, "w")
		put(g, ox + 1, 5, "w")
		put(g, ox + 3, 5, "h")
	for x in range(8, 25):
		put(g, x, 28, "o")
		put(g, x, 29, "o")
	return rows_of(g)


def piling():
	g = blank()
	# wooden pier post with rope wrap and barnacle
	trunk(g, 13, 18, 6, 30)
	for y in range(8, 12):
		for x in range(12, 20):
			put(g, x, y, "h" if y == 8 else "l")
	for x in range(12, 20):
		put(g, x, 16, "w")
		put(g, x, 17, "m")
	put(g, 12, 22, "w")
	put(g, 19, 24, "l")
	put(g, 11, 28, "h")
	put(g, 20, 29, "w")
	return rows_of(g)


def willow():
	g = blank()
	canopy_round(g, 16, 9)
	# hanging strands — extra columns at 32px
	for x, y0, y1 in [
		(6, 12, 24), (7, 14, 22), (8, 13, 26), (9, 15, 23),
		(10, 14, 27), (11, 16, 22), (21, 16, 23), (22, 13, 26),
		(23, 15, 24), (24, 12, 25), (25, 14, 22), (26, 13, 21),
	]:
		for y in range(y0, y1):
			ch = "h" if y == y0 else ("l" if (x + y) % 2 == 0 else "g")
			put(g, x, y, ch)
	trunk(g, 14, 17, 18, 30)
	return rows_of(g)


def roundt():
	g = blank()
	for px, py, r in [
		(16, 12, 6.5), (10, 13, 5.0), (22, 13, 5.0), (13, 8, 4.6),
		(19, 8, 4.5), (16, 17, 5.2), (11, 17, 4.0), (21, 17, 4.0),
		(8, 11, 3.4), (24, 11, 3.3),
	]:
		clump(g, px, py, r)
	speckle(g, 9)
	trunk(g, 14, 17, 22, 30)
	put(g, 15, 22, "g")
	put(g, 16, 22, "g")
	return rows_of(g)


def fir():
	g = blank()
	pine_tier(g, 1, 6, 3)
	pine_tier(g, 5, 7, 5)
	pine_tier(g, 10, 8, 7)
	pine_tier(g, 16, 8, 9)
	trunk(g, 14, 17, 22, 30)
	return rows_of(g)


def palm():
	g = blank()
	trunk(g, 14, 17, 12, 30)
	# fronds
	for ang, length in [( -70, 10), (-40, 11), (-10, 9), (20, 11), (50, 10), (80, 8), (120, 7), (-110, 8)]:
		rad = math.radians(ang)
		for i in range(length):
			x = int(16 + math.cos(rad) * i)
			y = int(10 + math.sin(rad) * i * 0.45 - 2)
			ch = "h" if i < 3 else ("l" if i < 7 else "m")
			put(g, x, y, ch)
			if i > 3:
				put(g, x, y + 1, "g")
	disk(g, 16, 9, 3.2, 2.4, "h")
	return rows_of(g)


def cypress():
	g = blank()
	for cy, r in [(6, 2.6), (10, 3.2), (14, 3.6), (18, 3.4), (22, 2.8)]:
		clump(g, 16, cy, r)
		clump(g, 15, cy + 1, r * 0.7)
	speckle(g, 1)
	trunk(g, 14, 17, 24, 30)
	return rows_of(g)


def maple():
	g = blank()
	for px, py, r in [
		(11, 10, 5.4), (21, 10, 5.2), (16, 7, 5.0), (16, 14, 5.6),
		(12, 14, 4.2), (20, 14, 4.1), (8, 11, 3.2), (24, 11, 3.2),
	]:
		clump(g, px, py, r)
	speckle(g, 5)
	trunk(g, 14, 17, 19, 30)
	return rows_of(g)


def volcano_oak():
	g = blank()
	canopy_round(g)
	# scorched holes / embers
	for x, y in [(12, 10), (20, 12), (16, 8), (14, 14)]:
		put(g, x, y, "w")
		put(g, x + 1, y, "h")
	trunk(g, 14, 17, 20, 30)
	put(g, 13, 22, "h")
	put(g, 18, 24, "w")
	return rows_of(g)


def ice_pine():
	g = pine()
	g = [list(r) for r in g]
	for y in range(32):
		for x in range(32):
			if g[y][x] == "h" and (x + y) % 2 == 0:
				g[y][x] = "w"
			if g[y][x] == "l" and y < 8 and x % 3 == 0:
				g[y][x] = "w"
	# snow cap
	for x in range(13, 20):
		put(g, x, 3, "w")
	return rows_of(g)


def factory_pipe():
	return pipe()


def docks_piling():
	return piling()


TREES = {
	"tree_oak": oak(),
	"tree_pine": pine(),
	"tree_dead": dead(),
	"tree_pipe": pipe(),
	"tree_piling": piling(),
	"tree_willow": willow(),
	"tree_round": roundt(),
	"tree_fir": fir(),
	"tree_palm": palm(),
	"tree_cypress": cypress(),
	"tree_maple": maple(),
}


def emit(name: str, grid: list[str]) -> str:
	lines = [f'\t"{name}": [']
	for row in grid:
		assert len(row) == 32, (name, len(row), row)
		lines.append(f'\t\t"{row}",')
	lines.append("\t],")
	return "\n".join(lines)


def main():
	assert all(len(r) == 32 for g in TREES.values() for r in g)
	assert all(len(g) == 32 for g in TREES.values())
	chunks = ["const _TREES32 := {"]
	for k, v in TREES.items():
		chunks.append(emit(k, v))
	chunks.append("}")
	chunks.append("---VOLCANO---")
	chunks.append(emit("volcano", volcano_oak()))
	chunks.append("---ICE---")
	chunks.append(emit("ice", ice_pine()))
	chunks.append("---FACTORY---")
	chunks.append(emit("factory", factory_pipe()))
	chunks.append("---DOCKS---")
	chunks.append(emit("docks", docks_piling()))
	Path(__file__).with_name("_trees32_out.txt").write_text("\n".join(chunks) + "\n", encoding="utf-8")
	print("wrote _trees32_out.txt")


if __name__ == "__main__":
	main()
