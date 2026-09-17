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
	# Boss-defeat beat: a triumphant-ish stinger on top of the alert, so "you took the boss
	# down" reads as an event in the ears, not just the banner + ring sweep.
	"boss_defeat": [preload("res://assets/audio/sfx/boss_alert.ogg"), preload("res://assets/audio/sfx/level_up.ogg")],
	# Boss-takeover buff: a short rising chime when the killer "becomes the boss".
	"boss_takeover": [preload("res://assets/audio/sfx/level_up.ogg")],
	# Rain loop for the biome weather overlay (T3.5). Looped + crossfaded via set_rain().
	# Loaded lazily (not preload) so a missing import file can't break script parsing.
	"rain": [],
	"lava_cool": [],
	"electro_crackle": [],
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
	# T3.2: soft UI hover tick ΓÇö quieter and shorter than ui_click so it reads as a
	# gentle "you can interact here" cue without competing with the click.
	"ui_hover": [preload("res://assets/audio/themes/ui_hover.wav")],
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
	"attack_tobor": [
		preload("res://assets/audio/themes/attack_tobor.wav"),
		preload("res://assets/audio/themes/attack_tobor_2.wav"),
	],
	"attack_arclight": [
		preload("res://assets/audio/themes/attack_arclight.wav"),
		preload("res://assets/audio/themes/attack_arclight_2.wav"),
	],
	"attack_bulwark": [
		preload("res://assets/audio/themes/attack_bulwark.wav"),
		preload("res://assets/audio/themes/attack_bulwark_2.wav"),
	],
	"attack_warden": [
		preload("res://assets/audio/themes/attack_warden.wav"),
		preload("res://assets/audio/themes/attack_warden_2.wav"),
	],
	"attack_cinder": [preload("res://assets/audio/themes/attack_cinder.wav")],
	"attack_pyra": [preload("res://assets/audio/themes/attack_pyra.wav")],
	"attack_slag": [preload("res://assets/audio/themes/attack_slag.wav")],
	"attack_ember": [preload("res://assets/audio/themes/attack_ember.wav")],
	"attack_thorn": [preload("res://assets/audio/themes/attack_thorn.wav")],
	"attack_willow": [preload("res://assets/audio/themes/attack_willow.wav")],
	"attack_stump": [preload("res://assets/audio/themes/attack_stump.wav")],
	"attack_sage": [preload("res://assets/audio/themes/attack_sage.wav")],
	"attack_volt": [preload("res://assets/audio/themes/attack_volt.wav")],
	"attack_nebula": [preload("res://assets/audio/themes/attack_nebula.wav")],
	"attack_astral": [preload("res://assets/audio/themes/attack_astral.wav")],
	"attack_rime": [preload("res://assets/audio/themes/attack_rime.wav")],
	# T3.35 item 6: per-hero RMB/secondary banks, distinct timbre from the LMB
	# primary `attack_<hero>` bank (deeper, "charged release" feel).
	"attack_secondary_tobor": [preload("res://assets/audio/themes/secondary_tobor.wav")],
	"attack_secondary_frostbinder": [preload("res://assets/audio/themes/secondary_frostbinder.wav")],
	"attack_secondary_arclight": [preload("res://assets/audio/themes/secondary_arclight.wav")],
	"attack_secondary_bulwark": [preload("res://assets/audio/themes/secondary_bulwark.wav")],
	"attack_secondary_warden": [preload("res://assets/audio/themes/secondary_warden.wav")],
	"attack_secondary_cinder": [preload("res://assets/audio/themes/secondary_cinder.wav")],
	"attack_secondary_pyra": [preload("res://assets/audio/themes/secondary_pyra.wav")],
	"attack_secondary_slag": [preload("res://assets/audio/themes/secondary_slag.wav")],
	"attack_secondary_ember": [preload("res://assets/audio/themes/secondary_ember.wav")],
	"attack_secondary_thorn": [preload("res://assets/audio/themes/secondary_thorn.wav")],
	"attack_secondary_willow": [preload("res://assets/audio/themes/secondary_willow.wav")],
	"attack_secondary_stump": [preload("res://assets/audio/themes/secondary_stump.wav")],
	"attack_secondary_sage": [preload("res://assets/audio/themes/secondary_sage.wav")],
	"attack_secondary_volt": [preload("res://assets/audio/themes/secondary_volt.wav")],
	"attack_secondary_nebula": [preload("res://assets/audio/themes/secondary_nebula.wav")],
	"attack_secondary_astral": [preload("res://assets/audio/themes/secondary_astral.wav")],
	"attack_secondary_rime": [preload("res://assets/audio/themes/secondary_rime.wav")],
	# T3.35 item 7: boss-form attack (slam/cross/volley) shared deep/impactful stinger.
	"boss_attack": [preload("res://assets/audio/themes/boss_attack.wav")],
	"sfx_projectile": [preload("res://assets/audio/sfx/sfx_projectile.ogg")],
	# Summoned drones: a short zap when a turret fires. Reuses the shared projectile
	# bank (a short, distinct zap) so every firing drone has audible presence.
	"turret_fire": [preload("res://assets/audio/sfx/sfx_projectile.ogg")],
	# Companion-familiar (drone) firing stinger: a distinct quiet zap so the *drone*
	# has audible presence, separate from the hero's own attacks and the turret zap.
	"drone_fire": [preload("res://assets/audio/themes/drone_fire.wav")],
	"sfx_cone": [preload("res://assets/audio/sfx/sfx_cone.ogg")],
	"sfx_radius": [preload("res://assets/audio/sfx/sfx_radius.ogg")],
	"sfx_dash": [preload("res://assets/audio/sfx/sfx_dash.ogg")],
	"sfx_heal": [preload("res://assets/audio/sfx/sfx_heal.ogg")],
	"sfx_shield": [preload("res://assets/audio/sfx/sfx_shield.ogg")],
	"sfx_force": [preload("res://assets/audio/sfx/sfx_force.ogg")],
	# 5-4-3-2-1 fight countdown stingers: a short synthesized tick for each number
	# and a heavier "GO / FIGHT" beat when the wave starts.
	"countdown_tick": [preload("res://assets/audio/themes/countdown_tick.wav")],
	"countdown_fight": [preload("res://assets/audio/themes/countdown_fight.wav")],
	# Per-biome footstep stingers (P3 footstep sounds). Quiet, single-shot, fired on a
	# cadence while the hero walks so movement "reads" even in a busy mix.
	"step_grass": [preload("res://assets/audio/themes/step_grass.wav")],
	"step_ice": [preload("res://assets/audio/themes/step_ice.wav")],
	"step_lava": [preload("res://assets/audio/themes/step_lava.wav")],
	"step_metal": [preload("res://assets/audio/themes/step_metal.wav")],
	"step_wood": [preload("res://assets/audio/themes/step_wood.wav")],
	# Village minigame completion stinger: a bright, celebratory chime.
	"minigame_win": [preload("res://assets/audio/themes/minigame_win.wav")],
	# Per-minigame action stingers (P1.2): each game's signature action has a
	# unique one-shot so the four games read differently in the ears.
	"minigame_keg_toss": [preload("res://assets/audio/themes/minigame_keg_toss.wav")],
	"minigame_whack": [preload("res://assets/audio/themes/minigame_whack.wav")],
	"minigame_rps": [preload("res://assets/audio/themes/minigame_rps.wav")],
	"minigame_treasure": [preload("res://assets/audio/themes/minigame_treasure.wav")],
	"minigame_creep_tag": [preload("res://assets/audio/themes/minigame_creep_tag.wav")],
	"minigame_dance_disco": [preload("res://assets/audio/themes/minigame_dance_disco.wav")],
	"minigame_keg_toss_pro": [preload("res://assets/audio/themes/minigame_keg_toss_pro.wav")],
	"minigame_treasure_dash2": [preload("res://assets/audio/themes/minigame_treasure_dash2.wav")],
	"minigame_whack_rush": [preload("res://assets/audio/themes/minigame_whack_rush.wav")],
	"minigame_balloon_pop": [preload("res://assets/audio/themes/minigame_balloon_pop.wav")],
	"minigame_crate_stack": [preload("res://assets/audio/themes/minigame_crate_stack.wav")],
	"minigame_crystal_catch": [preload("res://assets/audio/themes/minigame_crystal_catch.wav")],
	"minigame_gem_relay": [preload("res://assets/audio/themes/minigame_gem_relay.wav")],
	"minigame_ring_roll": [preload("res://assets/audio/themes/minigame_ring_roll.wav")],
	"minigame_slime_splat": [preload("res://assets/audio/themes/minigame_slime_splat.wav")],
	"minigame_creep_pinball": [preload("res://assets/audio/themes/minigame_creep_pinball.wav")],
	# Arclight's bouncing lightning: a sharp electric "crack" that fires on every
	# chain hop so the bolt reads as it arcs between targets (Thunderbringer-style).
	"chain_bounce": [
		preload("res://assets/audio/themes/chain_bounce.wav"),
		preload("res://assets/audio/themes/chain_bounce_2.wav"),
	],
	"bomb_run": [preload("res://assets/audio/themes/bomb_run.wav")],
	"ability_arclight_arc_flash": [preload("res://assets/audio/themes/ability_arclight_arc_flash.wav")],
	"ability_arclight_ball_lightning": [preload("res://assets/audio/themes/ability_arclight_ball_lightning.wav")],
	"ability_arclight_blast_of_lightning": [preload("res://assets/audio/themes/ability_arclight_blast_of_lightning.wav")],
	"ability_arclight_chain_lightning": [preload("res://assets/audio/themes/ability_arclight_chain_lightning.wav")],
	"ability_arclight_ion_storm": [preload("res://assets/audio/themes/ability_arclight_ion_storm.wav")],
	"ability_arclight_overcharge": [preload("res://assets/audio/themes/ability_arclight_overcharge.wav")],
	"ability_arclight_overclock": [preload("res://assets/audio/themes/ability_arclight_overclock.wav")],
	"ability_arclight_paralyzing_bolt": [preload("res://assets/audio/themes/ability_arclight_paralyzing_bolt.wav")],
	"ability_arclight_repulsor_field": [preload("res://assets/audio/themes/ability_arclight_repulsor_field.wav")],
	"ability_arclight_second_wind": [preload("res://assets/audio/themes/ability_arclight_second_wind.wav")],
	"ability_arclight_static_bolt": [preload("res://assets/audio/themes/ability_arclight_static_bolt.wav")],
	"ability_arclight_thunder_step": [preload("res://assets/audio/themes/ability_arclight_thunder_step.wav")],
	"ability_arclight_thundergods_wrath": [preload("res://assets/audio/themes/ability_arclight_thundergods_wrath.wav")],
	"ability_arclight_track": [preload("res://assets/audio/themes/ability_arclight_track.wav")],
	"ability_arclight_volt_siphon": [preload("res://assets/audio/themes/ability_arclight_volt_siphon.wav")],
	"ability_astral_as_one": [preload("res://assets/audio/themes/ability_astral_as_one.wav")],
	"ability_astral_bright_tether": [preload("res://assets/audio/themes/ability_astral_bright_tether.wav")],
	"ability_astral_essence_link": [preload("res://assets/audio/themes/ability_astral_essence_link.wav")],
	"ability_astral_ethereal_link": [preload("res://assets/audio/themes/ability_astral_ethereal_link.wav")],
	"ability_astral_ghastly_touch": [preload("res://assets/audio/themes/ability_astral_ghastly_touch.wav")],
	"ability_astral_ghost_light": [preload("res://assets/audio/themes/ability_astral_ghost_light.wav")],
	"ability_astral_luminous_ward": [preload("res://assets/audio/themes/ability_astral_luminous_ward.wav")],
	"ability_astral_moonfall": [preload("res://assets/audio/themes/ability_astral_moonfall.wav")],
	"ability_astral_seance": [preload("res://assets/audio/themes/ability_astral_seance.wav")],
	"ability_astral_spirit_bond": [preload("res://assets/audio/themes/ability_astral_spirit_bond.wav")],
	"ability_astral_ward_of_light": [preload("res://assets/audio/themes/ability_astral_ward_of_light.wav")],
	"ability_astral_wisp_nova": [preload("res://assets/audio/themes/ability_astral_wisp_nova.wav")],
	"ability_bulwark_aftershock": [preload("res://assets/audio/themes/ability_bulwark_aftershock.wav")],
	"ability_bulwark_cleave": [preload("res://assets/audio/themes/ability_bulwark_cleave.wav")],
	"ability_bulwark_echo_slam": [preload("res://assets/audio/themes/ability_bulwark_echo_slam.wav")],
	"ability_bulwark_fissure": [preload("res://assets/audio/themes/ability_bulwark_fissure.wav")],
	"ability_bulwark_fortify": [preload("res://assets/audio/themes/ability_bulwark_fortify.wav")],
	"ability_bulwark_ground_slam": [preload("res://assets/audio/themes/ability_bulwark_ground_slam.wav")],
	"ability_bulwark_heavyweight": [preload("res://assets/audio/themes/ability_bulwark_heavyweight.wav")],
	"ability_bulwark_iron_charge": [preload("res://assets/audio/themes/ability_bulwark_iron_charge.wav")],
	"ability_bulwark_last_stand": [preload("res://assets/audio/themes/ability_bulwark_last_stand.wav")],
	"ability_bulwark_provoke": [preload("res://assets/audio/themes/ability_bulwark_provoke.wav")],
	"ability_bulwark_rallying_warcry": [preload("res://assets/audio/themes/ability_bulwark_rallying_warcry.wav")],
	"ability_bulwark_retribution": [preload("res://assets/audio/themes/ability_bulwark_retribution.wav")],
	"ability_bulwark_second_wind": [preload("res://assets/audio/themes/ability_bulwark_second_wind.wav")],
	"ability_bulwark_shockwave_strike": [preload("res://assets/audio/themes/ability_bulwark_shockwave_strike.wav")],
	"ability_bulwark_sunder": [preload("res://assets/audio/themes/ability_bulwark_sunder.wav")],
	"ability_cinder_combustion_wave": [preload("res://assets/audio/themes/ability_cinder_combustion_wave.wav")],
	"ability_cinder_dragon_fire": [preload("res://assets/audio/themes/ability_cinder_dragon_fire.wav")],
	"ability_cinder_fiery_assault": [preload("res://assets/audio/themes/ability_cinder_fiery_assault.wav")],
	"ability_cinder_firebomb": [preload("res://assets/audio/themes/ability_cinder_firebomb.wav")],
	"ability_cinder_flame_dash": [preload("res://assets/audio/themes/ability_cinder_flame_dash.wav")],
	"ability_cinder_heat_surge": [preload("res://assets/audio/themes/ability_cinder_heat_surge.wav")],
	"ability_cinder_ignite": [preload("res://assets/audio/themes/ability_cinder_ignite.wav")],
	"ability_cinder_magma_armor": [preload("res://assets/audio/themes/ability_cinder_magma_armor.wav")],
	"ability_cinder_pillar_of_flame": [preload("res://assets/audio/themes/ability_cinder_pillar_of_flame.wav")],
	"ability_cinder_pyroclasm": [preload("res://assets/audio/themes/ability_cinder_pyroclasm.wav")],
	"ability_cinder_scorch": [preload("res://assets/audio/themes/ability_cinder_scorch.wav")],
	"ability_cinder_whirling_flame": [preload("res://assets/audio/themes/ability_cinder_whirling_flame.wav")],
	"ability_ember_burning_aura": [preload("res://assets/audio/themes/ability_ember_burning_aura.wav")],
	"ability_ember_cinder_shield": [preload("res://assets/audio/themes/ability_ember_cinder_shield.wav")],
	"ability_ember_entangle": [preload("res://assets/audio/themes/ability_ember_entangle.wav")],
	"ability_ember_firebomb": [preload("res://assets/audio/themes/ability_ember_firebomb.wav")],
	"ability_ember_flamebreak": [preload("res://assets/audio/themes/ability_ember_flamebreak.wav")],
	"ability_ember_healing_wave": [preload("res://assets/audio/themes/ability_ember_healing_wave.wav")],
	"ability_ember_heat_vent": [preload("res://assets/audio/themes/ability_ember_heat_vent.wav")],
	"ability_ember_mending_flame": [preload("res://assets/audio/themes/ability_ember_mending_flame.wav")],
	"ability_ember_phoenix_dash": [preload("res://assets/audio/themes/ability_ember_phoenix_dash.wav")],
	"ability_ember_spark_volley": [preload("res://assets/audio/themes/ability_ember_spark_volley.wav")],
	"ability_ember_storm_cloud": [preload("res://assets/audio/themes/ability_ember_storm_cloud.wav")],
	"ability_ember_unbreakable": [preload("res://assets/audio/themes/ability_ember_unbreakable.wav")],
	"ability_nebula_arcane_bolt": [preload("res://assets/audio/themes/ability_nebula_arcane_bolt.wav")],
	"ability_nebula_blink": [preload("res://assets/audio/themes/ability_nebula_blink.wav")],
	"ability_nebula_chronofield": [preload("res://assets/audio/themes/ability_nebula_chronofield.wav")],
	"ability_nebula_cold_snap": [preload("res://assets/audio/themes/ability_nebula_cold_snap.wav")],
	"ability_nebula_curse_of_ages": [preload("res://assets/audio/themes/ability_nebula_curse_of_ages.wav")],
	"ability_nebula_emp": [preload("res://assets/audio/themes/ability_nebula_emp.wav")],
	"ability_nebula_frost_blast": [preload("res://assets/audio/themes/ability_nebula_frost_blast.wav")],
	"ability_nebula_meteor_shower": [preload("res://assets/audio/themes/ability_nebula_meteor_shower.wav")],
	"ability_nebula_rewind": [preload("res://assets/audio/themes/ability_nebula_rewind.wav")],
	"ability_nebula_time_shift": [preload("res://assets/audio/themes/ability_nebula_time_shift.wav")],
	"ability_nebula_void_rift": [preload("res://assets/audio/themes/ability_nebula_void_rift.wav")],
	"ability_nebula_warp_field": [preload("res://assets/audio/themes/ability_nebula_warp_field.wav")],
	"ability_pyra_air_strike": [preload("res://assets/audio/themes/ability_pyra_air_strike.wav")],
	"ability_pyra_bombardment": [preload("res://assets/audio/themes/ability_pyra_bombardment.wav")],
	"ability_pyra_boom_dust": [preload("res://assets/audio/themes/ability_pyra_boom_dust.wav")],
	"ability_pyra_fireball": [preload("res://assets/audio/themes/ability_pyra_fireball.wav")],
	"ability_pyra_flame_wall": [preload("res://assets/audio/themes/ability_pyra_flame_wall.wav")],
	"ability_pyra_heat_shield": [preload("res://assets/audio/themes/ability_pyra_heat_shield.wav")],
	"ability_pyra_meteor": [preload("res://assets/audio/themes/ability_pyra_meteor.wav")],
	"ability_pyra_molten_charge": [preload("res://assets/audio/themes/ability_pyra_molten_charge.wav")],
	"ability_pyra_rock_throw": [preload("res://assets/audio/themes/ability_pyra_rock_throw.wav")],
	"ability_pyra_scorch_mark": [preload("res://assets/audio/themes/ability_pyra_scorch_mark.wav")],
	"ability_pyra_sticky_bomb": [preload("res://assets/audio/themes/ability_pyra_sticky_bomb.wav")],
	"ability_pyra_volcano": [preload("res://assets/audio/themes/ability_pyra_volcano.wav")],
	"ability_rime_chilling_touch": [preload("res://assets/audio/themes/ability_rime_chilling_touch.wav")],
	"ability_rime_cleave": [preload("res://assets/audio/themes/ability_rime_cleave.wav")],
	"ability_rime_cold_rush": [preload("res://assets/audio/themes/ability_rime_cold_rush.wav")],
	"ability_rime_freezing_field": [preload("res://assets/audio/themes/ability_rime_freezing_field.wav")],
	"ability_rime_frost_armor": [preload("res://assets/audio/themes/ability_rime_frost_armor.wav")],
	"ability_rime_frozen_ward": [preload("res://assets/audio/themes/ability_rime_frozen_ward.wav")],
	"ability_rime_glacier_blast": [preload("res://assets/audio/themes/ability_rime_glacier_blast.wav")],
	"ability_rime_hailstorm": [preload("res://assets/audio/themes/ability_rime_hailstorm.wav")],
	"ability_rime_ice_imprisonment": [preload("res://assets/audio/themes/ability_rime_ice_imprisonment.wav")],
	"ability_rime_thaw": [preload("res://assets/audio/themes/ability_rime_thaw.wav")],
	"ability_rime_whiteout": [preload("res://assets/audio/themes/ability_rime_whiteout.wav")],
	"ability_rime_winters_grasp": [preload("res://assets/audio/themes/ability_rime_winters_grasp.wav")],
	"ability_sage_charm": [preload("res://assets/audio/themes/ability_sage_charm.wav")],
	"ability_sage_entangle": [preload("res://assets/audio/themes/ability_sage_entangle.wav")],
	"ability_sage_grace": [preload("res://assets/audio/themes/ability_sage_grace.wav")],
	"ability_sage_healing_wave": [preload("res://assets/audio/themes/ability_sage_healing_wave.wav")],
	"ability_sage_lifeward": [preload("res://assets/audio/themes/ability_sage_lifeward.wav")],
	"ability_sage_natures_step": [preload("res://assets/audio/themes/ability_sage_natures_step.wav")],
	"ability_sage_nymphoras_kiss": [preload("res://assets/audio/themes/ability_sage_nymphoras_kiss.wav")],
	"ability_sage_petal_dance": [preload("res://assets/audio/themes/ability_sage_petal_dance.wav")],
	"ability_sage_rejuvenate": [preload("res://assets/audio/themes/ability_sage_rejuvenate.wav")],
	"ability_sage_starfall": [preload("res://assets/audio/themes/ability_sage_starfall.wav")],
	"ability_sage_volatile_pod": [preload("res://assets/audio/themes/ability_sage_volatile_pod.wav")],
	"ability_sage_world_seed": [preload("res://assets/audio/themes/ability_sage_world_seed.wav")],
	"ability_slag_basalt_armour": [preload("res://assets/audio/themes/ability_slag_basalt_armour.wav")],
	"ability_slag_boulder_hurl": [preload("res://assets/audio/themes/ability_slag_boulder_hurl.wav")],
	"ability_slag_earthen_slam": [preload("res://assets/audio/themes/ability_slag_earthen_slam.wav")],
	"ability_slag_eruption": [preload("res://assets/audio/themes/ability_slag_eruption.wav")],
	"ability_slag_geysers": [preload("res://assets/audio/themes/ability_slag_geysers.wav")],
	"ability_slag_lava_surge": [preload("res://assets/audio/themes/ability_slag_lava_surge.wav")],
	"ability_slag_lava_wall": [preload("res://assets/audio/themes/ability_slag_lava_wall.wav")],
	"ability_slag_magma_charge": [preload("res://assets/audio/themes/ability_slag_magma_charge.wav")],
	"ability_slag_molten_skin": [preload("res://assets/audio/themes/ability_slag_molten_skin.wav")],
	"ability_slag_seismic_ring": [preload("res://assets/audio/themes/ability_slag_seismic_ring.wav")],
	"ability_slag_steam_bath": [preload("res://assets/audio/themes/ability_slag_steam_bath.wav")],
	"ability_slag_volcanic_touch": [preload("res://assets/audio/themes/ability_slag_volcanic_touch.wav")],
	"ability_stump_barkskin": [preload("res://assets/audio/themes/ability_stump_barkskin.wav")],
	"ability_stump_camouflage": [preload("res://assets/audio/themes/ability_stump_camouflage.wav")],
	"ability_stump_fortress_grove": [preload("res://assets/audio/themes/ability_stump_fortress_grove.wav")],
	"ability_stump_heartwood": [preload("res://assets/audio/themes/ability_stump_heartwood.wav")],
	"ability_stump_living_seed": [preload("res://assets/audio/themes/ability_stump_living_seed.wav")],
	"ability_stump_natures_rally": [preload("res://assets/audio/themes/ability_stump_natures_rally.wav")],
	"ability_stump_natures_veil": [preload("res://assets/audio/themes/ability_stump_natures_veil.wav")],
	"ability_stump_overgrowth": [preload("res://assets/audio/themes/ability_stump_overgrowth.wav")],
	"ability_stump_root_charge": [preload("res://assets/audio/themes/ability_stump_root_charge.wav")],
	"ability_stump_trunk_slam": [preload("res://assets/audio/themes/ability_stump_trunk_slam.wav")],
	"ability_stump_wall": [preload("res://assets/audio/themes/ability_stump_wall.wav")],
	"ability_stump_wildgrowth": [preload("res://assets/audio/themes/ability_stump_wildgrowth.wav")],
	"ability_thorn_ambush": [preload("res://assets/audio/themes/ability_thorn_ambush.wav")],
	"ability_thorn_bramble_dash": [preload("res://assets/audio/themes/ability_thorn_bramble_dash.wav")],
	"ability_thorn_poison_burst": [preload("res://assets/audio/themes/ability_thorn_poison_burst.wav")],
	"ability_thorn_poison_spray": [preload("res://assets/audio/themes/ability_thorn_poison_spray.wav")],
	"ability_thorn_root_tangle": [preload("res://assets/audio/themes/ability_thorn_root_tangle.wav")],
	"ability_thorn_spore_burst": [preload("res://assets/audio/themes/ability_thorn_spore_burst.wav")],
	"ability_thorn_thorn_armour": [preload("res://assets/audio/themes/ability_thorn_thorn_armour.wav")],
	"ability_thorn_toxic_cloud": [preload("res://assets/audio/themes/ability_thorn_toxic_cloud.wav")],
	"ability_thorn_toxicity": [preload("res://assets/audio/themes/ability_thorn_toxicity.wav")],
	"ability_thorn_toxin_ward": [preload("res://assets/audio/themes/ability_thorn_toxin_ward.wav")],
	"ability_thorn_venom_strike": [preload("res://assets/audio/themes/ability_thorn_venom_strike.wav")],
	"ability_thorn_vine_lash": [preload("res://assets/audio/themes/ability_thorn_vine_lash.wav")],
	"ability_tobor_boiler_burst": [preload("res://assets/audio/themes/ability_tobor_boiler_burst.wav")],
	"ability_tobor_energy_absorption": [preload("res://assets/audio/themes/ability_tobor_energy_absorption.wav")],
	"ability_tobor_energy_field": [preload("res://assets/audio/themes/ability_tobor_energy_field.wav")],
	"ability_tobor_ironclad_chassis": [preload("res://assets/audio/themes/ability_tobor_ironclad_chassis.wav")],
	"ability_tobor_keg_lob": [preload("res://assets/audio/themes/ability_tobor_keg_lob.wav")],
	"ability_tobor_repair_pulse": [preload("res://assets/audio/themes/ability_tobor_repair_pulse.wav")],
	"ability_tobor_scrap_shield": [preload("res://assets/audio/themes/ability_tobor_scrap_shield.wav")],
	"ability_tobor_spider_mines": [preload("res://assets/audio/themes/ability_tobor_spider_mines.wav")],
	"ability_tobor_steam_keg": [preload("res://assets/audio/themes/ability_tobor_steam_keg.wav")],
	"ability_tobor_steam_turret": [preload("res://assets/audio/themes/ability_tobor_steam_turret.wav")],
	"ability_tobor_steam_vent": [preload("res://assets/audio/themes/ability_tobor_steam_vent.wav")],
	"ability_tobor_turret_overdrive": [preload("res://assets/audio/themes/ability_tobor_turret_overdrive.wav")],
	"ability_tobor_wrench_toss": [preload("res://assets/audio/themes/ability_tobor_wrench_toss.wav")],
	"ability_volt_amp_field": [preload("res://assets/audio/themes/ability_volt_amp_field.wav")],
	"ability_volt_electro_dash": [preload("res://assets/audio/themes/ability_volt_electro_dash.wav")],
	"ability_volt_electroshock": [preload("res://assets/audio/themes/ability_volt_electroshock.wav")],
	"ability_volt_gust": [preload("res://assets/audio/themes/ability_volt_gust.wav")],
	"ability_volt_lightning_lunge": [preload("res://assets/audio/themes/ability_volt_lightning_lunge.wav")],
	"ability_volt_plasma_bolt": [preload("res://assets/audio/themes/ability_volt_plasma_bolt.wav")],
	"ability_volt_repulsor_blast": [preload("res://assets/audio/themes/ability_volt_repulsor_blast.wav")],
	"ability_volt_static_drain": [preload("res://assets/audio/themes/ability_volt_static_drain.wav")],
	"ability_volt_typhoon": [preload("res://assets/audio/themes/ability_volt_typhoon.wav")],
	"ability_volt_voltaic_cage": [preload("res://assets/audio/themes/ability_volt_voltaic_cage.wav")],
	"ability_volt_wind_control": [preload("res://assets/audio/themes/ability_volt_wind_control.wav")],
	"ability_volt_wind_shield": [preload("res://assets/audio/themes/ability_volt_wind_shield.wav")],
	"ability_warden_bramble_wall": [preload("res://assets/audio/themes/ability_warden_bramble_wall.wav")],
	"ability_warden_entangle": [preload("res://assets/audio/themes/ability_warden_entangle.wav")],
	"ability_warden_life_drain": [preload("res://assets/audio/themes/ability_warden_life_drain.wav")],
	"ability_warden_mending_wave": [preload("res://assets/audio/themes/ability_warden_mending_wave.wav")],
	"ability_warden_natures_grasp": [preload("res://assets/audio/themes/ability_warden_natures_grasp.wav")],
	"ability_warden_natures_wrath": [preload("res://assets/audio/themes/ability_warden_natures_wrath.wav")],
	"ability_warden_rising_choir": [preload("res://assets/audio/themes/ability_warden_rising_choir.wav")],
	"ability_warden_second_bloom": [preload("res://assets/audio/themes/ability_warden_second_bloom.wav")],
	"ability_warden_thorn_volley": [preload("res://assets/audio/themes/ability_warden_thorn_volley.wav")],
	"ability_warden_tongue_tied": [preload("res://assets/audio/themes/ability_warden_tongue_tied.wav")],
	"ability_warden_verdant_ward": [preload("res://assets/audio/themes/ability_warden_verdant_ward.wav")],
	"ability_warden_vine_lash": [preload("res://assets/audio/themes/ability_warden_vine_lash.wav")],
	"ability_warden_vine_step": [preload("res://assets/audio/themes/ability_warden_vine_step.wav")],
	"ability_warden_vital_drain": [preload("res://assets/audio/themes/ability_warden_vital_drain.wav")],
	"ability_warden_voodoo_wards": [preload("res://assets/audio/themes/ability_warden_voodoo_wards.wav")],
	"ability_willow_briar_jab": [preload("res://assets/audio/themes/ability_willow_briar_jab.wav")],
	"ability_willow_briar_wall": [preload("res://assets/audio/themes/ability_willow_briar_wall.wav")],
	"ability_willow_final_bloom": [preload("res://assets/audio/themes/ability_willow_final_bloom.wav")],
	"ability_willow_forsaken_shot": [preload("res://assets/audio/themes/ability_willow_forsaken_shot.wav")],
	"ability_willow_seed_bomb": [preload("res://assets/audio/themes/ability_willow_seed_bomb.wav")],
	"ability_willow_shadow_step": [preload("res://assets/audio/themes/ability_willow_shadow_step.wav")],
	"ability_willow_spore_volley": [preload("res://assets/audio/themes/ability_willow_spore_volley.wav")],
	"ability_willow_swift_strike": [preload("res://assets/audio/themes/ability_willow_swift_strike.wav")],
	"ability_willow_thorn_snare": [preload("res://assets/audio/themes/ability_willow_thorn_snare.wav")],
	"ability_willow_vital_strike": [preload("res://assets/audio/themes/ability_willow_vital_strike.wav")],
	"ability_willow_volley": [preload("res://assets/audio/themes/ability_willow_volley.wav")],
	"ability_willow_wall_of_roots": [preload("res://assets/audio/themes/ability_willow_wall_of_roots.wav")],
}

