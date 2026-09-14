"""
Generate a distinctive drone projectile sprite (drone_spark).
Larger and more visible than the standard spark — a bright cyan/white
hexagonal energy bolt with a glow, so drone shots read clearly in the chaos.
"""
from PIL import Image
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

T = (0, 0, 0, 0)
# Cyan/ice palette for the drone bolt (distinct from the gold "spark")
C_GLOW    = (80, 200, 255, 60)    # outer glow
C_MID     = (150, 230, 255, 180)  # mid
C_BRIGHT  = (200, 250, 255, 230)  # bright core
C_WHITE   = (255, 255, 255, 255)  # white hot center

# 20x20 hexagonal bolt
W, H = 20, 20
pixels = [[T] * W for _ in range(H)]

# Hexagon shape (pointing right)
hex_points = [
    (10, 2), (14, 5), (16, 8), (16, 11), (14, 14), (10, 17),
    (6, 14), (4, 11), (4, 8), (6, 5),
]

def in_hex(x, y):
    # Simple bounding-box check with the hexagon as a filled polygon
    # Using a point-in-polygon test
    inside = False
    j = len(hex_points) - 1
    for i in range(len(hex_points)):
        xi, yi = hex_points[i]
        xj, yj = hex_points[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside

for y in range(H):
    for x in range(W):
        if not in_hex(x, y):
            continue
        # Distance from center for shading
        dx = x - 9.5
        dy = y - 9.5
        dist = (dx * dx + dy * dy) ** 0.5
        # Normalize: center is hot, edges are mid
        if dist < 2.5:
            pixels[y][x] = C_WHITE
        elif dist < 5.0:
            pixels[y][x] = C_BRIGHT
        elif dist < 7.5:
            pixels[y][x] = C_MID
        else:
            pixels[y][x] = C_GLOW

# Add a bright leading edge (front of the bolt, right side)
for y in range(4, 16):
    for x in range(13, 17):
        if in_hex(x, y):
            pixels[y][x] = C_WHITE

# Trailing glow (left side, fainter)
for y in range(5, 15):
    for x in range(3, 6):
        if in_hex(x, y):
            pixels[y][x] = C_GLOW

img = Image.new("RGBA", (W, H))
for y in range(H):
    for x in range(W):
        img.putpixel((x, y), pixels[y][x])

path = os.path.join(OUT_DIR, "drone_spark.png")
img.save(path)
print(f"Wrote {path}")
