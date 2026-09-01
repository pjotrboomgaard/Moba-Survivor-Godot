from PIL import Image
import collections
def ink_colours(path, n=14):
    im = Image.open(path).convert("RGB").copy()
    im.thumbnail((96, 96), Image.Resampling.LANCZOS)
    cnt = collections.Counter()
    for r, g, b in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()):
        if min(r, g, b) < 235:
            key = (r // 24 * 24, g // 24 * 24, b // 24 * 24)
            cnt[key] += 1
    return cnt.most_common(n)
for hero in ["arclight", "bulwark", "warden"]:
    p = f"ref image/_debug/turnarounds/{hero}/front_0.png"
    print(hero)
    for rgb, count in ink_colours(p):
        print("   ", "#%02x%02x%02x" % rgb, count)
