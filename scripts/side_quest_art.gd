class_name SideQuestArt
extends RefCounted

## Tiny 16px props for side quests. Built at runtime so they do not need a forge pass.

const _P := {
	"o": "1a1210", "w": "f2f4f0", "y": "ffe14a", "g": "3a6130", "p": "c45ec8",
	"b": "4f8fe0", "c": "7fd4ff", "r": "e85a2a", "s": "8b95a1", "n": "6b4a1a",
	"l": "50f59e", "d": "2a2018", "m": "ff7a29", "i": "d0e8f6", "k": "c9a227",
	# Lagoon palette (tropical)
	"q": "2a6b5a", "Q": "1a4a3e",  # palm frond dark
	"e": "1a8f7a", "E": "3ecfa3",  # palm frond / lagoon water
	"f": "ff8a5a", "F": "d95a2a",  # flamingo / fruit red
	"u": "ffd85a", "U": "d9a83a",  # sun / gold
	"Ff": "b0401a",  # deep red
	# Forest palette
	"h": "2a1a0a", "H": "1a1208",  # dark wood / tree trunk
	"j": "7a5a3a", "J": "9c7a4a",  # mid wood
	"A": "1f3f1a",  # deep forest green
	"B": "2a5a2a",  # mid green
	"C": "4a8a4a",  # light green leaf
	# Mountain palette
	"M": "6b7a8a",  # mountain rock
	"N": "4a5560",  # mountain rock dark
	"X": "3a4550",  # mountain rock darker
	"O": "c8d4de",  # snow / ice light
	"W": "a8b8c8",  # snow / ice mid
	"V": "3a2a1a",  # mountain wood (hut beams)
	"z": "ff9a3d",  # coral / warm accent (crab shell, fruit, coral)
}


static func texture(id: String, frame: int = 0) -> Texture2D:
	return SpriteLibrary.texture_from_rows(_rows(id, frame), _P)


static func _rows(id: String, frame: int) -> Array:
	match id:
		"butterfly":
			return _BUTTER_B if frame % 2 == 1 else _BUTTER_A
		"wisp":
			return _WISP_B if frame % 2 == 1 else _WISP_A
		"ember":
			return _EMBER_B if frame % 2 == 1 else _EMBER_A
		"shard":
			return _SHARD
		"firefly":
			return _FLY_B if frame % 2 == 1 else _FLY_A
		"idol":
			return _IDOL
		"crate":
			return _CRATE
		"cog":
			return _COG
		"beacon":
			return _BEACON
		"cairn":
			return _CAIRN
		"bell":
			return _BELL
		"lantern":
			return _LANTERN
		"mushroom":
			return _SHROOM
		"spring":
			return _SPRING
		"vista":
			return _VISTA
		"rune":
			return _RUNE
		"coin":
			return _COIN
		"flock":
			return _FLOCK
		"valve":
			return _VALVE
		"dummy":
			return _DUMMY
		"marked":
			return _MARK
		"wolf":
			return _WOLF
		"raven":
			return _RAVEN
		"fox":
			return _FOX
		"otter":
			return _OTTER
		"boar":
			return _BOAR
		"golem":
			return _GOLEM
		"town_house":
			return _TOWN_HOUSE
		"lagoon_palm":
			return _LAGOON_PALM
		"forest_camp":
			return _FOREST_CAMP
		"scorch_rock":
			return _SCORCH_ROCK
		# ---- Lagoon (tropical) ----
		"lagoon_dodo":
			return _LAGOON_DODO_B if frame % 2 == 1 else _LAGOON_DODO_A
		"lagoon_flamingo":
			return _LAGOON_FLAMINGO
		"lagoon_parrot":
			return _LAGOON_PARROT
		"lagoon_fish":
			return _LAGOON_FISH_B if frame % 2 == 1 else _LAGOON_FISH_A
		"lagoon_crab":
			return _LAGOON_CRAB
		"lagoon_egg":
			return _LAGOON_EGG
		"lagoon_shell":
			return _LAGOON_SHELL
		"lagoon_palm_hut":
			return _LAGOON_PALM_HUT
		"lagoon_fruit_tree":
			return _LAGOON_FRUIT_TREE
		"lagoon_shrine":
			return _LAGOON_SHRINE
		"lagoon_well":
			return _LAGOON_WELL
		"lagoon_bonfire":
			return _LAGOON_BONFIRE
		# ---- Forest (woodland) ----
		"forest_owl":
			return _FOREST_OWL
		"forest_wolf":
			return _FOREST_WOLF
		"forest_stag":
			return _FOREST_STAG
		"forest_fox":
			return _FOREST_FOX_B if frame % 2 == 1 else _FOREST_FOX_A
		"forest_badger":
			return _FOREST_BADGER
		"forest_rabbit":
			return _FOREST_RABBIT
		"forest_squirrel":
			return _FOREST_SQUIRREL
		"forest_beetle":
			return _FOREST_BEETLE
		"forest_hut":
			return _FOREST_HUT
		"forest_treehouse":
			return _FOREST_TREEHOUSE
		"forest_stump_shrine":
			return _FOREST_STUMP_SHRINE
		"forest_well":
			return _FOREST_WELL
		"forest_totem":
			return _FOREST_TOTEM
		"forest_bonfire":
			return _FOREST_BONFIRE_B if frame % 2 == 1 else _FOREST_BONFIRE_A
		# ---- Mountain (alpine) ----
		"mountain_yeti":
			return _MOUNTAIN_YETI_B if frame % 2 == 1 else _MOUNTAIN_YETI_A
		"mountain_goat":
			return _MOUNTAIN_GOAT
		"mountain_owl":
			return _MOUNTAIN_OWL
		"mountain_icebear":
			return _MOUNTAIN_ICEBEAR
		"mountain_wolf":
			return _MOUNTAIN_WOLF
		"mountain_lizard":
			return _MOUNTAIN_LIZARD
		"mountain_cairn":
			return _MOUNTAIN_CAIRN
		"mountain_icestorm":
			return _MOUNTAIN_ICESTORM_B if frame % 2 == 1 else _MOUNTAIN_ICESTORM_A
		"mountain_isometric_hut":
			return _MOUNTAIN_ISOMETRIC_HUT
		"mountain_igloo":
			return _MOUNTAIN_IGLOO
		"mountain_shrine":
			return _MOUNTAIN_SHRINE
		"mountain_well":
			return _MOUNTAIN_WELL
		"mountain_bonfire":
			return _MOUNTAIN_BONFIRE
		"mountain_tower":
			return _MOUNTAIN_TOWER
		_:
			return _SHARD


