"""Generate non-pixel-art cover portraits for all 16 heroes via the ElevenLabs
Image & Video API (POST /v1/flows/image, poll GET /v1/flows/image/{id}).

Reads ELEVENLABS_API_KEY from the environment only (never prints it).
Reference style: assets/ui/{tobor,arclight,bulwark,warden}_menu_bg.png
  - chunky cute sci-fi robot, head-shoulders-chest crop, 3/4 view facing viewer
  - soft painterly cel-shaded 3D-render look (Pixar-like), smooth gradients
  - dramatic rim light in the hero accent color, sidelit from upper-left
  - smooth radial-gradient backdrop tinted to the hero, subject centered
  - square-ish 16:9 banner, hero centered

NOT committed: this talks to a paid API. Run manually.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "covers"
ENV_PATH = ROOT / ".env"

API_BASE = "https://api.elevenlabs.io/v1"
# Nano Banana (gemini-3.1-flash-image): strong stylized illustration, 16:9 PNG.
# ByteDance models are disabled by default on API keys; this one is not.
MODEL_ID = "gemini-3.1-flash-image"
ASPECT = "16:9"
RESOLUTION = "2K"
MIN_BYTES = 50 * 1024

POLL_INTERVAL_S = 3.0
POLL_TIMEOUT_S = 240.0

STYLE = (
    "painterly cel-shaded digital portrait, chunky cute stylized sci-fi robot, "
    "Pixar-like polished 3D render look, smooth clean surfaces, big expressive glowing eyes, "
    "head-shoulders-chest crop, three-quarter view facing the viewer, subject centered, "
    "dramatic rim lighting, soft key light from the upper left, "
    "smooth radial gradient backdrop, atmospheric haze, video game splash art, "
    "high detail, not pixel art, no text, no watermark, no logo"
)

# id -> (display name, role, world-biome backdrop, accent hex, body motif, prop)
HEROES = {
    "tobor": ("Wrench", "the Iron Engineer",
              "warm rust-orange industrial foundry haze with faint sparks", "ff8a3d",
              "stocky gunmetal-grey robot mechanic with riveted plating and a single round ocular lens",
              "hefting a giant wrench over one shoulder"),
    "arclight": ("Joule", "the Storm Caster",
                 "electric-yellow lightning haze with faint arc filaments", "ffe14a",
                 "sleek white robot mage with glowing orange chest core and antenna fin",
                 "crackling volt staff raised, arcs of lightning"),
    "bulwark": ("Tremor", "the Ground Tank",
                "warm amber-and-ember foundry glow", "ff8a3d",
                "heavy broad-shouldered orange robot with a small round head and massive forearms",
                "leaning on a huge shield-hammer"),
    "warden": ("Totem", "the Verdant Support",
               "soft mint-green botanical glow with drifting spores", "8cff4a",
               "gentle white hovering drone with glowing green accents and a caring round face",
               "emitting a soft green healing beam from a chest emitter"),
    "frostbinder": ("Frostbinder", "the Frost Controller",
                    "cool ice-blue crystalline haze with drifting snow", "7ba9ff",
                    "pale-blue elegant robot with angular frost-rimed pauldrons and a calm face",
                    "holding a slender rime lance that trails frost"),
    "cinder": ("Blaze", "the Pyromancer",
               "fiery volcanic ember glow with rising cinders", "ffb347",
               "sleek ember-red robot pyromancer with glowing hot seams and a confident smirk",
               "wreathed in a swirl of flame, pyro staff ignited"),
    "pyra": ("Barrage", "the Artillery Ranger",
             "smoky caldera glow with distant artillery flashes", "ffe14a",
             "rugged rust-brown robot dragon-like artillery unit with a mortar barrel on its back",
             " coughing a glowing shell from a shoulder mortar"),
    "slag": ("Vulcan", "the Walking Volcano",
             "deep molten red-orange lava glow with basalt shards", "ff6b2a",
             "massive dark basalt-crusted robot brute with molten cracks glowing across its fists",
             "magma dripping from its knuckles"),
    "ember": ("Witchfire", "the Ash Plague-Witch",
              "warm orange and sickly green swamp-ember glow", "ffb46b",
              "mysterious ember-orange robot witch with tattered metal cloak and glowing green sigils",
              "holding a cinder scepter wreathed in bramble-fire"),
    "thorn": ("Venom", "the Jungle Toxin Witch",
              "deep viridian jungle haze with glowing spores", "a8e05c",
              "slender leafy-green robot with thorned plating and sly glowing eyes",
              "spraying a virulent toxic mist from a wrist nozzle"),
    "willow": ("Flick", "the Forest Archer",
               "fresh moss-green forest glow with drifting pollen", "b8ff6b",
               "lithe tan-and-olive robot ranger with a hood-like head crest and keen eyes",
               "drawing a thorn longbow with a glowing arrow nocked"),
    "stump": ("Keeper", " the Living Tree-Fort",
              "warm bark-brown and gold grove glow", "d4b06b",
              "broad wooden robot treant with bark armor, glowing amber eyes and mossy shoulders",
              "raising a living-bark shield as roots sprawl at its feet"),
    "sage": ("Nymphel", "the Glade Nymph",
             "soft pink-and-green moonlit glade glow with petals", "ffd9e0",
             "graceful hovering robot nymph with petal-like plates and a serene glowing face",
             "cradling a radiant moon-blossom that sheds healing light"),
    "volt": ("Gale", "the Tempest Shaman",
             "electric cyan storm-wind glow with swirling gusts", "7af0ff",
             "sleek white robot storm-shaman with wind-swept fins and crackling cyan accents",
             "channeling a spiraling cyclone around a storm rod"),
    "nebula": ("Aeon", "the Time Manipulator",
               "deep violet cosmic-time glow with hourglass motes", "b48cff",
               "enigmatic dark-indigo robot with a floating aeon sphere and glowing purple eyes",
               "warping a shimmering chronosphere in one palm"),
    "astral": ("Lumina", "the Beacon of Light",
               "soft golden-white starlight glow", "ffe9a0",
               "luminous silver-white hovering robot with a halo of light and a kind glowing face",
               "holding a star lantern that threads warm light to unseen allies"),
    "rime": ("Glacier", "the Walking Glacier",
             "cold pale-blue glacial glow with falling snow", "b8d4ff",
             "imposing ice-blue robot golem with crystalline frozen armor and a stern face",
             "conjuring a cage of absolute-zero ice"),
}


def load_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key and ENV_PATH.exists():
        for line in ENV_PATH.read_text().splitlines():
            if line.startswith("ELEVENLABS_API_KEY="):
                key = line.split("=", 1)[1].strip()
    if not key:
        sys.exit("ELEVENLABS_API_KEY not set")
    return key


def http(method: str, url: str, key: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("xi-api-key", key)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {e.code} from {url}: {body[:600]}")


def build_prompt(hid: str) -> str:
    name, role, world, accent, motif, prop = HEROES[hid]
    return (
        f"Video game hero splash portrait of {name}, {role}. A {motif}, {prop}. "
        f"Background: {world}, smooth radial gradient tinted toward #{accent}. "
        f"Primary rim-light and accent color #{accent}. {STYLE}."
    )


def generate_one(hid: str, key: str) -> Path:
    out = OUT_DIR / f"{hid}.png"
    prompt = build_prompt(hid)
    created = http("POST", f"{API_BASE}/flows/image", key, {
        "model_id": MODEL_ID,
        "prompt": prompt,
        "aspect_ratio": ASPECT,
        "resolution": RESOLUTION,
    })
    gid = created.get("id")
    if not gid:
        raise RuntimeError(f"{hid}: no id in create response: {created}")

    deadline = time.time() + POLL_TIMEOUT_S
    content_url = None
    while time.time() < deadline:
        time.sleep(POLL_INTERVAL_S)
        st = http("GET", f"{API_BASE}/flows/image/{gid}", key)
        status = st.get("status")
        if status == "completed":
            content_url = st.get("content_url")
            break
        if status == "failed":
            raise RuntimeError(f"{hid}: failed - {st.get('failure_reason')}: {st.get('error_message')}")
    if not content_url:
        raise RuntimeError(f"{hid}: timed out waiting for generation")

    req = urllib.request.Request(content_url)
    with urllib.request.urlopen(req, timeout=120) as r:
        blob = r.read()
    out.write_bytes(blob)
    size = out.stat().st_size
    ok = blob[:8] == b"\x89PNG\r\n\x1a\n" and size > MIN_BYTES
    print(f"[{'OK' if ok else 'CHECK'}] {hid}.png  {size//1024}KB")
    return out


def main() -> None:
    key = load_key()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    only = sys.argv[1:] or list(HEROES.keys())
    failures = []
    for hid in only:
        try:
            generate_one(hid, key)
        except Exception as e:  # noqa: BLE001
            print(f"[FAIL] {hid}: {e}")
            failures.append(hid)
    if failures:
        sys.exit(f"Failed: {', '.join(failures)}")
    print("All covers generated.")


if __name__ == "__main__":
    main()
