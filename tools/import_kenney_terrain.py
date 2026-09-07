"""Import Kenney Tiny Town (CC0) trees/rocks into assets/sprites.

Source: https://kenney.nl/assets/tiny-town
Black tile backgrounds become alpha. 16x16 tiles are 2x nearest-neighbor
so they match our PIXEL_ZOOM field. Biome copies are hue-shifted.
"""
from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"
TOWN = Path.home() / "AppData" / "Local" / "Temp" / "pixel_trees" / "extracted" / "tiny-town" / "Tiles"

# Kenney Tiny Town tile indices (see tools/_kenney_town_numbered.png).
TREE_OAK = "0005"  # round green
TREE_PINE = "0004"  # conical green
TREE_DEAD = "0016"  # round autumn
TREE_PIPE = "0048"  # stone column
TREE_PILING = "0044"  # wooden post
ROCK_SMALL = "0043"  # cobbles in grass
ROCK_LARGE = "0050"  # stone brick
BOULDER = "0049"
SPIRE = "0051"
BUSH = "0017"
MUSHROOM = "0029"
PAD_DIRT = "0013"


def tile(index: str) -> Image.Image:
	path = TOWN / f"tile_{index}.png"
	im = Image.open(path).convert("RGBA")
	px = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 12 or (r < 22 and g < 22 and b < 22):
				px[x, y] = (0, 0, 0, 0)
	return im


def scale2(im: Image.Image) -> Image.Image:
	return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def hue_shift(im: Image.Image, dh: float, sat: float, val: float) -> Image.Image:
	out = im.copy()
	px = out.load()
	w, h = out.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 8:
				continue
			hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
			hh = (hh + dh) % 1.0
			ss = max(0.0, min(1.0, ss * sat))
			vv = max(0.0, min(1.0, vv * val))
			nr, ng, nb = colorsys.hsv_to_rgb(hh, ss, vv)
			px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
	return out


BIOME_SHIFT = {
	"volcano": (0.04, 0.85, 0.72),
	"ice": (0.48, 0.45, 1.12),
	"factory": (0.52, 0.35, 0.82),
	"docks": (0.08, 0.70, 0.90),
}


def save(name: str, im: Image.Image) -> None:
	path = OUT / f"{name}.png"
	im.save(path)
	print("wrote", path.name, im.size)


def main() -> None:
	if not TOWN.exists():
		raise SystemExit(f"missing Kenney tiles: {TOWN}")
	OUT.mkdir(parents=True, exist_ok=True)

	sprites = {
		"tree_oak": scale2(tile(TREE_OAK)),
		"tree_pine": scale2(tile(TREE_PINE)),
		"tree_dead": scale2(tile(TREE_DEAD)),
		"tree_pipe": scale2(tile(TREE_PIPE)),
		"tree_piling": scale2(tile(TREE_PILING)),
		"rock_small": scale2(tile(ROCK_SMALL)),
		"rock_large": scale2(tile(ROCK_LARGE)),
		"boulder": scale2(tile(BOULDER)),
		"spire": scale2(tile(SPIRE)),
		"grass_bush": scale2(tile(BUSH)),
		"grass_mushroom": scale2(tile(MUSHROOM)),
		"landmark_pad": scale2(tile(PAD_DIRT)),
	}
	for name, im in sprites.items():
		save(name, im)
		for biome, (dh, sat, val) in BIOME_SHIFT.items():
			save(f"tw_{biome}_{name}", hue_shift(im, dh, sat, val))


if __name__ == "__main__":
	main()
