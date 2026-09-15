from PIL import Image
import sys

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    print(f"\n=== {path.split('/')[-1]} ({w}x{h}) ===")
    # Look for any pixel where R is significantly greater than G and B
    reddish = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 60 and r > g * 1.5 and r > b * 1.5 and r > 80:
                reddish.append((x, y, r, g, b))
    print(f"Reddish pixels: {len(reddish)}")
    for p in reddish[:20]:
        print(f"  {p}")
