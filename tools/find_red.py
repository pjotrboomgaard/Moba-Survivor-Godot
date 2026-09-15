from PIL import Image
import sys

path = sys.argv[1]
im = Image.open(path).convert("RGB")
w, h = im.size
print(f"Image: {path} ({w}x{h})")

px = im.load()
# Find all red-ish pixels (eyes)
red_pixels = []
for y in range(h):
    for x in range(w):
        r, g, b = px[x, y]
        if r > 150 and g < 80 and b < 80:
            red_pixels.append((x, y, r, g, b))

if red_pixels:
    print(f"Found {len(red_pixels)} red-ish pixels:")
    for x, y, r, g, b in red_pixels[:30]:
        print(f"  ({x},{y}) = ({r},{g},{b})")
else:
    print("No red-ish pixels found (r>150, g<80, b<80)")
    # Try a wider threshold
    red_pixels2 = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 100 and r > g * 2 and r > b * 2:
                red_pixels2.append((x, y, r, g, b))
    if red_pixels2:
        print(f"Found {len(red_pixels2)} warmer-red pixels (looser threshold):")
        for x, y, r, g, b in red_pixels2[:30]:
            print(f"  ({x},{y}) = ({r},{g},{b})")
    else:
        print("No red pixels at all — the night ambient is likely dimming them too much.")
        # Sample some pixels where the creeps should be
        print("\nSample pixels near center:")
        for dy in range(-100, 100, 20):
            for dx in range(-100, 100, 20):
                x, y = w//2 + dx, h//2 + dy
                r, g, b = px[x, y]
                print(f"  ({x},{y}) = ({r},{g},{b})")
