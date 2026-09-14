"""
Generate pixel-art projectile sprites: frost_shard and scrap_bolt.
Style: small (~16x16) pixel-art with bright core + glow, matching spark/bolt/spit.
"""
from PIL import Image
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

def save(name, pixels, width, height):
    img = Image.new("RGBA", (width, height))
    for y in range(height):
        for x in range(width):
            img.putpixel((x, y), pixels[y * width + x])
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path)
    print(f"Wrote {path}")

# --- frost_shard: 16x16 ice crystal shard ---
# Palette: transparent, dark ice, mid ice, bright ice, white core
T = (0, 0, 0, 0)
D = (90, 180, 255, 255)    # dark ice blue
M = (140, 220, 255, 255)   # mid ice
L = (200, 245, 255, 255)   # light ice
W = (255, 255, 255, 255)   # white core

frost = [
    # 16x16 grid, diamond/crystal shape pointing right
    T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T, D, D, T, T, T, T, T, T,
    T, T, T, T, T, T, T, D, M, M, D, T, T, T, T, T,
    T, T, T, T, T, T, D, M, M, W, M, D, T, T, T, T,
    T, T, T, T, T, D, M, M, W, W, M, M, D, T, T, T,
    T, T, T, T, D, M, M, W, W, W, W, M, M, D, T, T,
    T, T, T, D, M, M, W, W, W, W, W, W, M, M, D, T,
    T, T, T, D, M, M, W, W, W, W, W, W, M, M, D, T,
    T, T, T, T, D, M, M, W, W, W, W, M, M, D, T, T,
    T, T, T, T, T, D, M, M, W, W, M, M, D, T, T, T,
    T, T, T, T, T, T, D, M, M, M, D, T, T, T, T, T,
    T, T, T, T, T, T, T, T, D, M, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T,
]
save("frost_shard", frost, 16, 16)

# --- scrap_bolt: 16x16 metallic bolt ---
# Palette: transparent, dark metal, mid metal, bright metal, white core
T2 = (0, 0, 0, 0)
DM = (80, 80, 90, 255)     # dark metal
MM = (160, 165, 175, 255)  # mid metal
LM = (220, 225, 235, 255)  # light metal
WM = (255, 255, 255, 255)  # white core

scrap = [
    T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, DM, DM, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, DM, MM, MM, DM, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, DM, MM, MM, LM, MM, DM, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, DM, MM, MM, LM, LM, MM, MM, DM, T2, T2, T2,
    T2, T2, T2, T2, DM, MM, MM, LM, LM, LM, LM, MM, MM, DM, T2, T2,
    T2, T2, T2, DM, MM, MM, LM, LM, LM, LM, LM, LM, MM, MM, DM, T2,
    T2, T2, T2, DM, MM, MM, LM, LM, LM, LM, LM, LM, MM, MM, DM, T2,
    T2, T2, T2, T2, DM, MM, MM, LM, LM, LM, LM, MM, MM, DM, T2, T2,
    T2, T2, T2, T2, T2, DM, MM, MM, LM, LM, MM, MM, DM, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, DM, MM, MM, MM, DM, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, DM, MM, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2,
    T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2, T2,
]
save("scrap_bolt", scrap, 16, 16)
