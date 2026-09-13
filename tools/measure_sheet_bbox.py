"""Measure the real opaque (non-white) character bounding box within each of the
4 columns of a source sheet. Reveals where sprites actually live and whether any
columns contain two stacked figures or overlap into neighbors."""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "SpritesImport"

SHEETS = {
    "jolt.png":   {"bg": (254, 254, 254)},
    "tremor.png": {"bg": (252, 252, 252)},
    "totem.png":  {"bg": (252, 252, 252)},
}

def opaque_bbox(cell: Image.Image, bg, thresh=60):
    """Return (x0,y0,x1,y1,w,h) of pixels that are clearly NOT background, plus
    the fraction of the cell that is opaque."""
    cell = cell.convert("RGB")
    W, H = cell.size
    px = cell.load()
    xs, ys = [], []
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            if d > thresh:
                xs.append(x); ys.append(y)
    if not xs:
        return None
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    return (x0, y0, x1, y1, x1 - x0 + 1, y1 - y0 + 1, len(xs) / (W * H))

for name in sys.argv[1:] if len(sys.argv) > 1 else SHEETS:
    spec = SHEETS[name]
    im = Image.open(SRC / name).convert("RGB")
    W, H = im.size
    print(f"\n=== {name}  ({W}x{H}) ===")
    # whole-sheet bbox first
    print("WHOLE SHEET bbox:", opaque_bbox(im, spec["bg"]))
    for i in range(4):
        x0 = int(W * i / 4); x1 = int(W * (i + 1) / 4)
        cell = im.crop((x0, 0, x1, H))
        bb = opaque_bbox(cell, spec["bg"])
        if bb is None:
            print(f"  col{i} [{x0}-{x1}]: EMPTY")
        else:
            cx0, cy0, cx1, cy1, w, h, frac = bb
            print(f"  col{i} [{x0}-{x1}]: bbox x={cx0}-{cx1} y={cy0}-{cy1}  size={w}x{h}  opaque_frac={frac:.3f}")
