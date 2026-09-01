"""One-shot generator for per-hero cast sound banks.

Writes assets/audio/themes/<hero>.wav (+ _2.wav, _3.wav for some heroes). Every bank is
synthesized procedurally (stdlib only: math/random/wave) — MIT-safe, no sampled assets.
Each recipe layers primitive waveforms (sine/square/saw), chime partials, and shaped
noise (crackle/zap/whoosh) with per-hero pitch envelopes so a Cinder cast sounds like a
fire whoosh and a Volt cast like a sharp electric zap.

Regenerate everything:
    python tools/synth_themes.py
"""

import math
import os
import random
import wave

OUT_DIR = os.path.join("assets", "audio", "themes")
MIX_RATE = 22050
FADE_MS = 6.0

# A recipe is a list of takes; each take is a list of layers. Layer fields:
#   wave:  sine | square | saw | chime | crackle | zap_noise | whoosh
#   f0/f1: start/end frequency Hz (exponential glide)
#   dur:   seconds
#   amp:   0..1
#   duty:  square-wave duty cycle
#   partials: for chime — sine partials as freq multipliers
RECIPES = {
    # --- Iron Foundry: steam, metal, sparks ---
    "tobor": [  # steam hiss + clank
        [dict(wave="whoosh", f0=900, f1=300, dur=0.42, amp=0.50),
         dict(wave="square", f0=180, f1=110, dur=0.30, amp=0.40, duty=0.28)],
        [dict(wave="crackle", f0=700, f1=220, dur=0.38, amp=0.50),
         dict(wave="square", f0=150, f1=90, dur=0.26, amp=0.42, duty=0.22)],
    ],
    "arclight": [  # electric zap, descending crackle
        [dict(wave="zap_noise", f0=2400, f1=500, dur=0.30, amp=0.55),
         dict(wave="saw", f0=1400, f1=320, dur=0.28, amp=0.35)],
        [dict(wave="sine", f0=1900, f1=720, dur=0.26, amp=0.50),
         dict(wave="zap_noise", f0=3200, f1=900, dur=0.20, amp=0.40)],
    ],
    "bulwark": [  # heavy slam thud
        [dict(wave="square", f0=210, f1=70, dur=0.42, amp=0.60, duty=0.35),
         dict(wave="saw", f0=130, f1=55, dur=0.38, amp=0.40)],
        [dict(wave="square", f0=165, f1=60, dur=0.40, amp=0.55, duty=0.30),
         dict(wave="crackle", f0=400, f1=120, dur=0.15, amp=0.28)],
    ],
    "warden": [  # totemic bell-thunk
        [dict(wave="chime", f0=520, f1=430, dur=0.45, amp=0.50, partials=[1.0, 1.5, 2.0]),
         dict(wave="square", f0=130, f1=85, dur=0.30, amp=0.35, duty=0.25)],
        [dict(wave="chime", f0=600, f1=390, dur=0.42, amp=0.48, partials=[1.0, 1.33, 2.0]),
         dict(wave="square", f0=110, f1=70, dur=0.28, amp=0.32, duty=0.25)],
    ],
    # --- Ashen Caldera: fire, embers ---
    "cinder": [  # fire whoosh + sub-crackle
        [dict(wave="whoosh", f0=500, f1=1600, dur=0.42, amp=0.55),
         dict(wave="crackle", f0=800, f1=300, dur=0.34, amp=0.40)],
        [dict(wave="whoosh", f0=420, f1=1300, dur=0.40, amp=0.50),
         dict(wave="crackle", f0=700, f1=240, dur=0.30, amp=0.42)],
        [dict(wave="whoosh", f0=560, f1=1800, dur=0.46, amp=0.52),
         dict(wave="sine", f0=130, f1=80, dur=0.34, amp=0.35)],
    ],
    "pyra": [  # rapid rising burst
        [dict(wave="saw", f0=280, f1=900, dur=0.28, amp=0.50),
         dict(wave="crackle", f0=900, f1=400, dur=0.22, amp=0.42)],
        [dict(wave="saw", f0=330, f1=1100, dur=0.26, amp=0.48),
         dict(wave="crackle", f0=1000, f1=480, dur=0.20, amp=0.40)],
        [dict(wave="saw", f0=250, f1=780, dur=0.30, amp=0.50),
         dict(wave="whoosh", f0=700, f1=1500, dur=0.24, amp=0.35)],
    ],
    "slag": [  # molten rumble + bubbling
        [dict(wave="saw", f0=110, f1=65, dur=0.44, amp=0.58),
         dict(wave="crackle", f0=300, f1=130, dur=0.40, amp=0.45)],
        [dict(wave="saw", f0=90, f1=55, dur=0.42, amp=0.55),
         dict(wave="crackle", f0=260, f1=110, dur=0.38, amp=0.48)],
    ],
    "ember": [  # witchy crackle + dark ping
        [dict(wave="crackle", f0=1300, f1=500, dur=0.36, amp=0.50),
         dict(wave="chime", f0=980, f1=720, dur=0.30, amp=0.40, partials=[1.0, 2.0])],
        [dict(wave="crackle", f0=1500, f1=600, dur=0.34, amp=0.48),
         dict(wave="chime", f0=1100, f1=800, dur=0.28, amp=0.38, partials=[1.0, 2.0])],
    ],
    # --- Verdant Wilds: wood, wind, life ---
    "thorn": [  # vine whip
        [dict(wave="whoosh", f0=800, f1=260, dur=0.34, amp=0.55),
         dict(wave="crackle", f0=1300, f1=480, dur=0.28, amp=0.40)],
        [dict(wave="whoosh", f0=700, f1=220, dur=0.32, amp=0.52),
         dict(wave="crackle", f0=1150, f1=420, dur=0.26, amp=0.42)],
    ],
    "willow": [  # flickering light chime
        [dict(wave="chime", f0=1500, f1=880, dur=0.34, amp=0.55, partials=[1.0, 1.5, 2.76])],
        [dict(wave="chime", f0=1650, f1=990, dur=0.32, amp=0.52, partials=[1.0, 1.4, 2.6])],
    ],
    "stump": [  # wood knock + low whoosh
        [dict(wave="square", f0=260, f1=120, dur=0.32, amp=0.52, duty=0.22),
         dict(wave="whoosh", f0=300, f1=90, dur=0.30, amp=0.45)],
        [dict(wave="square", f0=220, f1=100, dur=0.30, amp=0.50, duty=0.24),
         dict(wave="whoosh", f0=260, f1=80, dur=0.28, amp=0.42)],
    ],
    "sage": [  # fairy glass chime
        [dict(wave="chime", f0=1700, f1=1500, dur=0.45, amp=0.50, partials=[1.0, 2.0, 3.24])],
        [dict(wave="chime", f0=1950, f1=1720, dur=0.42, amp=0.50, partials=[1.0, 2.0, 3.0])],
    ],
    # --- Storm Court: lightning, cosmos, frost ---
    "volt": [  # sharp electric zap
        [dict(wave="zap_noise", f0=4200, f1=700, dur=0.26, amp=0.60),
         dict(wave="saw", f0=2100, f1=480, dur=0.22, amp=0.40)],
        [dict(wave="zap_noise", f0=4800, f1=800, dur=0.24, amp=0.55),
         dict(wave="saw", f0=2500, f1=520, dur=0.20, amp=0.38)],
    ],
    "nebula": [  # slow cosmic wobble
        [dict(wave="chime", f0=620, f1=480, dur=0.46, amp=0.50, partials=[1.0, 1.26, 2.0]),
         dict(wave="whoosh", f0=480, f1=700, dur=0.42, amp=0.30)],
        [dict(wave="chime", f0=700, f1=420, dur=0.44, amp=0.50, partials=[1.0, 1.19, 2.0]),
         dict(wave="whoosh", f0=540, f1=780, dur=0.40, amp=0.30)],
    ],
    "astral": [  # star choir
        [dict(wave="chime", f0=880, f1=720, dur=0.44, amp=0.50, partials=[1.0, 1.5, 2.0, 3.0])],
        [dict(wave="chime", f0=1040, f1=660, dur=0.42, amp=0.50, partials=[1.0, 1.5, 2.5])],
    ],
    "rime": [  # icy chime + granular sparkle
        [dict(wave="chime", f0=1650, f1=1100, dur=0.40, amp=0.50, partials=[1.0, 2.0, 2.76]),
         dict(wave="crackle", f0=2600, f1=1400, dur=0.30, amp=0.35)],
        [dict(wave="chime", f0=1800, f1=1250, dur=0.38, amp=0.48, partials=[1.0, 2.0, 2.4]),
         dict(wave="crackle", f0=2900, f1=1550, dur=0.28, amp=0.33)],
    ],
}


