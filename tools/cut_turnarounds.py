"""Cut hero turnaround sheets into per-view crops + tiled contact sheets.

Each `<hero>_turnaround.png` in `ref image/` holds one character drawn at
several angles on a near-white background.  This segments ink columns into
figures, labels them front / three-quarter / side / back (best effort from
left-to-right order and silhouette), and writes:

  ref image/_debug/turnarounds/<hero>/<view>_<i>.png   tight crops
  ref image/_debug/turnarounds/<hero>_sheet.png        labelled contact sheet

Run:  python tools/cut_turnarounds.py
"""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "ref image"
OUT = REF / "_debug" / "turnarounds"

HEROES = ["arclight", "bulwark", "warden"]
LABELS = ["front", "three_quarter", "side", "back"]


def is_ink(p) -> bool:
	r, g, b = p[:3]
	# white / paper-ish background is not ink
	if min(r, g, b) >= 232 and (max(r, g, b) - min(r, g, b)) < 22:
		return False
	return True


def ink_columns(im: Image.Image) -> list[bool]:
	px = im.load()
	w, h = im.size
	return [any(is_ink(px[x, y]) for y in range(h)) for x in range(w)]


def spans(flags: list[bool], min_width: int, max_gap: int) -> list[tuple[int, int]]:
	out: list[tuple[int, int]] = []
	i, w = 0, len(flags)
	while i < w:
		if not flags[i]:
			i += 1
			continue
		j = i
		while j < w:
			if flags[j]:
				j += 1
				continue
			# bridge small ink-free gaps inside one figure
			k = j
			while k < w and not flags[k]:
				k += 1
			if k < w and (k - j) <= max_gap:
				j = k
			else:
				break
		if j - i >= min_width:
			out.append((i, j))
		i = max(j, i + 1)
	return out


def figure_spans(im: Image.Image) -> list[tuple[int, int]]:
	w = im.size[0]
	return spans(ink_columns(im), min_width=max(28, w // 60), max_gap=max(10, w // 120))


def tight_crop(im: Image.Image, pad: int = 6) -> Image.Image:
	px = im.load()
	w, h = im.size
	xs: list[int] = []
	ys: list[int] = []
	for y in range(h):
		for x in range(w):
			if is_ink(px[x, y]):
				xs.append(x)
				ys.append(y)
	if not xs:
		return im
	x0, x1 = max(0, min(xs) - pad), min(w, max(xs) + pad)
	y0, y1 = max(0, min(ys) - pad), min(h, max(ys) + pad)
	return im.crop((x0, y0, x1, y1))


def load_font(size: int):
	try:
		return ImageFont.truetype("arial.ttf", size)
	except OSError:
		return ImageFont.load_default()


def contact(tiles: list[tuple[str, Image.Image]], path: Path, cell: int = 360, cols: int = 4) -> None:
	gap, label_h = 10, 26
	rows = (len(tiles) + cols - 1) // cols
	sheet = Image.new("RGB", (cols * (cell + gap) + gap, rows * (cell + label_h) + gap), (20, 22, 30))
	draw = ImageDraw.Draw(sheet)
	font = load_font(16)
	for i, (label, img) in enumerate(tiles):
		cx = gap + (i % cols) * (cell + gap)
		cy = gap + (i // cols) * (cell + label_h)
		draw.rectangle([cx, cy, cx + cell, cy + cell], fill=(28, 30, 40))
		scaled = img.copy()
		scaled.thumbnail((cell - 8, cell - 8), Image.Resampling.LANCZOS)
		sheet.paste(scaled, (cx + (cell - scaled.size[0]) // 2, cy + cell - scaled.size[1] - 4))
		draw.text((cx + 6, cy + cell + 4), label, fill=(255, 210, 90), font=font)
	path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(path)


def process(hero: str) -> None:
	src = REF / ("%s_turnaround.png" % hero)
	im = Image.open(src).convert("RGB")
	parts = figure_spans(im)
	hero_dir = OUT / hero
	hero_dir.mkdir(parents=True, exist_ok=True)
	tiles: list[tuple[str, Image.Image]] = []
	for i, (x0, x1) in enumerate(parts):
		crop = tight_crop(im.crop((x0, 0, x1, im.size[1])))
		label = LABELS[i] if i < len(LABELS) else "view%d" % i
		name = "%s_%d.png" % (label, i)
		crop.save(hero_dir / name)
		tiles.append(("%s %s [%dpx]" % (hero, label, crop.size[0]), crop))
	contact(tiles, OUT / ("%s_sheet.png" % hero), cols=min(4, max(1, len(parts))))
	print(hero, "figures:", len(parts), [t[0] for t in tiles])


def main() -> None:
	for hero in HEROES:
		process(hero)


if __name__ == "__main__":
	main()
