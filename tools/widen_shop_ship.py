"""Scale the SHOP ship content up so it has a comparable visual width to the
CRASH ship, while staying within the 1280x720 canvas and centered. This makes
the two ships read as the same object in two states for the morph."""
import os
from PIL import Image

W, H = 1280, 720
CX, CY = W // 2, H // 2
shop = r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

img = Image.open(shop).convert("RGBA")
bbox = img.getbbox()
if not bbox:
    raise SystemExit("shop ship empty")
content = img.crop(bbox)
cw, ch = content.size
# Scale up to widen: target content width ~ crash ship's (1044). Keep aspect.
target_w = 1044
scale = target_w / cw
nw, nh = int(cw * scale), int(ch * scale)
# If it overflows vertically, clamp scale so it fits height too.
if nh > H:
    scale = H / ch
    nw, nh = int(cw * scale), int(ch * scale)
resized = content.resize((nw, nh), Image.LANCZOS)
out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
offx = max(0, min(CX - nw // 2, W - nw))
offy = max(0, min(CY - nh // 2, H - nh))
out.paste(resized, (offx, offy), resized)
out.save(shop)
nb = out.getbbox()
print(f"shop: content {cw}x{ch} -> {nw}x{nh} at ({offx},{offy}), bbox={nb}")
print("DONE")