def render_layer(data, layer, rng):
    wave_kind = layer["wave"]
    f0, f1 = float(layer["f0"]), float(layer["f1"])
    dur, amp = float(layer["dur"]), float(layer["amp"])
    partials = layer.get("partials", [])
    samples = min(int(dur * MIX_RATE), len(data))
    fade = int(FADE_MS * 0.001 * MIX_RATE)
    phase = 0.0
    lp = 0.0  # one-pole lowpass state for whoosh
    for i in range(samples):
        u = i / samples
        f = f0 * (f1 / f0) ** u
        phase += f / MIX_RATE
        if phase >= 1.0:
            phase -= math.floor(phase)
        if wave_kind == "sine":
            s = math.sin(2 * math.pi * phase)
        elif wave_kind == "square":
            s = (1.0 if phase < layer.get("duty", 0.5) else -1.0) * 0.7
        elif wave_kind == "saw":
            s = (phase * 2.0 - 1.0) * 0.7
        elif wave_kind == "chime":
            s = sum(math.sin(2 * math.pi * phase * p) for p in partials) / len(partials)
        elif wave_kind == "crackle":
            n = rng.uniform(-1.0, 1.0)
            s = math.copysign(abs(n) ** 0.3, n)  # sparse pops
        elif wave_kind == "zap_noise":
            jitter = phase * 2.0 - 1.0
            s = max(-1.0, min(1.0, jitter * 0.6 + rng.uniform(-1.0, 1.0) * 0.4))
        elif wave_kind == "whoosh":
            lp = lp + 0.25 * (rng.uniform(-1.0, 1.0) - lp)
            s = lp * 2.2
        else:
            s = math.sin(2 * math.pi * phase)
        env = (1.0 - u) ** 1.4
        if i < fade:
            env *= i / fade
        if i > samples - fade:
            env *= (samples - i) / fade
        data[i] += s * amp * env


def synthesize(take, rng):
    length = int(max(l["dur"] for l in take) * MIX_RATE) + 1
    data = [0.0] * length
    for layer in take:
        render_layer(data, layer, rng)
    peak = max(abs(v) for v in data) or 1.0
    if peak > 0.98:
        data = [v * 0.98 / peak for v in data]
    return b"".join(int(max(-1.0, min(1.0, v)) * 32767).to_bytes(2, "little", signed=True) for v in data)


def write_wav(path, pcm):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(MIX_RATE)
        w.writeframes(pcm)


def main():
    rng = random.Random(0xC0FFEE)
    os.makedirs(OUT_DIR, exist_ok=True)
    written = 0
    for hero, takes in RECIPES.items():
        for i, take in enumerate(takes):
            suffix = "" if i == 0 else "_%d" % (i + 1)
            path = os.path.join(OUT_DIR, hero + suffix + ".wav")
            write_wav(path, synthesize(take, rng))
            written += 1
            print("wrote %s" % path)
    print("synth_themes: %d wav files" % written)


if __name__ == "__main__":
    main()
