extends Node2D

## Four distinct RECRUITMENT areas, one per arena corner, each themed to a
## region of the map. This is separate from the "fight to farm" combat creep
## camps (creep_camp.gd): here the creeps are neutral and can be RECRUITED into
## the player's team after the player completes a simple on-site quest.
##
##   top-left    -> Town       (wolf)     friendly town animal
##   bottom-left -> Lagoon     (flamingo) tropical water bird
##   top-right   -> Forest     (stag)     forest beast
##   bottom-right-> Mountain   (goat)     alpine sure-footed goat
##
## Each area shows its recruit creeps idle near a ground marker, lingering and
## doing a small wander (no aggro) until recruited. Standing in the area for
## BOND_SECONDS "befriends" them; on completion the creeps become friendly_minion
## allies that follow the player and fight enemies + enemy heroes + other teams'
## minions. Each player can recruit each area once.

const BOND_SECONDS := 3.0
const BOND_RADIUS := 170.0
## How many distinct recruit creeps stand in each area (3 each: a "lead", a "kit",
## and a "scout" so the areas read as a small camp, not a lone dot).
const CREEPS_PER_AREA := 3
## Recruit allies live long but not forever.
const RECRUIT_LIFETIME := 120.0

## Area definitions: art id (recruit creature), structure art id (the themed camp
## building/prop shown at the area), display name, marker accent color.
## Each area lists up to 3 candidate creature art ids: "art" is the lead recruit
## (biggest, slot 0), "alt_1"/"alt_2" fill the smaller kit + scout slots. Each
## slot is looked up in SideQuestArt; an empty id means that slot is skipped
## (never a blank dot).
const AREAS: Array[Dictionary] = [
	{"name": "Town",     "art": "wolf",       "alt_1": "fox",    "alt_2": "raven",  "structure": "town_house",             "accent": Color("8fae6a"), "corner": Vector2(-1.0, -1.0)},
	{"name": "Lagoon",   "art": "lagoon_flamingo", "alt_1": "lagoon_dodo", "alt_2": "lagoon_crab", "structure": "lagoon_palm_hut", "accent": Color("5ad4ff"), "corner": Vector2(-1.0,  1.0)},
	{"name": "Forest",   "art": "forest_stag",  "alt_1": "forest_owl",  "alt_2": "forest_squirrel", "structure": "forest_hut",             "accent": Color("7dbb5a"), "corner": Vector2( 1.0, -1.0)},
	{"name": "Mountain", "art": "mountain_goat","alt_1": "mountain_yeti", "alt_2": "mountain_wolf", "structure": "mountain_isometric_hut", "accent": Color("a8c8e0"), "corner": Vector2( 1.0,  1.0)},
]

var _main: Node = null
var _arena: Node2D = null
var _area_positions: Array[Vector2] = []
var _area_markers: Array = []
## Themed camp structure at each area (building/palm/tent/spire).
var _area_structures: Array = []
## Recruit candidate sprites: index -> array of Sprite2D still in "idle" state.
var _recruit_sprites: Array = []
## Which players have already recruited each area: index -> Array[int] peer_ids.
var _recruited_by: Array = []
## BOND progress per (peer_id, area_index) for the HUD hint.
var _bond_progress: Dictionary = {}
var _enabled := false

func start(main_node: Node, arena_node: Node2D) -> void:
	_main = main_node
	_arena = arena_node
	if _main == null or _arena == null:
		push_warning("RecruitAreas: main or arena null, disabled.")
		return
	if not _arena.has_method("half_extents"):
		push_warning("RecruitAreas: arena.half_extents missing, disabled.")
		return

	_area_positions = _build_positions()
	_build_markers()
	_spawn_structures()
	_spawn_recruits()
	_enabled = true


func _build_positions() -> Array[Vector2]:
	var half: Vector2 = _arena.half_extents()
	if half.x < 80.0 or half.y < 80.0:
		half = Vector2(2360.0, 1560.0) * 0.5
	var out: Array[Vector2] = []
	for i in AREAS.size():
		var corner: Vector2 = AREAS[i]["corner"]
		# Sit each area well inside the walkable field (~60% of half-extent) so it
		# is comfortably reachable and not clamped against the corner walls.
		out.append(Vector2(corner.x * half.x * 0.60, corner.y * half.y * 0.60))
	return out


## A themed camp structure (medieval house, tropical palm, campsite, obsidian
## spire) sits at each recruit area so the corner reads as a distinct, inhabited
## region — not just a ring on the ground. Rendered low so the recruit creeps and
## the walking player stay in front of it.
func _spawn_structures() -> void:
	for i in _area_positions.size():
		var structure_art := str(AREAS[i].get("structure", ""))
		if structure_art.is_empty():
			continue
		var tex: Texture2D = SideQuestArt.texture(structure_art)
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.z_as_relative = false
		# Sit just behind the recruit creeps so it reads as the "home" they live at.
		spr.z_index = 4
		# Larger than a tree (tree scale ~3-4x); 2x a tree reads as a building.
		spr.scale = Vector2(7.0, 7.0)
		spr.position = _area_positions[i] - Vector2(0.0, 10.0)
		add_child(spr)
		_area_structures.append(spr)


