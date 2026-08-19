extends Node

## Plays short one-shot sound effects by id. Non-positional and fire-and-forget: spawns a
## throwaway AudioStreamPlayer that frees itself when playback finishes, mirroring the
## self-freeing cosmetic-effect pattern used by scripts/lightning_effect.gd.

const SOUND_LIBRARY: Dictionary = {
	"hit": preload("res://assets/audio/sfx/hit.ogg"),
	"enemy_death": preload("res://assets/audio/sfx/enemy_death.ogg"),
	"explosion": preload("res://assets/audio/sfx/explosion.ogg"),
	"enemy_shoot": preload("res://assets/audio/sfx/enemy_shoot.ogg"),
	"xp": preload("res://assets/audio/sfx/xp.ogg"),
	"gold": preload("res://assets/audio/sfx/gold.ogg"),
	"purchase": preload("res://assets/audio/sfx/purchase.ogg"),
	"level_up": preload("res://assets/audio/sfx/level_up.ogg"),
	"wave_start": preload("res://assets/audio/sfx/wave_start.ogg"),
	"boss_alert": preload("res://assets/audio/sfx/boss_alert.ogg"),
	"shop_open": preload("res://assets/audio/sfx/shop_open.ogg"),
	"shop_close": preload("res://assets/audio/sfx/shop_close.ogg"),
	"game_over": preload("res://assets/audio/sfx/game_over.ogg"),
	"ui_click": preload("res://assets/audio/sfx/ui_click.ogg"),
	"dash": preload("res://assets/audio/sfx/dash.ogg"),
	"charge": preload("res://assets/audio/sfx/charge.ogg"),
	"cast_arclight": preload("res://assets/audio/sfx/cast_arclight.ogg"),
	"cast_bulwark": preload("res://assets/audio/sfx/cast_bulwark.ogg"),
	"cast_warden": preload("res://assets/audio/sfx/cast_warden.ogg"),
	"cast_frostbinder": preload("res://assets/audio/sfx/cast_frostbinder.ogg"),
}


func play(sound_id: String) -> void:
	var stream: AudioStream = SOUND_LIBRARY.get(sound_id)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
