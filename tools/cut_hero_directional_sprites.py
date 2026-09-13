"""Cut 4-directional hero sprites (front/back/side/left) out of a 4-panel sprite sheet.

Mirrors the method used for Tobor's own directional sprites (see
tools/extract_tobor_sprite.py): background keying + tight crop, but generalized to
any sheet laid out as 4 equal-width vertical slices. Each slice is keyed to a
transparent background, tightly cropped to the character's bounding box, then
nearest-neighbor resized to TARGET_SIZE (32x32, matching tobor.png) so all heroes
render at the same on-screen density.

Slice order in the sheet: front, back, side, left.
Output files:  <hero>.png (front), <hero>_back.png, <hero>_side.png, <hero>_left.png
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "SpritesImport"
OUT_DIR = ROOT / "assets" / "sprites"
TARGET_SIZE = 32

# Map source sheet filename -> in-game hero class_id.
JOBS = [
    ("tremor.png", "bulwark"),
    ("totem.png", "warden"),
    ("jolt.png", "arclight"),
]

SLICE_NAMES = ["front", "back", "side", "left"]


def background_color(im: Image.Image, slice_box: tuple) -> tuple:
    """Sample the top-left corner of the slice as the assumed flat background color."""
    sub = im.crop(slice_box)
    px = sub.load()
    # Median of a 10x10 sample in the top-left corner (usually background, not character).
    samples = []
    for y in range(0, min(10, sub.size[1])):
        for x in range(0, min(10, sub.size[0])):
            r, g, b, _a = px[x, y]
            samples.append((r, g, b))
    if not samples:
        return (0, 0, 0)
    samples.sort(key=lambda c: c[0] + c[1] + c[2])
    return samples[len(samples) // 2]


def key_out(im: Image.Image, bg: tuple, thresh: int = 48) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            if d <= thresh:
                px[x, y] = (0, 0, 0, 0)
    return im


def tight_crop(im: Image.Image) -> Image.Image:
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 20:
                xs.append(x)
                ys.append(y)
    if not xs:
        return im
    return im.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))


def resize_to_square(img: Image.Image, size: int = TARGET_SIZE) -> Image.Image:
    """Nearest-neighbor resize into a square canvas, character centered, preserving
    pixel-art crispness (no smoothing)."""
    w, h = img.size
    # Scale so the longer edge fits within `size`, keeping aspect ratio.
    scale = size / max(w, h)
    new_w, new_h = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    resized = img.resize((new_w, new_h), Image.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - new_w) // 2
    oy = (size - new_h) // 2
    canvas.paste(resized, (ox, oy))
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, hero in JOBS:
        src = SRC_DIR / filename
        im = Image.open(src).convert("RGBA")
        w, h = im.size
        q = w // 4
        for i, slice_name in enumerate(SLICE_NAMES):
            slice_box = (i * q, 0, (i + 1) * q, h)
            sub = im.crop(slice_box)
            bg = background_color(im, slice_box)
            keyed = key_out(sub, bg)
            cropped = tight_crop(keyed)
            final = resize_to_square(cropped, TARGET_SIZE)
            suffix = "" if slice_name == "front" else "_" + slice_name
            out_path = OUT_DIR / f"{hero}{suffix}.png"
            final.save(out_path)
            print(f"{filename} slice[{i}] ({slice_name}) bg~{bg} -> {out_path.name} {final.size}")


if __name__ == "__main__":
    main()
