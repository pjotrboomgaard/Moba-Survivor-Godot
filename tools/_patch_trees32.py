"""Patch 32x32 trees into tobor_world_art.gd."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
out = (root / "tools" / "_trees32_out.txt").read_text(encoding="utf-8")
art = root / "tools" / "tobor_world_art.gd"
text = art.read_text(encoding="utf-8")

# Parse named blocks from generator output.
blocks = {}
current = None
rows = []
for line in out.splitlines():
	if line.startswith("const ") or line.startswith("---"):
		if current and rows:
			blocks[current] = rows
		current = None
		rows = []
		if line.startswith("---") and line.endswith("---"):
			current = line.strip("-").strip().lower()
		continue
	m = re.match(r'\t"([^"]+)": \[', line)
	if m:
		if current and rows:
			blocks[current] = rows
		current = m.group(1)
		rows = []
		continue
	if line.strip() == "],":
		if current:
			blocks[current] = rows
			current = None
			rows = []
		continue
	if line.startswith('\t\t"') and current:
		rows.append(line)

def block_src(name: str) -> str:
	body = "\n".join(blocks[name])
	return f'\t"{name}": [\n{body}\n\t],'

for name in [
	"tree_oak", "tree_pine", "tree_dead", "tree_pipe", "tree_piling",
	"tree_willow", "tree_round", "tree_fir", "tree_palm", "tree_cypress", "tree_maple",
]:
	pat = rf'\t"{name}": \[\n(?:\t\t".*",\n)+ \t\],'
	# less strict
	pat = rf'\t"{name}": \[\n(?:\t\t"[^"]*",\n)+\t\],'
	new = block_src(name)
	n = len(re.findall(pat, text))
	if n != 1:
		raise SystemExit(f"{name} matches {n}")
	text = re.sub(pat, new.replace("\\", "\\\\"), text, count=1)

def const_block(const_name: str, key: str) -> None:
	global text
	pat = rf'const {const_name} := \[\n(?:\t"[^"]*",\n)+\]'
	body = "\n".join("\t" + line.strip() if not line.startswith("\t\t") else line.replace("\t\t", "\t", 1) for line in blocks[key])
	# generator rows are \t\t"...."
	rows = []
	for line in blocks[key]:
		rows.append("\t" + line.strip())
	new = f'const {const_name} := [\n' + "\n".join(rows) + "\n]"
	n = len(re.findall(pat, text))
	if n != 1:
		raise SystemExit(f"{const_name} matches {n}")
	text = re.sub(pat, new.replace("\\", "\\\\"), text, count=1)

const_block("_VOLCANO_TREE", "volcano")
const_block("_ICE_TREE", "ice")
const_block("_FACTORY_TREE", "factory")
const_block("_DOCKS_TREE", "docks")

art.write_text(text, encoding="utf-8")
print("patched", art)
print("keys", sorted(blocks))
