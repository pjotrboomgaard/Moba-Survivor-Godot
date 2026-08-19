extends Node

## Plays short one-shot sound effects by id. Non-positional and fire-and-forget: spawns a
## throwaway AudioStreamPlayer that frees itself when playback finishes, mirroring the
## self-freeing cosmetic-effect pattern used by scripts/lightning_effect.gd.
##
## Each id maps to one or more takes (Mixkit License, mixkit.co/license — free for commercial
## use, no attribution required) so repeated events like hits and clicks don't all sound
## identical; play() picks one at random.

const SOUND_LIBRARY: Dictionary = {
	"hit": [
		preload("res://assets/audio/sfx/hit.ogg"),
		preload("res://assets/audio/sfx/hit_2.ogg"),
		preload("res://assets/audio/sfx/hit_3.ogg"),
		preload("res://assets/audio/sfx/hit_4.ogg"),
	],
	"enemy_death": [
		preload("res://assets/audio/sfx/enemy_death.ogg"),
		preload("res://assets/audio/sfx/enemy_death_2.ogg"),
		preload("res://assets/audio/sfx/enemy_death_3.ogg"),
	],
	"explosion": [
		preload("res://assets/audio/sfx/explosion.ogg"),
		preload("res://assets/audio/sfx/explosion_2.ogg"),
	],
	"enemy_shoot": [
		preload("res://assets/audio/sfx/enemy_shoot.ogg"),
		preload("res://assets/audio/sfx/enemy_shoot_2.ogg"),
	],
	"xp": [preload("res://assets/audio/sfx/xp.ogg")],
	"gold": [
		preload("res://assets/audio/sfx/gold.ogg"),
		preload("res://assets/audio/sfx/gold_2.ogg"),
	],
	"purchase": [preload("res://assets/audio/sfx/purchase.ogg")],
	"level_up": [
		preload("res://assets/audio/sfx/level_up.ogg"),
		preload("res://assets/audio/sfx/level_up_2.ogg"),
	],
	"wave_start": [preload("res://assets/audio/sfx/wave_start.ogg")],
	"boss_alert": [preload("res://assets/audio/sfx/boss_alert.ogg")],
	"shop_open": [preload("res://assets/audio/sfx/shop_open.ogg")],
	"shop_close": [preload("res://assets/audio/sfx/shop_close.ogg")],
	"game_over": [
		preload("res://assets/audio/sfx/game_over.ogg"),
		preload("res://assets/audio/sfx/game_over_2.ogg"),
	],
	"ui_click": [
		preload("res://assets/audio/sfx/ui_click.ogg"),
		preload("res://assets/audio/sfx/ui_click_2.ogg"),
	],
	"dash": [preload("res://assets/audio/sfx/dash.ogg")],
	"charge": [preload("res://assets/audio/sfx/charge.ogg")],
	"cast_arclight": [preload("res://assets/audio/sfx/cast_arclight.ogg")],
	"cast_bulwark": [preload("res://assets/audio/sfx/cast_bulwark.ogg")],
	"cast_warden": [preload("res://assets/audio/sfx/cast_warden.ogg")],
	"cast_frostbinder": [preload("res://assets/audio/sfx/cast_frostbinder.ogg")],
}


## Lo-fi chiptune loop (Mixkit "Bold and Brash", Mixkit License) run through a lowpass +
## bitcrush + vinyl-noise pass so it reads as lo-fi rather than a bright straight chiptune.
const MUSIC_TRACK: AudioStreamOggVorbis = preload("res://assets/audio/music/arena_theme.ogg")
const MUSIC_VOLUME_DB := -15.0

## Turned off for now — the sourced takes/track didn't land well.
const SFX_ENABLED := false
const MUSIC_ENABLED := false

@onready var _music_player: AudioStreamPlayer = _make_music_player()


func play(sound_id: String) -> void:
	if not SFX_ENABLED:
		return
	var takes: Array = SOUND_LIBRARY.get(sound_id, [])
	if takes.is_empty():
		return
	var stream: AudioStream = takes[randi() % takes.size()]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_music() -> void:
	if MUSIC_ENABLED and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = MUSIC_TRACK
	player.volume_db = MUSIC_VOLUME_DB
	# Keeps playing through get_tree().paused (escape menu / solo shop breather).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player