func _build_markers() -> void:
	for i in _area_positions.size():
		var accent: Color = AREAS[i]["accent"]
		var spr := Sprite2D.new()
		spr.texture = _make_marker(accent)
		spr.position = _area_positions[i]
		spr.z_index = 3700
		spr.z_as_relative = false
		add_child(spr)
		_area_markers.append(spr)


func _make_marker(accent: Color) -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var p := Vector2(x - c, y - c)
			var d := p.length()
			var a := 0.0
			# A soft ground pad + ring so the area reads as "something lives here".
			if d <= 24.0:
				a = 0.06
			elif d <= 22.0 and d >= 20.0:
				a = 0.32
			elif d <= 4.0:
				a = 0.5
			if a > 0.0:
				var col := accent.lerp(Color.WHITE, 0.3)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func _spawn_recruits() -> void:
	for i in _area_positions.size():
		var sprites: Array = []
		var accent: Color = AREAS[i]["accent"]
		# Per-slot art ids: slot 0 = "art" (lead), slot 1 = alt_1 (kit), slot 2 = alt_2 (scout).
		var slot_arts := [str(AREAS[i]["art"]), str(AREAS[i].get("alt_1", "")), str(AREAS[i].get("alt_2", ""))]
		for slot in CREEPS_PER_AREA:
			# Three distinct-looking creatures per camp: one bigger "lead" plus two
			# smaller "kit"/"scout" of different species, offset around the marker.
			var spr := Sprite2D.new()
			spr.z_as_relative = false
			spr.z_index = 6
			var scale := 4.2 if slot == 0 else 3.0
			spr.scale = Vector2(scale, scale)
			var offset := Vector2.RIGHT.rotated(slot * 2.4 + i) * 26.0
			spr.position = _area_positions[i] + offset
			# Idle wander + gentle bob so they read as alive, not static props.
			spr.set_meta("recruit_base", _area_positions[i] + offset)
			spr.set_meta("recruit_seed", float(randf() * 10.0))
			spr.set_meta("area_index", i)
			# Distinct silhouette per species via SideQuestArt.
			var art: String = slot_arts[slot]
			var tex := SideQuestArt.texture(art) if art != "" else null
			if tex == null:
				tex = SideQuestArt.texture(str(AREAS[i]["art"]))
			if tex != null:
				spr.texture = tex
			else:
				spr.texture = _fallback_dot(accent)
			# A subtle accent outline ring under the sprite so each area's
			# recruits are distinguishable even from a distance.
			var ring := Sprite2D.new()
			ring.z_as_relative = false
			ring.z_index = 5
			ring.position = spr.position
			ring.texture = _make_recruit_ring(accent, 0.4 if slot == 0 else 0.25)
			add_child(ring)
			spr.set_meta("ring", ring)
			add_child(spr)
			sprites.append(spr)
		_recruit_sprites.append(sprites)
		_recruited_by.append([])


