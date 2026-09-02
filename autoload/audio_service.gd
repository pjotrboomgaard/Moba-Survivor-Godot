extends Node

## Short one-shot SFX by id, plus a looping music bed. Combat hits are pooled and voice-capped
## so a horde of robots doesn't turn into a wall of noise. Toggle SFX/music from the lobby,
## the pause menu, or set_sfx_enabled() / set_music_enabled().

const SOUND_LIBRARY: Dictionary = {
	"hit": [
		preload("res://assets/audio/sfx/hit.ogg"),
		preload("res://assets/audio/sfx/hit_2.ogg"),
		preload("res://assets/audio/sfx/hit_3.ogg"),
		preload("res://assets/audio/sfx/hit_4.ogg"),
	],
	"hurt": [
		preload("res://assets/audio/sfx/hurt.ogg"),
		preload("res://assets/audio/sfx/hurt_2.ogg"),
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
	"shop_fail": [preload("res://assets/audio/sfx/shop_fail.ogg")],
	"level_up": [
		preload("res://assets/audio/sfx/level_up.ogg"),
		preload("res://assets/audio/sfx/level_up_2.ogg"),
	],
	"wave_start": [preload("res://assets/audio/sfx/wave_start.ogg")],
	"wave_clear": [preload("res://assets/audio/sfx/wave_clear.ogg")],
	"boss_alert": [preload("res://assets/audio/sfx/boss_alert.ogg")],
	"scan": [preload("res://assets/audio/sfx/scan.ogg")],
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
	"player_down": [preload("res://assets/audio/sfx/player_down.ogg")],
	"revive": [preload("res://assets/audio/sfx/revive.ogg")],
	# Hero cast banks: 2-3 distinctive takes each, so a cast reads as *that* hero before
	# you even see the VFX. Pure-procedural wavs (tools/synth_themes.py, MIT-safe) cover
	# every hero; a few also have Kenney .ogg legacy takes mixed in for extra grit.
	"cast_tobor": [
		preload("res://assets/audio/themes/tobor.wav"),
		preload("res://assets/audio/themes/tobor_2.wav"),
		preload("res://assets/audio/sfx/cast_tobor.ogg"),
	],
	"cast_arclight": [
		preload("res://assets/audio/themes/arclight.wav"),
		preload("res://assets/audio/themes/arclight_2.wav"),
		preload("res://assets/audio/sfx/cast_arclight.ogg"),
	],
	"cast_bulwark": [
		preload("res://assets/audio/themes/bulwark.wav"),
		preload("res://assets/audio/themes/bulwark_2.wav"),
		preload("res://assets/audio/sfx/cast_bulwark.ogg"),
	],
	"cast_warden": [
		preload("res://assets/audio/themes/warden.wav"),
		preload("res://assets/audio/themes/warden_2.wav"),
		preload("res://assets/audio/sfx/cast_warden.ogg"),
	],
	"cast_cinder": [
		preload("res://assets/audio/themes/cinder.wav"),
		preload("res://assets/audio/themes/cinder_2.wav"),
		preload("res://assets/audio/themes/cinder_3.wav"),
	],
	"cast_pyra": [
		preload("res://assets/audio/themes/pyra.wav"),
		preload("res://assets/audio/themes/pyra_2.wav"),
		preload("res://assets/audio/themes/pyra_3.wav"),
	],
	"cast_slag": [
		preload("res://assets/audio/themes/slag.wav"),
		preload("res://assets/audio/themes/slag_2.wav"),
	],
	"cast_ember": [
		preload("res://assets/audio/themes/ember.wav"),
		preload("res://assets/audio/themes/ember_2.wav"),
	],
	"cast_thorn": [
		preload("res://assets/audio/themes/thorn.wav"),
		preload("res://assets/audio/themes/thorn_2.wav"),
	],
	"cast_willow": [
		preload("res://assets/audio/themes/willow.wav"),
		preload("res://assets/audio/themes/willow_2.wav"),
	],
	"cast_stump": [
		preload("res://assets/audio/themes/stump.wav"),
		preload("res://assets/audio/themes/stump_2.wav"),
	],
	"cast_sage": [
		preload("res://assets/audio/themes/sage.wav"),
		preload("res://assets/audio/themes/sage_2.wav"),
	],
	"cast_volt": [
		preload("res://assets/audio/themes/volt.wav"),
		preload("res://assets/audio/themes/volt_2.wav"),
	],
	"cast_nebula": [
		preload("res://assets/audio/themes/nebula.wav"),
		preload("res://assets/audio/themes/nebula_2.wav"),
	],
	"cast_astral": [
		preload("res://assets/audio/themes/astral.wav"),
		preload("res://assets/audio/themes/astral_2.wav"),
	],
	"cast_rime": [
		preload("res://assets/audio/themes/rime.wav"),
		preload("res://assets/audio/themes/rime_2.wav"),
		preload("res://assets/audio/sfx/cast_frostbinder.ogg"),
	],
	"sfx_projectile": [preload("res://assets/audio/sfx/sfx_projectile.ogg")],
	"sfx_cone": [preload("res://assets/audio/sfx/sfx_cone.ogg")],
	"sfx_radius": [preload("res://assets/audio/sfx/sfx_radius.ogg")],
	"sfx_dash": [preload("res://assets/audio/sfx/sfx_dash.ogg")],
	"sfx_heal": [preload("res://assets/audio/sfx/sfx_heal.ogg")],
	"sfx_shield": [preload("res://assets/audio/sfx/sfx_shield.ogg")],
	"sfx_force": [preload("res://assets/audio/sfx/sfx_force.ogg")],
}

const FAMILY_FOR_ARCHETYPE := {
	PlayerClass.Archetype.NUKE_BOLT: "sfx_projectile",
	PlayerClass.Archetype.CHAIN_NUKE: "sfx_projectile",
	PlayerClass.Archetype.CONE_BURST: "sfx_cone",
	PlayerClass.Archetype.RADIUS_BURST: "sfx_radius",
	PlayerClass.Archetype.DASH_STRIKE: "sfx_dash",
	PlayerClass.Archetype.BLINK: "sfx_dash",
	PlayerClass.Archetype.SELF_HEAL: "sfx_heal",
	PlayerClass.Archetype.AOE_HEAL: "sfx_heal",
	PlayerClass.Archetype.SHIELD_BURST: "sfx_shield",
	PlayerClass.Archetype.BUFF_SELF: "sfx_shield",
	PlayerClass.Archetype.PUSH_PULL_BURST: "sfx_force",
}

const VOLUME_DB := {
	"hit": -10.0,
	"hurt": -4.0,
	"enemy_death": -11.0,
	"explosion": -7.0,
	"enemy_shoot": -12.0,
	"xp": -16.0,
	"gold": -14.0,
	"purchase": -8.0,
	"shop_fail": -8.0,
	"level_up": -6.0,
	"wave_start": -5.0,
	"wave_clear": -6.0,
	"boss_alert": -3.0,
	"scan": -12.0,
	"shop_open": -8.0,
	"shop_close": -8.0,
	"game_over": -4.0,
	"ui_click": -12.0,
	"dash": -10.0,
	"charge": -8.0,
	"player_down": -4.0,
	"revive": -6.0,
	"cast_arclight": -8.0,
	"cast_bulwark": -7.0,
	"cast_warden": -8.0,
	"cast_rime": -8.0,
	"cast_tobor": -6.0,
	"cast_cinder": -7.0,
	"cast_pyra": -7.0,
	"cast_slag": -6.0,
	"cast_ember": -7.0,
	"cast_thorn": -8.0,
	"cast_willow": -8.0,
	"cast_stump": -7.0,
	"cast_sage": -8.0,
	"cast_volt": -7.0,
	"cast_nebula": -8.0,
	"cast_astral": -8.0,
	"sfx_projectile": -9.0,
	"sfx_cone": -8.0,
	"sfx_radius": -7.0,
	"sfx_dash": -9.0,
	"sfx_heal": -9.0,
	"sfx_shield": -9.0,
	"sfx_force": -8.0,
}

const PITCH_SPREAD := {
	"hit": 0.08,
	"hurt": 0.05,
	"enemy_death": 0.09,
	"explosion": 0.05,
	"enemy_shoot": 0.06,
	"xp": 0.07,
	"gold": 0.06,
	"ui_click": 0.04,
	"dash": 0.05,
	"charge": 0.03,
	"cast_arclight": 0.05,
	"cast_bulwark": 0.04,
	"cast_warden": 0.04,
	"cast_rime": 0.05,
	"cast_tobor": 0.04,
	"cast_cinder": 0.05,
	"cast_pyra": 0.05,
	"cast_slag": 0.04,
	"cast_ember": 0.06,
	"cast_thorn": 0.05,
	"cast_willow": 0.05,
	"cast_stump": 0.04,
	"cast_sage": 0.05,
	"cast_volt": 0.06,
	"cast_nebula": 0.04,
	"cast_astral": 0.04,
	"sfx_projectile": 0.05,
	"sfx_cone": 0.04,
	"sfx_radius": 0.04,
	"sfx_dash": 0.05,
	"sfx_heal": 0.03,
	"sfx_shield": 0.03,
	"sfx_force": 0.04,
}

const MAX_VOICES := {
	"hit": 4,
	"hurt": 2,
	"enemy_death": 4,
	"xp": 1,
	"gold": 2,
	"enemy_shoot": 3,
	"explosion": 2,
	"ui_click": 2,
	"dash": 2,
	"charge": 2,
}

const UI_SOUND_IDS := {
	"ui_click": true,
	"shop_open": true,
	"shop_close": true,
	"purchase": true,
	"shop_fail": true,
}

const STINGER_IDS := {
	"wave_start": true,
	"wave_clear": true,
	"boss_alert": true,
	"game_over": true,
	"player_down": true,
	"level_up": true,
}

const MUSIC_TRACK: AudioStreamOggVorbis = preload("res://assets/audio/music/arena_theme.ogg")
const MUSIC_VOLUME_DB := -18.0
const POOL_SIZE := 14
const DEFAULT_MAX_VOICES := 5

var sfx_enabled := false
var music_enabled := true

## Self-test/probe hooks: last_play_ability mirrors the ability_id passed to the latest
## play_ability call that actually fired a player; last_play records the sound id, the
## exact stream take, and the AudioStreamPlayer of the most recent play() so probes can
## assert non-null and inspect which bank file was picked.
var last_play_ability: String = ""
var last_play: Dictionary = {}

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _active_by_id: Dictionary = {}
var _music_duck_tween: Tween


func _ready() -> void:
	sfx_enabled = PlayerProfile.sfx_enabled
	music_enabled = PlayerProfile.music_enabled
	_ensure_buses()
	_music_player = _make_music_player()
	for _index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.finished.connect(_on_pool_finished.bind(player))
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)
	_apply_mute_state()