## P1.3: every archetype in the roster now maps to a distinct SFX family so each
## hero's 4 abilities read differently in the ears. New families reuse shared .ogg
## banks but each maps to a different family id (cone/radius/dash/heal/shield/force)
## so the 18 archetypes are never silent.
const FAMILY_FOR_ARCHETYPE := {
	PlayerClass.Archetype.NUKE_BOLT: "sfx_projectile",
	PlayerClass.Archetype.CHAIN_NUKE: "sfx_projectile",
	PlayerClass.Archetype.CONE_BURST: "sfx_cone",
	PlayerClass.Archetype.RADIUS_BURST: "sfx_radius",
	PlayerClass.Archetype.DASH_STRIKE: "sfx_dash",
	PlayerClass.Archetype.BLINK: "sfx_dash",
	PlayerClass.Archetype.BLINK_STRIKE: "sfx_dash",
	PlayerClass.Archetype.SELF_HEAL: "sfx_heal",
	PlayerClass.Archetype.AOE_HEAL: "sfx_heal",
	PlayerClass.Archetype.SHIELD_BURST: "sfx_shield",
	PlayerClass.Archetype.BUFF_SELF: "sfx_shield",
	PlayerClass.Archetype.PUSH_PULL_BURST: "sfx_force",
	## Storm-pull: a whirling gale that drags enemies in (Volt's kit).
	PlayerClass.Archetype.STORM_PULL: "sfx_cone",
	## Zone-channel: a lingering field that ticks (Rime's freezing field, Nebula's chronofield).
	PlayerClass.Archetype.ZONE_CHANNEL: "sfx_radius",
	## Summon-spirit: a familiar or ward appears on the field (Warden, Tobor turrets).
	PlayerClass.Archetype.SUMMON_SPIRIT: "sfx_shield",
	## Slam-taunt: a ground pound that also draws aggro (Bulwark).
	PlayerClass.Archetype.SLAM_TAUNT: "sfx_force",
	## Pit-slow: a cold ring that slows everything inside (Rime's chill).
	PlayerClass.Archetype.PIT_SLOW: "sfx_heal",
	## Attack-fury: a temporary attack-speed buff (self-buff, reads as a shield-up).
	PlayerClass.Archetype.ATTACK_FURY: "sfx_shield",
	## Spawn-wall: a linear wall of thorns/ice/bark that stuns along its line.
	PlayerClass.Archetype.SPAWN_WALL: "sfx_force",
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
	"ui_hover": -16.0,  # T3.2: quieter than click so hover never competes with a click
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
	# 2026-09-16 user rule: "there is missing sound for lmb and rmb." The primary and
	# secondary attack banks were sitting 6-8dB below the cast banks, so in a busy mix
	# (enemies, projectiles, music) they were easily lost. Brought up to roughly match
	# the cast banks so every swing / charge-release is clearly audible.
	"attack_tobor": -6.0,
	"attack_arclight": -7.0,
	"attack_bulwark": -5.0,
	"attack_warden": -7.0,
	"attack_cinder": -6.0,
	"attack_pyra": -6.0,
	"attack_slag": -5.0,
	"attack_ember": -7.0,
	"attack_thorn": -7.0,
	"attack_willow": -7.0,
	"attack_stump": -6.0,
	"attack_sage": -7.0,
	"attack_volt": -7.0,
	"attack_nebula": -7.0,
	"attack_astral": -7.0,
	"attack_rime": -7.0,
	# T3.35 item 6: secondary (RMB) SFX slightly louder than primary so the
	# "charge release" moment is clearly audible.
	"attack_secondary_tobor": -5.0,
	"attack_secondary_arclight": -6.0,
	"attack_secondary_bulwark": -4.0,
	"attack_secondary_warden": -6.0,
	"attack_secondary_cinder": -5.0,
	"attack_secondary_pyra": -5.0,
	"attack_secondary_slag": -4.0,
	"attack_secondary_ember": -6.0,
	"attack_secondary_thorn": -6.0,
	"attack_secondary_willow": -6.0,
	"attack_secondary_stump": -5.0,
	"attack_secondary_sage": -6.0,
	"attack_secondary_volt": -6.0,
	"attack_secondary_nebula": -6.0,
	"attack_secondary_astral": -6.0,
	"attack_secondary_rime": -6.0,
	# T3.35 item 7: boss attack is meant to be felt ΓÇö keep it prominent but not
	# ear-splitting since it can fire on a 2.6-3.5s cadence in boss form.
	"boss_attack": -4.0,
	"countdown_tick": -6.0,
	"countdown_fight": -4.0,
	"step_grass": -18.0,
	"step_ice": -18.0,
	"step_lava": -18.0,
	"step_metal": -18.0,
	"step_wood": -18.0,
	"sfx_projectile": -9.0,
	"turret_fire": -12.0,
	"drone_fire": -19.0,
	"sfx_cone": -8.0,
	"sfx_radius": -7.0,
	"sfx_dash": -9.0,
	"sfx_heal": -9.0,
	"sfx_shield": -9.0,
	"sfx_force": -8.0,
	"chain_bounce": -7.0,
	"boss_takeover": -3.0,
	"boss_defeat": -2.0,
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
	"cast_warden": 0.14,
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
	"attack_tobor": 0.05,
	"attack_arclight": 0.06,
	"attack_bulwark": 0.04,
	"attack_warden": 0.05,
	# T3.35 item 6: secondary SFX get a small pitch spread too, like the primaries.
	"attack_secondary_tobor": 0.04,
	"attack_secondary_arclight": 0.05,
	"attack_secondary_bulwark": 0.04,
	"attack_secondary_warden": 0.04,
	"attack_secondary_cinder": 0.04,
	"attack_secondary_pyra": 0.04,
	"attack_secondary_slag": 0.04,
	"attack_secondary_ember": 0.04,
	"attack_secondary_thorn": 0.04,
	"attack_secondary_willow": 0.04,
	"attack_secondary_stump": 0.04,
	"attack_secondary_sage": 0.04,
	"attack_secondary_volt": 0.05,
	"attack_secondary_nebula": 0.04,
	"attack_secondary_astral": 0.04,
	"attack_secondary_rime": 0.04,
	"boss_attack": 0.03,
	"countdown_tick": 0.02,
	"countdown_fight": 0.0,
	"step_grass": 0.08,
	"step_ice": 0.06,
	"step_lava": 0.06,
	"step_metal": 0.06,
	"step_wood": 0.08,
	"sfx_projectile": 0.05,
	"turret_fire": 0.05,
	"drone_fire": 0.06,
	"sfx_cone": 0.04,
	"sfx_radius": 0.04,
	"sfx_dash": 0.05,
	"sfx_heal": 0.03,
	"sfx_shield": 0.03,
	"sfx_force": 0.04,
	"chain_bounce": 0.05,
	"bomb_run": 0.03,
}

