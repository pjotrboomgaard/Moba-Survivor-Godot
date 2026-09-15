from PIL import Image
import sys

for p in sys.argv[1:]:
    im = Image.open(p).convert("RGB")
    w, h = im.size
    px = im.load()
    print(f"\n=== {p.split('/')[-1]} ({w}x{h}) ===")
    # Scan for reddish pixels in the central region where the grunt sits
    reds = []
    for y in range(300, 780):
        for x in range(760, 1160):
            r, g, b = px[x, y]
            if r > 120 and r > g * 1.5 and r > b * 1.5:
                reds.append((x, y, r, g, b))
    print(f"Reddish pixels in central region: {len(reds)}")
    for (x, y, r, g, b) in reds[:30]:
        print(f"  ({x},{y}) = ({r},{g},{b})")