func play(sound_id: String) -> AudioStreamPlayer:
	if not sfx_enabled or GameRuntime.is_dedicated_server():
		return null
	var takes: Array = SOUND_LIBRARY.get(sound_id, [])
	if takes.is_empty():
		push_warning("[AudioService] no sound bank for id '%s'" % sound_id)
		return null
	var player := _acquire_player(sound_id)
	if player == null:
		return null
	player.stream = takes[randi() % takes.size()]
	player.bus = "UI" if UI_SOUND_IDS.has(sound_id) else "SFX"
	player.volume_db = float(VOLUME_DB.get(sound_id, -8.0))
	var spread := float(PITCH_SPREAD.get(sound_id, 0.0))
	player.pitch_scale = 1.0 + randf_range(-spread, spread) if spread > 0.0 else 1.0
	player.play()
	last_play = {"sound_id": sound_id, "stream": player.stream, "player": player}
	if STINGER_IDS.has(sound_id):
		_duck_music()
	return player


func has_sound(sound_id: String) -> bool:
	return SOUND_LIBRARY.has(sound_id)


## Every cast plays its hero's own bank first — `cast_<hero>` from the ability id's hero
## prefix — so casts are hero-distinctive. Heroes without a bank of their own fall back to
## the shared archetype family takes (projectile/cone/heal/...) so the layer never goes
## silent; a total miss warns instead of crashing. last_play_ability records what fired
## for probes/debugging.
func play_ability(ability_id: String) -> AudioStreamPlayer:
	var bank := "cast_%s" % ability_id.split("_")[0]
	if SOUND_LIBRARY.has(bank):
		var player := play(bank)
		if player != null:
			last_play_ability = ability_id
		return player
	var info := PlayerClass.ability_info(ability_id)
	if not info.is_empty():
		var family := str(FAMILY_FOR_ARCHETYPE.get(int(info.get("archetype", -1)), ""))
		if family != "" and SOUND_LIBRARY.has(family):
			return play(family)
	push_warning("[AudioService] no cast bank or family take for ability '%s'" % ability_id)
	return null


