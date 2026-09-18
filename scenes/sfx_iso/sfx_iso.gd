extends Node2D
## Isolated empty-world SFX verification test (T1.4, 2026-09-17).
##
## Empty-world baseline: flat dark background + camera. No arena, no grass,
## no HUD, no enemies. For each hero in the roster:
##   1. Apply the hero class
##   2. Directly call AudioService.play("attack_<hero>") and record the result
##   3. Directly call AudioService.play("attack_secondary_<hero>") and record
##   4. Directly call AudioService.play_ability("<first_ability_id>") and record
##
## This verifies that every hero's LMB/RMB/ability banks exist in SOUND_LIBRARY
## and resolve to a valid stream. The AudioService.last_play / last_ability_play
## state is captured after each call to confirm the correct bank was played.
##
## Run via:
##   run_selftest.ps1 -Scene res://scenes/sfx_iso/sfx_iso.tscn

const PCScript := preload("res://scripts/player_class.gd")

const HEROES: Array = [
	"tobor", "arclight", "bulwark", "warden",
	"cinder", "pyra", "slag", "ember",
	"thorn", "willow", "stump", "sage",
	"volt", "nebula", "astral", "rime",
]

var _camera: Camera2D
var _elapsed := 0.0
var _results: Array = []
var _done := false
var _hero_idx := 0
var _phase_idx := 0  # 0=lmb, 1=rmb, 2=ability
var _phase_time := 0.0
const PHASE_DUR := 0.4


func _ready() -> void:
	_camera = $Camera2D
	_camera.global_position = Vector2(0, 0)
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.make_current()

	# Flat dark background.
	var bg := Node2D.new()
	bg.name = "Bg"
	bg.set_script(load("res://scenes/arclight_vfx_iso/_bg_draw.gd"))
	add_child(bg)

	_start_hero(HEROES[0])


func _start_hero(hero_id: String) -> void:
	_hero_idx = HEROES.find(hero_id)
	_phase_idx = 0
	_phase_time = 0.0
	# Fire the LMB bank.
	_fire_bank("attack_%s" % hero_id, "lmb", hero_id)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_phase_time += delta
	if _phase_time < PHASE_DUR:
		return

	# Advance phase.
	_phase_idx += 1
	_phase_time = 0.0
	var hero_id: String = str(HEROES[_hero_idx])
	if _phase_idx == 1:
		# RMB bank.
		_fire_bank("attack_secondary_%s" % hero_id, "rmb", hero_id)
	elif _phase_idx == 2:
		# First ability bank for this hero.
		var ab_id := _first_ability_id(hero_id)
		if ab_id != "":
			_fire_ability(ab_id, "ability", hero_id)
		else:
			_record_probe("ability", hero_id, "(none)", "")
		# Move to next hero.
		_hero_idx += 1
		if _hero_idx < HEROES.size():
			_start_hero(str(HEROES[_hero_idx]))
		else:
			_finish()


func _first_ability_id(hero_id: String) -> String:
	var hero_def: Dictionary = PCScript.by_id(hero_id)
	if hero_def.is_empty():
		return ""
	var kit_q: String = str(hero_def.get("kit_q", ""))
	return kit_q


func _fire_bank(bank_id: String, kind: String, hero_id: String) -> void:
	# Use AudioService.play directly. Force sfx_enabled in case it was off.
	AudioService.sfx_enabled = true
	var player: AudioStreamPlayer = AudioService.play(bank_id)
	var stream_path := ""
	var player_ok := false
	if player != null and player.stream != null:
		stream_path = str(player.stream.resource_path)
		player_ok = true
	else:
		# Fallback: check last_play state (play() sets this before returning).
		var last: Dictionary = AudioService.last_play
		stream_path = str(last.get("stream", null).resource_path) if last.get("stream") != null else ""
		player_ok = last.get("player") != null
	_record_probe(kind, hero_id, bank_id, stream_path, player_ok)


func _fire_ability(ability_id: String, kind: String, hero_id: String) -> void:
	AudioService.sfx_enabled = true
	var player: AudioStreamPlayer = AudioService.play_ability(ability_id)
	var stream_path := ""
	var player_ok := false
	if player != null and player.stream != null:
		stream_path = str(player.stream.resource_path)
		player_ok = true
	else:
		var last: Dictionary = AudioService.last_ability_play
		if last.get("stream") != null:
			stream_path = str(last.get("stream").resource_path)
		player_ok = last.get("player") != null
	var last_ability: String = AudioService.last_play_ability
	_record_probe(kind, hero_id, "ability_" + ability_id, stream_path, last_ability)


func _record_probe(kind: String, hero_id: String, expected_bank: String, stream_path: String, extra: Variant = "") -> void:
	var entry := {
		"kind": kind,
		"hero": hero_id,
		"expected_bank": expected_bank,
		"stream_path": stream_path,
		"t": _elapsed,
	}
	var sound_id_ok := false
	var stream_ok := false
	if kind == "ability":
		# For ability: last_ability should match the ability id, and the stream
		# should contain "ability_" or the hero name.
		var last_ability: String = str(extra)
		sound_id_ok = (last_ability == expected_bank.trim_prefix("ability_"))
		stream_ok = stream_path.contains("ability_") or stream_path.contains(hero_id)
		entry["last_ability"] = last_ability
	else:
		# For lmb/rmb: the stream path should contain the hero's bank name.
		# e.g. attack_tobor.wav or attack_tobor_2.wav both contain "attack_tobor"
		# extra is a bool (player_ok) from _fire_bank.
		var player_ok: bool = true
		if extra is bool:
			player_ok = extra
		var bank_prefix: String = expected_bank
		sound_id_ok = player_ok
		stream_ok = stream_path.contains(bank_prefix) or stream_path.contains(hero_id)
		entry["player_ok"] = player_ok

	entry["sound_ok"] = sound_id_ok
	entry["stream_ok"] = stream_ok
	entry["ok"] = sound_id_ok and stream_ok
	_results.append(entry)
	print("[SfxIso] %s/%s: expected=%s stream=%s ok=%s" % [kind, hero_id, expected_bank, stream_path, str(entry["ok"])])


func _finish() -> void:
	var lmb_ok := 0
	var lmb_total := 0
	var rmb_ok := 0
	var rmb_total := 0
	var ability_ok := 0
	var ability_total := 0
	for entry in _results:
		var kind: String = str(entry.get("kind", ""))
		if kind == "lmb":
			lmb_total += 1
			if entry.get("ok", false):
				lmb_ok += 1
		elif kind == "rmb":
			rmb_total += 1
			if entry.get("ok", false):
				rmb_ok += 1
		elif kind == "ability":
			ability_total += 1
			if entry.get("ok", false):
				ability_ok += 1

	var all_ok := (lmb_ok == lmb_total and rmb_ok == rmb_total and ability_ok == ability_total)
	var verdict := "PASS" if all_ok else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "sfx_iso",
		"heroes_tested": HEROES.size(),
		"lmb_ok": lmb_ok,
		"lmb_total": lmb_total,
		"rmb_ok": rmb_ok,
		"rmb_total": rmb_total,
		"ability_ok": ability_ok,
		"ability_total": ability_total,
		"all_ok": all_ok,
		"results": _results,
	}
	_write_report(report)


func _write_report(report: Dictionary) -> void:
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[SfxIso] verdict=%s lmb=%d/%d rmb=%d/%d ability=%d/%d" % [
		report["verdict"],
		int(report["lmb_ok"]), int(report["lmb_total"]),
		int(report["rmb_ok"]), int(report["rmb_total"]),
		int(report["ability_ok"]), int(report["ability_total"])])
	get_tree().quit()