func _fallback_dot(accent: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c := 8.0
	for y in 16:
		for x in 16:
			var d := Vector2(x - c, y - c).length()
			if d <= 5.0:
				img.set_pixel(x, y, accent)
			elif d <= 6.0:
				img.set_pixel(x, y, Color(accent.r, accent.g, accent.b, 0.4))
	return ImageTexture.create_from_image(img)


func _make_recruit_ring(accent: Color, alpha: float) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d <= 12.0 and d >= 10.5:
				img.set_pixel(x, y, Color(accent.r, accent.g, accent.b, alpha))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if not _enabled:
		return
	# Idle wander: bob each still-recruitable recruit around its base position.
	for sprites in _recruit_sprites:
		for spr in sprites:
			if not is_instance_valid(spr):
				continue
			var base: Vector2 = spr.get_meta("recruit_base", Vector2.ZERO)
			var seed: float = float(spr.get_meta("recruit_seed", 0.0))
			var t := Time.get_ticks_msec() / 1000.0 + seed
			var wob := Vector2(sin(t * 0.9), cos(t * 0.7)) * 6.0
			spr.global_position = base + wob
			var ring: Sprite2D = spr.get_meta("ring")
			if is_instance_valid(ring):
				ring.global_position = base + wob

	_try_recruit_all_players()


## Each player standing in an area for BOND_SECONDS recruits that area's creeps.
func _try_recruit_all_players() -> void:
	var players: Dictionary = _main.get("players")
	if players == null:
		return
	for peer_id in players.keys():
		var p: Node2D = players.get(peer_id)
		if p == null or not is_instance_valid(p):
			continue
		var health := p.get_node_or_null("HealthComponent")
		if health != null and bool(health.get("is_dead")):
			continue
		for i in _area_positions.size():
			# Already recruited by this player? skip.
			if (_recruited_by[i] as Array).has(int(peer_id)):
				continue
			if not is_instance_valid(_first_valid_sprite(_recruit_sprites[i])):
				continue  # area already fully recruited by someone else
			var pos: Vector2 = p.global_position
			if pos.distance_to(_area_positions[i]) > BOND_RADIUS:
				_bond_progress.erase(_key(peer_id, i))
				continue
			var key := _key(peer_id, i)
			var dt := get_process_delta_time()
			_bond_progress[key] = minf(BOND_SECONDS, float(_bond_progress.get(key, 0.0)) + dt)
			if float(_bond_progress[key]) >= BOND_SECONDS:
				_recruit_area(i, peer_id, p)


func _key(peer_id: Variant, area_index: int) -> String:
	return "%s:%d" % [peer_id, area_index]


func _first_valid_sprite(sprites: Array) -> Node:
	for s in sprites:
		if is_instance_valid(s):
			return s
	return null


## Convert an area's idle recruit sprites into a friendly_minion ally for the
## given player. Frees the sprites and the ring, spawns the minion.
func _recruit_area(area_index: int, peer_id: int, player: Node2D) -> void:
	var roster: Array = _recruited_by[area_index]
	if roster.has(int(peer_id)):
		return
	# Remove this player's bond progress.
	_bond_progress.erase(_key(peer_id, area_index))
	roster.append(int(peer_id))

	# Free the idle sprites + rings.
	for s in _recruit_sprites[area_index]:
		if not is_instance_valid(s):
			continue
		var ring: Sprite2D = s.get_meta("ring")
		if is_instance_valid(ring):
			ring.queue_free()
		s.queue_free()
	_recruit_sprites[area_index] = []

	# Spawn the recruited ally. Set art_id/stats BEFORE add_child so _build_sprite
	# (run in _ready) picks up the correct species art, not the generic circle.
	var art: String = str(AREAS[area_index]["art"])
	var accent: Color = AREAS[area_index]["accent"]
	var MinionScript: Variant = load("res://scripts/friendly_minion.gd")
	var minion: Variant = MinionScript.new()
	# Set art_id/stats BEFORE add_child (via .set so the typed-Node2D static
	# analyser won't reject the property lookups).
	minion.set("art_id", art)
	minion.set("hp", 150.0)
	minion.set("attack_damage", 32.0)
	minion.set("attack_interval", 0.55)
	minion.set("can_attack_heroes", true)
	# Parent to the same host as the enemies (main.actors if present).
	var host: Node = _main.get("actors")
	if host == null or not is_instance_valid(host):
		host = _main
	host.add_child(minion as Node)
	var minion_nd: Node2D = minion
	minion_nd.global_position = _area_positions[area_index]
	(minion as Object).call("configure", _main, int(peer_id), minion_nd.global_position)
	(minion as Object).call("set_lifetime", RECRUIT_LIFETIME)

	# HUD hint.
	_announce(area_index, art)


func _announce(area_index: int, art: String) -> void:
	var name := str(AREAS[area_index]["name"])
	var label := "recruited"
	# Prefer a localized-looking title per art.
	match art:
		"wolf":
			label = "wolf pup"
		"fox":
			label = "town fox"
		"raven":
			label = "town raven"
		"otter":
			label = "lagoon otter"
		"boar":
			label = "forest boar"
		"golem":
			label = "scorch golem"
		"lagoon_flamingo":
			label = "lagoon flamingo"
		"lagoon_dodo":
			label = "lagoon dodo"
		"lagoon_crab":
			label = "lagoon crab"
		"forest_stag":
			label = "forest stag"
		"forest_owl":
			label = "forest owl"
		"forest_squirrel":
			label = "forest squirrel"
		"mountain_goat":
			label = "mountain goat"
		"mountain_yeti":
			label = "mountain yeti"
		"mountain_wolf":
			label = "mountain wolf"
	# main owns the HUD; hand off the banner there (only the session authority /
	# local player sees it, avoiding duplicate flashes in co-op).
	if _main != null and _main.has_method("flash_recruit_joined"):
		_main.flash_recruit_joined(name, label, AREAS[area_index]["accent"])


func area_positions() -> Array[Vector2]:
	return _area_positions


## Bot-facing helper: nearest recruit area this player has not yet claimed, with
## the position and remaining bond info. Returns {index, pos, claimed} (claimed=true
## means already recruited this run). If all areas are claimed, index=-1.
func nearest_unclaimed_area(peer_id: int, from_pos: Vector2) -> Dictionary:
	var best_index := -1
	var best_dist := INF
	for i in _area_positions.size():
		if (_recruited_by[i] as Array).has(int(peer_id)):
			continue
		if not is_instance_valid(_first_valid_sprite(_recruit_sprites[i])):
			continue
		var d := from_pos.distance_to(_area_positions[i])
		if d < best_dist:
			best_dist = d
			best_index = i
	if best_index < 0:
		return {"index": -1, "pos": Vector2.ZERO, "claimed": true}
	return {
		"index": best_index,
		"pos": _area_positions[best_index],
		"claimed": false,
		"bond_seconds": BOND_SECONDS,
		"radius": BOND_RADIUS,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_main = null
		_arena = null
