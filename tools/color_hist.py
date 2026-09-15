from PIL import Image
import sys

path = sys.argv[1]
im = Image.open(path).convert("RGB")
w, h = im.size
px = im.load()
print(f"{path} ({w}x{h})")
# Find distinct colored regions — sample a grid and report unique-ish colors
from collections import Counter
colors = Counter()
for y in range(0, h, 4):
    for x in range(0, w, 4):
        r, g, b = px[x, y]
        # quantize
        key = (r//40*40, g//40*40, b//40*40)
        colors[key] += 1
for c, n in colors.most_common(20):
    print(f"  color~{c}: {n}")
