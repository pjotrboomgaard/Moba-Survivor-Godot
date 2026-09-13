"""Cut 4-directional hero sprites from SpritesImport sheets.

Layout (user-confirmed, left to right in source sheet):
  col0 = FRONT (face visible, facing camera)
  col1 = BACK (back of body, no face)
  col2 = LEFT profile (hero's left side faces viewer)
  col3 = RIGHT profile (hero's right side faces viewer)

Keying: flood-fill from the cell border with a TIGHT threshold (25) to remove
only the solid white background. No erosion — the flood fill alone handles the
white bg without eating into the silhouette. A 4px pad is kept around the
silhouette so it doesn't touch the 80x80 canvas edge.
"""
from pathlib import Path
from PIL import Image
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "SpritesImport"
OUT_DIR = ROOT / "assets" / "sprites"

JOBS = [
    ("jolt2.png", "arclight"),
    ("tremor.png", "bulwark"),
    ("totem2.png", "warden"),
]

SHEET_CELLS = {
    "jolt.png": {
        "cols": [(51, 352), (371, 666), (730, 930), (1005, 1207)],
    },
    "jolt2.png": {
        "cols": [(47, 358), (366, 672), (723, 936), (999, 1214)],
    },
    "tremor.png": {
        "cols": [(69, 368), (450, 688), (780, 910), (1025, 1185)],
    },
    "totem.png": {
        "cols": [(105, 353), (374, 618), (713, 922), (1044, 1184)],
    },
    "totem2.png": {
        "cols": [(105, 355), (373, 620), (711, 927), (1042, 1187)],
    },
}

# col index -> output direction name
# User-confirmed layout (left to right): front, back, left, right
DIRECTIONS = [
    ("front", 0),
    ("back",  1),
    ("left",  2),
    ("right", 3),
]

TARGET_SIZE = 32
PAD_PX = 2        # small padding kept around the silhouette
BG_TOL = 20       # L1 distance threshold for bg flood fill (conservative: keeps silhouette intact)


def flood_key_white(sub: Image.Image) -> Image.Image:
    """Make border-connected near-white pixels transparent (single pass)."""
    sub = sub.convert("RGBA")
    px = sub.load()
    w, h = sub.size
    visited = [[False] * w for _ in range(h)]

    def is_bg(x, y):
        r, g, b, _ = px[x, y]
        return abs(r - 255) + abs(g - 255) + abs(b - 255) <= BG_TOL * 3

    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not visited[y][x] and is_bg(x, y):
                q.append((x, y)); visited[y][x] = True
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and is_bg(x, y):
                q.append((x, y)); visited[y][x] = True
    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_bg(nx, ny):
                visited[ny][nx] = True
                q.append((nx, ny))
    return sub


def crop_with_pad(im: Image.Image, pad: int = PAD_PX) -> Image.Image:
    """Crop to the silhouette bounding box, keeping `pad` pixels of margin."""
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 30:
                xs.append(x); ys.append(y)
    if not xs:
        return im
    x0, x1 = max(0, min(xs) - pad), min(w, max(xs) + 1 + pad)
    y0, y1 = max(0, min(ys) - pad), min(h, max(ys) + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def resize_to_square(img: Image.Image, size: int = TARGET_SIZE) -> Image.Image:
    """Downscale to a square canvas (32×32 to match tobor).

    Process:
    1. Create a clean binary silhouette (alpha > 128 → opaque, else transparent)
    2. Downscale the silhouette with NEAREST → stays solid, no gaps
    3. Downscale the RGB colors with LANCZOS → preserves color detail
    4. Composite: solid silhouette alpha + LANCZOS colors
    5. Center in the 32×32 canvas (bottom-aligned like tobor sprites)
    """
    # Step 1: Keep the sprite fully intact — the anti-aliased grey border is part
    # of the sprite and must NOT be removed. Downscale RGB+alpha with LANCZOS.
    w, h = img.size
    mid = 64
    scale1 = mid / max(w, h)
    m1_w, m1_h = max(1, int(round(w * scale1))), max(1, int(round(h * scale1)))
    step1 = img.resize((m1_w, m1_h), Image.LANCZOS)
    # Render into a square that is 2px larger than the target so we can shrink
    # by 1px on every side afterward.
    big = size + 2
    scale2 = big / max(m1_w, m1_h)
    m2_w, m2_h = max(1, int(round(m1_w * scale2))), max(1, int(round(m1_h * scale2)))
    step2 = step1.resize((m2_w, m2_h), Image.LANCZOS)

    # Step 2: Center the sprite on a (size+2) canvas, then crop the central
    # `size x size` region -> the sprite is effectively shrunk by 1px all
    # around, which prevents internal gaps at the seams.
    big_canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    big_canvas.paste(step2, ((big - m2_w) // 2, (big - m2_h) // 2), step2)
    final = big_canvas.crop((1, 1, 1 + size, 1 + size))
    return final


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, hero in JOBS:
        spec = SHEET_CELLS[filename]
        src = SRC_DIR / filename
        im = Image.open(src).convert("RGB")
        W, H = im.size
        for direction, col_idx in DIRECTIONS:
            x0, x1 = spec["cols"][col_idx]
            cell = im.crop((x0, 0, x1, H))
            keyed = flood_key_white(cell)
            cropped = crop_with_pad(keyed)
            final = resize_to_square(cropped)
            suffix = "" if direction == "front" else "_" + direction
            out_path = OUT_DIR / f"{hero}{suffix}.png"
            final.save(out_path)
            print(f"{filename} {direction:6s} (col{col_idx}) -> {out_path.name} "
                  f"crop={cropped.size} final={final.size}")


if __name__ == "__main__":
    main()
