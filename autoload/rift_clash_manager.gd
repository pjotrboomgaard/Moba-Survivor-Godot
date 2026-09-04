## Four-corner FFA / Rift Clash: each peer is its own team, creeps spawn on that
## team's lane, and the first hero to GameRuntime.FFA_KILLS_TO_WIN rival kills wins.

extends Node

const TEAM_COUNT := 4
const CORNER_NAMES := ["NW", "NE", "SW", "SE"]
const TEAM_NAMES := ["Amber", "Cyan", "Violet", "Lime"]
const TEAM_COLORS := [
	Color("e8a23a"),
	Color("4ec4e8"),
	Color("c47bff"),
	Color("8ee04a"),
]
const SPAWN_INSET := 0.74
const LANE_FOCUS := 0.38

var assigned_teams: Dictionary = {}
var team_anchors: Dictionary = {}
var team_eliminated: Dictionary = {}
var hero_kills: Dictionary = {}
var winner_peer_id := 0


func reset_match() -> void:
	assigned_teams.clear()
	team_anchors.clear()
	team_eliminated.clear()
	hero_kills.clear()
	winner_peer_id = 0
	layout_anchors(Arena.playfield_size() * 0.5)


func layout_anchors(half: Vector2) -> void:
	var inset := Vector2(half.x * SPAWN_INSET, half.y * SPAWN_INSET)
	team_anchors[0] = Vector2(-inset.x, -inset.y)
	team_anchors[1] = Vector2(inset.x, -inset.y)
	team_anchors[2] = Vector2(-inset.x, inset.y)
	team_anchors[3] = Vector2(inset.x, inset.y)


func assign_teams(peer_ids: Array, _lobby_claims: Dictionary) -> void:
	assigned_teams.clear()
	var sorted: Array = peer_ids.duplicate()
	sorted.sort()
	var slot := 0
	for pid in sorted:
		assigned_teams[int(pid)] = slot % TEAM_COUNT
		if not hero_kills.has(int(pid)):
			hero_kills[int(pid)] = 0
		slot += 1
	if team_anchors.is_empty():
		layout_anchors(Arena.playfield_size() * 0.5)


func team_of(peer_id: int) -> int:
	return int(assigned_teams.get(peer_id, peer_id)) % TEAM_COUNT


func team_name(team_id: Variant) -> String:
	var index := int(team_id) % TEAM_COUNT
	return str(TEAM_NAMES[index])


func team_corner_name(team_id: Variant) -> String:
	return str(CORNER_NAMES[int(team_id) % TEAM_COUNT])


func team_color(team_id: Variant) -> Color:
	return TEAM_COLORS[int(team_id) % TEAM_COUNT]


func team_anchor(team_id: Variant) -> Vector2:
	var index := int(team_id) % TEAM_COUNT
	if team_anchors.is_empty():
		layout_anchors(Arena.playfield_size() * 0.5)
	return Vector2(team_anchors.get(index, Vector2.ZERO))


func is_team_eliminated(team_id: Variant) -> bool:
	if GameRuntime.is_ffa():
		return false
	return bool(team_eliminated.get(int(team_id), false))


func mark_team_eliminated(team_id: Variant) -> void:
	if GameRuntime.is_ffa():
		return
	team_eliminated[int(team_id)] = true


func record_hero_kill(killer_peer_id: int) -> int:
	var next := int(hero_kills.get(killer_peer_id, 0)) + 1
	hero_kills[killer_peer_id] = next
	if winner_peer_id == 0 and next >= GameRuntime.FFA_KILLS_TO_WIN:
		winner_peer_id = killer_peer_id
	return next


func kills_of(peer_id: int) -> int:
	return int(hero_kills.get(peer_id, 0))


func has_winner() -> bool:
	return winner_peer_id != 0


func apply_local_result(_local_peer_id: Variant) -> void:
	pass


func placements() -> Array:
	var rows: Array = []
	for pid in assigned_teams.keys():
		var team := team_of(int(pid))
		rows.append({
			"placement": 0,
			"name": "%s %s" % [team_name(team), team_corner_name(team)],
			"players": [int(pid)],
			"kills": kills_of(int(pid)),
			"team_id": team,
		})
	rows.sort_custom(func(a, b): return int(a.kills) > int(b.kills))
	for index in rows.size():
		rows[index].placement = index + 1
	return rows


## Creep waves march from this team's spawn toward the nearest contested landmark.
func spawn_focus_for_team(team_id: Variant) -> Vector2:
	var home := team_anchor(team_id)
	var mid := nearest_landmark_from(home)
	if mid == Vector2.ZERO:
		return home * (1.0 - LANE_FOCUS)
	return home.lerp(mid, LANE_FOCUS)


func nearest_landmark_from(origin: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_dist := INF
	for spot in Arena.contested_landmark_spots():
		var dist := origin.distance_squared_to(spot)
		if dist < best_dist:
			best_dist = dist
			best = spot
	return best
