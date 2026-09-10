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
			return _LAGOON_DODO
		"lagoon_flamingo":
			return _LAGOON_FLAMINGO
		"lagoon_parrot":
			return _LAGOON_PARROT
		"lagoon_fish":
			return _LAGOON_FISH
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
			return _FOREST_FOX
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
			return _FOREST_BONFIRE
		# ---- Mountain (alpine) ----
		"mountain_yeti":
			return _MOUNTAIN_YETI
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
			return _MOUNTAIN_ICESTORM
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

# Lagoon — birds/animals use the raven silhouette, structures use the palm.
const _LAGOON_DODO := _RAVEN
const _LAGOON_FLAMINGO := _OTTER
const _LAGOON_PARROT := _RAVEN
const _LAGOON_FISH := _FLOCK
const _LAGOON_CRAB := _WOLF
const _LAGOON_EGG := _COIN
const _LAGOON_SHELL := _COIN
const _LAGOON_PALM_HUT := _LAGOON_PALM
const _LAGOON_FRUIT_TREE := _LAGOON_PALM
const _LAGOON_SHRINE := _SCORCH_ROCK
const _LAGOON_WELL := _SCORCH_ROCK
const _LAGOON_BONFIRE := _SCORCH_ROCK

# Forest — woodland creatures reuse wolf/fox, structures reuse the forest camp.
const _FOREST_OWL := _RAVEN
const _FOREST_WOLF := _WOLF
const _FOREST_STAG := _BOAR
const _FOREST_FOX := _FOX
const _FOREST_BADGER := _OTTER
const _FOREST_RABBIT := _FOX
const _FOREST_SQUIRREL := _FOX
const _FOREST_BEETLE := _WOLF
const _FOREST_HUT := _FOREST_CAMP
const _FOREST_TREEHOUSE := _FOREST_CAMP
const _FOREST_STUMP_SHRINE := _SCORCH_ROCK
const _FOREST_WELL := _SCORCH_ROCK
const _FOREST_TOTEM := _SCORCH_ROCK
const _FOREST_BONFIRE := _SCORCH_ROCK

# Mountain — alpine creatures reuse the golem for the heavy hitters.
const _MOUNTAIN_YETI := _GOLEM
const _MOUNTAIN_GOAT := _BOAR
const _MOUNTAIN_OWL := _RAVEN
const _MOUNTAIN_ICEBEAR := _GOLEM
const _MOUNTAIN_WOLF := _WOLF
const _MOUNTAIN_LIZARD := _WOLF
const _MOUNTAIN_CAIRN := _SCORCH_ROCK
const _MOUNTAIN_ICESTORM := _SCORCH_ROCK
const _MOUNTAIN_ISOMETRIC_HUT := _SCORCH_ROCK
const _MOUNTAIN_IGLOO := _SCORCH_ROCK
const _MOUNTAIN_SHRINE := _SCORCH_ROCK
const _MOUNTAIN_WELL := _SCORCH_ROCK
const _MOUNTAIN_BONFIRE := _SCORCH_ROCK
const _MOUNTAIN_TOWER := _SCORCH_ROCK
