"""Measure crash-ship vs shop_combined content bboxes so the ship_wreck collision
segments and world placement line up. Also prints the crash-ship's bbox for
reference (the collision segments in ship_wreck.gd are tuned to it)."""
from PIL import Image

files = {
    "crash": r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
    "crash_white": r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12_white.png",
    "shop_combined": r"SpritesImport/toborship/shop_combined.png",
    "shop_combined_white": r"SpritesImport/toborship/shop_combined_white.png",
}
for name, p in files.items():
    img = Image.open(p).convert("RGBA")
    bbox = img.getbbox()
    print(f"{name}: size={img.size} bbox={bbox}")
    if bbox:
        x0, y0, x1, y1 = bbox
        print(f"   content: w={x1-x0} h={y1-y0} center=({(x0+x1)//2}, {(y0+y1)//2})")
