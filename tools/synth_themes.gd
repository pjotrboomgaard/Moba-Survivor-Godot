@tool
extends EditorScript

## One-shot generator for per-hero cast sound banks.
##
## Writes assets/audio/themes/<hero>.wav (+ _2.wav, _3.wav for some heroes). Every bank is
## synthesized procedurally under the MIT license (no sampled assets), with a per-hero
## sonic signature: waveform (sine/square/saw/chime/noise), pitch movement, envelope, and
## noise tint. Run from the editor: Script Editor -> File -> Run, or via
## `godot --headless --script tools/synth_themes.gd`.

const OUT_DIR := "res://assets/audio/themes"
const MIX_RATE := 22050
const FADES_MS := 6.0

# A "recipe" is 1-3 layers stacked on top of each other. Each layer:
#   wave:   "sine" | "square" | "saw" | "chime" | "crackle" | "zap_noise" | "whoosh"
#   f0/f1:  start/end frequency Hz (exponential glide)
#   dur:    seconds
#   amp:    0..1 peak amplitude for the layer
#   duty:   square-wave duty cycle (optional)
#   partials: for "chime" — extra sine partials as freq multipliers
const RECIPES := {
	# --- Iron Foundry: steam, metal, sparks ---
	"tobor": [  # steam hiss + clank: whoosh then square thunk
		[{"wave": "whoosh", "f0": 900.0, "f1": 300.0, "dur": 0.42, "amp": 0.5},
		 {"wave": "square", "f0": 180.0, "f1": 110.0, "dur": 0.30, "amp": 0.4, "duty": 0.28}],
		[{"wave": "crackle", "f0": 700.0, "f1": 220.0, "dur": 0.38, "amp": 0.5},
		 {"wave": "square", "f0": 150.0, "f1": 90.0, "dur": 0.26, "amp": 0.42, "duty": 0.22}],
	],
	"arclight": [  # electric zap, descending crackle
		[{"wave": "zap_noise", "f0": 2400.0, "f1": 500.0, "dur": 0.30, "amp": 0.55},
		 {"wave": "saw", "f0": 1400.0, "f1": 320.0, "dur": 0.28, "amp": 0.35}],
		[{"wave": "sine", "f0": 1900.0, "f1": 720.0, "dur": 0.26, "amp": 0.5},
		 {"wave": "zap_noise", "f0": 3200.0, "f1": 900.0, "dur": 0.2, "amp": 0.4}],
	],
	"bulwark": [  # heavy slam: low square+saw thud
		[{"wave": "square", "f0": 210.0, "f1": 70.0, "dur": 0.42, "amp": 0.6, "duty": 0.35},
		 {"wave": "saw", "f0": 130.0, "f1": 55.0, "dur": 0.38, "amp": 0.4}],
		[{"wave": "square", "f0": 165.0, "f1": 60.0, "dur": 0.4, "amp": 0.55, "duty": 0.30},
		 {"wave": "crackle", "f0": 400.0, "f1": 120.0, "dur": 0.15, "amp": 0.28}],
	],
	"warden": [  # totemic bell-thunk, chime partials with low square
		[{"wave": "chime", "f0": 520.0, "f1": 430.0, "dur": 0.45, "amp": 0.5,
		  "partials": [1.0, 1.5, 2.0]},
		 {"wave": "square", "f0": 130.0, "f1": 85.0, "dur": 0.3, "amp": 0.35, "duty": 0.25}],
		[{"wave": "chime", "f0": 600.0, "f1": 390.0, "dur": 0.42, "amp": 0.48,
		  "partials": [1.0, 1.33, 2.0]},
		 {"wave": "square", "f0": 110.0, "f1": 70.0, "dur": 0.28, "amp": 0.32, "duty": 0.25}],
	],
	# --- Ashen Caldera: fire, embers ---
	"cinder": [  # fire whoosh + sub-sine crackle
		[{"wave": "whoosh", "f0": 500.0, "f1": 1600.0, "dur": 0.42, "amp": 0.55},
		 {"wave": "crackle", "f0": 800.0, "f1": 300.0, "dur": 0.34, "amp": 0.4}],
		[{"wave": "whoosh", "f0": 420.0, "f1": 1300.0, "dur": 0.4, "amp": 0.5},
		 {"wave": "crackle", "f0": 700.0, "f1": 240.0, "dur": 0.3, "amp": 0.42}],
		[{"wave": "whoosh", "f0": 560.0, "f1": 1800.0, "dur": 0.46, "amp": 0.52},
		 {"wave": "sine", "f0": 130.0, "f1": 80.0, "dur": 0.34, "amp": 0.35}],
	],
	"pyra": [  # rapid burst: rising saw + snap
		[{"wave": "saw", "f0": 280.0, "f1": 900.0, "dur": 0.28, "amp": 0.5},
		 {"wave": "crackle", "f0": 900.0, "f1": 400.0, "dur": 0.22, "amp": 0.42}],
		[{"wave": "saw", "f0": 330.0, "f1": 1100.0, "dur": 0.26, "amp": 0.48},
		 {"wave": "crackle", "f0": 1000.0, "f1": 480.0, "dur": 0.2, "amp": 0.4}],
		[{"wave": "saw", "f0": 250.0, "f1": 780.0, "dur": 0.3, "amp": 0.5},
		 {"wave": "whoosh", "f0": 700.0, "f1": 1500.0, "dur": 0.24, "amp": 0.35}],
	],
	"slag": [  # molten rumble: low saw + bubbling crackle
		[{"wave": "saw", "f0": 110.0, "f1": 65.0, "dur": 0.44, "amp": 0.58},
		 {"wave": "crackle", "f0": 300.0, "f1": 130.0, "dur": 0.4, "amp": 0.45}],
		[{"wave": "saw", "f0": 90.0, "f1": 55.0, "dur": 0.42, "amp": 0.55},
		 {"wave": "crackle", "f0": 260.0, "f1": 110.0, "dur": 0.38, "amp": 0.48}],
	],
	"ember": [  # witchy crackle: narrow zap_noise + chime ping
		[{"wave": "crackle", "f0": 1300.0, "f1": 500.0, "dur": 0.36, "amp": 0.5},
		 {"wave": "chime", "f0": 980.0, "f1": 720.0, "dur": 0.3, "amp": 0.4, "partials": [1.0, 2.0]}],
		[{"wave": "crackle", "f0": 1500.0, "f1": 600.0, "dur": 0.34, "amp": 0.48},
		 {"wave": "chime", "f0": 1100.0, "f1": 800.0, "dur": 0.28, "amp": 0.38, "partials": [1.0, 2.0]}],
	],
	# --- Verdant Wilds: wood, wind, life ---
	"thorn": [  # vine whip: whoosh + rustling crackle
		[{"wave": "whoosh", "f0": 800.0, "f1": 260.0, "dur": 0.34, "amp": 0.55},
		 {"wave": "crackle", "f0": 1300.0, "f1": 480.0, "dur": 0.28, "amp": 0.4}],
		[{"wave": "whoosh", "f0": 700.0, "f1": 220.0, "dur": 0.32, "amp": 0.52},
		 {"wave": "crackle", "f0": 1150.0, "f1": 420.0, "dur": 0.26, "amp": 0.42}],
	],
	"willow": [  # flickering light: chime descending
		[{"wave": "chime", "f0": 1500.0, "f1": 880.0, "dur": 0.34, "amp": 0.55, "partials": [1.0, 1.5, 2.76]}],
		[{"wave": "chime", "f0": 1650.0, "f1": 990.0, "dur": 0.32, "amp": 0.52, "partials": [1.0, 1.4, 2.6]}],
	],
	"stump": [  # wood knock + low whoosh
		[{"wave": "square", "f0": 260.0, "f1": 120.0, "dur": 0.32, "amp": 0.52, "duty": 0.22},
		 {"wave": "whoosh", "f0": 300.0, "f1": 90.0, "dur": 0.3, "amp": 0.45}],
		[{"wave": "square", "f0": 220.0, "f1": 100.0, "dur": 0.3, "amp": 0.5, "duty": 0.24},
		 {"wave": "whoosh", "f0": 260.0, "f1": 80.0, "dur": 0.28, "amp": 0.42}],
	],
	"sage": [  # fairy chime: glassy partials, long decay
		[{"wave": "chime", "f0": 1700.0, "f1": 1500.0, "dur": 0.45, "amp": 0.5, "partials": [1.0, 2.0, 3.24]}],
		[{"wave": "chime", "f0": 1950.0, "f1": 1720.0, "dur": 0.42, "amp": 0.5, "partials": [1.0, 2.0, 3.0]}],
	],
	# --- Storm Court: lightning, frost, cosmos ---
	"volt": [  # pure electric: sharp zap_noise + high saw
		[{"wave": "zap_noise", "f0": 4200.0, "f1": 700.0, "dur": 0.26, "amp": 0.6},
		 {"wave": "saw", "f0": 2100.0, "f1": 480.0, "dur": 0.22, "amp": 0.4}],
		[{"wave": "zap_noise", "f0": 4800.0, "f1": 800.0, "dur": 0.24, "amp": 0.55},
		 {"wave": "saw", "f0": 2500.0, "f1": 520.0, "dur": 0.2, "amp": 0.38}],
	],
	"nebula": [  # cosmic wobble: slow chime sweep
		[{"wave": "chime", "f0": 620.0, "f1": 480.0, "dur": 0.46, "amp": 0.5, "partials": [1.0, 1.26, 2.0]},
		 {"wave": "whoosh", "f0": 480.0, "f1": 700.0, "dur": 0.42, "amp": 0.3}],
		[{"wave": "chime", "f0": 700.0, "f1": 420.0, "dur": 0.44, "amp": 0.5, "partials": [1.0, 1.19, 2.0]},
		 {"wave": "whoosh", "f0": 540.0, "f1": 780.0, "dur": 0.4, "amp": 0.3}],
	],
	"astral": [  # star choir: bright harmonic chime
		[{"wave": "chime", "f0": 880.0, "f1": 720.0, "dur": 0.44, "amp": 0.5, "partials": [1.0, 1.5, 2.0, 3.0]}],
		[{"wave": "chime", "f0": 1040.0, "f1": 660.0, "dur": 0.42, "amp": 0.5, "partials": [1.0, 1.5, 2.5]}],
	],
	"rime": [  # frost: icy chime + granular sparkle
		[{"wave": "chime", "f0": 1650.0, "f1": 1100.0, "dur": 0.4, "amp": 0.5, "partials": [1.0, 2.0, 2.76]},
		 {"wave": "crackle", "f0": 2600.0, "f1": 1400.0, "dur": 0.3, "amp": 0.35}],
		[{"wave": "chime", "f0": 1800.0, "f1": 1250.0, "dur": 0.38, "amp": 0.48, "partials": [1.0, 2.0, 2.4]},
		 {"wave": "crackle", "f0": 2900.0, "f1": 1550.0, "dur": 0.28, "amp": 0.33}],
	],
}


