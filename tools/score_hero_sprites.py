"""Objective similarity score: forged hero pawn vs turnaround reference crop.

Compares shape (opaque mask mismatch), colour (histogram L1 on sprite pixels),
and shared-palette occupancy so every hand-edit round has one number to beat.

Run:  python tools/score_hero_sprites.py
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "ref image" / "_debug" / "turnarounds"
SPRITES = ROOT / "assets" / "sprites"

HEROES = ["arclight", "bulwark", "warden"]
VIEW = "front_0.png"


def ink_mask(im: Image.Image) -> list[list[int]]:
	px = im.convert("RGBA").load()
	w, h = im.size
	return [[1 if px[x, y][3] >= 12 else 0 for x in range(w)] for y in range(h)]


def ref_mask(im: Image.Image) -> list[list[int]]:
	px = im.convert("RGB").load()
	w, h = im.size
	out = []
	for y in range(h):
		row = []
		for x in range(w):
			r, g, b = px[x, y]
			ink = min(r, g, b) < 235
			row.append(1 if ink else 0)
		out.append(row)
	return out


def normalise(mask: list[list[int]], target: int) -> list[list[int]]:
	h = len(mask)
	w = len(mask[0]) if h else 0
	ys = [y for y in range(h) for x in range(w) if mask[y][x]]
	xs = [x for y in range(h) for x in range(w) if mask[y][x]]
	if not xs:
		return [[0] * target for _ in range(target)]
	x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
	crop = [row[x0:x1] for row in mask[y0:y1]]
	scale = target / max(len(crop), len(crop[0]))
	nw = max(1, round(len(crop[0]) * scale))
	nh = max(1, round(len(crop) * scale))
	resized = [[0] * nw for _ in range(nh)]
	for y in range(nh):
		for x in range(nw):
			resized[y][x] = crop[min(y * len(crop) // nh, len(crop) - 1)][min(x * len(crop[0]) // nw, len(crop[0]) - 1)]
	return resized


def mask_iou(a: list[list[int]], b: list[list[int]]) -> float:
	n = min(len(a), len(b))
	m = min(len(a[0]), len(b[0]))
	inter = union = 0
	for y in range(n):
		for x in range(m):
			va, vb = a[y][x], b[y][x]
			inter += va & vb
			union += va | vb
	return inter / union if union else 0.0


def palette_hist(im: Image.Image, buckets: int = 8) -> Counter:
	cnt: Counter = Counter()
	for r, g, b, a in im.convert("RGBA").getdata():
		if a < 12:
			continue
		cnt[(r * buckets // 256, g * buckets // 256, b * buckets // 256)] += 1
	return cnt


def hist_l1(a: Counter, b: Counter) -> float:
	keys = set(a) | set(b)
	return sum(abs(a[k] - b[k]) for k in keys) / 2.0


def score(hero: str) -> dict:
	ref = Image.open(REF / hero / VIEW).convert("RGB")
	spr_path = SPRITES / ("%s.png" % hero)
	if not spr_path.exists():
		return {"hero": hero, "score": 0.0, "detail": "missing sprite"}
	spr = Image.open(spr_path).convert("RGBA")

	ref_ink = Image.new("RGBA", ref.size, (0, 0, 0, 0))
	rp = ref.load(); op = ref_ink.load()
	for y in range(ref.size[1]):
		for x in range(ref.size[0]):
			r, g, b = rp[x, y][:3]
			if min(r, g, b) < 235:
				op[x, y] = (r, g, b, 255)
	s_mask = ink_mask(spr)
	r_mask = ref_mask(ref_small := ref.resize((40, 40), Image.Resampling.LANCZOS))
	colour = colourful_shape_sim(spr, ref_small, s_mask, r_mask)
	shape = mask_iou(normalise(s_mask, 40), normalise(r_mask, 40))
	return {"hero": hero, "score": round(0.6 * shape + 0.4 * colour, 3), "shape": round(shape, 3), "colour": round(colour, 3)}


def colourful_shape_sim(spr: Image.Image, ref: Image.Image, s_mask, r_mask) -> float:
	sp = spr.convert("RGBA").load()
	rp = ref.convert("RGB").load()
	h, w = 40, 40
	total, match = 0, 0.0
	for y in range(h):
		for x in range(w):
			s_ink = s_mask[y][x] if y < len(s_mask) and x < len(s_mask[0]) else 0
			r_ink = r_mask[y][x] if y < len(r_mask) and x < len(r_mask[0]) else 0
			if not (s_ink or r_ink):
				continue
			total += 1
			if s_ink and r_ink:
				sr, sg, sb, _a = sp[x, y]
				rr, rg, rb = rp[x, y][:3]
				d = ((sr - rr) ** 2 + (sg - rg) ** 2 + (sb - rb) ** 2) / (3 * 255 * 255)
				match += max(0.0, 1.0 - d ** 0.5)
	return match / total if total else 0.0


def main() -> None:
	for hero in HEROES:
		print(score(hero))


if __name__ == "__main__":
	main()
