"""Hand-authored 32px facings for Warden / Arclight / Bulwark.

Denser than Tobor's cone: extra shade ramps, equipment, panel seams.
Bulwark's orange torso meets brown boots — no floating-feet gap.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ref image" / "_debug" / "hero_facings"

PAL = {
	".": (0, 0, 0, 0),
	"w": (232, 232, 232, 255),
	"u": (200, 200, 200, 255),
	"s": (156, 156, 156, 255),
	"m": (90, 90, 90, 255),
	"n": (224, 90, 40, 255),
	"r": (196, 72, 32, 255),
	"t": (220, 60, 46, 255),
	"l": (255, 160, 144, 255),
	"i": (242, 176, 144, 255),
	"y": (255, 225, 74, 255),
	"k": (26, 26, 26, 255),
	"g": (140, 255, 74, 255),
	"G": (48, 154, 34, 255),
	"c": (107, 74, 44, 255),
}

# --- Warden / Enord: hover drone, green lamp, orange ears, disc + cone ---
WARDEN = [
	"..............gg................",
	".............gGyg...............",
	"..............gg................",
	".............suus...............",
	"...........nwwwwwwn.............",
	"..........nwwuwwwuwn............",
	".........nwwwkkwwkkwwn..........",
	".........nwwwkkwwkkwwn.....g....",
	".........nwwwwggwwwwn.....ggg...",
	".........nwwuwwwuwwwn......g....",
	"..........nwwsssswwn.....n......",
	"...........nnnssnnn.....nsn.....",
	"..........nnnwwwwnnn....nkn.....",
	".........nnuwwwwwuunn...........",
	".........nrnnnnnnnnrn...........",
	"..........nnuuuuuunn............",
	"...........sswwwwss.............",
	"............muwwum..............",
	"............GGggGG..............",
	".............GgggG..............",
	"..............GgG...............",
	"...............G................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
WARDEN_LEFT = [
	".............gg.................",
	"............gGyg................",
	".............suu................",
	"...........nwwwwus..............",
	"..........nwwkwwwus.............",
	"....g.....nwwkwwwus.............",
	"...ggg....nwwggwwus.............",
	"....g.....nwwwwwus..............",
	"...n.......nnnnns...............",
	"..nsn.....nwwwwwnn..............",
	"..nkn....nnuwwwuunn.............",
	"..........nrnnnnnrn.............",
	"...........nnuuuunn.............",
	"............sswwwss.............",
	".............muwwum.............",
	".............GGggG..............",
	"..............GggG..............",
	"...............Gg...............",
	"................G...............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
WARDEN_BACK = [
	"..............gg................",
	".............gGyg...............",
	"..............gg................",
	".............suus...............",
	"...........nwwwwwwn.............",
	"..........nwwuwwwuwn............",
	".........nwwwwwwwwwwn...........",
	".........nwwuwwwwuwwwn..........",
	".........nwwsssssswwn...........",
	"..........nwwwwwwwwn............",
	"...........nnnssnnn.............",
	"..........nnnwwwwnnn............",
	".........nnuwwwwwuunn...........",
	".........nrnnnnnnnnrn...........",
	"..........nnuuuuuunn............",
	"...........sswwwwss.............",
	"............muwwum..............",
	"............GGggGG..............",
	".............GgggG..............",
	"..............GgG...............",
	"...............G................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

# --- Arclight / Diord: staff, chest plus, stubby legs ---
ARCLIGHT = [
	"....g...........tttt............",
	"...ggg.........tllttt...........",
	"....g..........tltttt...........",
	"...n.n.........ttttttt..........",
	"...nsn........suuusmmm..........",
	"...nkn........suuusmmm..........",
	"....s........ssuussmmmm.........",
	"....s........wwwwwwwsss.........",
	"....s.......wwuwwwwwuss.........",
	"....s...nnnwwkkwwwwkkssn........",
	"....s..nnnnwwkkwwwwkkssnn.......",
	"....s..nnnnwwwwiiiiwwssnn.......",
	"....s..nnnnwwuwwwwwussnnn.......",
	"....s...nnnwwwmmgmmwwssnn.......",
	"....s...nnnwwwgggggwwssn........",
	"....s....nnwwwmmgmmwwsn.........",
	"....s....nnwwwmmmmmwwsn.........",
	"....s.....nnnnrrrrnnnn..........",
	"....s......ssnnnnnnss...........",
	"....s......mknn..nnkm...........",
	"...........cccc..cccc...........",
	"...........cccc..cccc...........",
	"...........kkkk..kkkk...........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
ARCLIGHT_LEFT = [
	"..........tttttt................",
	".........tllttttt...............",
	".........tltttttt...............",
	"...g.....tttttttt...............",
	"..ggg....suuusmmm...............",
	"...g.....suuusmmm...............",
	"..n.n...ssuussmmmm..............",
	"..nsn...wwwwwwwsss..............",
	"..nkn..wwkwwwwwuss..............",
	"...s...wwkwwwwwssn..............",
	"...s...wwwiiiiwssn..............",
	"...s...wwuwwwwssnn..............",
	"...s....mmgmmwssnn..............",
	"...s....gggggssnn...............",
	"...s....mmgmmnnn................",
	"...s.....mmmmnnn................",
	"...s.....rrrrnn.................",
	"...s.....ssnnnss................",
	".........mknn.nkm...............",
	".........cccc.cccc..............",
	".........cccc.cccc..............",
	".........kkkk.kkkk..............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
ARCLIGHT_BACK = [
	"................tttt............",
	"...............tllttt...........",
	"...............tltttt...........",
	"...............ttttttt..........",
	"..............suuusmmm..........",
	"..............suuusmmm..........",
	".............ssuussmmmm.........",
	".............wwwwwwwsss.........",
	"............wwuwwwwwuss.........",
	"........nnnwwwwwwwwwwssn........",
	".......nnnnwwwwwwwwwsssnn.......",
	".......nnnnwwuwwwwwusssnn.......",
	".......nnnnwwwwwwwwwsssnnn......",
	"........nnnwwsssssswwssnn.......",
	"........nnnwwwwwwwwwsssn........",
	".........nnwwwwwwwwwssn.........",
	".........nnnnrrrrnnnnn..........",
	"..........ssnnnnnnss............",
	"..........mknn..nnkm............",
	"..........cccc..cccc............",
	"..........cccc..cccc............",
	"..........kkkk..kkkk............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

# --- Bulwark / Romra: shield tank. Torso meets boots. ---
BULWARK = [
	"............tttt................",
	"...........tllttt...............",
	"...........tltttt...............",
	"...........ttttttt..............",
	"..........suuusmmm..............",
	".........sswwwwwsss.............",
	"........nwwuwwwwwuwn............",
	".......nwwwkkwwwwkkwwn..........",
	".......nwwwkkwwwwkkwwn..........",
	".......nwwwwiiiiwwwwnn..........",
	"......nnwwuwwwwwuwwwnnn.www.....",
	"......nnnnnnnnnnnnnnnnnwwwww....",
	"......nnnuuuuuuuuunnnnwwwmmww...",
	"....c.nnnuuussuuuunnnnwwmmmmw...",
	"....c.nnnnnnnnnnnnnnnnwwwmmwww..",
	"....c.nnnnrrrrrrrrnnnnnwwmmww...",
	"......nnnnrrrrrrrrnnnn.nwwww....",
	"......nnnnnnnnnnnnnnn...nnn.....",
	".....ssnnnrrrrrrnnnss...........",
	".....mmmnn......nnmmm...........",
	".....cccnn......nnccc...........",
	".....ccccc......ccccc...........",
	".....ccccc......ccccc...........",
	".....kkkkk......kkkkk...........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
BULWARK_LEFT = [
	"..........ttttt.................",
	"....www..tlltttt................",
	"...wwwww.tlttttt................",
	"..wwwmwwwttttttt................",
	"..wwmmmmwsuuusmm................",
	"..wwwmwwwsswwwwss...............",
	"...wwwww.nwwuwwwn...............",
	"....nnn.nwwkwwwwn...............",
	".........nwwiiwwn...............",
	"........nnwwwwwwnn..............",
	".......cnnnnnnnnnn..............",
	".......cnnnuuuuunn..............",
	".......cnnnuussuun..............",
	"........nnnnnnnnnn..............",
	"........nnnrrrrnnn..............",
	"........nnnrrrrnnn..............",
	"........nnnnnnnnn...............",
	".......ssnnrrrnnss..............",
	".......mmmnn.nnmmm..............",
	".......cccnn.nnccc..............",
	".......ccccc.ccccc..............",
	".......ccccc.ccccc..............",
	".......kkkkk.kkkkk..............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]
BULWARK_BACK = [
	"............tttt................",
	"...........tllttt...............",
	"...........tltttt...............",
	"...........ttttttt..............",
	"..........suuusmmm..............",
	".........sswwwwwsss.............",
	"........nwwuwwwwwuwn............",
	".......nwwwwwwwwwwwwn...........",
	".......nwwuwwwwwwuwwwn..........",
	"......nnwwwwwwwwwwwwnnn.www.....",
	"......nnnnnnnnnnnnnnnnnwwwww....",
	"......nnnuuuuuuuuunnnnwwwmmww...",
	"......nnnuuussuuuunnnnwwmmmmw...",
	"......nnnnnnnnnnnnnnnnwwwmmwww..",
	"......nnnnrrrrrrrrnnnnnwwmmww...",
	"......nnnnrrrrrrrrnnnn.nwwww....",
	"......nnnnnnnnnnnnnnn...nnn.....",
	".....ssnnnrrrrrrnnnss...........",
	".....mmmnn......nnmmm...........",
	".....cccnn......nnccc...........",
	".....ccccc......ccccc...........",
	".....ccccc......ccccc...........",
	".....kkkkk......kkkkk...........",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]


def pad32(rows: list[str]) -> list[str]:
	out = [row.ljust(32, ".")[:32] for row in rows]
	while len(out) < 32:
		out.append("." * 32)
	if len(out) != 32 or any(len(r) != 32 for r in out):
		raise SystemExit("grid must be 32x32")
	return out[:32]


def mirror(rows: list[str]) -> list[str]:
	return [row[::-1] for row in rows]


def rows_to_image(rows: list[str], scale: int = 1) -> Image.Image:
	img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
	px = img.load()
	for y, row in enumerate(rows):
		for x, ch in enumerate(row):
			px[x, y] = PAL.get(ch, PAL["."])
	if scale != 1:
		img = img.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST)
	return img


HEROES = {
	"warden": {"front": WARDEN, "left": WARDEN_LEFT, "back": WARDEN_BACK},
	"arclight": {"front": ARCLIGHT, "left": ARCLIGHT_LEFT, "back": ARCLIGHT_BACK},
	"bulwark": {"front": BULWARK, "left": BULWARK_LEFT, "back": BULWARK_BACK},
}


def dump_gd() -> str:
	chunks: list[str] = []
	for hero, views in HEROES.items():
		for facing in ("front", "left", "right", "back"):
			rows = pad32(views["front"] if facing == "front" else (
				mirror(pad32(views["left"])) if facing == "right" else pad32(views[facing])
			))
			key = hero if facing == "front" else f"{hero}_{facing}"
			lines = [f'\t"{key}": [']
			for row in rows:
				lines.append(f'\t\t"{row}",')
			lines.append("\t],")
			chunks.append("\n".join(lines))
	return "\n".join(chunks)


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	cells: list[tuple[str, Image.Image]] = []
	for hero, views in HEROES.items():
		front = pad32(views["front"])
		left = pad32(views["left"])
		back = pad32(views["back"])
		right = mirror(left)
		for facing, rows in (("front", front), ("left", left), ("back", back), ("right", right)):
			for ch in "".join(rows):
				if ch not in PAL:
					raise SystemExit(f"{hero} {facing} unknown '{ch}'")
			big = rows_to_image(rows, 10)
			big.save(OUT / f"{hero}_{facing}_hand_x10.png")
			rows_to_image(rows, 1).save(OUT / f"{hero}_{facing}_hand_32.png")
			cells.append((f"{hero} {facing}", big))
			print(hero, facing, "opaque", sum(c != "." for row in rows for c in row))
	(OUT / "hero_rows_hand.gd").write_text(dump_gd(), encoding="utf-8")

	cell_w, cell_h = 320, 320
	cols = 4
	sheet = Image.new("RGBA", (cols * (cell_w + 8) + 8, 3 * (cell_h + 24) + 8), (18, 20, 26, 255))
	draw = ImageDraw.Draw(sheet)
	try:
		font = ImageFont.truetype("arial.ttf", 14)
	except OSError:
		font = ImageFont.load_default()
	for i, (label, img) in enumerate(cells):
		cx = 8 + (i % cols) * (cell_w + 8)
		cy = 8 + (i // cols) * (cell_h + 24)
		for y in range(0, 320, 8):
			for x in range(0, 320, 8):
				col = (32, 34, 42, 255) if ((x // 8) + (y // 8)) % 2 == 0 else (24, 26, 32, 255)
				draw.rectangle([cx + x, cy + y, cx + x + 8, cy + y + 8], fill=col)
		sheet.alpha_composite(img, (cx, cy))
		draw.text((cx + 4, cy + cell_h + 2), label, fill=(255, 210, 90, 255), font=font)
	sheet.save(OUT / "facing_hand_contact.png")
	print("wrote", OUT / "facing_hand_contact.png")


if __name__ == "__main__":
	main()
