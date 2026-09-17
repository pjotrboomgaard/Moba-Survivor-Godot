"""Remove the white/cream halo from the ship PNGs.

Strategy: the background is a light cream/white gradient that touches the image
border. We flood-fill from every border pixel, walking only through "light"
pixels (high value, low saturation — i.e. white/cream). This preserves the
ship's dark red / gold body (which is not light) and its own text. The halo
around the ship is light, so it gets removed even where it's not connected to
the exact corner color.
"""
import sys, os, shutil
from collections import deque
from PIL import Image, ImageEnhance

BG_LIGHT_THRESHOLD = 200  # min per-channel value to count as "light/background"
# A pixel is "background" if it is light on all channels (cream/white).
def is_bg(r, g, b):
    return r >= BG_LIGHT_THRESHOLD - 35 and g >= BG_LIGHT_THRESHOLD - 35 and b >= BG_LIGHT_THRESHOLD - 35


def make_transparent(path: str, out_path: str) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    print(f"  {os.path.basename(path)}: {w}x{h}")

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
        r, g, b, _ = px[cx, cy]
        # Make transparent, with a soft edge: near-bg pixels get partial alpha.
        px[cx, cy] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                r2, g2, b2, a2 = px[nx, ny]
                if a2 > 0 and is_bg(r2, g2, b2):
                    visited[ny][nx] = True
                    q.append((nx, ny))

    img.save(out_path)
    print(f"  saved -> {out_path}")


if __name__ == "__main__":
    crash = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
    shop = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"
    for p in (crash, shop):
        if not os.path.exists(p + ".orig"):
            shutil.copy2(p, p + ".orig")
        # Work from the pristine original each run.
        src = p + ".orig"
    make_transparent(crash + ".orig", crash)
    make_transparent(shop + ".orig", shop)
    print("DONE")
