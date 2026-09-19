"""
Batch-convert all pixel-art house sprites to 64px pixel-art style.

Approach that avoids the white-fringe problem:
  1. Downscale the ORIGINAL (white-bg) image to 64px first.
  2. Remove white background on the SMALL image via flood-fill — the white
     is now a solid, uniform color at small scale, so the fill is clean.
  3. For any remaining near-white pixel that's on the content edge, clear it.
  4. For any fully-opaque near-white pixel in the interior, snap it to the
     lightest non-white palette color (so white window frames become a warm
     off-white instead of pure white that looks like a bg leak).
  5. Quantize to 16 colors using THIS house's own dominant palette.

The key insight: doing background removal on the small image (after downscale)
works better than before downscale, because the downscale averages the white
into the edge pixels making them harder to distinguish. Instead, we downscale
with the white bg intact, then remove it on the clean small grid.
"""

import os
import sys
import argparse
import colorsys
from pathlib import Path
from collections import Counter, deque

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel_art_pipeline import SPRITES_DIR
from PIL import Image

TARGET_GRID = 64
N_COLORS = 16

HOUSE_PREFIXES = ("pixelart_house_", "pixelart_building_", "pixelart_combo_", "pixelart4_")

NEAR_WHITE = 205

# Desaturation factor to match the game's muted art pass.
# The tree sprites average ~0.27 saturation; the game uses TERRAIN_SAT_ADJUST=0.70
# for terrain. We apply 0.55 here to bring the vivid AI-generated houses into
# the same muted range, preserving hue identity (red roof stays reddish, etc.).
DESAT_FACTOR = 0.55


