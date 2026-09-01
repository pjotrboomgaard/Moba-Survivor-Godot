import re
from pathlib import Path

gd = Path("tools/tobor_world_art.gd").read_text(encoding="utf-8")
pat = re.compile(r'\t"pyrelord": \[\n((?:\t\t"[^"]*",\n)*)\t\],\n')
m = pat.search(gd)
if not m:
	print("not found"); raise SystemExit
rows = [ln.split('"')[1] for ln in m.group(1).strip().split("\n")]
size = max(len(r) for r in rows), len(rows)
S = max(size)
blank = "." * S
norm = [r.ljust(S, ".") for r in rows]
norm = [blank] * ((S - len(norm)) // 2) + norm + [blank] * ((S - len(norm)))
block = '\t"pyrelord": [\n' + "\n".join('\t\t"%s",' % r for r in norm[:S]) + '\n\t],\n'
gd = gd[:m.start()] + block + gd[m.end():]
Path("tools/tobor_world_art.gd").write_text(gd, encoding="utf-8")
print("tw_pyrelord now", S, "square")
