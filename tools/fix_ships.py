"""Step 1: remove white/cream halo from .orig files (edge flood-fill).
   Step 2: center the content on the 1280x720 canvas so both ships are
   symmetric around the wreck centre. Keeps original aspect ratios."""
import os
from collections import deque
from PIL import Image

W, H = 1280, 720
CX, CY = W // 2, H // 2
BG_TOL = 40

def remove_halo(path_in, path_out):
    img = Image.open(path_in).convert("RGBA")
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w-1, 0], px[0, h-1], px[w-1, h-1]]
    bg = tuple(int(sum(ch[i] for ch in corners)/4.0) for i in range(3))
    
    def is_bg(r, g, b):
        return r >= bg[0]-BG_TOL and g >= bg[1]-BG_TOL and b >= bg[2]-BG_TOL and \
               r >= bg[0]-BG_TOL and g >= bg[1]-BG_TOL and b >= bg[2]-BG_TOL
    
    visited = [[False]*w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h-1):
            r,g,b,a = px[x,y]
            if a > 0 and is_bg(r,g,b):
                visited[y][x] = True; q.append((x,y))
    for y in range(h):
        for x in (0, w-1):
            r,g,b,a = px[x,y]
            if a > 0 and is_bg(r,g,b) and not visited[y][x]:
                visited[y][x] = True; q.append((x,y))
    while q:
        cx,cy = q.popleft()
        px[cx,cy] = (0,0,0,0)
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny = cx+dx, cy+dy
            if 0<=nx<w and 0<=ny<h and not visited[ny][nx]:
                r,g,b,a = px[nx,ny]
                if a>0 and is_bg(r,g,b):
                    visited[ny][nx]=True; q.append((nx,ny))
    
    # Center content on canvas
    bbox = img.getbbox()
    if not bbox:
        img.save(path_out)
        return
    content = img.crop(bbox)
    cw,ch = content.size
    out = Image.new("RGBA",(W,H),(0,0,0,0))
    offx = max(0, min(CX - cw//2, W-cw))
    offy = max(0, min(CY - ch//2, H-ch))
    out.paste(content,(offx,offy),content)
    out.save(path_out)
    print(f"{os.path.basename(path_out)}: halo removed, centered {cw}x{ch} at ({offx},{offy}), bbox={out.getbbox()}")

base = "SpritesImport/toborship"
for suffix in ["2026-09-16T20_03_12", "2026-09-16T20_04_32"]:
    src = os.path.join(base, f"ElevenLabs_image_gpt-image-2_make it like th_{suffix}.png.orig")
    dst = os.path.join(base, f"ElevenLabs_image_gpt-image-2_make it like th_{suffix}.png")
    remove_halo(src, dst)
print("DONE")
