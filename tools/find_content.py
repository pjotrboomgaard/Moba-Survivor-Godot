from PIL import Image
import sys

for path in sys.argv[1:]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Find bounding box of all non-background pixels
    # Background is very dark (<20, <20, <25)
    minx, miny, maxx, maxy = w, h, 0, 0
    count = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 25 or g > 25 or b > 30:
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
                count += 1
    print(f"\n=== {path.split('/')[-1]} ===")
    print(f"Content bbox: ({minx},{miny})-({maxx},{maxy}), {count} non-bg px")
    if count > 0:
        # Now find red pixels in that bbox
        reds = 0
        red_locs = []
        for y in range(miny, maxy+1):
            for x in range(minx, maxx+1):
                r, g, b = px[x, y]
                if r > 150 and g < 80 and b < 80:
                    reds += 1
                    if len(red_locs) < 10:
                        red_locs.append((x, y, r, g, b))
        print(f"Red pixels in content bbox: {reds}")
        for loc in red_locs:
            print(f"  {loc}")
