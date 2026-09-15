from PIL import Image
import sys

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Find "red-ish" pixels: red channel notably higher than green/blue
    reds = []
    # Also track the region where the player/creeps are (center-ish)
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            # Bright red
            if r > 120 and r > g * 1.4 and r > b * 1.4:
                reds.append((x, y, r, g, b))
    print(f"\n=== {path.split('/')[-1]} ({w}x{h}) ===")
    print(f"Red-ish pixels (r>120, r>1.4g, r>1.4b): {len(reds)}")
    for p in reds[:30]:
        print(f"  {p}")

for p in sys.argv[1:]:
    analyze(p)
