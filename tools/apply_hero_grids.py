"""Write hand-authored hero grids into tools/sprite_art.gd.

Run:  python tools/apply_hero_grids.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GD = ROOT / "tools" / "sprite_art.gd"

GRIDS = {
	"warden": [
		"...............b....................",
		"..............bbb...................",
		".............bbkbb..................",
		".............bhyhb..................",
		".............bkukb..................",
		".............bbbbb..................",
		"..............bbb...................",
		"..........kk.....kk.................",
		".........wkww...kwkw................",
		"........wwwkwkwkwkwww...............",
		".......wwwkwkkkwkwkwww..............",
		"......nhwwkkkkkkkkkwwhn.............",
		"......nnwwwkwkkwkwwwnn..............",
		".......nnwwwwwwwwwnn................",
		"........nkkkkkkkkkn.................",
		"........nnnnnnnnnnn.................",
		".........nnnnnnnnn..................",
		"..........nnnnnnn...................",
		"...........nnnnn....................",
		"..........ggggggg...................",
		".........ggaaggaag..................",
		".........gaaaaaaag..................",
		".........ggaaggagg..................",
		"..........ggggggg...................",
		"...........ggggg....................",
		"............ggg.....................",
	],
	"warden_left": [
		"...............b....................",
		"..............bbb...................",
		".............bbkbb..................",
		".............bhyhb..................",
		".............bkukb..................",
		".............bbbbb..................",
		"..............bbb...................",
		"..........kk........................",
		".........wkww.......................",
		"........wkkwkwkw....................",
		".......wkwkkkwkww...................",
		"......nhwkkkkkkwn...................",
		"......nnkwkkwkwnn...................",
		".......nwwwwwwnn....................",
		"........nkkkkkn.....................",
		"........nnnnnnn.....................",
		".........nnnnn......................",
		"..........nnn.......................",
		"...........n........................",
		"..........ggggg.....................",
		".........ggaaggg....................",
		".........gaaaagg....................",
		".........ggagggg....................",
		"..........ggggg.....................",
		"...........ggg......................",
		"............g.......................",
	],
	"warden_back": [
		"...............b....................",
		"..............bbb...................",
		".............bbkbb..................",
		".............bkukb..................",
		".............bbbbb..................",
		"..............bbb...................",
		"..........kk.....kk.................",
		".........wkw.....wkw................",
		"........wwwkwkwkwkwww...............",
		".......wkwkkkkkkkwkw...............",
		"......nhkkkkkkkkkkkhn..............",
		"......nnkkkkkkkkkknn...............",
		".......nnnkkkkknnn..................",
		"........nnnnnnnnn...................",
		"........nnnnnnnnn...................",
		".........nnnnnnn....................",
		"..........nnnnn.....................",
		"...........nnn......................",
		"..........ggggggg...................",
		".........gkaagkakg..................",
		".........gaaaaaaag..................",
		".........ggaaggagg..................",
		"..........ggggggg...................",
		"...........ggggg....................",
		"............ggg.....................",
	],
	"arclight": [
		".....e..............................",
		"....eye........tttt.................",
		"...eynye......tltttttt..............",
		"....eye......tllttttttt.............",
		".....n.......ttttlttttt.............",
		".....s......ssuuushmmmmm............",
		"....sus.....suuuusmmmmmm............",
		"....s.s....ssuuussmmmmmmm...........",
		"....s.....wwwhhwwwwwsssmm...........",
		"....s....wwuwwwwwwwwussnm..........",
		"....s..nnwwkkwwwwwwkkssnnn..........",
		"....s.nnwwwkkwwwwwwkksssnn..........",
		"....s.nnwwwwwwiiiiwwwwssnn..........",
		"....s..nnwwuwwwwwwwwussnn...........",
		"....s..nnwww..yyyy..wssnn...........",
		"....s...nnww.yaaaay.wwsn............",
		"....s...nnwwyyyyyyyywn..............",
		"....s....nnnwwwyywwwsn..............",
		"....s.....nnnnrrrrnnnn..............",
		"....s......snnnnnnnns...............",
		"...........mdnn...nndm..............",
		"...........cccc...cccc..............",
		"...........cccc...cccc..............",
		"...........bcbb...bbcb..............",
		"...........kkkk...kkkk..............",
	],
	"arclight_left": [
		".....e..............................",
		"....eye.............................",
		"...eynye....tttttt..................",
		"....eye...tlttttttt.................",
		".....n...ttttltttttt................",
		".....s..ssuuushmmmm.................",
		"....sus.suuuusmmmmmm................",
		"....s..ssuuussmmmmmmm...............",
		"....s..wwwhhwwwwsssmm...............",
		"....s.wwuwwwwwwwussnm...............",
		"....snwwkkwwwwwkkssnn...............",
		"....snwwwkkwwwwkkssnn...............",
		"....snwwwwwiiiiwwwsnn...............",
		"....s.nwwuwwwwwwusnn................",
		"....s.nwww.yyyy.wsn..................",
		"....s.nwwwyaaaaywn...................",
		"....s..nwyyyyyyyn....................",
		"....s..nnwwyywwn.....................",
		"....s...nnrrrrnn.....................",
		"....s....snnnnns.....................",
		"........mdnn.nndm....................",
		"........cccc.cccc....................",
		"........cccc.cccc....................",
		"........bcbb.bbcb....................",
		"........kkkk.kkkk....................",
	],
	"arclight_back": [
		".....e..............................",
		"....eye.............................",
		"...eynye......tttt..................",
		"....eye......tltttttt...............",
		".....n......tllttttttt..............",
		".....s....ssuuushmmmmmm.............",
		"....sus...suuuusmmmmmmmm............",
		"....s....ssuuussmmmmmmmmm...........",
		"....s...wwwhhwwwwwsssmmmm...........",
		"....s..wwuwwwwwwwwussnnmm...........",
		"....snwwkkwwwwwwkksssnnn............",
		"....snwwwkkwwwwwkksssnnn............",
		"....snwwwwwwwwwwwwwssnnn............",
		"....s.nwwuwwwwwwwwussnn.............",
		"....s.nwwwssssssswwsnnn.............",
		"....s..nnwwwwwwwwwwsn...............",
		"....s..nnwwwwwwwwwwn................",
		"....s...nnnwwwwwwsn.................",
		"....s....nnnrrrrnnn.................",
		"....s.....snnnnnns..................",
		".........mdnn...nndm.................",
		".........cccc...cccc.................",
		".........cccc...cccc.................",
		".........bcbb...bbcb.................",
		".........kkkk...kkkk.................",
	],
	"bulwark": [
		".............tttttt.................",
		"............tltttttt................",
		"...........ttlltttttt...............",
		"..........tttttttttttt..............",
		".........ssuuuushmmmmmmm............",
		"........sswwhhhhwwwsssmm............",
		".......nwwuwwwwwwwwwuwnm............",
		"......nnwwwkkwwwwwkkwwwnn...nwww....",
		"......nwwwkkkwwwwwkkkwwwn..wwwwww...",
		"......nwwwwwwiiiiiwwwwwnn.wwmmmmww..",
		".....nnwwwwuwwwwwwwuwwwnnnwwmmmmww..",
		".....nnnnnnnnnnnnnnnnnnnnnwwwmmww...",
		"....c.nnnuuuhhhuuuhhunnnn..wwwwww...",
		"....c.nnuuuuuuuuuuuuuuunn....www....",
		"....c.nnnnnnnnnnnnnnnnnnnn..........",
		"......nnnrrrrrrrrrrrrrnnn...........",
		".....nnnnrrrrrrrrrrrrrnnnn..........",
		".....nnnnnrrrrrrrrrrrnnnnn..........",
		".....ssnnnnnnnnnnnnnnnnnss..........",
		".....mmmnnnnnnnnnnnnnnnmmm..........",
		".....cccnnnnnnnnnnnnnnnccc..........",
		".....ccccc...........................",
		".....bbbbb...........................",
		".....bbbbb...........................",
		".....kkkkk...........................",
	],
	"bulwark_left": [
		".............ttttt..................",
		"....nwww...tlttttt..................",
		"...nwwwww.tlltttttt.................",
		"..nwwmmmwwttttttttt.................",
		"..wwmmmmmwsuuushmmmm................",
		"..nwwmmmwwswwhhhwwssm...............",
		"...nwwwww.nwwuwwwwwnm...............",
		"....nnnn.nwwwkkwwwwn................",
		".........nwwwwiiwwwn................",
		"........nnwwwwwwwwwnn...............",
		".......cnnnnnnnnnnnnn...............",
		".......cnnuuuhhuuunnn...............",
		".......cnnuuuuuuuunnn...............",
		"........nnnnnnnnnnnn................",
		"........nnnrrrrrrnnn................",
		".......nnnnrrrrrrnnnn...............",
		".......nnnnnnnnnnnnn................",
		"......ssnnnnnnnnnnnss...............",
		"......cccnn....nnccc.................",
		"......ccccc....ccccc.................",
		"......bbbbb....bbbbb.................",
		"......bbbbb....bbbbb.................",
		"......kkkkk....kkkkk.................",
	],
	"bulwark_back": [
		".............tttttt.................",
		"............tltttttt................",
		"...........ttlltttttt...............",
		"..........tttttttttttt..............",
		".........ssuuuushmmmmmmm............",
		"........sswwhhhhwwwsssmm............",
		".......nwwuwwwwwwwwwuwnm............",
		".....................nwww...........",
		"......nnwwwwwwwwwwwwwwnn..wwwwww....",
		"......nwwwwwwwwwwwwwwwwnn.wwmmmmww..",
		".....nnwwwwwwwwwwwwwwwwnnnwwmmmmww..",
		".....nnnnnnnnnnnnnnnnnnnnnwwwmmww...",
		"....c.nnuuuuuuuuuuuuuunnnn..wwwwww..",
		"....c.nnuuuuuuuuuuuuuuunn....www....",
		"....c.nnnnnnnnnnnnnnnnnnnn..........",
		"......nnnnnnnnnnnnnnnnnnn...........",
		".....nnnnnnnnnnnnnnnnnnnn..........",
		".....nnnnnnnnnnnnnnnnnnnnn..........",
		".....ssnnnnnnnnnnnnnnnnnss..........",
		".....mmmnnnnnnnnnnnnnnnmmm..........",
		".....cccnnnnnnnnnnnnnnnccc..........",
		".....ccccc...........................",
		".....bbbbb...........................",
		".....bbbbb...........................",
		".....kkkkk...........................",
	],
}

ENTRY = re.compile(r'\t"([a-z_0-9]+)": \[\n(?:\t\t"[^"]*",\n)*\t\],\n')

GRID = 40


def square(rows: list[str]) -> list[str]:
	width = max(len(r) for r in rows)
	height = len(rows)
	size = max(GRID, width, height)
	blank = "." * size
	normalised = [r.ljust(size, ".") for r in rows]
	top = (size - height) // 2
	out = [blank] * top + normalised
	out += [blank] * (size - len(out))
	return out[:size]


def gd_block(key: str, rows: list[str]) -> str:
	lines = ['\t"%s": [' % key]
	for row in square(rows):
		lines.append('\t\t"%s",' % row)
	lines.append("\t],\n")
	return "\n".join(lines)


def main() -> None:
	src = GD.read_text(encoding="utf-8")

	def replace(match: re.Match) -> str:
		key = match.group(1)
		if key in GRIDS:
			return gd_block(key, GRIDS[key])
		return match.group(0)

	updated = ENTRY.sub(replace, src)
	GD.write_text(updated, encoding="utf-8")
	for key, rows in GRIDS.items():
		print(key, len(rows), "rows x", max(len(r) for r in rows), "cols")


if __name__ == "__main__":
	main()
