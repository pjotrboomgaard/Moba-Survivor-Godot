"""Side-by-side comparison of reference turnaround crops vs forged hero sprites.

For each hero (`arclight`, `bulwark`, `warden`) and each facing we pair the
turnaround crop from `ref image/_debug/turnarounds/<hero>/` with the baked
`<hero>[_<facing>].png` in `assets/sprites/`, normalise both to one cell
height, and emit a labelled contact sheet plus a per-pixel diff heatmap.

Run:  python tools/compare_hero_sprites.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "ref image" / "_debug" / "turnarounds"
SPRITES = ROOT / "assets" / "sprites"
OUT = ROOT / "ref image" / "_debug" / "compare"

HEROES = ["arclight", "bulwark", "warden"]
# facing -> turnaround crop prefix chosen by tools/cut_turnarounds.py order
CROPS = {
	"front": "front_0.png",
	"left": "side_2.png",
	"back": "back_3.png",
}
SPRITE_KEYS = {
	"front": "{h}",
	"left": "{h}_left",
	"back": "{h}_back",
	"right": "{h}_right",
}

CELL = 240
ZOOM_TARGET = 5


def load_font(size: int):
	try:
		return ImageFont.truetype("arial.ttf", size)
	except OSError:
		return ImageFont.load_default()


def normalise(im: Image.Image, height: int) -> Image.Image:
	w, h = im.size
	if h == height:
		return im
	nw = max(1, round(w * height / h))
	return im.resize((nw, height), Image.Resampling.NEAREST)


def alpha_flat(im: Image.Image, bg=(16, 18, 24, 255)) -> Image.Image:
	rgba = im.convert("RGBA")
	base = Image.new("RGBA", rgba.size, bg)
	base.alpha_composite(rgba)
	return base


def pixel_diff(a: Image.Image, b: Image.Image) -> Image.Image:
	size = (max(a.size[0], b.size[0]), max(a.size[1], b.size[1]))
	a2 = Image.new("RGBA", size, (0, 0, 0, 0))
	b2 = Image.new("RGBA", size, (0, 0, 0, 0))
	a2.alpha_composite(a, (0, 0))
	b2.alpha_composite(b, (0, 0))
	diff = ImageChops.difference(a2.convert("RGB"), b2.convert("RGB"))
	return ImageOps.autocontrast(diff)


def panel(label: str, img: Image.Image, draw_cell: int) -> tuple[str, Image.Image]:
	scaled = img.copy()
	scaled.thumbnail((draw_cell - 12, draw_cell - 12), Image.Resampling.NEAREST)
	return (label, scaled)


def hero_sheet(hero: str) -> Path:
	font = load_font(15)
	tiles: list[tuple[str, Image.Image]] = []
	for facing in ("front", "left", "back"):
		crop_name = CROPS.get(facing)
		ref_img = None
		if crop_name:
			candidate = REF / hero / crop_name
			if candidate.exists():
				ref_img = Image.open(candidate).convert("RGBA")
		sprite_path = SPRITES / (SPRITE_KEYS[facing].format(h=hero) + ".png")
		cur_img = Image.open(sprite_path).convert("RGBA") if sprite_path.exists() else None

		if ref_img is not None:
			tiles.append(panel("REF %s %s" % (hero, facing), alpha_flat(ref_img), CELL))
		else:
			tiles.append(("REF %s %s (missing)" % (hero, facing), Image.new("RGBA", (CELL // 2, CELL // 2), (40, 40, 52, 255))))
		if cur_img is not None:
			tiles.append(panel("CUR %s %s" % (hero, facing), alpha_flat(cur_img), CELL))
		else:
			tiles.append(("CUR %s %s (missing)" % (hero, facing), Image.new("RGBA", (CELL // 2, CELL // 2), (40, 40, 52, 255))))
		if ref_img is not None and cur_img is not None:
			ref_n = normalise(alpha_flat(ref_img), CELL)
			cur_n = normalise(alpha_flat(cur_img), CELL)
			tiles.append(panel("DIFF %s %s" % (hero, facing), pixel_diff(ref_n, cur_n), CELL))

	gap, label_h = 8, 22
	cols = 3
	rows = (len(tiles) + cols - 1) // cols
	sheet = Image.new("RGBA", (cols * (CELL + gap) + gap, rows * (CELL + label_h) + gap), (14, 16, 22, 255))
	draw = ImageDraw.Draw(sheet)
	for i, (label, img) in enumerate(tiles):
		cx = gap + (i % cols) * (CELL + gap)
		cy = gap + (i // cols) * (CELL + label_h)
		draw.rectangle([cx, cy, cx + CELL, cy + CELL], fill=(22, 24, 32, 255))
		x = max(cx, cx + (CELL - img.size[0]) // 2)
		y = max(cy, cy + CELL - img.size[1] - 4)
		sheet.alpha_composite(img.convert("RGBA"), (x, y))
		draw.text((cx + 5, cy + CELL + 3), label, fill=(255, 210, 90, 255), font=font)
	path = OUT / ("%s_compare.png" % hero)
	path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(path)
	return path


def main() -> None:
	for hero in HEROES:
		print(hero, "->", hero_sheet(hero))


if __name__ == "__main__":
	main()
