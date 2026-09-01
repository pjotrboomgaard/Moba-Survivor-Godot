"""Normalise all hero grids to perfect squares + report unknown palette keys."""
from __future__ import annotations

import re
import sys
from pathlib import Path

GD = Path("tools/sprite_art.gd")

# palettes we can statically resolve
PAL_KEY = re.compile(r'\t"\w+": (HERO_PALETTES|ROBOT_HERO_PALETTE),?')
ROBOT_KEYS = set(" wusmdnrtliyagGcbhoepqf".replace(" ", ""))

ENTRY = re.compile(r'\t"([a-z_0-9]+)": \[\n((?:\t\t"[^"]*",\n)*)\t\],\n')

def fix() -> int:
	src = GD.read_text(encoding="utf-8")
	fixed = 0

	def sub(m: re.Match) -> str:
		nonlocal fixed
		name = m.group(1)
		rows = [ln.split('"')[1] for ln in m.group(2).strip().split("\n")]
		h = len(rows)
		w = max(len(r) for r in rows)
		if w == h:
			return m.group(0)
		size = max(w, h)
		blank = "." * size
		norm = [r.ljust(size, ".") for r in rows]
		norm = [blank] * ((size - len(norm)) // 2) + norm
		norm += [blank] * (size - len(norm))
		block = '\t"%s": [\n%s\n\t],\n' % (name, "\n".join('\t\t"%s",' % r for r in norm))
		fixed += 1
		return block

	out = ENTRY.sub(sub, src)
	GD.write_text(out, encoding="utf-8")
	return fixed

if __name__ == "__main__":
	print("fixed", fix(), "grids")
