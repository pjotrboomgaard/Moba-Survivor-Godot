"""Crop Tobor views and key out paper without a hand-drawn cutout.

Flood paper from the image edge so the white face (enclosed) stays.
Left/back are scaled to the front's opaque height (nearest-neighbour)
so WASD facing does not shrink the pawn.
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "ref image" / "content_capped_resolution (3).webp"
SHOT = ROOT / "ref image" / "Screenshot 2026-08-26 165045.png"
OUT = ROOT / "assets" / "sprites"

CLOSE_RADIUS = 3
BARRIER_RADIUS = 2


def is_paper(p, loose: bool = False) -> bool:
	r, g, b, a = p if len(p) == 4 else (*p, 255)
	if a < 8:
		return True
	sat = max(r, g, b) - min(r, g, b)
	floor = 220 if loose else 248
	spread = 28 if loose else 14
	return min(r, g, b) >= floor and sat < spread


def is_ink(p) -> bool:
	r, g, b, a = p if len(p) == 4 else (*p, 255)
	if a < 8 or is_paper(p, loose=True):
		return False
	return True


def dilate_mask(src: list[list[bool]], radius: int) -> list[list[bool]]:
	h = len(src)
	w = len(src[0])
	out = [row[:] for row in src]
	r2 = radius * radius
	for y in range(h):
		for x in range(w):
			if src[y][x]:
				continue
			hit = False
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if dx * dx + dy * dy > r2:
						continue
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and src[ny][nx]:
						hit = True
						break
				if hit:
					break
			if hit:
				out[y][x] = True
	return out


def knockout_white(im: Image.Image) -> Image.Image:
	"""Drop paper connected to the border; keep enclosed white (the face).

	Ink is dilated into a temporary wall so anti-aliased gaps cannot leak the
	flood into the cone, then the wall itself is peeled if it is still paper.
	"""
	im = im.convert("RGBA")
	w, h = im.size
	src = im.load()
	ink = [[is_ink(src[x, y]) for x in range(w)] for y in range(h)]
	wall = dilate_mask(ink, BARRIER_RADIUS)
	edge: list[list[bool]] = [[False] * w for _ in range(h)]
	q: deque[tuple[int, int]] = deque()

	def push(x: int, y: int) -> None:
		if not (0 <= x < w and 0 <= y < h) or edge[y][x] or wall[y][x]:
			return
		if not is_paper(src[x, y], loose=True):
			return
		edge[y][x] = True
		q.append((x, y))

	for x in range(w):
		push(x, 0)
		push(x, h - 1)
	for y in range(h):
		push(0, y)
		push(w - 1, y)
	while q:
		x, y = q.popleft()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			push(x + dx, y + dy)

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	dst = out.load()
	for y in range(h):
		for x in range(w):
			if not edge[y][x]:
				dst[x, y] = src[x, y]
	out = defringe(out, passes=3)
	out = drop_specks(out, min_size=24)
	out = morph_close(out, CLOSE_RADIUS)
	out = fill_enclosed(out)
	out = bridge_row_gaps(out, max_gap=28)
	out = fill_pinholes(out, passes=2)
	return defringe(out, passes=2)


def drop_specks(im: Image.Image, min_size: int = 24) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	seen = [[False] * w for _ in range(h)]
	for y in range(h):
		for x in range(w):
			if seen[y][x] or px[x, y][3] < 12:
				continue
			q: deque[tuple[int, int]] = deque([(x, y)])
			seen[y][x] = True
			comp: list[tuple[int, int]] = []
			while q:
				cx, cy = q.popleft()
				comp.append((cx, cy))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = cx + dx, cy + dy
					if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= 12:
						seen[ny][nx] = True
						q.append((nx, ny))
			if len(comp) < min_size:
				for cx, cy in comp:
					px[cx, cy] = (0, 0, 0, 0)
	return im


def morph_close(im: Image.Image, radius: int) -> Image.Image:
	"""Dilate then erode opaque pixels so small shoulder gaps seal."""
	if radius <= 0:
		return im
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	opaque = [[px[x, y][3] >= 12 for x in range(w)] for y in range(h)]

	def grow(src: list[list[bool]]) -> list[list[bool]]:
		out = [row[:] for row in src]
		for y in range(h):
			for x in range(w):
				if src[y][x]:
					continue
				hit = False
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						if dx * dx + dy * dy > radius * radius:
							continue
						nx, ny = x + dx, y + dy
						if 0 <= nx < w and 0 <= ny < h and src[ny][nx]:
							hit = True
							break
					if hit:
						break
				if hit:
					out[y][x] = True
		return out

	def shrink(src: list[list[bool]]) -> list[list[bool]]:
		out = [row[:] for row in src]
		for y in range(h):
			for x in range(w):
				if not src[y][x]:
					continue
				kill = False
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						if dx * dx + dy * dy > radius * radius:
							continue
						nx, ny = x + dx, y + dy
						if not (0 <= nx < w and 0 <= ny < h) or not src[ny][nx]:
							kill = True
							break
					if kill:
						break
				if kill:
					out[y][x] = False
		return out

	closed = shrink(grow(opaque))
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	dst = out.load()
	for y in range(h):
		for x in range(w):
			if not closed[y][x]:
				continue
			if opaque[y][x]:
				dst[x, y] = px[x, y]
				continue
			rs = gs = bs = n = 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and opaque[ny][nx]:
						r, g, b, _a = px[nx, ny]
						rs += r
						gs += g
						bs += b
						n += 1
			if n > 0:
				dst[x, y] = (rs // n, gs // n, bs // n, 255)
	return out


def opaque_neighbors(px, x: int, y: int, w: int, h: int) -> int:
	n = 0
	for dy in (-1, 0, 1):
		for dx in (-1, 0, 1):
			if dx == 0 and dy == 0:
				continue
			nx, ny = x + dx, y + dy
			if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 12:
				n += 1
	return n


def is_paper_fringe(p) -> bool:
	r, g, b, a = p
	if a < 8:
		return False
	sat = max(r, g, b) - min(r, g, b)
	return min(r, g, b) >= 230 and sat < 22


def defringe(im: Image.Image, passes: int = 2) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	for _ in range(passes):
		kill: list[tuple[int, int]] = []
		for y in range(h):
			for x in range(w):
				if not is_paper_fringe(px[x, y]):
					continue
				if opaque_neighbors(px, x, y, w, h) >= 5:
					continue
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] < 8:
						kill.append((x, y))
						break
		if not kill:
			break
		for x, y in kill:
			px[x, y] = (0, 0, 0, 0)
	for y in range(h):
		for x in range(w):
			if px[x, y][3] < 12:
				px[x, y] = (0, 0, 0, 0)
	return im


def fill_enclosed(im: Image.Image) -> Image.Image:
	"""Fill transparent pockets that do not touch the image border."""
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	outside = [[False] * w for _ in range(h)]
	q: deque[tuple[int, int]] = deque()

	def push(x: int, y: int) -> None:
		if 0 <= x < w and 0 <= y < h and not outside[y][x] and px[x, y][3] < 12:
			outside[y][x] = True
			q.append((x, y))

	for x in range(w):
		push(x, 0)
		push(x, h - 1)
	for y in range(h):
		push(0, y)
		push(w - 1, y)
	while q:
		x, y = q.popleft()
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			push(x + dx, y + dy)

	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= 12 or outside[y][x]:
				continue
			rs = gs = bs = n = 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 12:
						r, g, b, _a = px[nx, ny]
						rs += r
						gs += g
						bs += b
						n += 1
			if n > 0:
				px[x, y] = (rs // n, gs // n, bs // n, 255)
	return im


def bridge_row_gaps(im: Image.Image, max_gap: int = 28) -> Image.Image:
	"""Seal narrow vertical slits between shoulders and body, not the feet."""
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	x0, y0, x1, y1 = opaque_bbox(im)
	y_limit = y0 + int((y1 - y0) * 0.78)
	for y in range(y0, y_limit):
		opa = [px[x, y][3] >= 12 for x in range(w)]
		x = x0
		while x < x1:
			if opa[x]:
				x += 1
				continue
			j = x
			while j < x1 and not opa[j]:
				j += 1
			gap = j - x
			if x > x0 and j < x1 and 1 <= gap <= max_gap:
				left = px[x - 1, y]
				right = px[j, y]
				color = (
					(left[0] + right[0]) // 2,
					(left[1] + right[1]) // 2,
					(left[2] + right[2]) // 2,
					255,
				)
				for gx in range(x, j):
					px[gx, y] = color
			x = j
	return im


def fill_pinholes(im: Image.Image, passes: int = 2) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	for _ in range(passes):
		fill: list[tuple[int, int, tuple]] = []
		for y in range(h):
			for x in range(w):
				if px[x, y][3] >= 12:
					continue
				rs = gs = bs = n = 0
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						if dx == 0 and dy == 0:
							continue
						nx, ny = x + dx, y + dy
						if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 12:
							r, g, b, _a = px[nx, ny]
							rs += r
							gs += g
							bs += b
							n += 1
				if n >= 5:
					fill.append((x, y, (rs // n, gs // n, bs // n, 255)))
		if not fill:
			break
		for x, y, color in fill:
			px[x, y] = color
	return im
	im = im.convert("RGBA")
	w, h = im.size
	px = im.load()
	for _ in range(passes):
		fill: list[tuple[int, int, tuple]] = []
		for y in range(h):
			for x in range(w):
				if px[x, y][3] >= 12:
					continue
				rs = gs = bs = n = 0
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						if dx == 0 and dy == 0:
							continue
						nx, ny = x + dx, y + dy
						if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 12:
							r, g, b, _a = px[nx, ny]
							rs += r
							gs += g
							bs += b
							n += 1
				if n >= 5:
					fill.append((x, y, (rs // n, gs // n, bs // n, 255)))
		if not fill:
			break
		for x, y, color in fill:
			px[x, y] = color
	return im


def opaque_bbox(im: Image.Image) -> tuple[int, int, int, int]:
	px = im.load()
	w, h = im.size
	xs: list[int] = []
	ys: list[int] = []
	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= 12:
				xs.append(x)
				ys.append(y)
	if not xs:
		return 0, 0, w, h
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def tight_crop(im: Image.Image, pad: int = 2) -> Image.Image:
	x0, y0, x1, y1 = opaque_bbox(im)
	return im.crop((
		max(0, x0 - pad),
		max(0, y0 - pad),
		min(im.size[0], x1 + pad),
		min(im.size[1], y1 + pad),
	))


def scale_to_height(im: Image.Image, target_h: int) -> Image.Image:
	x0, y0, x1, y1 = opaque_bbox(im)
	crop = im.crop((x0, y0, x1, y1))
	oh = max(1, crop.size[1])
	if oh == target_h:
		return crop
	nw = max(1, round(crop.size[0] * target_h / oh))
	return crop.resize((nw, target_h), Image.Resampling.NEAREST)


def pad_to(im: Image.Image, tw: int, th: int) -> Image.Image:
	canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
	x = (tw - im.size[0]) // 2
	y = th - im.size[1]
	canvas.paste(im, (max(0, x), max(0, y)), im)
	return canvas


def col_spans(im: Image.Image, min_width: int = 40) -> list[tuple[int, int]]:
	px = im.load()
	w, h = im.size
	flags = [any(is_ink(px[x, y]) for y in range(h)) for x in range(w)]
	spans: list[tuple[int, int]] = []
	i = 0
	while i < w:
		if not flags[i]:
			i += 1
			continue
		j = i
		while j < w and flags[j]:
			j += 1
		if j - i >= min_width:
			spans.append((i, j))
		i = j
	return spans


def opaque_height(im: Image.Image) -> int:
	_x0, y0, _x1, y1 = opaque_bbox(im)
	return y1 - y0


def main() -> None:
	sheet = Image.open(SHEET).convert("RGBA")
	shot = knockout_white(Image.open(SHOT))
	px = sheet.load()
	h = sheet.size[1]
	row_flags = [any(is_ink(px[x, y]) for x in range(sheet.size[0])) for y in range(h)]
	ys = [i for i, f in enumerate(row_flags) if f]
	band = sheet.crop((0, min(ys), sheet.size[0], max(ys) + 1))
	parts = [knockout_white(band.crop((x0, 0, x1, band.size[1]))) for x0, x1 in col_spans(band)]
	if len(parts) < 3:
		raise SystemExit("expected 3 sheet figures, got %d" % len(parts))
	left_src, _front_sheet, back_src = parts[-3], parts[-2], parts[-1]

	front = tight_crop(shot)
	left = tight_crop(left_src)
	back = tight_crop(back_src)
	body_h = opaque_height(front)
	front = scale_to_height(front, body_h)
	left = scale_to_height(left, body_h)
	back = scale_to_height(back, body_h)
	print("opaque height", body_h, "front", front.size, "left", left.size, "back", back.size)

	tw = max(front.size[0], left.size[0], back.size[0])
	th = body_h
	tw += tw % 2
	th += th % 2
	front = defringe(pad_to(front, tw, th), passes=1)
	left = defringe(pad_to(left, tw, th), passes=1)
	back = defringe(pad_to(back, tw, th), passes=1)
	right = ImageOps.mirror(left)

	OUT.mkdir(parents=True, exist_ok=True)
	front.save(OUT / "tobor.png")
	back.save(OUT / "tobor_back.png")
	left.save(OUT / "tobor_left.png")
	right.save(OUT / "tobor_right.png")
	print("canvas", (tw, th), "-> tobor.png / _back / _left / _right")


if __name__ == "__main__":
	main()
