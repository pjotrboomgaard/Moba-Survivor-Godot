extends SceneTree

## Bakes biome-specific themed props into 16x16 PNGs. Each biome gets props that
## fit its setting: volcano = fiery obsidian, ice = snow hills, factory = utility
## masts, docks = dock poles. Run: godot --headless --path . -s res://tools/gen_biome_props.gd

const OUT := "res://assets/sprites"

func _init() -> void:
	if not DirAccess.dir_exists_absolute(OUT):
		DirAccess.make_dir_recursive_absolute(OUT)
	# Volcano — fiery glowing rocks and black obsidian shards
	_write("volcano_rock_fiery", _VOLCANO_ROCK)
	_write("volcano_obsidian", _VOLCANO_OBSIDIAN)
	# Ice — snow-covered hills and frost-encrusted rocks
	_write("ice_snow_hill", _ICE_SNOW)
	_write("ice_frost_rock", _ICE_FROST)
	# Factory — industrial utility masts and radio towers
	_write("factory_mast", _FACTORY_MAST)
	_write("factory_tower", _FACTORY_TOWER)
	# Docks — wooden mooring poles and stacked barrels
	_write("docks_pole", _DOCKS_POLE)
	_write("docks_barrel_stack", _DOCKS_BARREL)
	print("Forged 8 biome props into %s" % OUT)
	quit(0)


func _write(id: String, rows: Array) -> void:
	var size := rows.size()
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == ".":
				continue
			img.set_pixel(x, y, _color_for(ch))
	var path := "%s/%s.png" % [OUT, id]
	img.save_png(path)
	print("Wrote %s (%dx%d)" % [path, size, size])


## Shared 16-char palette. Keys are single chars mapped to hex colors.
func _color_for(ch: String) -> Color:
	match ch:
		"o": return Color("1a1210")   # dark outline
		"s": return Color("3a2a1a")   # mid-dark earth
		"m": return Color("6b4a1a")   # mid earth
		"h": return Color("c9a227")   # highlight gold
		"g": return Color("ff7a29")   # hot orange (lava glow)
		"w": return Color("ffe14a")   # bright yellow (molten core)
		"r": return Color("c43018")   # deep red
		"R": return Color("e85a2a")   # bright red-orange
		"c": return Color("4f8fe0")   # blue
		"C": return Color("7fd4ff")   # light blue
		"i": return Color("d0e8f6")   # ice light
		"I": return Color("8ab0c8")   # ice mid
		"p": return Color("50f59e")   # green
		"P": return Color("3a6130")   # dark green
		"k": return Color("8b95a1")   # steel grey
		"K": return Color("3a3a40")   # dark steel
		"n": return Color("2a2018")   # dark brown
		"N": return Color("6b4a1a")   # brown
		"y": return Color("e85a2a")   # orange accent
		"Y": return Color("ff7a29")   # bright orange accent
		"l": return Color("ffffff")   # white (snow)
		"L": return Color("e4f2fa")   # light snow
		"b": return Color("1a3a58")   # dark blue (water/shadow)
		"B": return Color("3d6a8a")   # mid blue
		"d": return Color("1a0c08")   # darkest
		"D": return Color("2a1612")   # very dark
		"v": return Color("c45ec8")   # violet
		"V": return Color("7a3a90")   # dark violet
		"t": return Color("2c3038")   # factory dark
		"T": return Color("3e4650")   # factory mid
		"u": return Color("2bbfbe")   # teal glow
		"U": return Color("1a4a5a")   # dark teal
		"e": return Color("e85a2a")   # ember
		"E": return Color("ff4400")   # bright ember
		"z": return Color("8a6230")   # wood
		"Z": return Color("6b4a1a")   # dark wood
		"a": return Color("3a2a10")   # wood shadow
		"A": return Color("c9a227")   # wood highlight
		_ : return Color(0, 0, 0, 0)


