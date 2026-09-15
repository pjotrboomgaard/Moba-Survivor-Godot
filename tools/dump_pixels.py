from PIL import Image
import sys

names = sys.argv[1:]
for name in names:
    im = Image.open("assets/sprites/" + name).convert("RGBA")
    px = im.load()
    print(f"\n=== {name} ({im.width}x{im.height}) ===")
    for y in range(im.height):
        row = []
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                row.append('.')
            elif r > 150 and g < 90 and b < 90:
                row.append('R')
            elif r > 150 and g > 150 and b > 150:
                row.append('w')
            elif r < 80 and g < 80 and b < 80:
                row.append('k')
            else:
                row.append('o')
        print("%2d" % y, ''.join(row))
