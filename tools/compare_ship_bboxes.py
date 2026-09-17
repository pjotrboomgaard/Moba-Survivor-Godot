"""Compare the content bounding boxes of crash vs rebuilt shop ships.
If they differ, the morph will look like 'ship disappears in one spot, new ship
appears in another' instead of a clean in-place morph."""
from PIL import Image

crash = r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
shop = r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

for name, path in [("CRASH", crash), ("SHOP(rebuilt)", shop)]:
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox()
    w, h = img.size
    print(f"{name}: canvas {w}x{h}, content bbox={bbox}")
    if bbox:
        print(f"   content size: {bbox[2]-bbox[0]}x{bbox[3]-bbox[1]}, center=({(bbox[0]+bbox[2])//2},{(bbox[1]+bbox[3])//2})")
    print()

# Also check the white silhouettes match their color counterparts
crash_w = crash.replace(".png", "_white.png")
shop_w = shop.replace(".png", "_white.png")
for name, path in [("CRASH_WHITE", crash_w), ("SHOP_WHITE", shop_w)]:
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox()
    print(f"{name}: content bbox={bbox}")
print("DONE")