func _run() -> void:
	var seed_val := 0xC0FFEE
	seed(seed_val)
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var written := 0
	for hero in RECIPES.keys():
		var takes: Array = RECIPES[hero]
		for i in takes.size():
			var samples := _synthesize(takes[i])
			var path := "%s/%s%s.wav" % [OUT_DIR, hero, "" if i == 0 else "_%d" % (i + 1)]
			_write_wav(path, samples)
			written += 1
	print("[synth_themes] wrote %d wav files to %s" % [written, OUT_DIR])


func _synthesize(layers: Array) -> PackedByteArray:
	var dur := 0.0
	for layer in layers:
		dur = maxf(dur, float(layer.get("dur", 0.3)))
	var length := int(dur * MIX_RATE) + 1
	var data := PackedFloat32Array()
	data.resize(length)
	data.fill(0.0)
	for layer in layers:
		_render_layer(data, layer)
	return _encode_pcm16(data)


func _render_layer(data: PackedFloat32Array, layer: Dictionary) -> void:
	var wave: String = layer.get("wave", "sine")
	var f0: float = layer.get("f0", 440.0)
	var f1: float = layer.get("f1", 440.0)
	var dur: float = layer.get("dur", 0.3)
	var amp: float = layer.get("amp", 0.5)
	var partials: Array = layer.get("partials", [])
	var samples := int(dur * MIX_RATE)
	var phase := 0.0
	var fade_samples := int(FADES_MS * 0.001 * MIX_RATE)
	for i in mini(samples, data.size()):
		var t := float(i) / MIX_RATE
		var u := float(i) / float(samples)  # 0..1 through layer
		# Exponential glide between f0 and f1 (log-linear reads as even pitch slide).
		var f := f0 * pow(f1 / f0, u)
		phase += f / MIX_RATE
		if phase >= 1.0:
			phase -= floor(phase)
		var s := 0.0
		match wave:
			"sine":
				s = sin(TAU * phase)
			"square":
				var duty: float = layer.get("duty", 0.5)
				s = 1.0 if phase < duty else -1.0
				# Soft-clip square to shave harshness.
				s *= 0.7
			"saw":
				s = (phase * 2.0 - 1.0) * 0.7
			"chime":
				for p in partials:
					s += sin(TAU * phase * float(p)) / float(partials.size())
			"crackle":
				# Random impulses — reads as static/fire crackle.
				s = (randf() * 2.0 - 1.0)
				s = sign(s) * pow(abs(s), 0.3)  # sparse pops
			"zap_noise":
				# Banded noise: jittered saw + white-ish noise, classic arcade zap.
				var n := (randf() * 2.0 - 1.0)
				s = ((phase * 2.0 - 1.0) * 0.6) + n * 0.4
				s = clampf(s, -1.0, 1.0)
			"whoosh":
				# Filtered-ish noise: white noise through a one-pole lowpass.
				var n := (randf() * 2.0 - 1.0)
				s = n * 0.7 + (sin(TAU * phase * 0.5) * 0.3)
			_:
				s = sin(TAU * phase)
		# Envelope: fast attack, exponential-ish decay, tiny fade edges to avoid clicks.
		var env := pow(1.0 - u, 1.4)
		if i < fade_samples:
			env *= float(i) / float(fade_samples)
		if i > samples - fade_samples:
			env *= float(samples - i) / float(fade_samples)
		data[i] += s * amp * env


func _encode_pcm16(data: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(data.size() * 2)
	for i in data.size():
		var v := int(clampf(data[i], -1.0, 1.0) * 32767.0)
		out[i * 2] = v & 0xFF
		out[i * 2 + 1] = (v >> 8) & 0xFF
	return out


func _write_wav(path: String, pcm: PackedByteArray) -> void:
	var sample_count := pcm.size() / 2
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("RIFF")
	f.store_32(36 + pcm.size())
	f.store_string("WAVEfmt ")
	f.store_32(16)  # fmt chunk size
	f.store_16(1)  # PCM
	f.store_16(1)  # mono
	f.store_32(MIX_RATE)
	f.store_32(MIX_RATE * 2)  # byte rate
	f.store_16(2)  # block align
	f.store_16(16)  # bits
	f.store_string("data")
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
	print("[synth_themes] %s (%d samples)" % [path, sample_count])
