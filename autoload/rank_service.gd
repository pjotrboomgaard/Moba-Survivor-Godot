extends Node

## Ranked "Rift Clash" progression. Wraps the raw SkillPoints int stat into a
## tier readout (Bronze → Immortal), applies winner/loser deltas, and persists
## locally as a fallback for machines where the Steam client isn't reachable
## (CI, the headless dedicated server, ENet LAN matches). Steam remains the
## source of truth when connected.

signal rank_changed(tier_id: String, points: int)
signal points_applied(old_points: int, new_points: int, reason: String)

const SKILL_POINTS_PATH := "user://rift_clash_rank.json"

const WIN_POINTS := 25
const LOSS_POINTS := -15
const TOP2_POINTS := 8
const TOP3_POINTS := 2

## Mattermost/MOBA ladder style: each tier spans a fixed span of SkillPoints.
const TIERS: Array[Dictionary] = [
	{"id": "bronze", "name": "Bronze", "min": 0, "color": Color("a9714b")},
	{"id": "silver", "name": "Silver", "min": 100, "color": Color("9fa8b2")},
	{"id": "gold", "name": "Gold", "min": 200, "color": Color("d7a844")},
	{"id": "platinum", "name": "Platinum", "min": 350, "color": Color("4db8c4")},
	{"id": "diamond", "name": "Diamond", "min": 500, "color": Color("5b8def")},
	{"id": "master", "name": "Master", "min": 700, "color": Color("9b59d0")},
	{"id": "grandmaster", "name": "Grandmaster", "min": 900, "color": Color("d05252")},
	{
		"id": "immortal",
		"name": "Immortal",
		"min": 1200,
		"color": Color("e8c840"),
	},
]


var skill_points := 0
var current_tier := "bronze"


func _ready() -> void:
	_load_local_fallback()
	current_tier = tier_for_points(skill_points)
	if SteamService.is_available():
		skill_points = SteamService.get_stat_int(SteamService.STAT_SKILL_POINTS)
		SteamService.stat_changed.connect(_on_steam_stat_changed)


## Which tier a point total sits in. Tiers are ordered by `min` ascending, so
## the last one whose floor is <= points wins.
static func tier_for_points(points: int) -> String:
	var chosen := "bronze"
	var best_min := -1
	for tier in TIERS:
		var floor_points := int(tier.min)
		if points >= floor_points and floor_points >= best_min:
			best_min = floor_points
			chosen = str(tier.id)
	return chosen


static func tier_info(tier_id: String) -> Dictionary:
	for tier in TIERS:
		if str(tier.id) == tier_id:
			return tier
	return TIERS[0]


## Progress from 0..1 within the current tier toward the next, or 1 at the cap.
static func tier_progress(points: int) -> float:
	var tier := tier_info(tier_for_points(points))
	var floor_points := int(tier.min)
	var index := TIERS.find(tier)
	if index < 0 or index == TIERS.size() - 1:
		return 1.0
	var next_floor := int(TIERS[index + 1].min)
	return clampf(
		float(points - floor_points) / float(next_floor - floor_points), 0.0, 1.0
	)


## How many points to award the surviving teams when a match resolves.
## placement is 1-based (1 = winner). Deltas are deliberately small ladders so
## even a heads-down game trend keeps players moving.
static func points_for_placement(placement: int, team_count: int) -> int:
	if placement == 1:
		return WIN_POINTS
	if team_count >= 4 and placement == 2:
		return TOP2_POINTS
	if team_count >= 3 and placement == 3:
		return TOP3_POINTS
	return LOSS_POINTS


## Apply a match result for the local player. `won` doubles the loss penalty;
## passing short-cuts directly for RPC-fed lobby results.
func record_match(won: bool, placement: int = 1, team_count: int = 4) -> void:
	var delta := WIN_POINTS if won else LOSS_POINTS
	if not won:
		delta = points_for_placement(placement, team_count)
	var previous := skill_points
	skill_points = maxi(0, skill_points + delta)
	var previous_tier := current_tier
	current_tier = tier_for_points(skill_points)
	_save_local_fallback()
	points_applied.emit(previous, skill_points, "match result (placement %d)" % placement)
	if previous_tier != current_tier:
		rank_changed.emit(current_tier, skill_points)


func points_label() -> String:
	return "%s · %d SP" % [str(tier_info(current_tier).name), skill_points]


func _on_steam_stat_changed(stat_name: String, value: int) -> void:
	if stat_name != SteamService.STAT_SKILL_POINTS:
		return
	var previous_tier := current_tier
	skill_points = value
	current_tier = tier_for_points(skill_points)
	_save_local_fallback()
	if previous_tier != current_tier:
		rank_changed.emit(current_tier, skill_points)


func _load_local_fallback() -> void:
	if not FileAccess.file_exists(SKILL_POINTS_PATH):
		return
	var file := FileAccess.open(SKILL_POINTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		skill_points = maxi(0, int(parsed.get("skill_points", 0)))


func _save_local_fallback() -> void:
	var file := FileAccess.open(SKILL_POINTS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"skill_points": skill_points}))