const _BUTTER_A := [
	"................",
	"....pp....pp....",
	"...pwwp..pwwp...",
	"...pwlwp.pwlwp..",
	"....pp.yy.pp....",
	"......yyyy......",
	".......yy.......",
	"......y..y......",
	".......nn.......",
	"......n..n......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _BUTTER_B := [
	"................",
	"......pppp......",
	"....pwwwwwwp....",
	"...pwwpwwpwwp...",
	"....pp.yy.pp....",
	"......yyyy......",
	".......yy.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _WISP_A := [
	"................",
	"......cc........",
	".....cwwc.......",
	"....cwwwwc......",
	".....cwwc.......",
	"......cc........",
	".....c..c.......",
	"....c....c......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _WISP_B := [
	"................",
	".......cc.......",
	"......cwwc......",
	".....cwwwwc.....",
	"......cwwc......",
	".......cc.......",
	"......b.........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _EMBER_A := [
	"................",
	"......mm........",
	".....mwwm.......",
	"....mrwwrm......",
	".....mrym.......",
	"......rr........",
	"......r.r.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _EMBER_B := [
	"................",
	".......yy.......",
	"......ywwy......",
	".....ymwwmy.....",
	"......yrmy......",
	".......rr.......",
	"........r.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _SHARD := [
	"................",
	".......c........",
	"......cic.......",
	".....ciwic......",
	"....ciwwwic.....",
	".....ciwic......",
	"......cic.......",
	".......c........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _FLY_A := [
	"................",
	"......y.........",
	".....ywy........",
	"......y.........",
	".....l..........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _FLY_B := [
	"................",
	".......y........",
	"......ywy.......",
	".......y........",
	"........l.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _IDOL := [
	"................",
	"......nnn.......",
	".....nkkkn......",
	".....nk.kn......",
	"......nnn.......",
	".....nsssn......",
	"....nsnnnsn.....",
	"....nnnnnnn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _CRATE := [
	"................",
	"....nnnnnnn.....",
	"....nkknkkn.....",
	"....nkkkkkn.....",
	"....nkknkkn.....",
	"....nnnnnnn.....",
	"....nddddn......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _COG := [
	"................",
	"......s.s.......",
	".....sssss......",
	"....ssykyss.....",
	".....sssss......",
	"......s.s.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _BEACON := [
	"................",
	".......y........",
	"......ywy.......",
	".......y........",
	"......sss.......",
	".....sssss......",
	"....ssnnnss.....",
	"....snnnnns.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _CAIRN := [
	"................",
	"......sss.......",
	".....sssss......",
	"....ssnnnss.....",
	".....snnns......",
	"....ssnnnss.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _BELL := [
	"................",
	".......k........",
	"......kkk.......",
	".....kyyyk......",
	".....kyyyk......",
	"......kkk.......",
	".......y........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _LANTERN := [
	"................",
	"......nn........",
	".....nmmn.......",
	".....nmym.......",
	".....nmmn.......",
	"......nn........",
	".......n........",
	"....gggggg......",
	"...glllllg......",
	"...g.l..l.g.....",
	"...g.l..l.g.....",
	"...glllllg......",
	"....gggggg......",
	"................",
	"................",
	"................",
]
const _SHROOM := [
	"................",
	".....rrrrr......",
	"....rwwrrwr.....",
	"...rrrwrrwrr....",
	"....rrrrrrr.....",
	"......nnn.......",
	"......nln.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _SPRING := [
	"................",
	"......bbb.......",
	".....bwwb.......",
	"....bwcwcb......",
	".....bggb.......",
	"....ggggg.......",
	"....g.ll.g......",
	"...g.l..l.g.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _VISTA := [
	"................",
	"....c....c......",
	"...ccc..ccc.....",
	"..cgggccgggc....",
	"..gggggggggg....",
	"..gnggggggng....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _RUNE := [
	"................",
	".....lllll......",
	".....l...l......",
	".....l.l.l......",
	".....l...l......",
	".....lllll......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _COIN := [
	"................",
	"......kkk.......",
	".....kyyyk......",
	".....kywyk......",
	".....kyyyk......",
	"......kkk.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _FLOCK := [
	"................",
	"...w...w...w....",
	"..www.www.www...",
	"...w...w...w....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _VALVE := [
	"................",
	".....s...s......",
	"......sss.......",
	".....ssyss......",
	"......sss.......",
	".....s...s......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _DUMMY := [
	"................",
	"......nnn.......",
	".....nwwwn......",
	".....nw.wn......",
	"......nnn.......",
	".....nsssn......",
	"....n.....n.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _MARK := [
	"................",
	"......rrr.......",
	".....r...r......",
	"....r..y..r.....",
	".....r...r......",
	"......rrr.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Improved pixel art for the town animals — bigger, more detailed, with clear
## silhouettes so they read as real creatures, not blobs.
const _WOLF := [
	"................",
	"..s....ss.......",
	".ss..ssssss.....",
	".s.sswwsss......",
	"..ssssssss......",
	"..sssssssss.....",
	"...ssssssss.....",
	"...ss..ss..s....",
	"....ss.s.ss.....",
	"....s...s..s....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _RAVEN := [
	"................",
	".....ss.........",
	"....ssss........",
	"...swyys........",
	"...sssss........",
	"..ssssss........",
	"..ssss.s........",
	"..sss...s.......",
	"...ss..s........",
	"..s...s.........",
	"..s.s.s.........",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _FOX := [
	"................",
	"..r....r........",
	".rr..rrr........",
	".rrrwwrr........",
	"..rryrrr........",
	"..rrrrrr........",
	"...rrrrrr.......",
	"...rr..rr.......",
	"....r..r........",
	"...rr..rr.......",
	"..r..rr..r......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Lagoon recruit: a teal water otter/axolotl with fins and a bright eye.
const _OTTER := [
	"................",
	"................",
	"...bbbb.........",
	"..bwwwwb........",
	".bwwcwwbb.......",
	".bwycwwbbb......",
	".bbbbbbbbbbb....",
	".bwwwwwwwwb.....",
	"..bbbbbbbb.b....",
	"..b..b..b.bb....",
	"...b..b..b......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Forest recruit: a brown boar with a white snout and bright tusks.
const _BOAR := [
	"................",
	"................",
	"..nn....n.......",
	".nnnnnnn........",
	".nwwwnnnnn......",
	".nwwwnnnnnn.....",
	".nnnnnnnnnnn....",
	".nwwwwwwnnnn....",
	"..nnnnnnnnnn.b..",
	"..n..n..n..b....",
	"...n..n..n......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Scorch recruit: a rocky golem with a glowing amber core.
const _GOLEM := [
	"................",
	"................",
	"....sssss.......",
	"...sssssss......",
	"...s.k.k.s......",
	"...sssssss......",
	"..ssykykys......",
	"...sssssss......",
	"...ss..ss.......",
	"...ss..ss.......",
	"...ss..ss.......",
	"................",
	"................",
	"................",
	"................",
	"................",
]

## ---- Recruit-area camp structures (isometric-ish, 16x16) ----------------------
## Town (top-left): a medieval isometric longhouse — thatched roof, timber frame,
## small windows, and a wooden door. 2x the visual weight of a tree.
const _TOWN_HOUSE := [
	"................",
	"........nn......",
	"......nnnn......",
	".....nnnnnn.....",
	"....nnnnnnnn....",
	"...nnnnnnnnnn...",
	"..kkkkkkkkkkkk..",
	".kkwkkwkkwkkkkk.",
	"kwnnnnnnnnwkwwk.",
	"kwnnyynnyykwkwk.",
	"kwnnyyyyyykwnwk.",
	"kwnnnnnnnnkwkww.",
	"kwnkkkkkkkkkkww.",
	".kkkkkkkkkkkkkk.",
	"..gggggggggggg..",
	"................",
]
## Lagoon (bottom-left): a tropical palm over turquoise water with a small reed bank.
const _LAGOON_PALM := [
	"................",
	".....gggg.......",
	"....ggggggg.....",
	"...ggggggggg....",
	"..ggggggggggg...",
	"..ggggggggggg...",
	"....nnnnnn......",
	".....nnnn.......",
	"......nn........",
	"......nn........",
	".....nnnn.......",
	"....nnnnnn......",
	"....iiiiiic.....",
	"...iiiiiiccc....",
	"...iiiiicccccc..",
	"................",
]
## Forest (top-right): a campsite — a striped tent with a campfire in front.
const _FOREST_CAMP := [
	"................",
	"......rr........",
	".....rryyrr.....",
	"....rryyryyr....",
	"...rryyryyrr....",
	"...rryrrrryr....",
	"..rryrrrrrryr...",
	"..ryrryrrrryrr..",
	".rrryyrrryyrrr..",
	".ryryrrrrryryrr.",
	".rrryryyrrryrr..",
	"rrrrrryryrrrrrr.",
	"..mm....mm......",
	"..mm..mm..mm....",
	"...rrrrrrrr.....",
	"................",
]
## Scorch (bottom-right): an obsidian spire with a molten crack, volcanic rock base.
const _SCORCH_ROCK := [
	"................",
	"......oo........",
	".....oooo.......",
	".....ommo.......",
	"....oommoo......",
	"....ommmo.......",
	"...ooomooo......",
	"...oommoo.......",
	"..ooooooo.......",
	"..ommmmmo.......",
	"..ooooooo.......",
	".oooomoooo......",
	".oommmmmmo......",
	"..ooooooo.......",
	"...sssss........",
	"................",
]


# ============================================================
# Area-themed fallback art (Lagoon / Forest / Mountain).
# These are TEMPORARY stand-ins so the dispatcher in _rows() compiles and the
# game runs while Builder A bakes the full themed pixel art. Each falls back to
# an existing creature/structure sprite with the right silhouette, so the areas
# still show "something themed" until the real art lands.
# ============================================================

# ---- Lagoon: creatures ----
## Dodo: plump cream bird with a pale crest, blue beak, and a little crest puff.
## 2-frame walk: A has feet tucked, B has legs spread.
const _LAGOON_DODO_A := [
	"................",
	".......ww.......",
	".....wwwww......",
	"....wwwwww......",
	"...wwwwwww......",
	"...wbwwwww......",
	"...wwwwwwww.....",
	"..wwwwwwwwww....",
	"..wwwwwwwwww....",
	"...wwwwwwww.....",
	"....wwwwww......",
	"......ww........",
	"................",
	"................",
	"................",
	"................",
]
const _LAGOON_DODO_B := [
	"................",
	".......ww.......",
	".....wwwww......",
	"....wwwwww......",
	"...wwwwwww......",
	"...wbwwwww......",
	"...wwwwwwww.....",
	"..wwwwwwwwww....",
	"..wwwwwwwwww....",
	"...wwwwwwww.....",
	"....wwwwww......",
	"......ww........",
	"....w...w.......",
	"................",
	"................",
	"................",
]
## Flamingo: tall coral-pink bird with a long curved neck and one raised leg.
const _LAGOON_FLAMINGO := [
	"................",
	".....ff.........",
	"....fff.........",
	"....f.f.........",
	"....f.f.........",
	"...f..f.........",
	"..fff..f........",
	".fffffff........",
	".ffffff.........",
	"..ffff..........",
	"...ffff.........",
	"....ff..........",
	"....ff..........",
	"....f...f.......",
	"................",
	"................",
]
## Parrot: small multi-coloured tropical bird — green body, blue wing, red beak.
const _LAGOON_PARROT := [
	"................",
	".......CC.......",
	"......CCbb......",
	".....Cbbbb......",
	"....Cbbbbrr.....",
	"....bbbb...r....",
	"....Cbbbb.......",
	".....bbbb.......",
	"......bbbb......",
	".......bb.......",
	"......CC........",
	".....CC.........",
	"................",
	"................",
	"................",
	"................",
]
## Fish A: a small tropical fish with a big tail fin (tail up).
const _LAGOON_FISH_A := [
	"................",
	"................",
	"....ee..........",
	"...eeee.........",
	"..eeeeee.e......",
	".ebwwwee.ee.....",
	".eeeeeeeeee.....",
	".eeeeee.eee.....",
	"..eeee.eee......",
	"...eeee.........",
	"....ee..........",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Fish B: tail flipped down for the second frame.
const _LAGOON_FISH_B := [
	"................",
	"................",
	"....ee..........",
	"...eeee.........",
	"..eeeeee........",
	".ebwwweeeee.....",
	".eeeeeeeeee.....",
	".eeeeee.ee......",
	"..eeee.ee.......",
	"...eeee.........",
	"....ee..........",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Crab: wide coral-red body with two claw pincers and short legs.
const _LAGOON_CRAB := [
	"................",
	"................",
	"................",
	"..z.....z.......",
	".zz.....zz......",
	"..z.....z.......",
	".zzzzzzzzz......",
	".zwwzzzzwz......",
	".zwwzzzzwz......",
	".zzzzzzzzz......",
	"..z..z..z.......",
	"..z..z..z.......",
	"................",
	"................",
	"................",
	"................",
]
## Egg: a single speckled tropical egg.
const _LAGOON_EGG := [
	"................",
	"................",
	"................",
	"................",
	".......ww.......",
	"......www.......",
	".....wwwww......",
	"....wwwww.......",
	"....wwwwww......",
	"....wwwww.......",
	"....wwww........",
	".....wwww.......",
	"......ww........",
	"................",
	"................",
	"................",
]
## Shell: a fan-shaped tropical scallop shell with ridges.
const _LAGOON_SHELL := [
	"................",
	"................",
	"................",
	"................",
	".....wwww.......",
	"....wEwwwEw.....",
	"...wEwwwwwwEw...",
	"...wEwwwwwwEw...",
	"..wEwEwEwEwEw...",
	"..wEwEwEwEwEw...",
	"...wwwwwwww.....",
	"....wwwwww......",
	".....wwww.......",
	"......ww........",
	"................",
	"................",
]
## Palm hut: a stilted tropical hut with a thatched palm roof and reed stilts.
const _LAGOON_PALM_HUT := [
	"................",
	"......nnnn......",
	".....nkkkn......",
	"....nkkkkkn.....",
	"...nkkkkkkkn....",
	"..nkkkkkkkkkn...",
	"...eeeeeeee.....",
	"...e.jjjj.j.....",
	"...j.j...j.j....",
	"...j.j...j.j....",
	"...j.j...j.j....",
	"..jj.jj.jj.jj...",
	"...j.j...j.j....",
	"...j.j...j.j....",
	"..jj.jj.jj.jj...",
	"................",
]
## Fruit tree: a tropical tree with a broad canopy and a few hanging fruit.
const _LAGOON_FRUIT_TREE := [
	"................",
	"....EEEEE.......",
	"...EEEEEEE......",
	"..EEEEEEEE..u...",
	"..EEEEEE.u.u....",
	"..EEEEEE.uu.....",
	"...EEEEEE.......",
	"....EEEEE.......",
	"......nn........",
	".....nnnn.......",
	"......nn........",
	"......nn........",
	"....nnnnnn......",
	"................",
	"................",
	"................",
]
## Lagoon shrine: a small stone shrine with a water basin and a glowing totem.
const _LAGOON_SHRINE := [
	"................",
	"................",
	".......ss.......",
	"......sccs......",
	".......ss.......",
	"....ssssss......",
	"...s......s.....",
	"...s.oo..s......",
	"...s.oo..s......",
	"...s.oo..s......",
	"...s......s.....",
	"....ssssss......",
	"....ssssss......",
	"...eeeeeee......",
	"...eccccce......",
	"................",
]
## Lagoon well: a stone well with a wooden roof and a rope.
const _LAGOON_WELL := [
	"................",
	"......nnnn......",
	".....nkkkn......",
	"....nkkkkkn.....",
	"......nnnn......",
	".....n..n.......",
	"....s..s........",
	"....s..s........",
	"....sss.s.......",
	"....s.s.s.......",
	"....s..s.s......",
	"....s..s.s......",
	"....sss.s.......",
	"....s..s........",
	"....s..s........",
	"....eeeeee......",
]
## Lagoon bonfire: a small beach campfire with coral embers.
const _LAGOON_BONFIRE := [
	"................",
	"................",
	"................",
	"................",
	".......mm.......",
	"......mzzm......",
	".....mzzmz......",
	"......mmm.......",
	"....nnnnnn......",
	"....n.nnn.n.....",
	"....n..n..n.....",
	".....n..n.......",
	"......nn........",
	"................",
	"................",
	"................",
]

# ---- Forest: creatures ----
## Owl: a round brown woodland owl with big amber eyes and ear tufts.
const _FOREST_OWL := [
	"................",
	"................",
	"....j....j......",
	"...jjjjjjj......",
	"..jjjjjjjjj.....",
	"..jjyjjjjyj.....",
	"..jjyjjjjyj.....",
	"...jjjjjjj......",
	"..jCCCCCCj......",
	"..jCCCCCCj......",
	"...jCCCCjj......",
	"....jjjjjj......",
	".....j..j.......",
	"....jj..jj......",
	"................",
	"................",
]
## Forest wolf: a slate-grey wolf — same species as the town wolf but a colder,
## blue-grey coat to read as "wild".
const _FOREST_WOLF := [
	"................",
	"..M....MM.......",
	".MM..MMMMM......",
	".M.MMWMMMM......",
	"..MMMMMMMM......",
	"..MMMMMMMMM.....",
	"...MMMMMMMM.....",
	"...MM..MM..M....",
	"....MM.M.MM.....",
	"....M...M..M....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Stag: a deer with a tan body and large branching antlers.
const _FOREST_STAG := [
	"................",
	".J..........J...",
	".JJ..........JJ.",
	".J.J....J....J..",
	".JJ....JJJJ.....",
	"...JJJJJJJJ.....",
	"..JJWWWJJJJ.....",
	".JJJJJJJJJJ.....",
	".JJJJJJJJJJJ....",
	".JJ..JJ..JJ.....",
	".JJ..JJ..JJ.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Fox A: a woodland fox with a bushy white-tipped tail.
const _FOREST_FOX_A := [
	"................",
	"..r....r........",
	".rr..rrr........",
	".rrrwwrr........",
	"..rryrrr........",
	"..rrrrrr........",
	"...rrrrrr.......",
	"...rr..rr.......",
	"....r..r........",
	"...rr..rr.......",
	"..r..rr..r......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Fox B: tail raised for the second walk frame.
const _FOREST_FOX_B := [
	"................",
	"..r....r........",
	".rr..rrr........",
	".rrrwwrr........",
	"..rryrrr........",
	"..rrrrrr........",
	"...rrrrrr.......",
	"...rr..rr.......",
	"....r..r........",
	"...rr..rr.......",
	".r...rr...r.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Badger: a stocky grey-brown animal with a white face stripe.
const _FOREST_BADGER := [
	"................",
	"................",
	"................",
	"..j....j........",
	".jjjjjjjjj......",
	".jwwjjjjwj......",
	".jjjjjjjjjj.....",
	".jwwjjjjwwj.....",
	".jjjjjjjjjj.....",
	".jj..jj..jj.....",
	".jj..jj..jj.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Rabbit: a small brown rabbit with long ears.
const _FOREST_RABBIT := [
	"................",
	"....J...J.......",
	"....JJ.JJ.......",
	"....JwJwJ.......",
	"...JwJwJwJ......",
	"...JwwwwwJ......",
	"...JwwwwwJ......",
	"....JwwwJ.......",
	".....JwJ........",
	"....J...J.......",
	"....J...J.......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Squirrel: a small red-brown squirrel with a big curved tail.
const _FOREST_SQUIRREL := [
	"................",
	"......J.........",
	".....JJJ........",
	"....JJJJ....J...",
	"....JJwwJJ.JJ...",
	"....JJwwJJJJ....",
	".....JJJJJJ.....",
	"......JJJJ......",
	".....JJ.JJ......",
	"....JJ...JJ.....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Beetle: a dark rounded beetle with a split shell and legs.
const _FOREST_BEETLE := [
	"................",
	"................",
	"................",
	"................",
	".....dddddd.....",
	"....dd.dddd.....",
	"...dd.dd.ddd....",
	"...dddddddd.....",
	"...dd.dd.ddd....",
	"....dd.dddd.....",
	".....dddddd.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Woodcutter cabin: a log cabin with a stone chimney and a door.
const _FOREST_HUT := [
	"................",
	"......nnn.......",
	"....nnnnnn......",
	"...nnnnnnnn.....",
	"..JhJhJhJhJ.....",
	".JhJhJhJhJhJ....",
	".JhJhJhJhJhJ....",
	".JhJhHJhJhJ.....",
	".JhJhHJhJhJ.....",
	".JhJhJhJhJhJ....",
	"..ggggggggg.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Tree hollow: a tree with a dark round doorway carved into the trunk.
const _FOREST_TREEHOUSE := [
	"................",
	"................",
	"....CCCCC.......",
	"..CCCCCCCCC.....",
	".CCCCCCCCCCC....",
	".CCCCCCCCCC C...",
	"..CCCCCCCCC.....",
	"....nnnnnn......",
	"...nnHHHHnn.....",
	"...nnH..Hnn.....",
	"...nnH..Hnn.....",
	"...nnHHHHnn.....",
	"...nnnnnnnn.....",
	"....nnnnnn......",
	"................",
	"................",
	"................",
]
## Mushroom ring: a fairy ring of small mushrooms on grass.
const _FOREST_STUMP_SHRINE := [
	"................",
	"................",
	"................",
	"................",
	"...rr...rr......",
	"..rwr...rwr.....",
	"..rwr...rwr.....",
	"...rr...rr......",
	"rr......rr......",
	"rwr.....rwr.....",
	"rwr.....rwr.....",
	"rr......rr......",
	"..gggggggggg....",
	"................",
	"................",
	"................",
]
## Forest well: a rustic stone well with a roof and a pulley.
const _FOREST_WELL := [
	"................",
	"......nnnn......",
	".....nkkkn......",
	"....nkkkkkn.....",
	"......nnnn......",
	".....n..n.......",
	"....s..s........",
	"....s..s........",
	"....sss.s.......",
	"....s.s.s.......",
	"....s..s.s......",
	"....s..s.s......",
	"....sss.s.......",
	"....s..s........",
	"....s..s........",
	"....CCCCCC......",
]
## Totem post: a tall carved wooden totem with a face.
const _FOREST_TOTEM := [
	"................",
	"....hhhhhh......",
	"....hwhhwh......",
	"....hhhhhh......",
	"....hyyyyh......",
	"....hhhhhh......",
	"....hwwwwh......",
	"....hhhhhh......",
	"....hwhhwh......",
	"....hhhhhh......",
	"....hyyyyh......",
	"....hhhhhh......",
	"....hhhhhh......",
	"................",
	"................",
	"................",
]
## Forest bonfire A: a flickering campfire — flames leaning left, logs below.
const _FOREST_BONFIRE_A := [
	"................",
	"................",
	"................",
	".......mm.......",
	"......mzm.......",
	".....mmzmz......",
	"....zzmzmz......",
	".....mmm........",
	"....nnnnnn......",
	"....n.nnn.n.....",
	"....n..n..n.....",
	".....n..n.......",
	"......nn........",
	"................",
	"................",
	"................",
]
## Forest bonfire B: flames leaning right for the flicker frame.
const _FOREST_BONFIRE_B := [
	"................",
	"................",
	"................",
	"......mm........",
	".....mzm........",
	"....mzmmz.......",
	"....zmmzmz......",
	".....mmm........",
	"....nnnnnn......",
	"....n.nnn.n.....",
	"....n..n..n.....",
	".....n..n.......",
	"......nn........",
	"................",
	"................",
	"................",
]

# ---- Mountain: creatures ----
## Yeti A: a big shaggy white creature crouched low, head tucked.
const _MOUNTAIN_YETI_A := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"....wwwwww......",
	"...wwwwwwwww....",
	"..wwowwwwwwow...",
	"..wwwwwwwwwww...",
	"..wwwwwwwwwww...",
	".wwwwwwwwwwwww..",
	".www..www..ww...",
	".ww....ww....w..",
	"................",
	"................",
	"................",
]
## Yeti B: yeti upright, head raised, standing taller.
const _MOUNTAIN_YETI_B := [
	"................",
	".....wwww.......",
	"....wwwwww......",
	"....wwooww......",
	"....wwwwww......",
	"....wwwwww......",
	"...wwwwwwwww....",
	"..wwwwwwwwwww...",
	"..wwwwwwwwwww...",
	".wwwwwwwwwwwww..",
	".wwwwwwwwwwwww..",
	".www..www..ww...",
	".ww....ww....w..",
	"................",
	"................",
	"................",
]
## Mountain goat: a sure-footed goat with curved horns.
const _MOUNTAIN_GOAT := [
	"................",
	"..O...O.........",
	"..O..OO.........",
	"..OOOOO.........",
	"...OOOO.........",
	"....OOOOO.......",
	"...OOOOOOOO.....",
	"..OOOOOOOOOO....",
	"..OO.OO..OO.O...",
	"..OO.OO..OO.....",
	"..OO.OO..OO.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Mountain owl: a snowy grey-brown raptor perched, big amber eyes.
const _MOUNTAIN_OWL := [
	"................",
	"...M....M.......",
	"..MMMMMM........",
	".MMMMMMMMM......",
	".MMAMMMAAM......",
	".MMAMMMAAM......",
	"..MMMMMMMM......",
	"..MWWWWWWWM.....",
	"..MWWWWWWWM.....",
	"...MWWWWWM......",
	"....MMMMMM......",
	".....M..M.......",
	"....MM..MM......",
	"................",
	"................",
	"................",
]
## Ice bear: a large white polar bear.
const _MOUNTAIN_ICEBEAR := [
	"................",
	"................",
	"...wwww.........",
	"..wwwwww........",
	".wwwowwwww......",
	".wwwwwwwwww.....",
	".wwwwwwwwwwww...",
	".wwwwwwwwwwww...",
	".wwwwwwwwwwww...",
	".ww..ww..ww.....",
	".ww..ww..ww.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Mountain wolf: a white-furred wolf.
const _MOUNTAIN_WOLF := [
	"................",
	"..w....ww.......",
	".ww..wwwww......",
	".w.wwwwwww......",
	"..wwwwwwww......",
	"..wwwwwwwww.....",
	"...wwwwwwww.....",
	"...ww..ww..w....",
	"....ww.w.ww.....",
	"....w...w..w....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Ice lizard: a small blue-green cold-blooded reptile.
const _MOUNTAIN_LIZARD := [
	"................",
	"................",
	"................",
	"................",
	"....E....E......",
	"...EE....EE.....",
	"....EEEEEE......",
	"...EEEEEEEE.....",
	"..EEEEEEEEEE....",
	"..EE..EE..EE....",
	"..EE..EE..EE....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Cairn: a stacked pile of alpine stones with a flag.
const _MOUNTAIN_CAIRN := [
	"................",
	"......r.........",
	"....rrrr........",
	".......s........",
	".....sss........",
	"....ssss........",
	"...ssssss.......",
	"..ssssssss......",
	".ssssssssss.....",
	"....ssss........",
	"...ssssss.......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Ice storm A: a swirling snowstorm vortex (spinning left).
const _MOUNTAIN_ICESTORM_A := [
	"................",
	"....c.........c.",
	"...cc.......cc..",
	"..c..cc...cc....",
	".cc....ww....c..",
	"..c..wwww....c..",
	"...cc.wWWw.cc...",
	"....cc.wWw.cc...",
	"......ccwwcc....",
	".....cc...cc....",
	"....c.......c...",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Ice storm B: vortex spun to the opposite side.
const _MOUNTAIN_ICESTORM_B := [
	"................",
	".c.........c....",
	"..cc.......cc...",
	"....cc...c..c...",
	"..c....ww....cc.",
	"..c....wwww...c.",
	"...cc.wWWw.cc...",
	"...cc.wWw.cc....",
	"....ccwwcc......",
	"....cc...cc.....",
	"...c.......c....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Isometric stone hut: a diamond-roofed alpine hut (isometric).
const _MOUNTAIN_ISOMETRIC_HUT := [
	"................",
	".......OO.......",
	".....OOOOWW.....",
	"...OOOOWWWWW....",
	"...OOWWWWWWW....",
	"..NNNWWWWWWNN...",
	"..NVVVVVVVVVN...",
	"..NVVwVVVVVVN...",
	"..NVVVVVVVVVN...",
	"...NNVVVVVN.....",
	"....NNNNNN......",
	"................",
	"................",
	"................",
	"................",
	"................",
]
## Igloo: a smooth white dome.
const _MOUNTAIN_IGLOO := [
	"................",
	"................",
	"................",
	"......OOOO......",
	"....OOOOOOOO....",
	"...OOOOOOOOOO...",
	"..OOOOWWWWWOOO..",
	"..OOWWWWWWWWWO..",
	".OOWWWWWWWWWWWO.",
	".OOWWWWwwWWWWOO.",
	".OWWWWWWWWWWWWO.",
	"..OOOOOOOOOOOO..",
	"...OOOOOOOOOO...",
	"....OOOOOOOO....",
	"................",
	"................",
]
## Mountain shrine: a stone cairn-shrine with glowing runes.
const _MOUNTAIN_SHRINE := [
	"................",
	"................",
	".......yy.......",
	"......syyss.....",
	".....ssssss.....",
	"....ss....ss....",
	"....s.ll.lls....",
	"....s.ll.lls....",
	"....s.ll.lls....",
	"....s.ll.lls....",
	"....ss....ss....",
	".....ssssss.....",
	"....ssssssss....",
	"................",
	"................",
	"................",
]
## Mountain well: an ice-rimmed stone well.
const _MOUNTAIN_WELL := [
	"................",
	"......OOOO......",
	"....OOOOOOOO....",
	"...OOWWWWWWWO...",
	"...OWWWWWWWWWO..",
	"....NWWWWWWWN...",
	"....NWWwwWWWN...",
	"....NWWWWWWWN...",
	"....NWWWWWWWN...",
	"....NWWwwWWWN...",
	"....NWWWWWWWN...",
	".....NNNNNN.....",
	"................",
	"................",
	"................",
	"................",
]
## Mountain bonfire: a cold-snow-bordered campfire.
const _MOUNTAIN_BONFIRE := [
	"................",
	"................",
	"................",
	".......mm.......",
	"......mzzm......",
	".....mzzmz......",
	"......mmm.......",
	"....nnnnnn......",
	"....n.nnn.n.....",
	"....n..n..n.....",
	".....n..n.......",
	"......nn........",
	"....OOOOOO......",
	"................",
	"................",
	"................",
]
## Lookout tower: a tall wooden watchtower on a rock base.
const _MOUNTAIN_TOWER := [
	"................",
	"....VVVVVV......",
	"....VwVVwV......",
	"....VVVVVV......",
	"...V......V.....",
	"...V..VV..V.....",
	"...V......V.....",
	"...V..VV..V.....",
	"...V......V.....",
	"...V..VV..V.....",
	"...VV....VV.....",
	"...VVVVVVVV.....",
	"..NNNNNNNNN.....",
	".NNNNNNNNNNNN...",
	"................",
	"................",
]
