"""
Generate pixel-art fire-tree flame frames + dead tree stump sprite.
3 flicker frames (fire_frame_0/1/2) that cycle on a burning tree,
plus a charred dead-tree stump (dead_tree_stump).

Style: ~24x32 pixel-art, layered flames with a hot core, matching the
game's pixel-art density (nearest-neighbor, chunky pixels).
"""
from PIL import Image
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

T = (0, 0, 0, 0)          # transparent
# Fire palette: dark ember -> mid orange -> bright yellow -> white core
C_EMBER   = (120, 30, 10, 255)    # deep ember / charred
C_DARK    = (200, 60, 10, 240)    # dark orange
C_MID     = (255, 110, 20, 235)   # mid orange
C_BRIGHT  = (255, 190, 50, 230)   # bright yellow
C_HOT     = (255, 240, 150, 220)  # hot yellow-white
C_WHITE   = (255, 255, 220, 210)  # white core
# Trunk (charred wood showing through flames)
C_TRUNK   = (45, 28, 15, 255)
C_TRUNK_D = (28, 16, 8, 255)

def make_frame(seed_offset):
    """Build a 24x32 flame frame. The flame wiggles based on seed_offset."""
    W, H = 24, 32
    pixels = [T] * (W * H)
    import math
    # Flame is in the upper portion; trunk occupies the lower ~12 rows.
    # Flame base at y=20, tip at y=2.
    for y in range(H):
        for x in range(W):
            idx = y * W + x
            if y >= 20:
                # Trunk (charred, 8px wide centered)
                if 8 <= x <= 15:
                    shade = C_TRUNK if (x + y) % 3 != 0 else C_TRUNK_D
                    pixels[idx] = shade
                continue
            # Flame region y 2..19
            # Flame width narrows toward the tip (y=2).
            cx = 12.0
            dist_to_tip = (20 - y)  # 0 at base, 18 at tip
            # Base width 12, shrinking to 2 at tip, with flicker wiggle
            flicker = math.sin((y * 0.7 + seed_offset * 1.3) * 0.6) * 1.8
            half_w = max(1.0, (6.0 - dist_to_tip * 0.28) + flicker)
            if abs(x - cx) <= half_w:
                # Color by height: tip = hot white, mid = bright, base = dark
                frac = dist_to_tip / 20.0  # 0 tip, 1 base
                if frac < 0.22:
                    col = C_WHITE
                elif frac < 0.45:
                    col = C_HOT
                elif frac < 0.72:
                    col = C_BRIGHT
                else:
                    col = C_DARK
                # Inner hot core: near center is brighter
                if abs(x - cx) <= half_w * 0.45 and frac < 0.55:
                    col = C_WHITE if frac < 0.25 else C_HOT
                # Skip some pixels for pixel-art texture (random holes)
                if (x * 7 + y * 13 + seed_offset * 5) % 11 == 0:
                    pixels[idx] = C_EMBER
                else:
                    pixels[idx] = col
    return pixels, W, H

def save(name, pixels, w, h):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            img.putpixel((x, y), pixels[y * w + x])
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path)
    print(f"Wrote {path}")

# 3 flicker frames
for i in range(3):
    pixels, w, h = make_frame(i)
    save(f"fire_frame_{i}", pixels, w, h)

# --- dead tree stump: 20x24 charred trunk stub ---
def make_stump():
    W, H = 20, 24
    pixels = [T] * (W * H)
    # Ground char patch
    for y in range(H - 3, H):
        for x in range(W):
            if (x - W // 2) ** 2 + (y - H) ** 2 * 4 < 100:
                pixels[y * W + x] = (20, 14, 8, 150)
    # Trunk: charred, broken, ~8px wide, y 4..21
    for y in range(4, 22):
        for x in range(6, 14):
            # Tapered top (broken)
            if y < 8 and not (7 <= x <= 12):
                continue
            if (x + y) % 4 == 0:
                pixels[y * W + x] = C_TRUNK_D
            else:
                pixels[y * W + x] = C_TRUNK
    # Broken branch stubs
    for y in range(8, 13):
        pixels[y * W + 3] = C_TRUNK
        pixels[y * W + 4] = C_TRUNK_D
    for y in range(10, 14):
        pixels[y * W + 15] = C_TRUNK
        pixels[y * W + 16] = C_TRUNK_D
    # Lingering ember glow at the base
    for y in range(19, 22):
        for x in range(8, 12):
            pixels[y * W + x] = (120, 50, 15, 90)
    return pixels, W, H

pixels, w, h = make_stump()
save("dead_tree_stump", pixels, w, h)

print("Done generating fire-tree pixel art.")
