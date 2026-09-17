"""Rebuild the upgraded (shop) ship: crash body + a BIGGER radar antenna that is
well-integrated and uses DARKER metallic colors (no near-white pixels that would
read as 'white bg'). Regenerates the matching white silhouette too."""
import os
from PIL import Image, ImageDraw

W, H = 1280, 720
crash = r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_03_12.png"
shop = r"SpritesImport\toborship\ElevenLabs_image_gpt-image-2_make it like th_2026-09-16T20_04_32.png"

base = Image.open(crash).convert("RGBA")
out = base.copy()
draw = ImageDraw.Draw(out)

bbox = base.getbbox()
cx0, cy0, cx1, cy1 = bbox
body_top = cy0
body_cx = (cx0 + cx1) // 2

# Radar assembly mounted on top of the hull, centred. BIGGER than before and uses
# darker steel/teal tones so no pixel reads as white background.
radar_x = body_cx
dish_cy = body_top - 115          # higher so the dish is clearly above the hull
mast_bottom = body_top + 10

# Mast: a tapered pylon (two stacked rects, darker steel).
mast_w = 18
draw.rectangle([radar_x - mast_w//2, dish_cy - 10, radar_x + mast_w//2, mast_bottom],
               fill=(96, 118, 148, 255))
draw.rectangle([radar_x - 5, dish_cy - 10, radar_x + 5, mast_bottom],
               fill=(70, 92, 122, 255))
# cross braces
for by in range(dish_cy + 10, mast_bottom, 18):
    draw.line([(radar_x - mast_w//2, by), (radar_x + mast_w//2, by + 12)],
              fill=(120, 140, 168, 255), width=3)

# Dish: a larger elliptical satellite dish (dark teal face + steel rim).
dish_w = 130
dish_h = 80
draw.ellipse([radar_x - dish_w//2, dish_cy - dish_h//2 - 20,
              radar_x + dish_w//2, dish_cy + dish_h//2 - 20],
             fill=(52, 88, 132, 255), outline=(150, 172, 198, 255), width=4)
# inner concave shading (darker)
inset = 14
draw.ellipse([radar_x - dish_w//2 + inset, dish_cy - dish_h//2 - 20 + inset,
              radar_x + dish_w//2 - inset, dish_cy + dish_h//2 - 20 - inset],
             fill=(34, 62, 98, 255))
# feed horn (steel, not white) + a small amber sensor tip (amber, not white).
draw.line([(radar_x, dish_cy - 20), (radar_x, dish_cy - 44)], fill=(150, 172, 198, 255), width=4)
draw.ellipse([radar_x - 6, dish_cy - 56, radar_x + 6, dish_cy - 42], fill=(230, 150, 60, 255))

out.save(shop)

# White silhouette (matches the new shop art for the morph).
alpha = out.getchannel("A")
white = Image.new("RGBA", out.size, (255, 255, 255, 0))
white.putalpha(alpha)
white.save(shop.replace(".png", "_white.png"))

# Also ensure the crash ship's white silhouette is up to date (regenerate).
alpha_c = base.getchannel("A")
white_c = Image.new("RGBA", base.size, (255, 255, 255, 0))
white_c.putalpha(alpha_c)
white_c.save(crash.replace(".png", "_white.png"))

print("shop ship rebuilt: crash body + bigger darker radar")
print("crash bbox:", bbox)
print("shop bbox:", out.getbbox())
