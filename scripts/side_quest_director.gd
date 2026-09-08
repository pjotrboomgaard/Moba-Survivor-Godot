extends Node

const SideQuestScript := preload("res://scripts/side_quest.gd")

## Per-player randomized outskirts side quests. A completed task rolls a new kind
## after a cooldown. Up to MAX_ACTIVE_QUESTS_PER_PEER may be active at once so a
## player can choose between several objectives.

const DELAY_BEFORE_FIRST := 2.8
## Cooldown between spawns. When a quest completes while another is still active, a
## new one rolls after this delay (45-60s game time) so the bot sees fresh quests.
const DELAY_AFTER_COMPLETE := 50.0
## Maximum concurrent side quests a single player can have at once.
const MAX_ACTIVE_QUESTS_PER_PEER := 2
## How many recent quest modes to deprioritize for variety.
const RECENT_MODE_COUNT := 2

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

## Biome (GameRuntime.biome_id) -> per-quest-mode weight. 1.0 = neutral, >1 boosts,
## <1 suppresses. Grass (id 0) falls through to _DEFAULT_WEIGHTS (all 1.0).
const _BIOME_MODE_WEIGHTS: Dictionary = {
	# Volcano: favor smashing and shard-collecting (lava/volcanic theme)
	1: {"smash": 2.0, "collect": 1.6, "chase": 1.0, "stand": 0.7, "visit": 0.7, "kill": 1.2, "rescue": 0.8, "dance": 0.6},
	# Ice: favor standing-still and chase quests (frozen theme)
	2: {"stand": 2.0, "chase": 1.6, "collect": 0.8, "smash": 0.8, "visit": 0.9, "kill": 1.0, "rescue": 0.9, "dance": 0.8},
	# Factory: favor collect and smash (industrial theme)
	3: {"collect": 2.0, "smash": 1.6, "kill": 1.1, "chase": 0.8, "stand": 0.9, "visit": 0.9, "rescue": 0.8, "dance": 0.8},
	# Docks: favor visit and rescue (port theme)
	4: {"visit": 2.0, "rescue": 1.8, "collect": 1.0, "kill": 1.0, "chase": 0.8, "smash": 0.8, "stand": 0.8, "dance": 0.8},
}
const _DEFAULT_MODE_WEIGHT: float = 1.0


var _main: Node = null
## Per-peer list of currently active SideQuest nodes (up to MAX_ACTIVE_QUESTS_PER_PEER).
var _active_quests: Dictionary = {}
## Per-peer list of the most recent quest modes used (for variety deprioritization).
var _recent_modes: Dictionary = {}
## Per-peer last quest ids (kept small to avoid exact repeats back-to-back).
var _recent_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(main: Node) -> void:
	_main = main
	_rng.randomize()
	await get_tree().create_timer(DELAY_BEFORE_FIRST).timeout
	if not is_instance_valid(_main) or bool(_main.get("game_over")):
		return
	for peer in _main.players.keys():
		_grant(int(peer))


func _active_count(peer_id: int) -> int:
	var quests: Array = _active_quests.get(peer_id, [])
	var count := 0
	for q in quests:
		if is_instance_valid(q):
			count += 1
	return count


func _remove_quest_from_peer(peer_id: int, quest: Node2D) -> void:
	var quests: Array = _active_quests.get(peer_id, [])
	quests.erase(quest)
	_active_quests[peer_id] = quests


## Initial grant: top a peer up to MAX_ACTIVE_QUESTS_PER_PEER so they get choices.
func _grant(peer_id: int) -> void:
	if _main == null or not _main.players.has(peer_id):
		return
	# Prune stale entries so the count reflects live quests.
	var quests: Array = _active_quests.get(peer_id, [])
	var alive: Array = []
	for q in quests:
		if is_instance_valid(q):
			alive.append(q)
	_active_quests[peer_id] = alive
	while _active_count(peer_id) < MAX_ACTIVE_QUESTS_PER_PEER:
		_spawn_one(peer_id)


## Spawn a single new quest for a peer.
func _spawn_one(peer_id: int) -> void:
	if _main == null or not _main.players.has(peer_id):
		return
	# Remove any stale/inactive quest entries for this peer first.
	var quests: Array = _active_quests.get(peer_id, [])
	var alive: Array = []
	for q in quests:
		if is_instance_valid(q):
			alive.append(q)
	_active_quests[peer_id] = alive
	var spec := _pick_spec(peer_id)
	var quest := SideQuestScript.new()
	quest.name = "SideQuest_%d" % peer_id
	quest.configure(peer_id, spec)
	quest.completed.connect(_on_quest_completed)
	var host: Node = _main.actors if _main.get("actors") != null else _main
	host.add_child(quest)
	quest.begin(_main)
	_active_quests[peer_id].append(quest)
	_track_recent_mode(peer_id, str(spec.get("mode", "collect")))
	if _main.has_method("_refresh_side_quest_hud"):
		_main._refresh_side_quest_hud()
	_notify_quest_spawned(quest, peer_id)


