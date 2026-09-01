import re
from pathlib import Path

gd = Path("tools/sprite_art.gd").read_text(encoding="utf-8")
# square every 24-tall non-hero grid the validator complained about (pyrelord)
def square_rows(rows, size=24):
	blank = "." * size
	out = [r.ljust(size, ".")[:size] for r in rows]
	out = [blank] * ((size - len(out)) // 2) + out
	out += [blank] * (size - len(out))
	return out[:size]

pat = re.compile(r'\t"pyrelord": \[\n((?:\t\t"[^"]*",\n)*)\t\],\n')
m = pat.search(gd)
if m:
	rows = [ln.split('"')[1] for ln in m.group(1).strip().split("\n")]
	new = "\t\"pyrelord\": [\n" + "\n".join('\t\t"%s",' % r for r in square_rows([r for r in rows if r.strip('.')])) + "\n\t],\n"
	gd = gd[:m.start()] + new + gd[m.end():]
	Path("tools/sprite_art.gd").write_text(gd, encoding="utf-8")
	print("padded pyrelord to 24x24")
else:
	print("pyrelord not found")
