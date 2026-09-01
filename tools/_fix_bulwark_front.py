import re
from pathlib import Path

gd = Path("tools/sprite_art.gd").read_text(encoding="utf-8")

GRID = [
	".............tttttttttttt...............",
	"............ttlltttttttttt..............",
	"...........ttttllttttttttt..............",
	"..........ttttrrrrtttttttt..............",
	".........sssrrrrrrrrmmss...............",
	"........srrwwwwwwwwwwrrrss.............",
	".......nrrwwwwwwwwwwwwrrsn............",
	"......nnrwwwwwwwwwwwwwwrnnn..nwww......",
	"......nrwwkkwwwwwwwkkwwrnwnwwwwwww.....",
	"......nrwwkkwwiiiiwwkkwwnwwwwwwmmww....",
	"......nrrwwwwiiiiiwwwwrrnnwwmmmwwww....",
	"....cnnrrrwwwwwwwwwwrrrrrnnnnnwwwww....",
	"....cnnrrrrrrrrrrrrrrnrrnnnnnnnww.....",
	"....cnnrrrrrrrrrrrrrrrrrnnnnnnnnnn.....",
	"....cnnnrrrrrrrrrrrrrnnnnnnnnnnnnn.....",
	"......nnnrrrrrrrrrrrrrrnnnnnnnnnnn.....",
	".....nnnnrrrrrrrrrrrrrrrnnnnnnnnnn.....",
	".....nnnnnrrrrrrrrrrrrrnnnnnnnnnnn.....",
	".....ssnnnnnnrrrrrrrnnnnnnnnnnssss.....",
	".....mmnnnnnnnnnnnnnnnnnnnnnnnmmmmm....",
	".....cccnnnnnnnnnnnnnnnnnnncccccc......",
	".....ccccc..............................",
	".....bbbbb..............................",
	".....bbbbb..............................",
	".....kkkkk..............................",
]

pad = ["." * 40 for _ in range(40 - len(GRID))]
rows = pad + [r.ljust(40, ".")[:40] for r in GRID]
assert all(len(r) == 40 for r in rows) and len(rows) == 40

pat = re.compile(r'\t"bulwark": \[\n(?:\t\t"[^"]*",\n)*\t\],\n')
block = '\t"bulwark": [\n' + "\n".join('\t\t"%s",' % r for r in rows) + "\n\t],\n"
gd2, n = pat.subn(lambda m: block, gd)
print("bulwark front replaced:", n)
Path("tools/sprite_art.gd").write_text(gd2, encoding="utf-8")
