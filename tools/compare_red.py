from PIL import Image
import sys

day_path = sys.argv[1]
night_path = sys.argv[2]

day = Image.open(day_path).convert("RGB")
night = Image.open(night_path).convert("RGB")
dw, dh = day.size
nw, nh = night.size

dpx = day.load()
npx = night.load()

# Scan the whole image for pixels that are RED in night but NOT in day.
# Red = r notably greater than g and b.
red_in_night = []
red_in_day = []
for y in range(dh):
    for x in range(dw):
        r, g, b = npx[x, y]
        if r > 120 and r > g + 30 and r > b + 30:
            red_in_night.append((x, y, r, g, b))
        r2, g2, b2 = dpx[x, y]
        if r2 > 120 and r2 > g2 + 30 and r2 > b2 + 30:
            red_in_day.append((x, y, r2, g2, b2))

print(f"DAY red pixels: {len(red_in_day)}")
for p in red_in_day[:20]:
    print("  day", p)
print(f"NIGHT red pixels: {len(red_in_night)}")
for p in red_in_night[:30]:
    print("  night", p)
