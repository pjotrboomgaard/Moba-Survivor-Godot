"""Paint several in-game-style Tobor head options onto a contact sheet."""
from __future__ import annotations

from PIL import Image, ImageDraw, ImageFont

PAL = {
	".": (0, 0, 0, 0),
	"o": (12, 14, 18, 255),
	"w": (236, 236, 232, 255),
	"u": (196, 196, 188, 255),
	"s": (154, 162, 170, 255),
	"m": (74, 82, 90, 255),
	"n": (255, 122, 42, 255),
	"r": (196, 62, 16, 255),
	"y": (255, 206, 96, 255),
	"e": (236, 196, 58, 255),
	"k": (16, 14, 14, 255),
	"b": (42, 154, 170, 255),
	"d": (52, 58, 68, 255),
	"h": (196, 154, 58, 255),
	"c": (122, 70, 36, 255),
	"p": (74, 82, 96, 255),
	"q": (36, 40, 48, 255),
	"a": (168, 176, 186, 255),
}


def rows_to_image(rows: list[str]) -> Image.Image:
	h = len(rows)
	w = len(rows[0])
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y, row in enumerate(rows):
		for x, ch in enumerate(row):
			px[x, y] = PAL.get(ch, PAL["."])
	return img


# A: drawing-like — small round eyes, cylindrical siren, short neck + wheels
A = [
	"...........nnn...........",
	"..........nyynn..........",
	"..........nnnnn..........",
	"..........osssso.........",
	".........owwwwwwo........",
	"........owwwwwwwwo.......",
	".......oww.k.k.wwwo......",
	".......oww.e.e.wwwo......",
	".......owwwwwwwwwwo......",
	".......owwwwkwwwwwo......",
	".......onnnnnnnnnno......",
	".......onn.b.nnnnno......",
	"........onkkkkknno.......",
	".........ooooooo.........",
	"..........oppppo.........",
	"..........opqqpo.........",
	".........ooddddoo........",
	"........od.dkk.ddo.......",
	".........ooddddoo........",
]

# B: photo-faithful but smaller — tiny gauge eyes, cylinder+dome siren, more torso
B = [
	"............nn...........",
	"...........nyyn..........",
	"...........nnnn..........",
	"...........nnnn..........",
	"..........osssso.........",
	".........owwwwwwo........",
	"........owuwwwwuwo.......",
	".......owwkkwwkkwwo......",
	".......owwekeekwwo.......",
	".......owwkkwwkkwwo......",
	".......owwwsssswwwo......",
	".......owwwwbwwwwwo......",
	".......onnnnnnnnnno......",
	".......onnnkkknnno.......",
	"........onnnnnnno........",
	".........opppppo.........",
	".........opqqqqpo........",
	".........opppppo.........",
	"........ood....doo.......",
	".......oddo....oddo......",
	"........oo......oo.......",
]

# C: hero-sprite language (chunky 16-wide feel, scaled to 24) — more body
C = [
	"..........nnnn...........",
	".........nyyyyn..........",
	".........nnnnnn..........",
	"........osssssso.........",
	".......owwwwwwwwo........",
	"......oww.ee.ee.wwo......",
	"......oww.kk.kk.wwo......",
	"......owwwwwwwwwwo.......",
	"......owwwwkkwwwwo.......",
	"......onnnnnnnnnno.......",
	".......onnnnnnnno........",
	"........oppppppo.........",
	".......oppqqqqppo........",
	".......oppqqqqppo........",
	"........oppppppo.........",
	".......oo......oo........",
	"......oddo....oddo.......",
	".......oo......oo........",
]

# D: lighthouse siren (tall cylinder, not a ball), smallest eyes, longest body
D = [
	"............nn...........",
	"...........nyyn..........",
	"...........nnnn..........",
	"...........nnnn..........",
	"...........nnnn..........",
	"..........osssso.........",
	".........owwwwwwo........",
	"........owwwwwwwwo.......",
	"........ow.k.k.wwo.......",
	"........ow.e.e.wwo.......",
	"........owwwwwwwwo.......",
	"........owwwwkwwwo.......",
	"........onnnnnnnno.......",
	"........onn.b.nnno.......",
	".........onkkkno.........",
	"..........oooo...........",
	"..........ccccc..........",
	".........cchhhcc.........",
	"..........oppppo.........",
	".........opqqqqpo........",
	".........opqqqqpo........",
	"..........oppppo.........",
	".........ooddddoo........",
	"........oddkddkddo.......",
	".........ooddddoo........",
]

# E: start-form with default stub body (head ~1/3 height), tiny eyes, round-top cylinder siren
E = [
	"...........nnn...........",
	"..........nynyn..........",
	"..........nnnnn..........",
	"..........osssso.........",
	".........owwwwwwo........",
	"........owuwwwwuwo.......",
	".......owwwk.kwwwwo......",
	".......owwwe.ewwwwo......",
	".......owwwwwwwwwwo......",
	".......owwwwbwwwwwo......",
	".......onnnkkknnno.......",
	"........onnnnnnno........",
	".........ooooooo.........",
	".........oppppppo........",
	"........oppqqqqppo.......",
	"........oppqqqqppo.......",
	"........oppaaaappo.......",
	".........oppppppo........",
	"........oo......oo.......",
	".......oddo.dd.oddo......",
	"........oo......oo.......",
]

OPTIONS = [
	("A  klein kegel", A),
	("B  foto-klein", B),
	("C  hero-stijl", C),
	("D  vuurtoren + lijf", D),
	("E  meer lichaam", E),
]


def pad(rows: list[str], width: int, height: int) -> list[str]:
	out = []
	for row in rows:
		row = row.ljust(width, ".")[:width]
		if len(row) < width:
			extra = width - len(row)
			row = ("." * (extra // 2)) + row + ("." * (extra - extra // 2))
			row = row[:width]
		out.append(row)
	while len(out) < height:
		out.append("." * width)
	# center vertically remaining? already top-aligned with empty bottom — put content at bottom-ish
	return out[:height]


def main() -> None:
	cell_w, cell_h = 24, 28
	scale = 10
	label_h = 18
	gap = 8
	n = len(OPTIONS)
	sheet_w = n * (cell_w * scale + gap) + gap
	sheet_h = cell_h * scale + label_h + gap * 2
	sheet = Image.new("RGBA", (sheet_w, sheet_h), (18, 20, 26, 255))
	draw = ImageDraw.Draw(sheet)
	try:
		font = ImageFont.truetype("arial.ttf", 14)
	except OSError:
		font = ImageFont.load_default()

	for i, (name, rows) in enumerate(OPTIONS):
		img = rows_to_image(pad(rows, cell_w, cell_h))
		big = img.resize((cell_w * scale, cell_h * scale), Image.Resampling.NEAREST)
		x = gap + i * (cell_w * scale + gap)
		y = gap
		# checker behind
		for cy in range(0, big.size[1], 8):
			for cx in range(0, big.size[0], 8):
				col = (32, 34, 42, 255) if (cx // 8 + cy // 8) % 2 == 0 else (24, 26, 32, 255)
				draw.rectangle([x + cx, y + cy, x + cx + 8, y + cy + 8], fill=col)
		sheet.alpha_composite(big, (x, y))
		draw.text((x + 4, y + cell_h * scale + 2), name, fill=(255, 210, 90, 255), font=font)
		img.resize((cell_w * 4, cell_h * 4), Image.Resampling.NEAREST).save(
			f"ref image/tobor_head_opt_{chr(65+i)}.png"
		)

	sheet.save("ref image/tobor_head_options.png")
	print("wrote contact sheet", sheet.size)


if __name__ == "__main__":
	main()