func play_music() -> void:
	if music_enabled and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	PlayerProfile.sfx_enabled = enabled
	PlayerProfile.save_audio_prefs()
	_apply_mute_state()
	if not enabled:
		_stop_sfx()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	PlayerProfile.music_enabled = enabled
	PlayerProfile.save_audio_prefs()
	_apply_mute_state()
	if enabled:
		play_music()
	else:
		stop_music()


func _acquire_player(sound_id: String) -> AudioStreamPlayer:
	var cap := int(MAX_VOICES.get(sound_id, DEFAULT_MAX_VOICES))
	var active: Array = _active_by_id.get(sound_id, [])
	if active.size() >= cap:
		var stolen := active[0] as AudioStreamPlayer
		stolen.stop()
		_release_player(stolen)
	for candidate in _sfx_pool:
		if not candidate.playing:
			_mark_active(sound_id, candidate)
			return candidate
	var oldest: AudioStreamPlayer = _sfx_pool[0]
	oldest.stop()
	_release_player(oldest)
	_mark_active(sound_id, oldest)
	return oldest


func _mark_active(sound_id: String, player: AudioStreamPlayer) -> void:
	player.set_meta("sound_id", sound_id)
	var active: Array = _active_by_id.get(sound_id, [])
	active.append(player)
	_active_by_id[sound_id] = active


