"""Normalize both ship PNGs so their content has the SAME WIDTH (horizontal
extent), keeping left/right edges aligned. Both keep transparent backgrounds.
The taller ship may extend above/below but the horizontal footprint matches,
so collision segments (defined in image-uv) still line up with the solid parts."""
import os
from PIL import Image

W, H = 1280, 720
crash = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
shop = r"SpritesImport/toborship/ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

# Target content width = crash ship's content width (the reference / wider one).
crash_img = Image.open(crash).convert("RGBA")
cb = crash_img.getbbox()
target_w = cb[2] - cb[0]
target_cx = (cb[0] + cb[2]) // 2   # keep crash ship's horizontal centre
print(f"crash content width={target_w}, centre x={target_cx}")

def fit_width(path, target_w, target_cx):
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox()
    if not bbox:
        print(f"{os.path.basename(path)}: empty"); return
    content = img.crop(bbox)
    cw, ch = content.size
    scale = target_w / cw
    nw, nh = int(cw * scale), int(ch * scale)
    resized = content.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    offx = target_cx - nw // 2
    offy = H // 2 - nh // 2   # vertically centre on the canvas
    offx = max(0, min(offx, W - nw))
    offy = max(0, min(offy, H - nh))
    out.paste(resized, (offx, offy), resized)
    out.save(path)
    nb = out.getbbox()
    print(f"{os.path.basename(path)}: {cw}x{ch} -> {nw}x{nh} at ({offx},{offy}), new bbox={nb}")

fit_width(crash, target_w, target_cx)
fit_width(shop, target_w, target_cx)
print("DONE")
