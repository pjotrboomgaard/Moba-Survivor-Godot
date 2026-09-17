from PIL import Image
import os

for f in [
    r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png",
    r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png",
]:
    img = Image.open(f).convert("RGBA")
    w, h = img.size
    corners = [img.getpixel((0,0)), img.getpixel((w-1,0)), img.getpixel((0,h-1)), img.getpixel((w-1,h-1))]
    print(f"  {os.path.basename(f)[:45]}: {w}x{h}")
    print(f"    corners={corners}")
    bbox = img.getbbox()
    print(f"    alpha bbox: {bbox}, content: {bbox[2]-bbox[0]}x{bbox[3]-bbox[1] if bbox else 'none'}")
    alphas = img.getchannel("A")
    hist = alphas.histogram()
    opaque = sum(hist[128:])
    print(f"    opaque pixels: {opaque}/{w*h} ({opaque/(w*h)*100:.1f}%)")
    print()