## ---- Volcano: fiery glowing rock (16x16) ----
## A cracked boulder with glowing orange magma veins.
const _VOLCANO_ROCK := [
	"................",
	".....oooooo.......",
	"....ossssssso.....",
	"...ossgggggsso....",
	"...osgwwwgssso....",
	"..osgwwwwwwgso....",
	"..osgwwwwwggso....",
	"..ossggwwggssso...",
	"..osggrrrrgrsso...",
	"...osgrrrrgrso....",
	"...osgrrrrgrso....",
	"....ossggggso.....",
	".....ossssoo......",
	"......ooooo.......",
	"................",
	"................",
]

## ---- Volcano: obsidian shard cluster (16x16) ----
## Dark glassy black rocks with sharp facets.
const _VOLCANO_OBSIDIAN := [
	"................",
	"................",
	".....oooooo.....",
	"....odddddo.....",
	"...oddddKddo....",
	"...odKddKddo....",
	"..odKddKKdddo...",
	"..odddKddKddo...",
	"..odKdddKdddo...",
	"...oddddKddo....",
	"...odKddKddo....",
	"....odddddo.....",
	".....oooooo.....",
	"................",
	"................",
	"................",
]

## ---- Ice: snow-covered hill (16x16) ----
## A soft rounded mound of packed snow.
const _ICE_SNOW := [
	"................",
	"................",
	"......llll......",
	"....llllllll....",
	"...llllllllll...",
	"...liiiiiiill...",
	"..liiiiiiiiii...",
	"..liiiiiiiiii...",
	"..liiiiiiIiii...",
	"..liiiIiiIiii...",
	"...liiIiiiIi....",
	"....liiIiiI.....",
	".....liiii......",
	"......llll......",
	"................",
	"................",
]

## ---- Ice: frost-encrusted rock (16x16) ----
## A dark rock base with white frost patches on top.
const _ICE_FROST := [
	"................",
	".....oooooo.....",
	"....ollllllo....",
	"...ollllllllo...",
	"...oliIliIio....",
	"..oIIIIIIIIoo...",
	"..oIdddddddoo...",
	"..oddKdddKddo...",
	"..odKddKKdddo...",
	"...oddddKddo....",
	"...odKddKddo....",
	"....odddddo.....",
	".....oooooo.....",
	"................",
	"................",
	"................",
]

## ---- Factory: utility mast (16x16) ----
## A tall industrial pole with cross-arms and a blinking light.
const _FACTORY_MAST := [
	"......uu........",
	"......kt........",
	".....kttk.......",
	"....tktktt......",
	".....ktkt.......",
	"......kt........",
	"......kt........",
	"......kt........",
	"......kt........",
	"......kt........",
	"......kt........",
	"......kt........",
	".....ktktt......",
	"....ttttttt.....",
	"................",
	"................",
]

## ---- Factory: radio tower (16x16) ----
## A lattice-style radio antenna tower.
const _FACTORY_TOWER := [
	"......kk........",
	"......kt........",
	".....ktkt.......",
	".....kttk.......",
	"....ktkttk......",
	"....ktktkt......",
	".....ktttk......",
	"......ktk.......",
	"......kt........",
	"......kt........",
	"......kt........",
	".....ktkt.......",
	"....ktkttk......",
	"...tttttttt.....",
	"................",
	"................",
]

## ---- Docks: wooden mooring pole (16x16) ----
## A tall wooden post with a rope wrap.
const _DOCKS_POLE := [
	"......zz........",
	".....zzzz.......",
	".....zaaz.......",
	".....zzzz.......",
	".....zzaz.......",
	".....zzzz.......",
	".....zzazz......",
	".....zzzz.......",
	".....zzazz......",
	".....zzzz.......",
	".....zaaz.......",
	".....zzzz.......",
	"....zaaazz......",
	"....zzzzzz......",
	"................",
	"................",
]

## ---- Docks: stacked barrels (16x16) ----
## A neat stack of 4 wooden barrels (2x2).
const _DOCKS_BARREL := [
	"................",
	"................",
	"....aaaaaa......",
	"...aAzzzzAa.....",
	"...azzZZzza.....",
	"...azzZZzza.....",
	"...aAzzzzAa.....",
	"....aaaaaa......",
	"................",
	"....aaaaaa......",
	"...aAzzzzAa.....",
	"...azzZZzza.....",
	"...azzZZzza.....",
	"...aAzzzzAa.....",
	"....aaaaaa......",
	"................",
]
