from PIL import Image
import sys

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    cx, cy = w // 2, h // 2
    # Sample a grid of points around center
    print(f"\n=== {path.split('/')[-1]} ===")
    reds = 0
    for y in range(cy - 30, cy + 30):
        for x in range(cx - 30, cx + 30):
            r, g, b = px[x, y]
            if r > 150 and g < 80 and b < 80:
                reds += 1
    print(f"Red pixels in center 60x60: {reds}")
    # Sample specific points
    for dy in range(-10, 10, 3):
        row = ""
        for dx in range(-10, 10, 2):
            x, y = cx + dx, cy + dy
            r, g, b = px[x, y]
            if r > 150 and g < 80 and b < 80:
                row += "R"
            elif r < 20 and g < 20 and b < 20:
                row += "."
            elif r > 150 and g > 150 and b > 150:
                row += "w"
            else:
                row += "o"
        print(row)
