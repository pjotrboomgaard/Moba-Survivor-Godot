from PIL import Image
import sys

path = sys.argv[1]
im = Image.open(path).convert("RGB")
px = im.load()
w, h = im.size
cx, cy = w // 2, h // 2

# Dump a 40x40 region centered on the enemy with full RGB
print(f"{path.split('/')[-1]} ({w}x{h}), center=({cx},{cy})")
print("Sampling 40x40 region around center:")
for y in range(cy - 20, cy + 20):
    row = ""
    for x in range(cx - 20, cx + 20):
        r, g, b = px[x, y]
        # Map to chars: red high, green high, blue high, or dark
        if r < 15 and g < 15 and b < 15:
            row += "."
        elif r > 150 and g < 80 and b < 80:
            row += "R"
        elif r > 150 and g > 150 and b > 150:
            row += "W"
        elif r > 100:
            row += "r"  # somewhat red
        else:
            row += "o"
    print("%3d %s" % (y, row))

# Now print raw values for a small 10x10 around where eyes should be
print("\nRaw RGB around center-top (eye region):")
for y in range(cy - 15, cy + 5):
    vals = []
    for x in range(cx - 10, cx + 10):
        r, g, b = px[x, y]
        vals.append(f"({r:3d},{g:3d},{b:3d})")
    print("%3d: %s" % (y, " ".join(vals)))