func _release_player(player: AudioStreamPlayer) -> void:
	if not player.has_meta("sound_id"):
		return
	var sound_id := str(player.get_meta("sound_id"))
	player.remove_meta("sound_id")
	var active: Array = _active_by_id.get(sound_id, [])
	active.erase(player)
	if active.is_empty():
		_active_by_id.erase(sound_id)
	else:
		_active_by_id[sound_id] = active


func _on_pool_finished(player: AudioStreamPlayer) -> void:
	_release_player(player)


func _stop_sfx() -> void:
	for player in _sfx_pool:
		if player.playing:
			player.stop()
		_release_player(player)


func _duck_music() -> void:
	if not music_enabled or _music_player == null:
		return
	if _music_duck_tween != null:
		_music_duck_tween.kill()
	_music_player.volume_db = MUSIC_VOLUME_DB - 7.0
	_music_duck_tween = create_tween()
	_music_duck_tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, 0.7)


func _apply_mute_state() -> void:
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var ui_bus := AudioServer.get_bus_index("UI")
	var music_bus := AudioServer.get_bus_index("Music")
	if sfx_bus >= 0:
		AudioServer.set_bus_mute(sfx_bus, not sfx_enabled)
	if ui_bus >= 0:
		AudioServer.set_bus_mute(ui_bus, not sfx_enabled)
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, not music_enabled)


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = MUSIC_TRACK
	player.volume_db = MUSIC_VOLUME_DB
	player.bus = "Music"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player