def desaturate(img: Image.Image, factor: float = DESAT_FACTOR) -> Image.Image:
    """
    Reduce saturation of all opaque pixels by `factor` (0.0 = fully grey,
    1.0 = unchanged). This matches the game's muted, desaturated art pass
    so the houses don't look out of place next to the tree sprites.
    """
    import colorsys
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h_hsv, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            s = s * factor
            r2, g2, b2 = colorsys.hsv_to_rgb(h_hsv, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return img


def downscale_to_grid(img: Image.Image, target: int) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    scale = target / max(w, h)
    new_w = max(1, round(w * scale))
    new_h = max(1, round(h * scale))
    mid_w = max(1, round(new_w * 2))
    mid_h = max(1, round(new_h * 2))
    small = img.resize((mid_w, mid_h), Image.LANCZOS)
    small = small.resize((new_w, new_h), Image.BOX)
    return small


def remove_white_bg_small(img: Image.Image, tolerance: int = 45) -> Image.Image:
    """
    Remove white background on the already-downscaled small image.
    Flood-fill from all border pixels. On the small grid, the white background
    is a solid, uniform color so the fill is very clean.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    # Find the dominant border color
    border_samples = []
    for x in range(w):
        border_samples.append(px[x, 0][:3])
        border_samples.append(px[x, h - 1][:3])
    for y in range(h):
        border_samples.append(px[0, y][:3])
        border_samples.append(px[w - 1, y][:3])
    bg = Counter(border_samples).most_common(1)[0][0]

    def is_bg(c):
        return (abs(c[0] - bg[0]) <= tolerance and
                abs(c[1] - bg[1]) <= tolerance and
                abs(c[2] - bg[2]) <= tolerance)

    visited = [[False] * w for _ in range(h)]
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y][:3]) and not visited[y][x]:
                visited[y][x] = True
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(px[x, y][:3]) and not visited[y][x]:
                visited[y][x] = True
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                if is_bg(px[nx, ny][:3]):
                    visited[ny][nx] = True
                    queue.append((nx, ny))

    return img


def clear_edge_fringe(img: Image.Image, ring: int = 2) -> Image.Image:
    """
    Clear near-white or semi-transparent pixels on the outer ring of the
    content bounding box. Also clears any semi-transparent near-white pixel
    anywhere in the image.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    min_x, min_y, max_x, max_y = w, h, 0, 0
    found = False
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 128:
                found = True
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
    if not found:
        return img

    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            near_white = (r >= NEAR_WHITE and g >= NEAR_WHITE and b >= NEAR_WHITE)
            if not near_white:
                continue
            on_ring = (
                (x - min_x) <= ring or (max_x - x) <= ring
                or (y - min_y) <= ring or (max_y - y) <= ring
            )
            semi = a < 255
            if on_ring or semi:
                px[x, y] = (0, 0, 0, 0)
                cleared += 1

    if cleared:
        print(f"    [fringe] cleared {cleared} pixels")
    return img


def extract_own_palette(img: Image.Image, n_colors: int) -> list:
    """Extract a palette from THIS image's opaque, non-white pixels."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    samples = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            if r > 235 and g > 235 and b > 235:
                continue
            samples.append((r, g, b))

    if not samples:
        return [(128, 100, 80)] * n_colors

    grid_w = 32
    grid_h = max(1, (len(samples) + grid_w - 1) // grid_w)
    canvas = Image.new("RGB", (grid_w, grid_h))
    cpx = canvas.load()
    for i, (r, g, b) in enumerate(samples):
        x, y = i % grid_w, i // grid_w
        if y < grid_h:
            cpx[x, y] = (r, g, b)

    quantized = canvas.quantize(colors=n_colors, method=Image.MEDIANCUT, kmeans=6)
    pdata = quantized.getpalette()
    colors = []
    for i in range(n_colors):
        idx = i * 3
        if idx + 2 < len(pdata):
            colors.append((pdata[idx], pdata[idx + 1], pdata[idx + 2]))
    while len(colors) < n_colors:
        colors.append(colors[-1])
    return colors[:n_colors]


def snap_interior_white(img: Image.Image, palette: list) -> Image.Image:
    """
    Replace any remaining fully-opaque near-white pixel in the interior with
    the lightest non-white palette color. This turns white window frames into
    a warm off-white that fits the art pass.
    """
    best = None
    for c in palette:
        if c[0] < 240 or c[1] < 240 or c[2] < 240:
            lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
            if best is None or lum > best[0]:
                best = (lum, c)
    if best is None:
        return img
    snap_color = best[1]

    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    changed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r >= NEAR_WHITE and g >= NEAR_WHITE and b >= NEAR_WHITE:
                px[x, y] = (snap_color[0], snap_color[1], snap_color[2], 255)
                changed += 1
    if changed:
        print(f"    [snap-white] {changed} px -> #{snap_color[0]:02x}{snap_color[1]:02x}{snap_color[2]:02x}")
    return img


def convert_one(src: Image.Image, target: int, n_colors: int) -> Image.Image:
    # 1. Downscale the original (white-bg) image to target grid
    small = downscale_to_grid(src, target)

    # 2. Remove white background on the small image (clean, uniform white)
    small = remove_white_bg_small(small, tolerance=45)

    # 3. Clear any remaining edge fringe (near-white on the content border)
    small = clear_edge_fringe(small, ring=2)

    # 4. Desaturate to match the game's muted art pass (trees avg sat ~0.27)
    small = desaturate(small, DESAT_FACTOR)

    # 5. Extract this house's own palette (from non-transparent, non-white pixels)
    palette = extract_own_palette(small, n_colors)

    # 6. Quantize to 16 colors
    rgb = small.convert("RGB")
    rgb = rgb.point(lambda v: (v >> 3) << 3)
    quantized = rgb.quantize(colors=n_colors, method=Image.MEDIANCUT, kmeans=4)
    result = quantized.convert("RGBA")

    # 7. Re-apply transparency (pixels that were transparent stay transparent)
    spx = small.load()
    rpx = result.load()
    for y in range(result.height):
        for x in range(result.width):
            if spx[x, y][3] < 128:
                rpx[x, y] = (0, 0, 0, 0)

    # 8. Snap remaining interior white to lightest non-white palette color
    result = snap_interior_white(result, palette)

    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    house_files = []
    for prefix in HOUSE_PREFIXES:
        for f in sorted(SPRITES_DIR.glob(f"{prefix}*.png")):
            if f.name.endswith("_preview.png"):
                continue
            house_files.append(f)

    print(f"\n[BATCH] Converting {len(house_files)} house sprites to "
          f"{TARGET_GRID}px grid ({N_COLORS} colors, per-house palette)\n")

    for i, src in enumerate(house_files, 1):
        print(f"[{i}/{len(house_files)}] {src.name} ({src.stat().st_size // 1024} KB)", end=" ")
        img = Image.open(src)
        orig_w, orig_h = img.size

        if args.dry_run:
            print(f"  DRY RUN: would convert {orig_w}x{orig_h}")
            continue

        result = convert_one(img, TARGET_GRID, N_COLORS)

        out = src
        out.parent.mkdir(parents=True, exist_ok=True)
        result.save(str(out))

        preview = result.resize((result.width * 4, result.height * 4), Image.NEAREST)
        preview_path = out.with_name(out.stem + "_preview.png")
        preview.save(str(preview_path))

        colors_used = len(result.getcolors(maxcolors=9999))
        print(f"  {orig_w}x{orig_h} -> {result.width}x{result.height}, {colors_used} colors")

    if not args.dry_run:
        print(f"\n[BATCH] Done. All {len(house_files)} houses converted to {TARGET_GRID}px grid.")
    else:
        print(f"\n[DRY] Would convert {len(house_files)} houses.")


if __name__ == "__main__":
    main()
