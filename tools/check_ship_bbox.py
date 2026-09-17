"""Check the content bounding boxes of both ship PNGs to see if their widths
differ, and print the scale factor that would make them the same width."""
from PIL import Image

crash = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
shop = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

for name, path in [("CRASH", crash), ("SHOP", shop)]:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    bbox = img.getbbox()
    print(f"{name}: image {w}x{h}, content bbox={bbox}")
    if bbox:
        cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
        print(f"   content: {cw}x{ch}  ({cw/w*100:.1f}% wide, {ch/h*100:.1f}% tall)")
    print()
