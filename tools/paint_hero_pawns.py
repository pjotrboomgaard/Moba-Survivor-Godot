"""40px rescue-robot heroes + 48px shop stall, in-game pixel language.

Warden  = hover medic (healer.webp / warden_turnaround)
Arclight = volt-staff caster (arclight.webp)
Bulwark = shield tank (bulwark_turnaround)
Shop    = wooden stall from ref image/itemshop2.webp
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ref image" / "_debug" / "hero_facings"

SIZE = 40
SHOP_SIZE = 48

PAL = {
	".": (0, 0, 0, 0),
	"w": (232, 232, 232, 255),
	"u": (200, 200, 200, 255),
	"s": (156, 156, 156, 255),
	"m": (90, 90, 90, 255),
	"d": (42, 48, 56, 255),
	"n": (224, 90, 40, 255),
	"r": (196, 72, 32, 255),
	"t": (220, 60, 46, 255),
	"l": (255, 160, 144, 255),
	"i": (242, 176, 144, 255),
	"y": (255, 225, 74, 255),
	"a": (255, 246, 200, 255),
	"k": (26, 26, 26, 255),
	"g": (140, 255, 74, 255),
	"G": (48, 154, 34, 255),
	"c": (107, 74, 44, 255),
	"b": (58, 32, 16, 255),
	"h": (255, 255, 255, 255),
	"o": (18, 16, 20, 255),
	"e": (255, 154, 40, 255),
	"p": (79, 143, 224, 255),
	"q": (109, 118, 128, 255),
	"f": (232, 212, 168, 255),
}


def pad(rows: list[str], size: int = SIZE) -> list[str]:
	out = [row.ljust(size, ".")[:size] for row in rows]
	while len(out) < size:
		out.append("." * size)
	if len(out) != size or any(len(r) != size for r in out):
		raise SystemExit("grid must be %dx%d (got %d x %s)" % (size, size, len(out), [len(r) for r in out if len(r) != size][:3]))
	return out[:size]


def mirror(rows: list[str]) -> list[str]:
	return [row[::-1] for row in rows]


def rows_to_image(rows: list[str], scale: int = 1) -> Image.Image:
	h, w = len(rows), len(rows[0])
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y, row in enumerate(rows):
		for x, ch in enumerate(row):
			if ch not in PAL:
				raise SystemExit("unknown '%s' at %d,%d" % (ch, x, y))
			px[x, y] = PAL[ch]
	if scale != 1:
		img = img.resize((w * scale, h * scale), Image.Resampling.NEAREST)
	return img


# Dome head, orange ear discs, saucer + green hover cone, plus on the right.
WARDEN = [
	"..............gggg................",
	".............ghaayg...............",
	".............gGgggG...............",
	"............hwwwwwu...............",
	"........nn.whwwwwwuw.nn...........",
	".......nww.wwwwwwwww.wwn..........",
	"......nwww.wwkkwwwkk.wwwn.....g...",
	"......nwww.wwkkwwwkk.wwwn....ggg..",
	".......nww.wwggggwww.wwn......g...",
	"........nn.uwwwwwwwu.nn.....n.....",
	"...........ssssssss........nsn....",
	"..........nnnwhwunnn.......nkn....",
	".........nnuwwwwwwunn.............",
	".........nrnnnnnnnnrn.............",
	"..........nnuuuuuuunn.............",
	"...........sswwwwss...............",
	"............muwwum................",
	"...........dmuuuumd...............",
	"...........GGggggGG...............",
	"............GaggGG................",
	".............GggG.................",
	"..............GgG.................",
	"...............G..................",
]
WARDEN_LEFT = [
	".............gggg.................",
	"............ghaayg................",
	"............gGgggG................",
	"...........hwwwwus................",
	".........nnwhwwwusn...............",
	"........nwwwwwwwusn...............",
	"...g...nwwwkwwwusn................",
	"..ggg..nwwwkwwwusn................",
	"...g...nwwwggwwus.................",
	"..n.....uwwwwwwus.................",
	".nsn.....sssssss..................",
	".nkn....nnwhwunnn.................",
	".......nnuwwwwwunn................",
	".......nrnnnnnnnrn................",
	"........nnuuuuuunn................",
	".........sswwwwss.................",
	"..........muwwum..................",
	"..........dmuuumd.................",
	"..........GGgggGG.................",
	"...........GaggG..................",
	"............GggG..................",
	".............Gg...................",
	"..............G...................",
]
WARDEN_BACK = [
	"..............gggg................",
	".............ghaayg...............",
	".............gGgggG...............",
	"............hwwwwwu...............",
	"........nn.whwwwwwuw.nn...........",
	".......nww.wwwwwwwww.wwn..........",
	"......nwww.wwwwwwwww.wwwn.........",
	"......nwww.wwwwwwwww.wwwn.........",
	".......nww.wwsssswww.wwn..........",
	"........nn.uwwwwwwwu.nn...........",
	"...........ssssssss...............",
	"..........nnnwhwunnn..............",
	".........nnuwwwwwwunn.............",
	".........nrnnnnnnnnrn.............",
	"..........nnuuuuuuunn.............",
	"...........sswwwwss...............",
	"............muwwum................",
	"...........dmuuuumd...............",
	"...........GGggggGG...............",
	"............GaggGG................",
	".............GggG.................",
	"..............GgG.................",
	"...............G..................",
]

# Red siren, white cone, orange shoulders, yellow lightning chest, orange-orb staff.
ARCLIGHT = [
	"...e..............tttt............",
	"..eye............tltttt...........",
	".eynye...........tlttttt..........",
	"..eye............ttttttt..........",
	"...n............suuushmmm.........",
	"...s............suuusmmmm.........",
	"...s...........ssuussmmmmm........",
	"...s..........wwhwwwwwssss........",
	"...s.........wwuwwwwwwussn........",
	"...s.....nnnwwkkwwwwwkkssn........",
	"...s....nnnnwwkkwwwwwkkssnn.......",
	"...s....nnnnwwwwiiiiwwwssnn.......",
	"...s....nnnnwwuwwwwwwussnnn.......",
	"...s.....nnnwww..y...wwssnn.......",
	"...s.....nnnwww.yay..wwssn........",
	"...s......nnwww.yayy.wwsn.........",
	"...s......nnwww..yy..wwsn.........",
	"...s.......nnnnnrrrrrnnn..........",
	"...s........ssnnnnnnnss...........",
	"............mdnn...nnndm..........",
	"............cccc...cccc...........",
	"............cccc...cccc...........",
	"............bbbb...bbbb...........",
	"............kkkk...kkkk...........",
]
ARCLIGHT_LEFT = [
	"...........tttttt.................",
	"..........tlttttt.................",
	"..e.......tlttttt.................",
	".eye......ttttttt.................",
	"eynye.....suuushmm................",
	".eye......suuusmmm................",
	"..n......ssuussmmmm...............",
	"..s......wwhwwwwsss...............",
	"..s.....wwkwwwwwuss...............",
	"..s.....wwkwwwwwssn...............",
	"..s.....wwwiiiiwssn...............",
	"..s.....wwuwwwwssnn...............",
	"..s......w.y..wssnn...............",
	"..s......wyay.ssnn................",
	"..s......wyayynn..................",
	"..s.......wyy.nn..................",
	"..s.......rrrrnn..................",
	"..s.......ssnnnss.................",
	"..........mdnn.nndm...............",
	"..........cccc.cccc...............",
	"..........cccc.cccc...............",
	"..........bbbb.bbbb...............",
	"..........kkkk.kkkk...............",
]
ARCLIGHT_BACK = [
	"..................tttt............",
	".................tltttt...........",
	".................tlttttt..........",
	".................ttttttt..........",
	"................suuushmmm.........",
	"................suuusmmmm.........",
	"...............ssuussmmmmm........",
	"...............wwhwwwwwssss.......",
	"..............wwuwwwwwwussn.......",
	"..........nnnwwwwwwwwwwwssn.......",
	".........nnnnwwwwwwwwwwsssnn......",
	".........nnnnwwuwwwwwwusssnn......",
	".........nnnnwwwwwwwwwwsssnnn.....",
	"..........nnnwwsssssswwssnn.......",
	"..........nnnwwwwwwwwwwssn........",
	"...........nnwwwwwwwwwwsn.........",
	"...........nnnnrrrrrnnnn..........",
	"............ssnnnnnnnss...........",
	"............mdnn...nnndm..........",
	"............cccc...cccc...........",
	"............cccc...cccc...........",
	"............bbbb...bbbb...........",
	"............kkkk...kkkk...........",
]

# Siren, orange armour, white shoulders, tall oval shield with orange rim.
BULWARK = [
	".............tttt.................",
	"............tltttt................",
	"............tlttttt...............",
	"............ttttttt...............",
	"...........suuushmmm..............",
	"..........sswhwwwsss..............",
	".........nwwuwwwwwuwn.............",
	"........nwwwkkwwwwkkwwn...........",
	"........nwwwkkwwwwkkwwn...........",
	"........nwwwwiiiiwwwwnn.nwww......",
	".......nnwwuwwwwwwuwnnnnwwwww.....",
	".......nnnnnnnnnnnnnnnnwwmmmww....",
	".....c.nnnuhuuuuuuhnnnwwmmmmww....",
	".....c.nnnuuussuuuunnnnwwmmmww....",
	".....c.nnnnnnnnnnnnnnn.nwwwnww....",
	".......nnnnrrrrrrrrnnn..nwww......",
	".......nnnnrrrrrrrrnnn...nnn......",
	".......nnnnnnnnnnnnnnn............",
	"......ssnnnrrrrrrnnnss............",
	"......mmmnn......nnmmm............",
	"......cccnn......nnccc............",
	"......ccccc......ccccc............",
	"......ccccc......ccccc............",
	"......bbbbb......bbbbb............",
	"......kkkkk......kkkkk............",
]
BULWARK_LEFT = [
	"..........ttttt...................",
	"....nwww.tltttt...................",
	"...nwwwwwtlttttt..................",
	"..nwwmmmwwtttttt..................",
	"..wwmmmmmwsuuushm.................",
	"..nwwmmmwwsswhwwss................",
	"...nwwwww.nwwuwwwn................",
	"....nnnn.nwwkwwwwn................",
	".........nwwiiwwn.................",
	"........nnwwwwwwnn................",
	".......cnnnnnnnnnn................",
	".......cnnnuhuuunn................",
	".......cnnnuussuun................",
	"........nnnnnnnnnn................",
	"........nnnrrrrnnn................",
	"........nnnrrrrnnn................",
	"........nnnnnnnnn.................",
	".......ssnnrrrnnss................",
	".......mmmnn.nnmmm................",
	".......cccnn.nnccc................",
	".......ccccc.ccccc................",
	".......ccccc.ccccc................",
	".......bbbbb.bbbbb................",
	".......kkkkk.kkkkk................",
]
BULWARK_BACK = [
	".............tttt.................",
	"............tltttt................",
	"............tlttttt...............",
	"............ttttttt...............",
	"...........suuushmmm..............",
	"..........sswhwwwsss..............",
	".........nwwuwwwwwuwn.............",
	"........nwwwwwwwwwwwwn............",
	"........nwwuwwwwwwuwnn.nwww.......",
	".......nnwwwwwwwwwwwnnnnwwwww.....",
	".......nnnnnnnnnnnnnnnnwwmmmww....",
	".......nnnuhuuuuuuhnnnwwmmmmww....",
	".......nnnuuussuuuunnnnwwmmmww....",
	".......nnnnnnnnnnnnnnn.nwwwnww....",
	".......nnnnrrrrrrrrnnn..nwww......",
	".......nnnnrrrrrrrrnnn...nnn......",
	".......nnnnnnnnnnnnnnn............",
	"......ssnnnrrrrrrnnnss............",
	"......mmmnn......nnmmm............",
	"......cccnn......nnccc............",
	"......ccccc......ccccc............",
	"......ccccc......ccccc............",
	"......bbbbb......bbbbb............",
	"......kkkkk......kkkkk............",
]


def paint_shop() -> list[str]:
	n = SHOP_SIZE
	g = [["."] * n for _ in range(n)]

	def put(x: int, y: int, ch: str) -> None:
		if 0 <= x < n and 0 <= y < n:
			g[y][x] = ch

	def fill(x0: int, y0: int, x1: int, y1: int, ch: str) -> None:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				put(x, y, ch)

	def hline(x0: int, x1: int, y: int, ch: str) -> None:
		for x in range(x0, x1 + 1):
			put(x, y, ch)

	def vline(x: int, y0: int, y1: int, ch: str) -> None:
		for y in range(y0, y1 + 1):
			put(x, y, ch)

	# Red shingled roof.
	fill(7, 8, 37, 14, "o")
	fill(8, 9, 36, 13, "r")
	fill(9, 10, 35, 12, "t")
	hline(9, 35, 11, "r")

	# Sign + siren.
	fill(14, 1, 32, 7, "o")
	fill(15, 2, 31, 6, "f")
	fill(16, 3, 21, 6, "t")
	put(17, 4, "k")
	put(20, 4, "k")
	put(18, 5, "k")
	put(24, 3, "s")
	put(25, 4, "s")
	put(26, 5, "s")
	put(27, 6, "s")
	put(27, 3, "s")
	put(26, 4, "m")
	put(25, 5, "s")
	put(24, 6, "s")
	fill(22, 0, 24, 1, "t")
	put(23, 0, "l")

	# Flag + pole.
	vline(41, 4, 18, "s")
	fill(39, 4, 45, 9, "t")
	put(42, 6, "w")
	put(41, 7, "w")
	put(43, 7, "w")
	put(42, 8, "w")

	# Lantern under left eave.
	put(5, 8, "s")
	fill(4, 9, 6, 12, "e")
	put(5, 10, "y")
	put(5, 11, "a")

	# Back wall.
	fill(9, 15, 35, 28, "o")
	fill(10, 16, 34, 27, "c")
	fill(11, 17, 33, 26, "b")
	hline(11, 33, 17, "c")

	# Wall goods: hammer, blue-gold shield, sword, potion.
	hline(12, 16, 18, "s")
	put(12, 17, "m")
	put(12, 19, "m")
	fill(18, 18, 22, 23, "o")
	fill(19, 19, 21, 22, "p")
	put(20, 20, "y")
	vline(25, 18, 24, "s")
	put(25, 18, "y")
	put(24, 18, "s")
	put(26, 18, "s")
	fill(29, 19, 31, 23, "t")
	put(30, 20, "l")
	put(30, 18, "s")

	# Shopkeep: white head, red hat, grey body, waving arm.
	fill(20, 18, 24, 19, "t")
	put(22, 18, "l")
	fill(19, 20, 25, 24, "u")
	fill(20, 21, 24, 23, "h")
	put(21, 22, "k")
	put(23, 22, "k")
	put(22, 23, "i")
	fill(20, 25, 24, 27, "s")
	fill(25, 21, 29, 22, "s")
	put(29, 20, "s")
	put(28, 21, "u")

	# Counter + red cloth.
	fill(8, 28, 36, 37, "o")
	fill(9, 29, 35, 36, "c")
	fill(10, 30, 34, 35, "b")
	fill(17, 28, 27, 32, "t")
	hline(17, 27, 28, "r")

	# Counter icons: sword, shield, heart, potion.
	fill(10, 33, 14, 36, "d")
	put(11, 34, "s")
	put(12, 35, "s")
	put(13, 34, "s")
	fill(16, 33, 20, 36, "d")
	fill(17, 34, 19, 35, "s")
	put(18, 34, "p")
	fill(22, 33, 26, 36, "d")
	put(23, 34, "t")
	put(25, 34, "t")
	put(24, 35, "t")
	fill(28, 33, 32, 36, "d")
	fill(29, 34, 31, 35, "t")
	put(30, 33, "s")

	# Target + barrel left.
	fill(1, 26, 7, 37, "o")
	fill(2, 27, 6, 36, "c")
	fill(3, 28, 5, 32, "t")
	put(4, 30, "f")
	put(4, 29, "t")

	# Stone forge + fire + chimney.
	fill(37, 20, 46, 37, "o")
	fill(38, 21, 45, 36, "q")
	fill(39, 25, 44, 33, "k")
	fill(40, 27, 43, 32, "e")
	put(41, 29, "y")
	put(42, 28, "a")
	fill(43, 14, 46, 21, "m")
	fill(41, 14, 43, 16, "m")
	put(42, 13, "m")

	return ["".join(row) for row in g]


HEROES = {
	"warden": {"front": WARDEN, "left": WARDEN_LEFT, "back": WARDEN_BACK},
	"arclight": {"front": ARCLIGHT, "left": ARCLIGHT_LEFT, "back": ARCLIGHT_BACK},
	"bulwark": {"front": BULWARK, "left": BULWARK_LEFT, "back": BULWARK_BACK},
}


def dump_rows(key: str, rows: list[str]) -> str:
	lines = ['\t"%s": [' % key]
	for row in rows:
		lines.append('\t\t"%s",' % row)
	lines.append("\t],")
	return "\n".join(lines)


def dump_hero_gd() -> str:
	chunks: list[str] = []
	for hero, views in HEROES.items():
		for facing in ("front", "left", "right", "back"):
			if facing == "front":
				rows = pad(views["front"])
			elif facing == "right":
				rows = mirror(pad(views["left"]))
			else:
				rows = pad(views[facing])
			key = hero if facing == "front" else "%s_%s" % (hero, facing)
			chunks.append(dump_rows(key, rows))
	return "\n".join(chunks)


def contact(cells: list[tuple[str, Image.Image]], cols: int, cell: int, path: Path) -> None:
	gap, label_h = 8, 22
	rows_n = (len(cells) + cols - 1) // cols
	sheet = Image.new(
		"RGBA",
		(cols * (cell + gap) + gap, rows_n * (cell + label_h) + gap),
		(18, 20, 26, 255),
	)
	draw = ImageDraw.Draw(sheet)
	try:
		font = ImageFont.truetype("arial.ttf", 14)
	except OSError:
		font = ImageFont.load_default()
	for i, (label, img) in enumerate(cells):
		cx = gap + (i % cols) * (cell + gap)
		cy = gap + (i // cols) * (cell + label_h)
		for y in range(0, cell, 8):
			for x in range(0, cell, 8):
				col = (32, 34, 42, 255) if ((x // 8) + (y // 8)) % 2 == 0 else (24, 26, 32, 255)
				draw.rectangle([cx + x, cy + y, cx + x + 8, cy + y + 8], fill=col)
		sheet.alpha_composite(img, (cx, cy))
		draw.text((cx + 4, cy + cell + 2), label, fill=(255, 210, 90, 255), font=font)
	path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(path)
	print("wrote", path, sheet.size)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	cells: list[tuple[str, Image.Image]] = []
	for hero, views in HEROES.items():
		front = pad(views["front"])
		left = pad(views["left"])
		back = pad(views["back"])
		right = mirror(left)
		for facing, rows in (("front", front), ("left", left), ("back", back), ("right", right)):
			big = rows_to_image(rows, 8)
			big.save(OUT / ("%s_%s_hand_x10.png" % (hero, facing)))
			rows_to_image(rows, 1).save(OUT / ("%s_%s_hand_32.png" % (hero, facing)))
			cells.append(("%s %s" % (hero, facing), big))
			print(hero, facing, "opaque", sum(c != "." for row in rows for c in row))
	shop = pad(paint_shop(), SHOP_SIZE)
	shop_img = rows_to_image(shop, 6)
	shop_img.save(OUT / "shop_stand_x6.png")
	rows_to_image(shop, 1).save(OUT / "shop_stand_48.png")
	cells.append(("shop", shop_img.resize((320, 320), Image.Resampling.NEAREST)))
	contact(cells, 4, 320, OUT / "facing_hand_contact.png")
	(OUT / "hero_rows_hand.gd").write_text(dump_hero_gd(), encoding="utf-8")
	(OUT / "shop_rows_hand.gd").write_text(dump_rows("shop_stand", shop), encoding="utf-8")
	print("gd dumped")


if __name__ == "__main__":
	main()
