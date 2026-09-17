"""Make the shop (upgraded ship) use shop.png as its body + radar.png as its radar.

Steps:
  1. Take shop.png, remove its white background (flood-fill from edges) -> RGBA.
  2. Take radar.png, remove its white background -> RGBA.
  3. Measure both in a 1280x720 frame and align them:
       - Both centered horizontally in the 1280x720 frame.
       - The radar sits ABOVE the shop body (the radar is the upgraded antenna
         that sits on top of the crash-ship hull).
       - shop.png body bbox is kept at its natural position (centered).
       - radar.png is centered horizontally and placed so its bottom edge
         overlaps slightly with the top of the shop body (like an antenna
         mounted on the hull).
  4. Composite: shop body + radar on top -> output to a clean 1280x720 RGBA.
  5. Generate the matching white silhouette for the morph.

Output files:
  SpritesImport/toborship/shop_combined.png   (RGBA, transparent bg)
  SpritesImport/toborship/shop_combined_white.png (white silhouette)
"""
import os, shutil
from collections import deque
from PIL import Image, ImageDraw

W, H = 1280, 720
SHOP = r"SpritesImport/toborship/shop.png"
RADAR = r"SpritesImport/toborship/radar.png"
OUT = r"SpritesImport/toborship/shop_combined.png"
OUT_WHITE = r"SpritesImport/toborship/shop_combined_white.png"

BG_LIGHT = 200

def is_bg(r, g, b):
    return r >= BG_LIGHT - 35 and g >= BG_LIGHT - 35 and b >= BG_LIGHT - 35


def remove_bg(path: str):
    """Flood-fill from borders through light pixels -> transparent."""
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


def content_bbox(img):
    """Return (x0, y0, x1, y1) of the non-transparent content, or None."""
    return img.getbbox()


def center_in_frame(img, frame_w=W, frame_h=H):
    """Crop to content and re-center in a frame_w x frame_h transparent canvas."""
    bbox = content_bbox(img)
    if bbox is None:
        return Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    x0, y0, x1, y1 = bbox
    content = img.crop(bbox)
    cw, ch = content.size
    canvas = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    # Center horizontally. Keep vertical center at frame center (caller adjusts).
    cx = (frame_w - cw) // 2
    cy = (frame_h - ch) // 2
    canvas.paste(content, (cx, cy), content)
    return canvas


def main():
    # Ensure originals are backed up once.
    for p in (SHOP, RADAR):
        if not os.path.exists(p + ".orig"):
            shutil.copy2(p, p + ".orig")
            print(f"backed up {os.path.basename(p)} -> .orig")
        else:
            print(f"backup exists for {os.path.basename(p)}")

    # Work from pristine originals.
    shop = remove_bg(SHOP + ".orig")
    radar = remove_bg(RADAR + ".orig")

    shop_bbox = content_bbox(shop)
    radar_bbox = content_bbox(radar)
    print(f"shop content bbox: {shop_bbox}")
    print(f"radar content bbox: {radar_bbox}")

    # Center shop body in the 1280x720 frame.
    shop_frame = center_in_frame(shop)
    shop_bbox_frame = content_bbox(shop_frame)
    print(f"shop centered bbox in frame: {shop_bbox_frame}")

    # Radar: center horizontally in frame, then place it so its bottom edge
    # sits slightly ABOVE the top of the shop body (antenna mounted on hull).
    radar_frame = center_in_frame(radar)
    radar_bbox_frame = content_bbox(radar_frame)
    if radar_bbox_frame is None:
        raise SystemExit("radar has no content after bg removal")

    # The shop body's top edge in the frame:
    shop_top_y = shop_bbox_frame[1]
    radar_bottom_y = radar_bbox_frame[3]
    # We want radar_bottom to sit ~30px above shop_top (mounted antenna look).
    # Move the radar up by (shop_top_y - 30 - radar_bottom_y) pixels.
    offset_y = shop_top_y - 30 - radar_bottom_y
    if offset_y != 0:
        radar_moved = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # Shift the radar content up.
        shifted = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # Crop the radar content, then paste at shifted position.
        rx0, ry0, rx1, ry1 = radar_bbox_frame
        radar_content = radar_frame.crop((rx0, ry0, rx1, ry1))
        paste_x = rx0
        paste_y = ry0 + offset_y
        shifted.paste(radar_content, (paste_x, paste_y), radar_content)
        radar_moved = shifted
    else:
        radar_moved = radar_frame

    radar_moved_bbox = content_bbox(radar_moved)
    print(f"radar final bbox in frame: {radar_moved_bbox}")

    # Composite: shop body (bottom layer) + radar (top layer).
    combined = shop_frame.copy()
    combined.alpha_composite(radar_moved)

    combined.save(OUT)
    print(f"saved {OUT}")

    # White silhouette for the morph.
    alpha = combined.getchannel("A")
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    white.putalpha(alpha)
    white.save(OUT_WHITE)
    print(f"saved {OUT_WHITE}")
    print(f"combined bbox: {content_bbox(combined)}")
    print("DONE")


if __name__ == "__main__":
    main()
