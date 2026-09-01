"""Wire the traced/despeckled/grid-clean warden and arclight rows into sprite_art.gd."""
import re
from pathlib import Path

GD = Path("tools/sprite_art.gd")
GRID = 40

def square(rows: list[str], size: int = GRID) -> list[str]:
	strrows = [r if isinstance(r, str) else "".join(r) for r in rows]
	out = [r.ljust(size, ".")[:size] for r in strrows]
	out = [("." * size)] * ((size - len(out)) // 2) + out
	out += [("." * size)] * (size - len(out))
	return out[:size]

def entry_block(key: str, rows: list[str]) -> str:
	return '\t"%s": [\n%s\n\t],\n' % (key, "\n".join('\t\t"%s",' % r for r in square(rows)))

def replace_entry(src: str, key: str, rows: list[str]) -> str:
	pat = re.compile(r'\t"%s": \[\n(?:\t\t"[^"]*",\n)*\t\],\n' % re.escape(key))
	out, n = pat.subn(lambda m: entry_block(key, rows), src)
	return out

def load_grid(hero: str, facing: str) -> list[str]:
	for name in [f"ref image/_debug/trace/{hero}/{hero}_{facing}_trace.txt"]:
		p = Path(name)
		if p.exists():
			return p.read_text(encoding="utf-8").splitlines()
	return []

def despeckle(rows: list[list[str]], min_neigh: int = 2) -> list[list[str]]:
	S = len(rows)
	out = [r[:] for r in rows]
	for y in range(S):
		for x in range(S):
			if rows[y][x] == ".":
				continue
			n = 0
			for dy in (-1, 0, 1):
				for dx in (-1, 0, 1):
					if dy == 0 and dx == 0:
						continue
					ny, nx = y + dy, x + dx
					if 0 <= ny < S and 0 <= nx < S and rows[ny][nx] != ".":
						n += 1
			if n < min_neigh:
				out[y][x] = "."
	return out

# fallback: use the smooth hand paint files saved by _trace_pipe (same trace, despeckled)
def load_txt_grid(hero: str, facing: str) -> list[str]:
	p = Path(f"ref image/_debug/trace/{hero}_{facing}_smooth.png_rows.txt")
	if p.exists():
		return p.read_text(encoding="utf-8").splitlines()
	p = Path(f"ref image/_debug/trace/{hero}/{hero}_{facing}_trace.txt")
	if p.exists():
		rows = [list(r) for r in p.read_text(encoding="utf-8").splitlines()]
		return ["".join(r) for r in despeckle(rows)]
	return []

def main() -> None:
	src = GD.read_text(encoding="utf-8")

	# Reference-matched palette
	NEW_PALETTE = (
		'const ROBOT_HERO_PALETTE := {\n'
		'\t"w": "f4f6f8", "u": "e2e6ea", "s": "b8bec6", "m": "6e767f",\n'
		'\t"d": "232830", "n": "ff7828", "r": "e05a1c", "t": "ff4a2e",\n'
		'\t"l": "ffb294", "i": "ffc19a", "y": "f2ec3c", "a": "fcffd0",\n'
		'\t"k": "14171c", "g": "a8ff3c", "G": "36c432", "c": "795a30",\n'
		'\t"b": "3a2210", "h": "ffffff", "o": "10141a", "e": "ff9a28",\n'
		'\t"p": "4f8fe0", "q": "6d7680", "f": "f2e2b0",\n'
		'}'
	)
	src = re.sub(r'const ROBOT_HERO_PALETTE := \{[^}]*\}', lambda m: NEW_PALETTE, src)

	# Warden: bright hover drone traced from turnaround; keep right = mirror of left
	warden_front = load_txt_grid("warden", "front")
	if warden_front:
		src = replace_entry(src, "warden", warden_front)
	warden_left = load_txt_grid("warden", "left")
	if warden_left:
		src = replace_entry(src, "warden_left", warden_left)
		# right facing = mirrored left
		src = replace_entry(src, "warden_right", [r[::-1] for r in warden_left])
	warden_back = load_txt_grid("warden", "back")
	if warden_back:
		src = replace_entry(src, "warden_back", warden_back)

	# Arclight: blood-orange staff-hex caster traced from turnaround
	arclight_front = load_txt_grid("arclight", "front")
	if arclight_front:
		src = replace_entry(src, "arclight", arclight_front)
	arclight_left = load_txt_grid("arclight", "left")
	if arclight_left:
		src = replace_entry(src, "arclight_left", arclight_left)
		src = replace_entry(src, "arclight_right", [r[::-1] for r in arclight_left])
	arclight_back = load_txt_grid("arclight", "back")
	if arclight_back:
		src = replace_entry(src, "arclight_back", arclight_back)

	GD.write_text(src, encoding="utf-8")
	print("wired warden + arclight traced grids")

if __name__ == "__main__":
	main()
