from PIL import Image
import collections
import re
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
from autotrace_heroes import trace, rows_of, render, PALETTE

def despeckle(rows, min_neigh=2):
    S = len(rows)
    out = [r[:] for r in rows]
    for y in range(S):
        for x in range(S):
            if rows[y][x] == ".":
                continue
            n = 0
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    if dy==0 and dx==0: continue
                    ny,nx = y+dy, x+dx
                    if 0<=ny<S and 0<=nx<S and rows[ny][nx] != ".":
                        n += 1
            if n < min_neigh:
                out[y][x] = "."
    # fill fully-enclosed holes left by despeckle
    return out

VIEWS = {"front": "front_0.png", "left": "side_2.png", "back": "back_3.png"}

def trace_hero(hero):
	out = {}
	for facing, fname in VIEWS.items():
		path = Path(f"ref image/_debug/turnarounds/{hero}/{fname}")
		if not path.exists():
			continue
		img = Image.open(path)
		rows = despeckle(trace(img))
		out[facing] = rows
		render(rows).save(f"ref image/_debug/trace/{hero}_{facing}_smooth.png")
	# right = mirror of left
	if "left" in out:
		out["right"] = [row[::-1] for row in out["left"]]
	return out

def square(rows, size=40):
	strrows = [r if isinstance(r, str) else "".join(r) for r in rows]
	blank = "." * size
	out = [r.ljust(size, ".")[:size] for r in strrows]
	out = [blank] * ((size - len(out)) // 2) + out
	out += [blank] * (size - len(out))
	return out[:size]

if len(sys.argv) > 1 and sys.argv[1] == "emit":
	gd = Path("tools/sprite_art.gd").read_text(encoding="utf-8")
	for hero in ["arclight", "warden"]:
		views = trace_hero(hero)
		for facing, rows in views.items():
			key = hero if facing == "front" else f"{hero}_{facing}"
			rows = square(rows)
			lines = [f'\t"{key}": [']
			for row in rows:
				lines.append(f'\t\t"{row}",')
			lines.append("\t],\n")
			block = "\n".join(lines)
			pat = re.compile(r'\t"%s": \[\n(?:\t\t"[^"]*",\n)*\t\],\n' % re.escape(key))
			gd = pat.sub(lambda m: block, gd)
	Path("tools/sprite_art.gd").write_text(gd, encoding="utf-8")
	print("wrote traced grids (arclight+warden only; bulwark kept manual)")
else:
	for hero in ["arclight", "bulwark", "warden"]:
		views = trace_hero(hero)
		print(hero, {f: (len(r), len(r[0])) for f, r in views.items()})
