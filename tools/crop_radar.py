"""Inspect the exact minimap region and surrounding pixels in the unlocked-shop shot."""
from PIL import Image

src = r"tools\selftest\results\ship_wreck_ingame\ingame_unlocked_shop_8.608_12312.png"
img = Image.open(src)
w, h = img.size
print("full", w, h)
sx, sy = w / 1280.0, h / 720.0
# minimap: 1050-1260 x, 556-696 y
x0, y0 = int(1030 * sx), int(540 * sy)
x1, y1 = int(1280 * sx), int(720 * sy)
crop = img.crop((x0, y0, x1, y1))
crop.save(r"tools\selftest\results\ship_wreck_ingame\crop_minimap_exact.png")
# sample a vertical strip of pixels through the minimap center x=1155
cx = int(1155 * sx)
for ly in [550, 560, 580, 600, 620, 640, 660, 680, 700, 715]:
    py = int(ly * sy)
    if py < h:
        px = img.getpixel((cx, py))
        print(f"  y={ly:4d}: rgb={px}")
print("saved crop_minimap_exact.png", crop.size)
