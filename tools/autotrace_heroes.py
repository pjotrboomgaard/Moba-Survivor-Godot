"""Auto-trace turnaround reference crops into 40px sprite grids.

Downsamples each tight figure crop onto the 40px cell (nearest), snaps each
resulting pixel to the closest colour in the project's ROBOT_HERO palette, then
emits printable row strings.  Comparing the traced grid against hand-authored
rows tells us exactly where the hand rows drift from the turnaround art.

Run:  python tools/autotrace_heroes.py [hero ...]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "ref image" / "_debug" / "turnarounds"
OUT = ROOT / "ref image" / "_debug" / "trace"

PALETTE = {
	"w": (244, 246, 248), "u": (226, 230, 234), "s": (184, 190, 198), "m": (110, 118, 127),
	"d": (35, 40, 48), "n": (255, 120, 40), "r": (224, 90, 28), "t": (255, 74, 46),
	"l": (255, 178, 148), "i": (255, 193, 154), "y": (242, 236, 60), "a": (252, 255, 208),
	"k": (20, 23, 28), "g": (168, 255, 60), "G": (54, 196, 50), "c": (121, 90, 48),
	"b": (58, 34, 16), "h": (255, 255, 255), "o": (16, 20, 26), "e": (255, 154, 40),
	"p": (79, 143, 224), "q": (109, 118, 128), "f": (242, 226, 176),
}

SIZE = 40
VIEWS = {"front": "front_0.png", "left": "side_2.png", "back": "back_3.png"}


def nearest(rgb: tuple[int, int, int]) -> str:
	r, g, b = rgb
	best, best_d = "w", 1 << 62
	for key, (pr, pg, pb) in PALETTE.items():
		d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
		if d < best_d:
			best, best_d = key, d
	return best


def is_ink(rgb: tuple[int, int, int]) -> bool:
	return min(rgb) < 235


def trace(crop: Image.Image) -> list[list[str]]:
	rgb = crop.convert("RGB")
	# downsample with averaging so the figure's shading lands on the right ramp,
	# then nearest-resample up to the cell grid so we get crisp 1px cells
	rgb.thumbnail((SIZE, SIZE), Image.Resampling.BOX)
	w, h = rgb.size
	rows: list[list[str]] = [["."] * SIZE for _ in range(SIZE)]
	ox = (SIZE - w) // 2
	oy = SIZE - h
	px = rgb.load()
	for y in range(h):
		for x in range(w):
			colour = px[x, y]
			if is_ink(colour):
				rows[oy + y][ox + x] = nearest(colour)
	return rows


def render(rows: list[list[str]], scale: int = 8) -> Image.Image:
	img = Image.new("RGB", (SIZE * scale, SIZE * scale), (18, 20, 26))
	px = img.load()
	for y in range(SIZE):
		for x in range(SIZE):
			key = rows[y][x]
			if key == ".":
				continue
			r, g, b = PALETTE[key]
			for dy in range(scale):
				for dx in range(scale):
					px[x * scale + dx, y * scale + dy] = (r, g, b)
	return img


def rows_of(rows: list[list[str]]) -> list[str]:
	return ["".join(r) for r in rows]


def process(hero: str) -> Path:
	hero_dir = REF / hero
	out_dir = OUT / hero
	out_dir.mkdir(parents=True, exist_ok=True)
	sheets = []
	for facing, fname in VIEWS.items():
		crop_file = hero_dir / fname
		if not crop_file.exists():
			continue
		rows = trace(Image.open(crop_file))
		render(rows).save(out_dir / ("%s_%s_trace.png" % (hero, facing)))
		(out_dir / ("%s_%s_trace.txt" % (hero, facing))).write_text("\n".join(rows_of(rows)), encoding="utf-8")
		sheets.append((facing, rows))
		fmt = lambda r: "\t\t\"" + r + "\","
		print("\t\"%s%s\": [" % (hero, "" if facing == "front" else "_" + facing))
		print("".join(fmt(r) + "\n" for r in rows_of(rows)), "\t],")
	return out_dir


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("heroes", nargs="*", default=["arclight", "bulwark", "warden"])
	args = parser.parse_args()
	for hero in args.heroes:
		print("===", hero, "===")
		process(hero)


if __name__ == "__main__":
	main()
