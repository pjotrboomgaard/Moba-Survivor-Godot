"""One-shot tidy: arclight warm-orange tint, bulwark speck sweep, re-verify."""
import re
from pathlib import Path

gd = Path("tools/sprite_art.gd").read_text(encoding="utf-8")

# 1) arclight: shift the hot-red 't' body accent to blood-orange 'r'
for key in ["arclight", "arclight_left", "arclight_back", "arclight_right"]:
	pat = re.compile(r'\t"%s": \[\n(?:\t\t"[^"]*",\n)*\t\],\n' % re.escape(key))
	m = pat.search(gd)
	if not m:
		print("missing", key); continue
	block = m.group(0)
	# change t -> r only inside body rows (not the staff tip 'e'..)
	lines = block.split("\n")
	changed = 0
	for i, ln in enumerate(lines):
		if '"' not in ln:
			continue
		row = ln.split('"')[1]
		# body area rows: those that contain 'n' (armour) or 'w' (face)
		if "n" in row or "w" in row:
			new_row = row.replace("t", "r")
			if new_row != row:
				changed += row.count("t")
				lines[i] = ln.replace(row, new_row)
	gd = gd.replace(block, "\n".join(lines))
	print("arclight", key, "t->r", changed)
Path("tools/sprite_art.gd").write_text(gd, encoding="utf-8")
