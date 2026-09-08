class_name SideQuestDirector
extends Node

const SideQuest := preload("res://scripts/side_quest.gd")

## Per-player randomized outskirts side quests. A completed task rolls a new kind.

const DELAY_BEFORE_FIRST := 2.8
const DELAY_AFTER_COMPLETE := 3.6

const POOL: Array[Dictionary] = [
	{"id": "chase_butterfly", "mode": "chase", "art": "butterfly", "anim": true, "speed": 235.0, "title": "Catch the butterfly", "gold": 45, "xp": 40},
	{"id": "chase_wisp", "mode": "chase", "art": "wisp", "anim": true, "speed": 250.0, "title": "Catch the pale wisp", "gold": 50, "xp": 44, "buff": {"movement_speed_mult": 1.22}, "buff_time": 8.0},
	{"id": "chase_ember", "mode": "chase", "art": "ember", "anim": true, "speed": 260.0, "title": "Catch the ember spark", "gold": 55, "xp": 42},
	{"id": "collect_shards", "mode": "collect", "art": "shard", "anim": false, "count": 4, "title": "Gather ice shards", "gold": 40, "xp": 36},
	{"id": "collect_fireflies", "mode": "collect", "art": "firefly", "anim": true, "count": 5, "title": "Scoop fireflies", "gold": 38, "xp": 34},
	{"id": "collect_coins", "mode": "collect", "art": "coin", "anim": false, "count": 3, "title": "Pocket stray coins", "gold": 70, "xp": 20},
	{"id": "collect_flock", "mode": "collect", "art": "flock", "anim": false, "count": 4, "title": "Herd the white birds", "gold": 42, "xp": 38},
	{"id": "smash_crate", "mode": "smash", "art": "crate", "hits": 3, "title": "Smash the outskirts crate", "gold": 48, "xp": 30},
	{"id": "smash_idol", "mode": "smash", "art": "idol", "hits": 4, "title": "Topple a roadside idol", "gold": 60, "xp": 40},
	{"id": "smash_valve", "mode": "smash", "art": "valve", "hits": 3, "title": "Break the rusted valve", "gold": 44, "xp": 32},
	{"id": "smash_shroom", "mode": "smash", "art": "mushroom", "hits": 2, "title": "Kick the giant cap", "gold": 36, "xp": 28},
	{"id": "smash_dummy", "mode": "smash", "art": "dummy", "hits": 4, "title": "Spar the training dummy", "gold": 40, "xp": 48},
	{"id": "stand_beacon", "mode": "stand", "art": "beacon", "stand": 2.6, "title": "Hold the signal beacon", "gold": 50, "xp": 36, "buff": {"damage_dealt_mult": 1.2}, "buff_time": 10.0},
	{"id": "stand_cairn", "mode": "stand", "art": "cairn", "stand": 2.2, "title": "Tend the stone cairn", "gold": 40, "xp": 30},
	{"id": "stand_lantern", "mode": "stand", "art": "lantern", "stand": 2.0, "title": "Light the dock lantern", "gold": 38, "xp": 28},
	{"id": "stand_spring", "mode": "stand", "art": "spring", "stand": 2.4, "title": "Drink from the wild spring", "gold": 0, "xp": 24, "heal": 40.0},
	{"id": "visit_runes", "mode": "visit", "art": "rune", "count": 3, "title": "Trace the outer runes", "gold": 52, "xp": 44},
	{"id": "visit_vista", "mode": "visit", "art": "vista", "count": 3, "title": "Walk the three vistas", "gold": 46, "xp": 40},
	{"id": "ring_bell", "mode": "stand", "art": "bell", "stand": 1.6, "title": "Ring the far bell", "gold": 42, "xp": 34},
	{"id": "kill_marked", "mode": "kill", "art": "marked", "title": "Slay the marked creep", "gold": 80, "xp": 55},
	{"id": "rescue_kid", "mode": "rescue", "art": "marked", "npc": "kid", "npc_health": 50.0, "hostiles": 3, "title": "Save the lost kid", "gold": 80, "xp": 55},
	{"id": "rescue_villager", "mode": "rescue", "art": "marked", "npc": "villager", "npc_health": 80.0, "hostiles": 4, "title": "Rescue the villager", "gold": 90, "xp": 60},
	{"id": "rescue_scout", "mode": "rescue", "art": "marked", "npc": "scout", "npc_health": 40.0, "hostiles": 5, "title": "Pull the scout to safety", "gold": 100, "xp": 70},
	{"id": "dance_mimic", "mode": "dance", "art": "marked", "title": "Mirror the dancer", "gold": 90, "xp": 65},
	{"id": "dance_circle", "mode": "dance", "art": "marked", "title": "Dance the circle", "gold": 85, "xp": 60},
	{"id": "dance_giggle", "mode": "dance", "art": "marked", "title": "Giggle-run with the sprite", "gold": 95, "xp": 70, "buff": {"damage_dealt_mult": 1.15}, "buff_time": 12.0},
]