const MAX_VOICES := {
	"hit": 4,
	"hurt": 2,
	"enemy_death": 4,
	"xp": 1,
	"gold": 2,
	"enemy_shoot": 3,
	"explosion": 1,
	"ui_click": 2,
	"dash": 2,
	"turret_fire": 6,
	"drone_fire": 4,
	"charge": 2,
	"step_grass": 2,
	"step_ice": 2,
	"step_lava": 2,
	"step_metal": 2,
	"step_wood": 2,
	"cast_tobor": 2,
	"attack_tobor": 3,
	"attack_arclight": 3,
	"attack_bulwark": 3,
	"attack_warden": 3,
	"chain_bounce": 8,
	"bomb_run": 2,
}

const UI_SOUND_IDS := {
	"ui_click": true,
	"ui_hover": true,
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

## Per-world ambient beds: T3.2 — each biome layers up to 4 simultaneous loops
## (a primary bed + 3 sub-layers) so every world has a layered soundscape instead of
## a single bed. Each entry is [AudioStream, volume_offset_db]. Synthesized by
## tools/synth_themes.py (WORLD_AMBIENT_LOOPS).
const WORLD_THEME_TRACKS: Dictionary = {
	0: [
		[preload("res://assets/audio/themes/world_grass.wav"), 0.0],
		[preload("res://assets/audio/themes/world_grass_birds.wav"), -4.0],
		[preload("res://assets/audio/themes/world_grass_wind.wav"), -6.0],
		[preload("res://assets/audio/themes/world_grass_stream.wav"), -5.0],
	],
	1: [
		[preload("res://assets/audio/themes/world_volcano.wav"), 0.0],
		[preload("res://assets/audio/themes/world_volcano_embers.wav"), -4.0],
		[preload("res://assets/audio/themes/world_volcano_magma.wav"), -5.0],
		[preload("res://assets/audio/themes/world_volcano_sub.wav"), -8.0],
	],
	2: [
		[preload("res://assets/audio/themes/world_ice.wav"), 0.0],
		[preload("res://assets/audio/themes/world_ice_gust.wav"), -4.0],
		[preload("res://assets/audio/themes/world_ice_snow.wav"), -5.0],
		[preload("res://assets/audio/themes/world_ice_tinkle.wav"), -6.0],
	],
	3: [
		[preload("res://assets/audio/themes/world_factory.wav"), 0.0],
		[preload("res://assets/audio/themes/world_factory_clang.wav"), -5.0],
		[preload("res://assets/audio/themes/world_factory_clank.wav"), -6.0],
		[preload("res://assets/audio/themes/world_factory_steam.wav"), -4.0],
	],
	4: [
		[preload("res://assets/audio/themes/world_docks.wav"), 0.0],
		[preload("res://assets/audio/themes/world_docks_gull.wav"), -4.0],
		[preload("res://assets/audio/themes/world_docks_lapping.wav"), -5.0],
		[preload("res://assets/audio/themes/world_docks_rope.wav"), -7.0],
	],
}
const WORLD_THEME_VOLUME_DB := -24.0
## Number of simultaneous ambient-loop layers per world (T3.2).
const _WORLD_THEME_SLOT_COUNT := 4

var sfx_enabled := false
var music_enabled := true
var _world_theme_players: Array[AudioStreamPlayer] = []
var _world_theme_biome: int = -1

## Self-test/probe hooks: last_play_ability mirrors the ability_id passed to the latest
## play_ability call that actually fired a player; last_play records the sound id, the
## exact stream take, and the AudioStreamPlayer of the most recent play() so probes can
## assert non-null and inspect which bank file was picked. last_ability_play mirrors the
## same triple but ONLY for the most recent play_ability() call that actually fired a
## hero bank/family take ΓÇö it is never clobbered by unrelated play() calls (footsteps,
## countdown ticks, etc.), so probes that read it right after a cast still see the
## ability sound even when other SFX fire in between.
var last_play_ability: String = ""
var last_play: Dictionary = {}
var last_ability_play: Dictionary = {}

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
	for _slot in _WORLD_THEME_SLOT_COUNT:
		_world_theme_players.append(_make_world_theme_player())
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
## prefix — so casts are hero-distinctive. 2026-09-16 user rule: "i dont think there is
## unique sounds for all abilities." Each ability now gets a deterministic per-ability
## pitch offset (derived from a hash of the ability id) so that no two abilities of the
## same hero sound identical. The offset range is ±0.18 semitones (pitch_scale 0.82–1.18)
## which is clearly distinguishable without sounding like a different instrument.
## Heroes without a bank of their own fall back to the shared archetype family takes
## (projectile/cone/heal/...) so the layer never goes silent; a total miss warns instead
## of crashing. last_play_ability records what fired for probes/debugging.
func play_ability(ability_id: String, is_ult: bool = false) -> AudioStreamPlayer:
	# 2026-09-17: per-ABILITY banks. Every ability in the roster has its own
	# authored SFX (ability_<id>.wav) so no two abilities of the same hero sound
	# identical. Prefer the specific ability bank; fall back to the hero's shared
	# cast_<hero> bank (with a per-ability pitch offset) if the specific file is
	# missing, then the archetype family.
	var ability_bank := "ability_%s" % ability_id
	if SOUND_LIBRARY.has(ability_bank):
		var player := play(ability_bank)
		if player != null:
			if is_ult:
				player.pitch_scale = 0.7
				_ult_echo_call(ability_bank, player)
			last_play_ability = ability_id
			last_ability_play = {"sound_id": ability_bank, "stream": player.stream, "player": player, "pitch_scale": player.pitch_scale}
		return player
	var bank := "cast_%s" % ability_id.split("_")[0]
	if SOUND_LIBRARY.has(bank):
		var player := play(bank)
		if player != null:
			# Per-ability pitch differentiation: deterministic offset so each ability
			# of a hero has a distinct timbre. Hash the ability id into [0,1) and map
			# to a pitch_scale in [0.82, 1.18]. Ultimates get a deeper pitch.
			var ability_pitch := _ability_pitch_offset(ability_id)
			if is_ult:
				ability_pitch *= 0.7
				var echo := player
				_ult_echo_call(bank, echo)
			else:
				player.pitch_scale = ability_pitch
			last_play_ability = ability_id
			# Record the ability-specific take so probes can read it independently of
			# unrelated play() calls that clobber last_play between the cast and probe.
			last_ability_play = {"sound_id": bank, "stream": player.stream, "player": player, "pitch_scale": player.pitch_scale}
		return player
	var info := PlayerClass.ability_info(ability_id)
	if not info.is_empty():
		var family := str(FAMILY_FOR_ARCHETYPE.get(int(info.get("archetype", -1)), ""))
		if family != "" and SOUND_LIBRARY.has(family):
			var fam_player := play(family)
			if fam_player != null:
				if is_ult:
					fam_player.pitch_scale = 0.7
				last_play_ability = ability_id
				last_ability_play = {"sound_id": family, "stream": fam_player.stream, "player": fam_player}
			return fam_player
	push_warning("[AudioService] no cast bank or family take for ability '%s'" % ability_id)
	return null


## 2026-09-16: per-ability pitch differentiation.
## Hashes the ability id into a deterministic pitch offset in [0.82, 1.18],
## so that each of a hero's abilities sounds distinct even though they share
## the same cast_<hero> bank. The range is ~±0.18 semitones — clearly
## distinguishable by ear without sounding like a different instrument.
func _ability_pitch_offset(ability_id: String) -> float:
	var h := ability_id.hash()
	# Map to [0, 1), then to [0.82, 1.18].
	var norm := fmod(float(abs(h)) / 2147483647.0, 1.0)
	return 0.82 + 0.36 * norm


## Re-triggers the same cast bank one beat later, stretched down, so the ultimate SFX
## reads as a long, heavy flourish rather than a single blip. Skips if muted/stopped.
func _ult_echo_call(bank: String, _primary: AudioStreamPlayer) -> void:
	## P1.3c: the ultimate SFX now rings out for roughly 2x the normal-ability
	## duration. Instead of a single short echo we fire TWO staggered, down-pitched
	## echoes so the total sustain is ~2x the primary bank length. Skips if muted.
	var takes: Array = SOUND_LIBRARY.get(bank, [])
	if takes.is_empty() or not sfx_enabled:
		return
	for i in range(2):
		var echo := AudioStreamPlayer.new()
		add_child(echo)
		echo.bus = "SFX"
		echo.volume_db = float(VOLUME_DB.get(bank, -8.0)) - 3.0 - 2.0 * float(i)
		echo.pitch_scale = 0.55 - 0.12 * float(i)
		echo.stream = takes[0]
		var delay := 0.28 + 0.42 * float(i)
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			if echo.is_inside_tree() and sfx_enabled:
				echo.play()
			echo.queue_free()
		)


