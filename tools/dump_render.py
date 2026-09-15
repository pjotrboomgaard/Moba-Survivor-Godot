from PIL import Image
import sys

path = sys.argv[1]
im = Image.open(path).convert("RGB")
w, h = im.size
print(f"Image: {path} ({w}x{h})")

# Find the bounding box of non-background content
# Background is very dark (8,8,13)
px = im.load()
minx, miny, maxx, maxy = w, h, 0, 0
for y in range(h):
    for x in range(w):
        r, g, b = px[x, y]
        if r > 30 or g > 30 or b > 30:
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)

print(f"Content bbox: ({minx},{miny}) to ({maxx},{maxy})")
print(f"Content size: {maxx-minx+1}x{maxy-miny+1}")

# Now crop to content + 5px margin and print the pixel grid
margin = 5
cx0 = max(0, minx - margin)
cy0 = max(0, miny - margin)
cx1 = min(w, maxx + margin + 1)
cy1 = min(h, maxy + margin + 1)

crop = im.crop((cx0, cy0, cx1, cy1))
cpx = crop.load()
cw, ch = crop.size
print(f"\nPixel map ({cw}x{ch}):")
print("   " + "".join(str((cx0 + x) % 1000 // 100) for x in range(cw)))
for y in range(ch):
    row = []
    for x in range(cw):
        r, g, b = cpx[x, y]
        if r < 20 and g < 20 and b < 20:
            row.append('.')
        elif r > 150 and g < 80 and b < 80:
            row.append('R')
        elif r > 150 and g > 150 and b > 150:
            row.append('w')
        elif r < 80 and g < 80 and b < 80:
            row.append('k')
        else:
            row.append('o')
    print("%3d" % (cy0 + y), ''.join(row))
