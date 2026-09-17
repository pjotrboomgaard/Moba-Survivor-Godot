"""Restore both ship PNGs from the .orig backups (halo-removed, original aspect),
then re-center each ship's content on the 1280x720 canvas centre (640, 360) so
both ships are horizontally symmetric around the wreck centre. Keeps original
proportions (collision segments stay valid in image-uv)."""
import os, shutil
from PIL import Image

W, H = 1280, 720
CX, CY = W // 2, H // 2
files = [
    r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
    r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png",
]
for path in files:
    shutil.copy2(path + ".orig", path)
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox()
    if not bbox:
        continue
    content = img.crop(bbox)
    cw, ch = content.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    offx = max(0, min(CX - cw // 2, W - cw))
    offy = max(0, min(CY - ch // 2, H - ch))
    out.paste(content, (offx, offy), content)
    out.save(path)
    print(f"{os.path.basename(path)}: centered {cw}x{ch} at ({offx},{offy})")
print("DONE")
