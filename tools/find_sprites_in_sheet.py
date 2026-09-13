"""Find each sprite as a connected component in a source sheet.
For every sprite, print its exact bbox, area, and save it cut out with a small pad,
so we can identify which component is front/back/side/left by looking at the images."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "SpritesImport"
OUT = ROOT / "tools" / "selftest" / "results"
OUT.mkdir(parents=True, exist_ok=True)

def is_bg_px(px, x, y):
    r, g, b, _ = px[x, y]
    return abs(r - 255) + abs(g - 255) + abs(b - 255) <= 30

for name in sys.argv[1:]:
    im = Image.open(SRC / name).convert("RGBA")
    px = im.load()
    W, H = im.size
    visited = [[False] * W for _ in range(H)]
    comps = []
    for sy in range(H):
        for sx in range(W):
            if visited[sy][sx] or is_bg_px(px, sx, sy):
                continue
            q = deque([(sx, sy)])
            visited[sy][sx] = True
            xs = [sx]; ys = [sy]; n = 0
            while q:
                x, y = q.popleft()
                n += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and not visited[ny][nx] and not is_bg_px(px, nx, ny):
                        visited[ny][nx] = True
                        q.append((nx, ny))
                        xs.append(nx); ys.append(ny)
            if n < 300:
                continue
            comps.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1, n))
    comps.sort(key=lambda c: c[0])
    print(f"\n=== {name} ({W}x{H}) — {len(comps)} large components, sorted by x ===")
    for i, (x0, y0, x1, y1, n) in enumerate(comps):
        print(f"  comp[{i}] x=[{x0},{x1}) y=[{y0},{y1}) size={x1-x0}x{y1-y0} area={n} cx={ (x0+x1)//2}")
        pad = 4
        cut = im.crop((max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)))
        cut.save(OUT / f"{Path(name).stem}_comp{i}.png")
    # also a sheet of all comps side by side for visual inspection
    if comps:
        cw, chh = max(x1 - x0 for x0, y0, x1, y1, n in comps) + 8, max(y1 - y0 for x0, y0, x1, y1, n in comps) + 8
        sheet = Image.new("RGB", (cw * len(comps) + 10, chh + 30), (30, 30, 40))
        d = ImageDraw.Draw(sheet)
        for i, (x0, y0, x1, y1, n) in enumerate(comps):
            pad = 4
            cut = im.crop((max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)))
            cut = cut.convert("RGB")
            sheet.paste(cut, (5 + i * cw, 25))
            d.text((5 + i * cw, 8), f"comp{i} x{x0}-{x1}", fill=(255, 255, 0))
        sheet.save(OUT / f"{Path(name).stem}_components.png")
        print(f"  -> sheet saved: {Path(name).stem}_components.png")
