"""Generate white-silhouette versions of both ship sprites (all opaque pixels
turned white, alpha preserved). Used by the ship morph to create a
color -> white silhouette -> color transition."""
import os
from PIL import Image

W, H = 1280, 720
files = {
    "crash": r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
    "shop": r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png",
}
for name, path in files.items():
    img = Image.open(path).convert("RGBA")
    alpha = img.getchannel("A")
    white = Image.new("RGBA", img.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    out = path.replace(".png", "_white.png")
    white.save(out)
    print(f"{name}: {os.path.basename(out)}, alpha bbox={alpha.getbbox()}")
print("DONE")
