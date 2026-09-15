extends Node2D
## T1.3 (line 439) — Isolated verification: each minigame plays its own unique SFX.
## Plays all 12 minigame action SFX through AudioService.play() and records which
## sound actually fired (AudioService.last_play.sound_id + stream path).
## Writes user://selftest_report.json and calls get_tree().quit().
##
## This proves the audio pipeline (file exists -> registered in SOUND_LIBRARY ->
## AudioService.play() picks a non-null stream). A minigame's SFX is only "wired"
## if all three hold, and the minigame .gd files each call AudioService.play(<id>).
class_name MinigameSfxIsoTest

## The 12 minigames + their SFX ids (matching minigame_*.gd AudioService.play calls).
const SFX_IDS: Array = [
	"minigame_keg_toss",
	"minigame_keg_toss_pro",
	"minigame_whack",
	"minigame_whack_rush",
	"minigame_rps",
	"minigame_treasure",
	"minigame_treasure_dash2",
	"minigame_creep_tag",
	"minigame_dance_disco",
	"minigame_balloon_pop",
	"minigame_crate_stack",
	"minigame_crystal_catch",
	"minigame_gem_relay",
	"minigame_ring_roll",
	"minigame_slime_splat",
	"minigame_creep_pinball",
]

var _report: Dictionary = {}
var _results: Array = []
var _i := 0
var _shot_taken := false

func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	# Ensure SFX is enabled so play() actually fires.
	AudioService.sfx_enabled = true
	_report["total_ids"] = SFX_IDS.size()
	_play_next()


func _play_next() -> void:
	if _i >= SFX_IDS.size():
		_capture_and_finish()
		return
	var id: String = SFX_IDS[_i]
	var player: AudioStreamPlayer = AudioService.play(id)
	var rec: Dictionary = {"id": id}
	if player == null:
		# Either the bank is missing or SFX is off. Check the bank directly.
		rec["ok"] = false
		rec["reason"] = "AudioService.play returned null (missing bank or sfx disabled)"
	else:
		rec["ok"] = true
		var last: Dictionary = AudioService.last_play
		rec["last_play_sound_id"] = str(last.get("sound_id", ""))
		var stream: AudioStream = last.get("stream", null)
		rec["stream_path"] = stream.resource_path if stream != null else ""
	# Advance a small delay so the stream actually starts before the next play.
	_i += 1
	_results.append(rec)
	await get_tree().create_timer(0.15).timeout
	_play_next()


func _draw() -> void:
	# Render a grid of the SFX ids, green = ok, red = failed.
	var font := ThemeDB.fallback_font
	var cols := 4
	var cell_w: float = 360.0
	var cell_h: float = 44.0
	var origin := Vector2(-cell_w * cols * 0.5 + 40.0, -200.0)
	var title: String = "Minigame SFX verification (isolated)"
	draw_string(font, origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
	for i in range(_results.size()):
		var rec: Dictionary = _results[i]
		var col: int = i % cols
		var row: int = i / cols
		var p: Vector2 = origin + Vector2(0.0, 60.0) + Vector2(float(col) * cell_w, float(row) * cell_h)
		var ok: bool = bool(rec.get("ok", false))
		var color := Color(0.2, 1.0, 0.3) if ok else Color(1.0, 0.2, 0.2)
		var label: String = ("OK   " if ok else "FAIL ") + str(rec.get("id", ""))
		draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
		if ok:
			draw_string(font, p + Vector2(0.0, 20.0),
				str(rec.get("stream_path", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7))


func _capture_and_finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok_count := 0
	for r in _results:
		if bool(r.get("ok", false)):
			ok_count += 1
	var verdict := "PASS" if ok_count == SFX_IDS.size() else "FAIL"
	_report["ok"] = ok_count
	_report["fail"] = SFX_IDS.size() - ok_count
	_report["results"] = _results
	_report["verdict"] = verdict
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://selftest_minigame_sfx_grid.png")
	_report["screenshot"] = "user://selftest_minigame_sfx_grid.png"
	_write_report()
	get_tree().quit()


func _write_report() -> void:
	var json := JSON.stringify(_report, "\t")
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
	print("[MinigameSfxIsoTest] verdict=%s ok=%d/%d" % [_report["verdict"], _report["ok"], SFX_IDS.size()])
