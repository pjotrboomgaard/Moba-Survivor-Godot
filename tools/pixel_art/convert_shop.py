"""
Convert the shop/crash ship sprites to pixel-art style matching the game's
art pass (muted colors, clean edges, no white fringe).

The source images are full-frame 1280x720 with the ship content filling most
of the frame. We downscale the ENTIRE frame to a pixel-art grid (128x72),
preserving the content position and relative size. This keeps the ship the
same size in-game (the full 1280x720 is rendered at SHIP_WIDTH_WORLD=620px).

Pipeline:
  1. Downscale the full 1280x720 frame to 128x72 (two-stage LANCZOS+BOX).
  2. Remove white/near-white background via flood-fill on the small image.
  3. Clear edge fringe (near-white or semi-transparent on content border).
  4. Desaturate to match the game's muted art pass.
  5. Quantize to a limited palette.
  6. Snap remaining interior white to lightest non-white color.
  7. Upscale back to 1280x720 (NEAREST) — the ship fills the same region.

Targets: shop_combined.png, shop_combined_white.png,
         and the crash sprite (ElevenLabs...20_03_12.png + _white.png).
"""

import os
import sys
from pathlib import Path
from collections import Counter, deque

from PIL import Image, ImageOps

BASE = Path(__file__).resolve().parent.parent.parent
SPRITES_IMPORT = BASE / "SpritesImport" / "toborship"

# Target pixel grid for the full 1280x720 frame.
# 128x72 = 1:10 scale, giving ~10px per pixel block at full res.
TARGET_W = 128
TARGET_H = 72
N_COLORS = 16
NEAR_WHITE = 200
DESAT_FACTOR = 0.65


def downscale_full_frame(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Downscale the full frame to target_w x target_h, two-stage LANCZOS+BOX."""
    img = img.convert("RGBA")
    mid_w = target_w * 2
    mid_h = target_h * 2
    small = img.resize((mid_w, mid_h), Image.LANCZOS)
    small = small.resize((target_w, target_h), Image.BOX)
    return small


def remove_white_bg(img: Image.Image, tolerance: int = 40) -> Image.Image:
    """Flood-fill remove white background from border pixels."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

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
    """Clear near-white or semi-transparent pixels on the content edge."""
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
        print(f"    [fringe] cleared {cleared} px")
    return img


def desaturate(img: Image.Image, factor: float = DESAT_FACTOR) -> Image.Image:
    """Reduce saturation of all opaque pixels."""
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


def extract_palette(img: Image.Image, n_colors: int) -> list:
    """Extract palette from opaque, non-white pixels."""
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
    """Snap remaining fully-opaque near-white pixels to lightest non-white palette color."""
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
    changed = 0
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r >= NEAR_WHITE and g >= NEAR_WHITE and b >= NEAR_WHITE:
                px[x, y] = (snap_color[0], snap_color[1], snap_color[2], 255)
                changed += 1
    if changed:
        print(f"    [snap-white] {changed} px -> #{snap_color[0]:02x}{snap_color[1]:02x}{snap_color[2]:02x}")
    return img


def make_white_silhouette(img: Image.Image) -> Image.Image:
    """Create a white-silhouette version (same alpha, all opaque pixels white)."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (255, 255, 255, a)
    return img


def convert_ship(src_path: str) -> Image.Image:
    """
    Full pipeline on the ENTIRE frame:
    downscale to 128x72 -> remove bg -> fringe -> desaturate -> quantize -> snap white
    -> upscale back to 1280x720 (NEAREST, preserving position).
    """
    img = Image.open(src_path).convert("RGBA")
    orig_w, orig_h = img.size

    # Downscale full frame to pixel grid
    small = downscale_full_frame(img, TARGET_W, TARGET_H)
    print(f"    [downscale] {orig_w}x{orig_h} -> {small.width}x{small.height}")

    # Remove white background
    small = remove_white_bg(small, tolerance=40)

    # Clear edge fringe
    small = clear_edge_fringe(small, ring=2)

    # Desaturate
    small = desaturate(small, DESAT_FACTOR)

    # Quantize
    palette = extract_palette(small, N_COLORS)
    rgb = small.convert("RGB")
    rgb = rgb.point(lambda v: (v >> 3) << 3)
    quantized = rgb.quantize(colors=N_COLORS, method=Image.MEDIANCUT, kmeans=4)
    result = quantized.convert("RGBA")

    # Re-apply transparency
    spx = small.load()
    rpx = result.load()
    for y in range(result.height):
        for x in range(result.width):
            if spx[x, y][3] < 128:
                rpx[x, y] = (0, 0, 0, 0)

    # Snap interior white
    result = snap_interior_white(result, palette)

    colors_used = len(result.getcolors(maxcolors=9999))
    print(f"    [quantize] {colors_used} colors, {result.width}x{result.height}")

    # Upscale back to 1280x720 with NEAREST (pixel-art look, same position)
    final = result.resize((orig_w, orig_h), Image.NEAREST)
    print(f"    [upscale] -> {final.width}x{final.height}")
    return final


def main():
    files = [
        ("shop_combined.png", "shop_combined.png"),
        ("ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
         "ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"),
    ]

    for src_name, out_name in files:
        src_path = str(SPRITES_IMPORT / src_name)
        if not os.path.exists(src_path):
            print(f"[SKIP] {src_name} not found")
            continue

        print(f"\n[CONVERT] {src_name}")

        # Convert the main sprite
        result = convert_ship(src_path)

        # Save
        out_path = str(SPRITES_IMPORT / out_name)
        result.save(out_path)
        print(f"    [save] {out_name} -> {result.width}x{result.height}")

        # Create white silhouette version
        white = make_white_silhouette(result)
        white_name = out_name.replace(".png", "_white.png")
        white_path = str(SPRITES_IMPORT / white_name)
        white.save(white_path)
        print(f"    [save] {white_name} -> {white.width}x{white.height}")

        # Preview: crop to content bbox and scale 4x for inspection
        bbox = result.getbbox()
        if bbox:
            content = result.crop(bbox)
            preview = content.resize((content.width * 4, content.height * 4), Image.NEAREST)
            preview_path = str(SPRITES_IMPORT / out_name.replace(".png", "_preview.png"))
            preview.save(preview_path)
            print(f"    [preview] {preview.width}x{preview.height} (content {content.width}x{content.height})")

    print(f"\n[DONE] All shop/crash sprites converted to {TARGET_W}x{TARGET_H} pixel art (full frame).")


if __name__ == "__main__":
    main()
