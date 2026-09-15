from PIL import Image
import sys

def compare(path1, path2):
    im1 = Image.open(path1).convert("RGB")
    im2 = Image.open(path2).convert("RGB")
    w1, h1 = im1.size
    w2, h2 = im2.size
    p1 = im1.load()
    p2 = im2.load()
    
    # Find "content" in each (pixels that aren't the dark night background ~ (30,30,40))
    def content_bbox(px, w, h):
        minx, miny, maxx, maxy = w, h, 0, 0
        count = 0
        for y in range(0, h, 3):
            for x in range(0, w, 3):
                r, g, b = px[x, y]
                if r > 40 or g > 40 or b > 50:
                    minx = min(minx, x)
                    miny = min(miny, y)
                    maxx = max(maxx, x)
                    maxy = max(maxy, y)
                    count += 1
        return (minx, miny, maxx, maxy, count)
    
    bb1 = content_bbox(p1, w1, h1)
    bb2 = content_bbox(p2, w2, h2)
    print(f"\n{path1.split('/')[-1]}: bbox={bb1[:4]}, content_samples={bb1[4]}")
    print(f"{path2.split('/')[-1]}: bbox={bb2[:4]}, content_samples={bb2[4]}")
    
    # Now for each image, count bright-red pixels in the center region
    def red_count(px, w, h, cx, cy):
        cnt = 0
        for y in range(max(0,cy-200), min(h,cy+200)):
            for x in range(max(0,cx-200), min(w,cx+200)):
                r, g, b = px[x, y]
                if r > 100 and r > g + 30 and r > b + 30:
                    cnt += 1
        return cnt
    
    rc1 = red_count(p1, w1, h1, w1//2, h1//2)
    rc2 = red_count(p2, w2, h2, w2//2, h2//2)
    print(f"Red px in img1 center: {rc1}")
    print(f"Red px in img2 center: {rc2}")
    print(f"Difference (img2-img1): {rc2-rc1}")

if len(sys.argv) == 3:
    compare(sys.argv[1], sys.argv[2])
