"""Rebuild shop_combined with the radar placed ON the shop body (not 30px above).

The radar is the upgraded antenna that belongs to the shop — it must sit on top
of the hull, not floating above it. Also re-align: keep the same horizontal
centering as the crash ship (so the morph reads as one object transforming,
not two different objects).
"""
import os
from collections import deque
from PIL import Image

W, H = 1280, 720
SHOP = r"SpritesImport/toborship/shop.png.orig"
RADAR = r"SpritesImport/toborship/radar.png.orig"
OUT = r"SpritesImport/toborship/shop_combined.png"
OUT_WHITE = r"SpritesImport/toborship/shop_combined_white.png"
CRASH = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"

BG_LIGHT = 200

def is_bg(r, g, b):
    return r >= BG_LIGHT - 35 and g >= BG_LIGHT - 35 and b >= BG_LIGHT - 35


def remove_bg(path: str):
    img = Image.open(path).convert("RGBA")
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


def bbox(img):
    return img.getbbox()


def main():
    # Load crash ship to get its exact content bbox (reference for alignment).
    crash = Image.open(CRASH).convert("RGBA")
    crash_bbox = bbox(crash)
    print(f"crash bbox: {crash_bbox}")  # (118, 166, 1162, 554)

    shop = remove_bg(SHOP)
    radar = remove_bg(RADAR)
    shop_bbox = bbox(shop)
    radar_bbox = bbox(radar)
    print(f"shop bbox: {shop_bbox}")
    print(f"radar bbox: {radar_bbox}")

    # Build the combined canvas at 1280x720 (same as crash, so same scale).
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Paste shop body: keep it at its natural position (already centered ~640,360).
    canvas.alpha_composite(shop)

    # Place radar ON the shop body: bottom of radar overlaps top of shop body
    # by ~40% of radar height (mounted antenna look). Center horizontally with
    # the crash ship's content center.
    crash_cx = (crash_bbox[0] + crash_bbox[2]) // 2
    radar_w = radar_bbox[2] - radar_bbox[0]
    radar_h = radar_bbox[3] - radar_bbox[1]
    shop_top_y = shop_bbox[1]
    # Radar bottom edge = shop_top_y + 0.4 * radar_h (overlaps into body).
    radar_bottom = shop_top_y + int(0.4 * radar_h)
    radar_top = radar_bottom - radar_h
    paste_x = crash_cx - radar_w // 2
    radar_crop = radar.crop(radar_bbox)
    canvas.alpha_composite(radar_crop, (paste_x, radar_top))

    final_bbox = bbox(canvas)
    print(f"combined bbox: {final_bbox}")
    print(f"combined content center: ({(final_bbox[0]+final_bbox[2])//2}, {(final_bbox[1]+final_bbox[3])//2})")

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
