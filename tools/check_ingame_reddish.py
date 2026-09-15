from PIL import Image
import sys

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # The creeps in the in-game shot are in the center region. Let's find
    # any pixel where red is notably higher than green (the night eye color).
    # Use a looser threshold to catch dimmed-but-red pixels.
    reddish = []
    center_x = w // 2
    center_y = h // 2
    # Scan center 300x300 region
    for y in range(center_y - 150, center_y + 150):
        for x in range(center_x - 150, center_x + 150):
            r, g, b = px[x, y]
            # Red channel > green + 15 (catches warm-red even when dimmed)
            if r > 50 and r > g + 15 and r > b + 5:
                reddish.append((x, y, r, g, b))
    print(f"\n=== {path.split('/')[-1]} ===")
    print(f"Center-region reddish pixels: {len(reddish)}")
    for p in reddish[:40]:
        print(f"  {p}")

for p in sys.argv[1:]:
    analyze(p)
