import re
from pathlib import Path

gd = Path("tools/sprite_art.gd").read_text(encoding="utf-8")
pat = re.compile(r'\t"arclight": \[\n((?:\t\t"[^"]*",\n)*)\t\],\n')
m = pat.search(gd)
rows = [ln.split('"')[1] for ln in m.group(1).strip().split("\n")]
changed = 0
out_rows = []
for row in rows:
	new = row
	if "r" in new or "t" in new or "l" in new:
		# swap the hot highlights inside armour/face rows to a warmer blood-orange
		new = new.replace("t", "r").replace("l", "i")
		changed += sum(a != b for a, b in zip(row, new))
	out_rows.append(new)
block = '\t"arclight": [\n' + "\n".join('\t\t"%s",' % r for r in out_rows) + '\n\t],\n'
gd = gd[:m.start()] + block + gd[m.end():]
Path("tools/sprite_art.gd").write_text(gd, encoding="utf-8")
print("arclight warmth swaps:", changed)
