from PIL import Image
import sys

path = sys.argv[1]
im = Image.open(path).convert("RGB")
w, h = im.size
px = im.load()

# Focus on center region where creeps are
cx, cy = w // 2, h // 2
region_w, region_h = 400, 300

# Find reddish pixels in center region (where creeps are)
reds = []
for y in range(max(0, cy - region_h//2), min(h, cy + region_h//2)):
    for x in range(max(0, cx - region_w//2), min(w, cx + region_w//2)):
        r, g, b = px[x, y]
        # Look for pixels where red is notably higher than green and blue
        if r > 80 and r > g + 20 and r > b + 20:
            reds.append((x, y, r, g, b))

print(f"Center-region reddish pixels in {path}: {len(reds)}")
for x, y, r, g, b in reds[:40]:
    print(f"  ({x},{y}) = ({r},{g},{b})")

if not reds:
    print("No reddish pixels in center — eyes are likely not visible (too dim).")
    # Sample the actual color where a creep body should be
    print("\nSampling center pixel colors:")
    for dy in range(-50, 50, 10):
        for dx in range(-50, 50, 10):
            x, y = cx + dx, cy + dy
            r, g, b = px[x, y]
            if r > 15 or g > 15 or b > 15:  # non-background
                print(f"  ({x},{y}) = ({r},{g},{b})")
