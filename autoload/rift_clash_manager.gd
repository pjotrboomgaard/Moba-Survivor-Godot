extends Node

## Server-side + shared math for Rift Clash, the ranked team FFA overlay.
##
## The world has one instance of every system (Arena, WaveDirector nodes, players, enemies)
## like co-op, but spawns are partitioned: every team owns a corner of the arena, its own
## WaveDirector fans waves into that corner, and `wave_focus` swap-outs steer roaming
## enemies back at the raiding team when a rival walks in. Team data itself is owned by
## NetworkService (Steam lobby member data); this class only interprets it and resolves
## the match into RankService points.

signal teams_assigned(teams: Dictionary)
signal match_resolved(placements: Array)

## Up to 4 corners on a 4-team field; fewer teams use the first N corners.
const TEAM_KEYS := ["a", "b", "c", "d"]
## Human labels match the compass direction of the corner on the default field.
const TEAM_NAMES := {
	"a": "Amber",
	"b": "Bermuda",
	"c": "Crimson",
	"d": "Dusk",
}
const TEAM_COLORS := {
	"a": Color("e8b04a"),
	"b": Color("3fa8c4"),
	"c": Color("c4504a"),
	"d": Color("7a68c8"),
}

## Teams huddle in a square at this distance from the arena corner.
const CORNER_HUDDLE_RADIUS := 220.0
## Enemies bound to a team prefer targets inside this many px of that team's anchor.
const TEAM_FOCUS_RADIUS := 1200.0

var assigned_teams: Dictionary = {}  # peer_id -> "a"|"b"|"c"|"d"
var team_eliminated: Dictionary = {}  # team_id -> true
var match_over := false
var match_winner := ""


func reset_match() -> void:
	assigned_teams.clear()
	team_eliminated.clear()
	match_over = false
	match_winner = ""


## Assign teams deterministically for both transports: Steam uses lobby member data,
## offline/ENet falls back to round-robin over connected players. Called on the server
## just before the first enemy spawns.
func assign_teams(peer_ids: Array, claims: Dictionary = {}) -> Dictionary:
	var next: Dictionary = {}
	var steam_teams := {}
	if NetworkService.is_rift_clash_lobby():
		NetworkService.refresh_team_assignments()
		steam_teams = NetworkService.teams()
	var chosen_index := 0
	for peer_id in peer_ids:
		var team := ""
		if claims.has(peer_id):
			team = str(claims[peer_id])
		if team == "" and steam_teams.has(peer_id):
			team = str(steam_teams[peer_id])
		if not TEAM_KEYS.has(team):
			team = str(TEAM_KEYS[chosen_index % TEAM_KEYS.size()])
			chosen_index += 1
		next[peer_id] = team
	assigned_teams = next
	teams_assigned.emit(next.duplicate())
	return next


func team_of(peer_id: int) -> String:
	return str(assigned_teams.get(peer_id, "a"))


func team_name(team_id: String) -> String:
	return str(TEAM_NAMES.get(team_id, team_id.to_upper()))


func team_color(team_id: String) -> Color:
	return TEAM_COLORS.get(team_id, Color.WHITE)


## Human label for which arena quadrant a corner sits in — "NW", "NE", "SE", or "SW".
func team_corner_name(team_id: String) -> String:
	match maxi(0, TEAM_KEYS.find(team_id)):
		0:
			return "NW"
		1:
			return "NE"
		2:
			return "SE"
		_:
			return "SW"


func active_teams() -> Array[String]:
	var seen: Array[String] = []
	for peer_id in assigned_teams.keys():
		var team := str(assigned_teams[peer_id])
		if not seen.has(team):
			seen.append(team)
	seen.sort()
	return seen


## Corner anchor for a team in the game's current playfield. Derived from
## Arena.playfield_size() at call time so biome growth stays free.
func team_anchor(team_id: String) -> Vector2:
	var half := Vector2(2400.0, 1600.0) * 0.5
	var arena := get_tree().root.find_child("Arena", true, false)
	if arena != null and arena.has_method("half_extents"):
		half = arena.call("half_extents")
	var margin := 320.0
	var corner_index := maxi(0, TEAM_KEYS.find(team_id))
	match corner_index:
		0:
			return Vector2(-half.x + margin, -half.y + margin)
		1:
			return Vector2(half.x - margin, -half.y + margin)
		2:
			return Vector2(half.x - margin, half.y - margin)
		_:
			return Vector2(-half.x + margin, half.y - margin)


## Where a group for this team should materialize: a ring around their anchor, biased
## toward the arena center so players can see the threat coming before it touches them.
func spawn_focus_for_team(team_id: String) -> Vector2:
	var anchor := team_anchor(team_id)
	var inward := (Vector2.ZERO - anchor).normalized()
	return anchor + inward * (CORNER_HUDDLE_RADIUS + 640.0)


func mark_team_eliminated(team_id: String) -> void:
	if team_eliminated.get(team_id, false):
		return
	team_eliminated[team_id] = true
	_check_match_end()


func is_team_eliminated(team_id: String) -> bool:
	return bool(team_eliminated.get(team_id, false))


func _check_match_end() -> void:
	if match_over:
		return
	var survivors: Array[String] = []
	for team in active_teams():
		if not is_team_eliminated(team):
			survivors.append(team)
	if survivors.size() <= 1:
		match_over = true
		match_winner = survivors[0] if survivors.size() == 1 else ""
		match_resolved.emit(placements())


## Final placement array: [{"team": "a", "players": [peer_ids], "placement": 1}, ...].
## Survivors place above eliminated teams; remaining slots sort by stable key order so
## every peer computes the same map without another sync.
func placements() -> Array:
	var result: Array = []
	var teams := active_teams()
	var survivors: Array = teams.filter(func(team): return not is_team_eliminated(team))
	var fallen: Array = teams.filter(func(team): return is_team_eliminated(team))
	var placement := 1
	for team in survivors + fallen:
		var members: Array = []
		for peer_id in assigned_teams.keys():
			if str(assigned_teams[peer_id]) == team:
				members.append(peer_id)
		members.sort()
		result.append({
			"team": team,
			"name": team_name(team),
			"color": team_color(team),
			"players": members,
			"placement": placement,
		})
		placement += 1
	return result


## Push the end-of-match result into RankService. `local_peer_id` decides which
## placement the local player walks away with.
func apply_local_result(local_peer_id: int) -> void:
	if not match_over:
		return
	var my_team := team_of(local_peer_id)
	for entry in placements():
		if str(entry.team) == my_team:
			var won := bool(entry.placement == 1)
			RankService.record_match(won, int(entry.placement), active_teams().size())
			if SteamService.is_available():
				SteamService.report_match_result(
					won,
					RankService.points_for_placement(
						int(entry.placement), active_teams().size()
					)
				)
			return
