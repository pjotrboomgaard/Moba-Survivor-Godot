"""Generate a small 96x96 beacon icon (glowing signal tower) as a transparent PNG."""
import os
from PIL import Image, ImageDraw

SIZE = 128
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
cx = SIZE // 2

# Glow circle
d.ellipse([cx - 40, cx - 40, cx + 40, cx + 40], fill=(40, 160, 220, 60))
d.ellipse([cx - 30, cx - 30, cx + 30, cx + 30], fill=(70, 200, 255, 90))

# Tower (a small triangle/mast)
d.polygon([(cx, cx - 24), (cx - 10, cx + 28), (cx + 10, cx + 28)], fill=(200, 230, 255, 240))
d.rectangle([cx - 14, cx + 28, cx + 14, cx + 34], fill=(150, 200, 240, 240))

# Signal arcs
for r, a in ((20, 200), (30, 160), (40, 120)):
    d.arc([cx - r, cx - 50 - r + 10, cx + r, cx - 50 + r + 10], start=210, end=330,
          fill=(180, 240, 255, a), width=4)

out = r"SpritesImport/icons/beacon.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print("wrote", out)
