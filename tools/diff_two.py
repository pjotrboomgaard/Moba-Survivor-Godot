from PIL import Image
import sys

day = Image.open("assets/sprites/grunt.png").convert("RGBA")
night = Image.open("assets/sprites/grunt_night.png").convert("RGBA")
dp = day.load()
np_ = night.load()
diff = 0
diffs = []
for y in range(day.height):
    for x in range(day.width):
        a = dp[x, y]
        b = np_[x, y]
        if a != b:
            diff += 1
            diffs.append((x, y, a, b))
print(f"grunt.png vs grunt_night.png: {diff} pixels differ")
for d in diffs[:20]:
    print(d)
