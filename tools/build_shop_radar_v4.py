"""Rebuild shop_combined.png: composite shop body + isolated radar dish.

v4: The radar dish in radar.png is the white dish at the top-center of the
image (rows ~82-260). The rest of the image is the ship body with a white/cream
background. We isolate ONLY the radar dish (crop rows 0-300, full width) and
remove its background, then composite it onto the bg-removed shop body.

Output:
  SpritesImport/toborship/shop_combined.png
  SpritesImport/toborship/shop_combined_white.png
"""
import os, shutil
from collections import deque
from PIL import Image

W, H = 1280, 720
SHOP = r"SpritesImport/toborship/shop.png"
RADAR = r"SpritesImport/toborship/radar.png"
OUT = r"SpritesImport/toborship/shop_combined.png"
OUT_WHITE = r"SpritesImport/toborship/shop_combined_white.png"
CRASH = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"

BG_LIGHT = 200

def is_bg(r, g, b):
    return r >= BG_LIGHT - 35 and g >= BG_LIGHT - 35 and b >= BG_LIGHT - 35

def remove_bg_from_edges(path: str, crop_box=None):
    """Flood-fill from borders through light pixels -> transparent."""
    img = Image.open(path).convert("RGBA")
    if crop_box:
        img = img.crop(crop_box)
    w, h = img.size
    px = img.load()
    visited = [[False] * w for _ in range(h)]
    q = deque()

    def seed(x, y):
        r, g, b, a = px[x, y]
        if a > 0 and is_bg(r, g, b):
            visited[y][x] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0); seed(x, h - 1)
    for y in range(h):
        seed(0, y); seed(w - 1, y)

    while q:
        cx, cy = q.popleft()
        px[cx, cy] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                r2, g2, b2, a2 = px[nx, ny]
                if a2 > 0 and is_bg(r2, g2, b2):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return img

def main():
    for p in (SHOP, RADAR):
        if not os.path.exists(p + ".orig"):
            shutil.copy2(p, p + ".orig")
            print(f"backed up {os.path.basename(p)} -> .orig")

    # Remove bg from shop.png (full image)
    shop = remove_bg_from_edges(SHOP + ".orig")
    shop_bbox = shop.getbbox()
    print(f"shop content bbox: {shop_bbox}")

    # Isolate the radar dish: crop the TOP portion of radar.png (rows 0-300).
    # The radar dish is the white object at top-center; the ship body below it
    # is cut off by the crop. Then remove bg.
    radar_region = remove_bg_from_edges(RADAR + ".orig", crop_box=(0, 0, 1280, 300))
    radar_bbox = radar_region.getbbox()
    print(f"radar dish bbox (in 1280x300 crop): {radar_bbox}")
    if not radar_bbox:
        raise SystemExit("Could not isolate radar dish")

    radar_crop = radar_region.crop(radar_bbox)
    rw, rh = radar_crop.size
    print(f"radar dish: {rw}x{rh}")

    # Load crash ship for reference centering
    crash = Image.open(CRASH).convert("RGBA")
    crash_bbox = crash.getbbox()
    crash_cx = (crash_bbox[0] + crash_bbox[2]) // 2
    print(f"crash center x: {crash_cx}")

    # Build the combined canvas
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Paste shop body at its natural position
    canvas.alpha_composite(shop)

    shop_top_y = shop_bbox[1]
    print(f"shop top y: {shop_top_y}")

    # Place radar ON the ship body: bottom edge of radar overlaps ~35% into hull top
    overlap = int(0.35 * rh)
    radar_bottom = shop_top_y + overlap
    radar_top = radar_bottom - rh
    paste_x = crash_cx - rw // 2
    print(f"radar paste at ({paste_x}, {radar_top}), bottom={radar_bottom}")

    canvas.alpha_composite(radar_crop, (paste_x, radar_top))

    final_bbox = canvas.getbbox()
    print(f"combined bbox: {final_bbox}")
    print(f"combined content: {final_bbox[2]-final_bbox[0]}x{final_bbox[3]-final_bbox[1]}")

    canvas.save(OUT)
    print(f"saved {OUT}")

    alpha = canvas.getchannel("A")
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    white.putalpha(alpha)
    white.save(OUT_WHITE)
    print(f"saved {OUT_WHITE}")
    print("DONE")

if __name__ == "__main__":
    main()
