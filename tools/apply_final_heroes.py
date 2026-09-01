"""Surgical hero-grid replacement: palette + traced warden/arclight + bulwark, on HEAD base."""
import re
from pathlib import Path

GD = Path("tools/sprite_art.gd")
GRID = 40

# --- brighter, reference-matched palette (probe-driven) ---
NEW_PALETTE = '''const ROBOT_HERO_PALETTE := {
	"w": "f4f6f8", "u": "e2e6ea", "s": "b8bec6", "m": "6e767f",
	"d": "232830", "n": "ff7828", "r": "e05a1c", "t": "ff4a2e",
	"l": "ffb294", "i": "ffc19a", "y": "f2ec3c", "a": "fcffd0",
	"k": "14171c", "g": "a8ff3c", "G": "36c432", "c": "795a30",
	"b": "3a2210", "h": "ffffff", "o": "10141a", "e": "ff9a28",
	"p": "4f8fe0", "q": "6d7680", "f": "f2e2b0",
}'''

def entry_block(key: str, rows: list[str]) -> str:
	return '\t"%s": [\n%s\n\t],\n' % (key, "\n".join('\t\t"%s",' % r for r in rows))

def square(rows: list[str], size: int = GRID) -> list[str]:
	blank = "." * size
	out = [r.ljust(size, ".")[:size] for r in rows]
	out = [blank] * ((size - len(out)) // 2) + out
	out += [blank] * (size - len(out))
	return out[:size]

def replace_entry(src: str, key: str, rows: list[str]) -> str:
	pat = re.compile(r'\t"%s": \[\n(?:\t\t"[^"]*",\n)*\t\],\n' % re.escape(key))
	new_block = entry_block(key, square(rows))
	out, n = pat.subn(lambda m: new_block, src)
	if n != 1:
		print("! %s replaced %d times" % (key, n))
	return out

def main() -> None:
	src = GD.read_text(encoding="utf-8")

	pat = re.compile(r'const ROBOT_HERO_PALETTE := \{[^}]+\}')
	src = pat.sub(lambda m: NEW_PALETTE, src)

	# traced despecked warden / arclight grids
	trace_dir = Path("ref image/_debug/trace")
	for hero in ["warden", "arclight"]:
		front_file = trace_dir / ("%s_front_smooth.png_rows.txt" % hero)
		# prefer a hand-tuned text version if present, else derive from trace txt
		txt = trace_dir / ("%s_front_trace.txt" % hero)
		if txt.exists():
			rows = txt.read_text(encoding="utf-8").splitlines()
			src = replace_entry(src, hero, rows)
		lt = trace_dir / ("%s_left_trace.txt" % hero)
		if lt.exists():
			src = replace_entry(src, hero + "_left", lt.read_text(encoding="utf-8").splitlines())

	# warden right = mirrored left
	left_file = trace_dir / "warden_left_trace.txt"
	if left_file.exists():
		left_rows = left_file.read_text(encoding="utf-8").splitlines()
		src = replace_entry(src, "warden_right", [r[::-1] for r in left_rows])

	# bulwark front: hand-aligned tall silhouette
	bulwark_front = [
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
	src = replace_entry(src, "bulwark", bulwark_front)

	# bulwark back: mirror of front's orange mass minus face detail
	bw_back = [r.replace("iiiii", "rrrrr").replace("iiii", "rrrr").replace("kkww", "rrww").replace("wwkk", "wwrr") for r in bulwark_front]
	src = replace_entry(src, "bulwark_back", bw_back)

	GD.write_text(src, encoding="utf-8")
	print("headings replaced")

if __name__ == "__main__":
	main()
