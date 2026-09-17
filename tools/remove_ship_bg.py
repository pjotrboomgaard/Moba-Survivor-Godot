"""Remove white background from the toborship PNGs.

Uses a flood-fill from the image borders so that white/near-white pixels that
are part of the ship (enclosed by non-white pixels) are preserved, while the
white background that touches the image edge becomes transparent.

Writes RGBA PNGs in place (backing up the originals first).
"""
import os
import shutil
from collections import deque

from PIL import Image

BASE = os.path.join(os.path.dirname(__file__), "..", "SpritesImport", "toborship")
FILES = [
    "ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
    "ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png",
]

# A pixel is "background-ish" if it is very light (near white).
THRESH = 232  # min of (r,g,b) must be >= THRESH to be considered background


def is_bg(px):
    r, g, b = px[0], px[1], px[2]
    return min(r, g, b) >= THRESH


def flood_remove(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    visited = [[False] * w for _ in range(h)]
    q = deque()

    # Seed from all four edges.
    for x in range(w):
        for y in (0, h - 1):
            if not visited[y][x] and is_bg(px[x, y]):
                q.append((x, y))
                visited[y][x] = True
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and is_bg(px[x, y]):
                q.append((x, y))
                visited[y][x] = True

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_bg(px[nx, ny]):
                visited[ny][nx] = True
                q.append((nx, ny))
    return img


def main():
    os.makedirs(BASE, exist_ok=True)
    for fname in FILES:
        path = os.path.join(BASE, fname)
        if not os.path.exists(path):
            print("missing", path)
            continue
        backup = path + ".orig"
        if not os.path.exists(backup):
            shutil.copyfile(path, backup)
            print("backed up ->", backup)
        img = Image.open(path)
        out = flood_remove(img)
        out.save(path)
        print("wrote", path, out.size, out.mode)
    print("done")


if __name__ == "__main__":
    main()