func play_music() -> void:
	if music_enabled and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## Crossfades the layered world-ambient beds to match the current biome. Each world
## now runs up to _WORLD_THEME_SLOT_COUNT simultaneous loops so the soundscape reads
## as layered rather than a single bed. No-op if the biome hasn't changed.
func set_world_theme(biome_id: int) -> void:
	if _world_theme_players.is_empty():
		return
	if biome_id == _world_theme_biome:
		return
	_world_theme_biome = biome_id
	var layers: Variant = WORLD_THEME_TRACKS.get(biome_id, null)
	if layers == null:
		_stop_world_theme()
		return
	for slot in _world_theme_players.size():
		var player: AudioStreamPlayer = _world_theme_players[slot]
		if player == null or not player.is_inside_tree():
			continue
		if slot >= int((layers as Array).size()):
			if player.playing:
				player.stop()
			continue
		var entry: Array = layers[slot]
		var stream: AudioStream = entry[0]
		var offset_db: float = float(entry[1])
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_begin = 0
			(stream as AudioStreamWAV).loop_end = -1
		var target_db: float = WORLD_THEME_VOLUME_DB + offset_db
		if player.playing:
			# Crossfade: swap the stream at a ducked volume, then fade up to target.
			player.stream = stream
			player.volume_db = target_db - 14.0
			player.play()
			var tw := create_tween()
			tw.tween_property(player, "volume_db", target_db, 1.2)
		else:
			player.stream = stream
			player.volume_db = target_db
			player.play()


