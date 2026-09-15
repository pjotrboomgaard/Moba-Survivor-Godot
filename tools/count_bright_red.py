from PIL import Image
import sys

def count_red(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Bright-red pixels
    bright = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            if r > 200 and g < 90 and b < 90:
                bright += 1
    return bright, w, h

for path in sys.argv[1:]:
    n, w, h = count_red(path)
    print(f"{path}: {n} bright-red px  ({w}x{h})")