func _track_recent_mode(peer_id: int, mode: String) -> void:
	var modes: Array = _recent_modes.get(peer_id, [])
	modes.push_front(mode)
	if modes.size() > RECENT_MODE_COUNT:
		modes.pop_back()
	_recent_modes[peer_id] = modes


func _recent_mode_set(peer_id: int) -> Array:
	return _recent_modes.get(peer_id, [])


func _biome_mode_weight(mode: String) -> float:
	var biome: int = int(GameRuntime.biome_id)
	var weights: Dictionary = _BIOME_MODE_WEIGHTS.get(biome, {})
	if not weights.has(mode):
		return _DEFAULT_MODE_WEIGHT
	return float(weights[mode])


func _notify_quest_spawned(quest: Node2D, peer_id: int) -> void:
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
	# Avoid exact repeats: skip ids used in the last 4 rolls.
	var banned_ids: Array = _recent_ids.get(peer_id, [])
	# Deprioritize modes used in the last RECENT_MODE_COUNT rolls (variety).
	var recent_modes: Array = _recent_mode_set(peer_id)
	var biome_weights: Array[Dictionary] = []
	for entry in POOL:
		var id_key: String = str(entry.id)
		var banned: bool = banned_ids.has(id_key)
		var weight: float = _biome_mode_weight(str(entry.get("mode", "collect")))
		# Recent modes get a heavy penalty to push variety.
		if recent_modes.has(str(entry.get("mode", "collect"))):
			weight *= 0.25
		if banned:
			weight *= 0.1
		biome_weights.append({"entry": entry, "weight": weight})
	# Weighted random pick.
	var total_weight: float = 0.0
	for bw in biome_weights:
		total_weight += maxf(0.001, float(bw.weight))
	var roll: float = _rng.randf() * total_weight
	var acc: float = 0.0
	var chosen: Dictionary = POOL[0]
	for bw in biome_weights:
		acc += maxf(0.001, float(bw.weight))
		if roll <= acc:
			chosen = bw.entry
			break
	var spec: Dictionary = chosen.duplicate(true)
	banned_ids.push_front(str(chosen.id))
	if banned_ids.size() > 4:
		banned_ids.pop_back()
	_recent_ids[peer_id] = banned_ids
	return spec


func _on_quest_completed(quest: Node2D) -> void:
	if quest == null:
		return
	var peer_id: int = int(quest.owner_peer_id)
	_pay_out(quest)
	# Remove only this quest from the peer's list, keeping any other active quest.
	_remove_quest_from_peer(peer_id, quest)
	if _main != null and _main.has_method("_refresh_side_quest_hud"):
		_main._refresh_side_quest_hud()
	# After the cooldown, spawn a replacement only if the peer is still below the cap.
	await get_tree().create_timer(DELAY_AFTER_COMPLETE).timeout
	if not (is_instance_valid(_main) and not bool(_main.get("game_over"))):
		return
	if _active_count(peer_id) < MAX_ACTIVE_QUESTS_PER_PEER:
		_spawn_one(peer_id)


func _pay_out(quest: Node2D) -> void:
	if _main == null:
		return
	var player = _main.players.get(quest.owner_peer_id)
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


## HUD shows up to MAX_ACTIVE_QUESTS_PER_PEER lines for the local player, joined
## with a newline so the HUD label can render multiple concurrent quests.
func hud_text_for_local() -> String:
	if _main == null:
		return ""
	for player_node in _main.players.values():
		var player = player_node
		if player == null or not player.is_local_player:
			continue
		var quests: Array = _active_quests.get(player.owner_peer_id, [])
		var lines: Array[String] = []
		for q in quests:
			if is_instance_valid(q) and not str(q.hud_line).is_empty():
				lines.append(str(q.hud_line))
		return "\n".join(lines)
	return ""


## Free every active quest for a peer. Used on game-over / teardown.
func _clear_peer(peer_id: int) -> void:
	var quests: Array = _active_quests.get(peer_id, [])
	for q in quests:
		if is_instance_valid(q):
			q.queue_free()
	_active_quests.erase(peer_id)
	_recent_modes.erase(peer_id)
	_recent_ids.erase(peer_id)