func _stop_world_theme() -> void:
	for player in _world_theme_players:
		if player != null and player.is_inside_tree():
			player.stop()
	_world_theme_biome = -1


## Rain loop for the biome weather overlay (T3.5). Crossfades a quiet rain bed
## in/out when the arena toggles rain. No-op in the editor or when SFX is off.
var _rain_player: AudioStreamPlayer = null
const RAIN_VOLUME_DB := -22.0

func _load_rain_stream() -> AudioStream:
	var stream: AudioStream = ResourceLoader.load("res://assets/audio/themes/rain.wav", "", ResourceLoader.CACHE_MODE_IGNORE)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
		(stream as AudioStreamWAV).loop_end = -1
	return stream

func set_rain(on: bool) -> void:
	if not sfx_enabled or GameRuntime.is_dedicated_server():
		return
	if on:
		if _rain_player == null or not _rain_player.is_inside_tree():
			_rain_player = AudioStreamPlayer.new()
			_rain_player.bus = "SFX"
			_rain_player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_rain_player)
			var stream: AudioStream = _load_rain_stream()
			if stream != null:
				_rain_player.stream = stream
				_rain_player.volume_db = RAIN_VOLUME_DB - 20.0
				_rain_player.play()
				var tw := create_tween()
				tw.tween_property(_rain_player, "volume_db", RAIN_VOLUME_DB, 1.5)
		elif not _rain_player.playing:
			_rain_player.volume_db = RAIN_VOLUME_DB - 10.0
			_rain_player.play()
			var tw2 := create_tween()
			tw2.tween_property(_rain_player, "volume_db", RAIN_VOLUME_DB, 1.5)
	else:
		if _rain_player != null and _rain_player.is_inside_tree():
			var tw3 := create_tween()
			tw3.tween_property(_rain_player, "volume_db", RAIN_VOLUME_DB - 30.0, 1.2)
			tw3.tween_callback(_rain_player.stop)


## Play a one-shot SFX loaded by file path (for the biome-hazard theme SFX that
## aren't in the SOUND_LIBRARY). No-op if the file hasn't been imported yet.
func play_theme_stream(path: String) -> void:
	if not sfx_enabled or GameRuntime.is_dedicated_server():
		return
	var stream: AudioStream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if stream == null:
		return
	var player := _acquire_player("theme_stream")
	if player == null:
		return
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = -12.0
	player.play()


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


## A dedicated looping player for the current world's ambient bed. It shares the Music bus
## so it ducks with everything else, and sits low under the main theme.
func _make_world_theme_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = WORLD_THEME_VOLUME_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player
