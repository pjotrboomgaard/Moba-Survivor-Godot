extends SceneTree

## Bakes hand-authored, straight (no-tilt) semi-isometric town building pixel art
## into 32x32 PNGs in assets/sprites/. Each building is a distinct style so the town
## reads as a real settlement, not a wall of identical blocks.
##
## Run: godot --headless --path . -s res://tools/gen_town_art.gd

const OUT := "res://assets/sprites"

# Shared palette (16-char rows, '.' = transparent).
const PAL := {
	# Walls
	"n": "e8dcc8",  # light stucco (front)
	"N": "b8a888",  # stucco shadow (side)
	"w": "d4a76a",  # warm timber (front)
	"W": "9c6b3e",  # timber shadow (side)
	"g": "c9c3ba",  # grey stone (front)
	"G": "918b80",  # grey stone shadow (side)
	# Roofs
	"r": "8b4a2a",  # terracotta roof
	"R": "6f3920",  # roof shadow
	"b": "5a4a3a",  # dark slate roof
	"B": "453829",  # slate shadow
	"p": "7d5a3f",  # brown roof
	"P": "614631",  # brown roof shadow
	"c": "4a5560",  # cobalt roof
	"C": "38414b",  # cobalt shadow
	# Details
	"d": "3a2510",  # door (dark)
	"D": "5a3a1a",  # door light
	"e": "f2e8b0",  # window warm
	"E": "fff5d0",  # window glint
	"a": "c0392b",  # awning red
	"A": "e8d8a8",  # awning cream
	"s": "8a8a8a",  # well stone
	"S": "a8a8a8",  # well stone light
	"i": "5a8ad0",  # stained glass
	"I": "9ac8f0",  # glass glint
	"y": "f2e8b0",  # sign cream
	"o": "6b4226",  # chimney
	"O": "8b5a36",  # chimney light
	"x": "2a1a0a",  # cross / dark trim
	"l": "6b4a2a",  # post / wood dark
}

func _init() -> void:
	if not DirAccess.dir_exists_absolute(OUT):
		DirAccess.make_dir_recursive_absolute(OUT)
	for id in _SPRITES.keys():
		var rows: Array = _SPRITES[id]
		_write(id, rows)
	# Also generate a couple of extra house variants for variety.
	_write("town_house2", _S_HOUSE2)
	_write("town_house3", _S_HOUSE3)
	_write("town_cottage", _S_COTTAGE)
	print("Forged %d town sprites into %s" % [_SPRITES.size() + 3, OUT])
	quit(0)


func _write(id: String, rows: Array) -> void:
	var size := rows.size()
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == ".":
				continue
			var key: String = ch
			img.set_pixel(x, y, Color(str(PAL[key])))
	var path := "%s/%s.png" % [OUT, id]
	img.save_png(path)
	print("Wrote %s (%dx%d)" % [path, size, size])


## House: warm timber front, terracotta gabled roof, chimney, door + window.
const _S_HOUSE := [
	"..................",
	"..........OO......",
	"..........Oo......",
	"......rrrrrrrr....",
	".....rrrrrrrrr...",
	"....rrrrrrrrrr..",
	"...rrrrrrrrrrrr.",
	"..rrrrrrrrrrrrr.",
	".wwwwwwwwwwwwww.",
	".weeewwwwwweeew.",
	".weeewwwwwweeew.",
	".wwwwwwwwwwwwww.",
	".wddwwwwwwwwwwd.",
	".wDDwwwwwwwwwwd.",
	".wwwwwwwwwwwwww.",
	".wwwwwwwwwwwwww.",
]

## Shop: wide cream front, red/cream striped awning, sign, door.
const _S_SHOP := [
	"................",
	"......bBBBB.....",
	".....bbbbbbb....",
	"..bBBBBBBBBBB...",
	".nnnnnnnnnnnnn.",
	".nnnnnnnnnnnnn.",
	"aaaaaaaaaaaaaaa.",
	"AAAAAAAAAAAAAAA.",
	".yyyyyyyyyyyy..",
	".yyyyyyyyyyyy..",
	".nnnnnnnnnnnnn.",
	".nnnnnnnnnnnnn.",
	".nddnndnnnnnnn.",
	".nDDnDnDnnnnnn.",
	".nnnnnnnnnnnnn.",
	".nnnnnnnnnnnnn.",
]

## Church: tall stucco, slate gable, spire + cross, stained glass.
const _S_CHURCH := [
	"........x.......",
	"........xx......",
	"........xx......",
	"........bb......",
	".......bbbb.....",
	"......bBBBB.....",
	".....nnnnnnn....",
	"....nnnnnnnnn...",
	"....nnnnnnnnN...",
	"....nniinnnnN...",
	"....nnIIinnnN...",
	"....nnnnnnnnN...",
	"....nddnndnnN...",
	"....nDDnnDDnN...",
	"....nnnnnnnnN...",
	"....nnnnnnnnN...",
]

## Well: round stone base, timber posts, small roof, rope + bucket.
const _S_WELL := [
	"................",
	"................",
	"....pPPPPPP.....",
	"....ppppppp.....",
	".....ll.ll......",
	".....ll.ll......",
	"....llllllll....",
	"....l.......l...",
	"....l..ll..l....",
	"....l.l..l.l....",
	"...SSSSSSSSSS...",
	"...ssssssssss...",
	"...sSSSSSSSSs...",
	"...ssssssssss...",
	"....ssssssss....",
	"....G.......G...",
]

## Default house (keeps the classic name working).
const _SPRITES := {
	"town_house": _S_HOUSE,
	"town_shop": _S_SHOP,
	"town_church": _S_CHURCH,
	"town_well": _S_WELL,
}

## Extra house variants for a more varied streetscape.
## House2: grey stone, cobalt roof, arched door.
const _S_HOUSE2 := [
	"..................",
	".........oo.......",
	"........oo........",
	"......cccccc......",
	".....ccccccc......",
	"....ccccccccc.....",
	"...cccccccccC.....",
	"..gggggggggggC....",
	".gggggggggggggC...",
	".ggeeggggggeegC...",
	".ggeeggggggeegC...",
	".ggggggggggggg....",
	".gddgggggggggd....",
	".gDDeeggddggd....",
	".ggggggggggggg....",
	".GGGGGGGGGGGGG....",
]

## House3: brown timber, brown gable, two windows, big door.
const _S_HOUSE3 := [
	"..................",
	".........o........",
	"........oO........",
	"......ppppppp.....",
	".....pppppppp.....",
	"....ppppppppp.....",
	"...pppppppppP.....",
	"..wwwwwwwwwWP.....",
	".weeeewwwwWwP.....",
	".weeeewwwwWwP.....",
	".wwwwwwwwwwwW.....",
	".wwwwwwwwwwww.....",
	".wddddwwwwwwd.....",
	".wDDeeDwwwwdd.....",
	".wwwwwwwwwwww.....",
	".WWWWWWWWWWWW.....",
]

## Cottage: small, low, thatched feel, single window, rounded.
const _S_COTTAGE := [
	"................",
	"....pppppp......",
	"...pppppppp.....",
	"..pppppppppP....",
	".wwwwwwwwwW.....",
	".weeeewwwW......",
	".weeeewwwW......",
	".wwwwwwwwwW.....",
	".wdwwwwwwww.....",
	".wDDwwwwwwd.....",
	".wwwwwwwwww.....",
	".wwwwwwwwW......",
	".WWWWWWWWW......",
	".WWW..WWW.......",
	".WW....WW.......",
	"................",
]
