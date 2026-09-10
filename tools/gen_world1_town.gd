extends SceneTree

## Authors a starter World 1 (grass) level with a little town in the top-left
## quadrant: 8 distinct buildings arranged around a central square, a well in the
## middle, a sand/dirt floor under the square, accent trees, rocks, and a campfire.
##
## Run: godot --headless --path . -s res://tools/gen_world1_town.gd
## Output: user://world_editor_level.json  (World 1 = biome_id 0)

const OUT := "user://world_editor_level.json"

# Top-left quadrant of an 8400x5600 map. Town centered at ~ (820, 760).
const TOWN_CENTER := Vector2(820.0, 760.0)


func _init() -> void:
	var obstacles: Array = []
	var landmarks: Array = []
	var features: Array = []

	# --- Central square: sand/dirt floor tiles (floor_cover, no collision). ---
	var step := 72.0
	var half := 180.0
	var i := 0
	while i < 25:
		var dx := -half + step * float(i % 5)
		var dy := -half + step * float(i / 5)
		obstacles.append({
			"pos": [TOWN_CENTER.x + dx, TOWN_CENTER.y + dy],
			"sprite": "dirt_tile",
		})
		i += 1

	# --- 8 distinct buildings arranged in a ring around the square. ---
	var ring := 210.0
	var buildings: Array = [
		["town_house", 0.0],
		["town_shop", 45.0],
		["town_house2", 90.0],
		["town_church", 135.0],
		["town_cottage", 180.0],
		["town_house3", 225.0],
		["town_shop", 270.0],
		["town_house", 315.0],
	]
	for b in buildings:
		var a: float = deg_to_rad(float(b[1]))
		var pos := TOWN_CENTER + Vector2.from_angle(a) * ring
		obstacles.append({
			"pos": [pos.x, pos.y],
			"sprite": str(b[0]),
		})

	# --- Well at the exact center of the square. ---
	obstacles.append({
		"pos": [TOWN_CENTER.x, TOWN_CENTER.y],
		"sprite": "town_well",
	})

	# --- Accent trees framing the town (outside the ring). ---
	var frame := 420.0
	for angle in [30.0, 105.0, 165.0, 210.0, 285.0, 345.0]:
		var a: float = deg_to_rad(angle)
		var pos := TOWN_CENTER + Vector2.from_angle(a) * frame
		obstacles.append({
			"pos": [pos.x, pos.y],
			"sprite": "tree_oak",
		})
	# A couple of rocks + a campfire for life.
	for angle in [70.0, 250.0]:
		var a: float = deg_to_rad(angle)
		var pos := TOWN_CENTER + Vector2.from_angle(a) * (frame + 60.0)
		obstacles.append({
			"pos": [pos.x, pos.y],
			"sprite": "rock_small",
		})
	features.append({
		"pos": [TOWN_CENTER.x - 130.0, TOWN_CENTER.y + 130.0],
		"id": "grass_campfire",
	})

	var data := {
		"obstacles": obstacles,
		"landmarks": landmarks,
		"features": features,
		"biome": 0,
	}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("[gen_world1_town] wrote %d obstacles + %d features -> %s" % [obstacles.size(), features.size(), OUT])
	quit(0)
