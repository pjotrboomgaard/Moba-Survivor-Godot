## Team manager for Rift Clash mode (the mode where players split into separate arena teams).
## Stub with the surface scripts/main.gd calls; the actual team mode wiring lives elsewhere
## and is outside the scope of this pass — messages here return sensible no-op defaults so
## co-op / solo play keeps working.

extends Node

var assigned_teams: Dictionary = {}
var team_anchors: Dictionary = {}
var team_eliminated: Dictionary = {}


func reset_match() -> void:
	assigned_teams.clear()
	team_anchors.clear()
	team_eliminated.clear()


func assign_teams(peer_ids: Array, _lobby_claims: Dictionary) -> void:
	# Default: every player is its own team — safe for a mode we're not actively using.
	assigned_teams.clear()
	for pid in peer_ids:
		assigned_teams[int(pid)] = int(pid)


func team_of(peer_id: int) -> int:
	return int(assigned_teams.get(peer_id, peer_id))


func team_name(team_id: Variant) -> String:
	return "Team %d" % int(team_id)


func team_corner_name(team_id: Variant) -> String:
	match int(team_id) % 4:
		0: return "NW"
		1: return "NE"
		2: return "SW"
		_: return "SE"


func team_color(_team_id: Variant) -> Color:
	return Color(0.85, 0.85, 0.85, 1.0)


func team_anchor(team_id: Variant) -> Vector2:
	return Vector2(team_anchors.get(int(team_id), Vector2.ZERO))


func is_team_eliminated(team_id: Variant) -> bool:
	return bool(team_eliminated.get(int(team_id), false))


func mark_team_eliminated(team_id: Variant) -> void:
	team_eliminated[int(team_id)] = true


func apply_local_result(_local_peer_id: Variant) -> void:
	pass


func placements() -> Array:
	return []


func spawn_focus_for_team(_team_id: Variant) -> Vector2:
	return Vector2.ZERO