var _main: Node = null
var _active: Dictionary = {}
var _recent: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(main: Node) -> void:
	_main = main
	_rng.randomize()
	await get_tree().create_timer(DELAY_BEFORE_FIRST).timeout
	if not is_instance_valid(_main) or bool(_main.get("game_over")):
		return
	for peer in _main.players.keys():
		_grant(int(peer))


func _grant(peer_id: int) -> void:
	if _main == null or not _main.players.has(peer_id):
		return
	_clear_peer(peer_id)
	var spec := _pick_spec(peer_id)
	var quest := SideQuest.new()
	quest.name = "SideQuest_%d" % peer_id
	quest.configure(peer_id, spec)
	quest.completed.connect(_on_quest_completed)
	var host: Node = _main.actors if _main.get("actors") != null else _main
	host.add_child(quest)
	quest.begin(_main)
	_active[peer_id] = quest
	if _main.has_method("_refresh_side_quest_hud"):
		_main._refresh_side_quest_hud()
	_notify_quest_spawned(quest, peer_id)


func _notify_quest_spawned(quest: SideQuest, peer_id: int) -> void:
	if _main == null or _main.get("hud") == null:
		return
	var hud: Node = _main.get("hud")
	if not (hud is CanvasLayer and hud.has_method("show_quest_toast")):
		return
	# Only toast for the local player's quest. In solo/authority the local peer is 1.
	if peer_id != 1:
		return
	hud.show_quest_toast("New side quest: %s" % quest.hud_line)


func _pick_spec(peer_id: int) -> Dictionary:
	var banned: Array = _recent.get(peer_id, [])
	var choices: Array[Dictionary] = []
	for entry in POOL:
		if banned.has(str(entry.id)):
			continue
		choices.append(entry)
	if choices.is_empty():
		choices = POOL.duplicate()
	var spec: Dictionary = choices[_rng.randi() % choices.size()].duplicate(true)
	banned.append(str(spec.id))
	if banned.size() > 4:
		banned.pop_front()
	_recent[peer_id] = banned
	return spec


func _on_quest_completed(quest: SideQuest) -> void:
	if quest == null:
		return
	var peer_id := quest.owner_peer_id
	_pay_out(quest)
	_clear_peer(peer_id)
	if _main != null and _main.has_method("_refresh_side_quest_hud"):
		_main._refresh_side_quest_hud()
	await get_tree().create_timer(DELAY_AFTER_COMPLETE).timeout
	if is_instance_valid(_main) and not bool(_main.get("game_over")):
		_grant(peer_id)


func _pay_out(quest: SideQuest) -> void:
	if _main == null:
		return
	var player := _main.players.get(quest.owner_peer_id) as Player
	if player == null:
		return
	var gold := int(quest.spec.get("gold", 0))
	var xp := int(quest.spec.get("xp", 0))
	if gold > 0:
		player.add_gold(gold)
	if xp > 0:
		player.add_xp(xp)
	var heal := float(quest.spec.get("heal", 0.0))
	if heal > 0.0 and player.health != null:
		player.health.heal(heal)
	var buff: Dictionary = quest.spec.get("buff", {})
	if not buff.is_empty():
		player._apply_ability_buff(buff, float(quest.spec.get("buff_time", 8.0)))
	var line := "QUEST +%dG +%dXP" % [gold, xp]
	if player.is_local_player and _main.has_method("_landmark_flash"):
		_main._landmark_flash(line, Color("7dffb0"))


func hud_text_for_local() -> String:
	if _main == null:
		return ""
	for player_node in _main.players.values():
		var player := player_node as Player
		if player == null or not player.is_local_player:
			continue
		var quest: SideQuest = _active.get(player.owner_peer_id) as SideQuest
		if quest == null:
			return ""
		return quest.hud_line
	return ""


func _clear_peer(peer_id: int) -> void:
	var quest: SideQuest = _active.get(peer_id) as SideQuest
	_active.erase(peer_id)
	if quest != null and is_instance_valid(quest):
		quest.queue_free()
