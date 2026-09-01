"""Derive 4-directional 3-frame walk variants from the authored HERO_ROWS bases.

For each hero facing sprite (front/base, left, right, back) we synthesize stepping
frames "<base>_w1..w3":
  * frame1: whole sprite raised 1px (hop), left leg column-group shifts right
  * frame2: legs swapped horizontally (mid-stride)
  * frame3: whole sprite raised 1px, left leg column-group shifts left
The "leg band" is taken as the bottom quarter of the sprite's used opaque region.
All frames are padded back to the original square so every hero's facing sprites share
one canvas size. Operates directly on HERO_ROWS + HERO_PALETTES in tools/sprite_art.gd.
"""
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "tools", "sprite_art.gd")

# 15 grid heroes (tobor is procedural in tobor_body.gd)
HEROES = ["arclight", "bulwark", "warden", "cinder", "pyra", "slag", "ember",
          "thorn", "willow", "stump", "sage", "volt", "nebula", "astral", "rime"]


def load_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _global_entry_slices(text):
    """Map each HERO-grid \"id\" to its row-list slice (start of line to the '],' before
    the next entry or next section). Searching the whole file sidesteps the nested
    brace-scan problem (palette dicts contain '{'/'}')."""
    pattern = re.compile(r'^\s*"([a-z_0-9]+)":\s*\[', re.M)
    matches = list(pattern.finditer(text))
    slices = {}
    for k, m in enumerate(matches):
        end = matches[k + 1].start() if k + 1 < len(matches) else len(text)
        slices[m.group(1)] = (m.start(), end)
    return slices


def parse_hero_rows(text):
    rows = {}
    for rid, (s, e) in _global_entry_slices(text).items():
        seg = text[s:e]
        rows[rid] = re.findall(r'"([.a-zA-Z]+)"', seg)
    return rows


def parse_hero_palettes(text):
    m = re.search(r"^const HERO_PALETTES := \{", text, re.M)
    rows_ref = re.search(r"^const HERO_ROWS := \{", text, re.M)
    block = text[m.start():rows_ref.start()]
    pals = {}
    for em in re.finditer(r'^\s*"([a-z_0-9]+)":\s*(ROBOT_HERO_PALETTE|\{.*?\}),', block, re.S | re.M):
        rid, blob = em.group(1), em.group(2)
        if blob == "ROBOT_HERO_PALETTE":
            pals[rid] = "ROBOT_HERO_PALETTE"
        else:
            pals[rid] = dict(re.findall(r'"([a-zA-Z])":\s*"([0-9a-fA-F]{6})"', blob))
    return pals


def palette_for(pals, rid, base):
    if rid in pals:
        return pals[rid]
    if base in pals:
        return pals[base]
    return "ROBOT_HERO_PALETTE"


def used_bounds(rows):
    xs, ys = [], []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), max(xs), min(ys), max(ys)


def pad(rows, size):
    out = []
    for row in rows:
        r = row[:size]
        out.append(r + "." * max(0, size - len(r)))
    while len(out) < size:
        out.append("." * size)
    return out[:size]


def make_frames(base_rows):
    """Return dict {phase: rows} for phases 1..3."""
    size = len(base_rows)
    b = used_bounds(base_rows)
    if b is None:
        return {}
    minx, maxx, miny, maxy = b
    body_h = maxy - miny + 1
    band_start = max(miny, maxy - max(2, body_h // 4) + 1)
    band_rows = base_rows[band_start:maxy + 1]
    band_bounds = used_bounds(band_rows)
    if band_bounds is None:
        leg_min, leg_max = minx, maxx
    else:
        leg_min, leg_max = band_bounds[0], band_bounds[1]
    band_w = leg_max - leg_min + 1
    # Widen the perceived legs for the 16px rollback robots (nearly full width).
    if band_w <= 3:
        leg_min = max(minx, leg_min - 2)
        leg_max = min(maxx, leg_max + 2)
        band_w = leg_max - leg_min + 1
    split = leg_min + band_w // 2

    def crop(row):
        seg = row[leg_min:leg_max + 1]
        return seg + "." * max(0, (leg_max - leg_min + 1) - len(seg))

    def anim_band(anim_rows, left_shift, swap):
        res = []
        for row in anim_rows:
            if left_shift == -999:  # plain (no leg anim)
                res.append(row)
                continue
            seg = crop(row)
            seg = seg + "." * max(0, band_w * 2 - len(seg))
            left = seg[:split - leg_min]
            right = seg[split - leg_min:band_w]
            if swap:
                left, right = right, left
            left = ("." * max(0, left_shift) + left) if left_shift >= 0 else left[-left_shift:]
            right = ("." * max(0, -left_shift) + right) if left_shift < 0 else right[left_shift:]
            merged = (left + "." * band_w + right)[:band_w]
            merged = merged + "." * max(0, band_w - len(merged))
            nrow = row[:leg_min] + merged + row[leg_max + 1:]
            res.append(nrow[:size])
        return res

    def lift(rows):
        return [rows[0]] + rows[:-1]

    fr1 = lift(base_rows)
    fr2 = base_rows[:]
    fr3 = lift(base_rows)
    animated1 = anim_band(fr1[:], +1, False)
    animated2 = anim_band(fr2[:], 0, True)
    animated3 = anim_band(fr3[:], -1, False)
    f1 = fr1[:band_start] + animated1[band_start:]
    f2 = fr2[:band_start] + animated2[band_start:]
    f3 = fr3[:band_start] + animated3[band_start:]
    return {1: pad(f1, size), 2: pad(f2, size), 3: pad(f3, size)}


def format_entry(rid, rows, pal):
    lines = ['\t"%s": [' % rid]
    for r in rows:
        lines.append('\t\t"%s",' % r)
    lines.append("\t],")
    return "\n".join(lines) + "\n"


def main():
    text = load_text(ART)
    rows = parse_hero_rows(text)
    pals = parse_hero_palettes(text)

    # Generate walk entries (id -> (rows, base)).
    gen_rows = {}
    gen_pals = {}
    facing_map = []  # (base, key)
    for h in HEROES:
        facing_map.append((h, h))
        for f in ("left", "right", "back"):
            facing_map.append((h, "%s_%s" % (h, f)))

    count = 0
    for base, key in facing_map:
        if key not in rows:
            print("!! missing base rows:", key, file=sys.stderr)
            continue
        frames = make_frames(rows[key])
        pal = palette_for(pals, key, base)
        for phase, rws in frames.items():
            nid = "%s_w%d" % (key, phase)
            gen_rows[nid] = rws
            gen_pals[nid] = pal
            count += 1
    print("generated %d walk entries" % count)

    # Strip previously-generated entries so the run is idempotent.
    existing_keys = sorted(gen_rows.keys())
    name_alt = "|".join(re.escape(k) for k in existing_keys)
    text = re.sub(r'^\s*"(?:%s)":\s*\[.*?\],\n' % name_alt, "", text, flags=re.S | re.M)
    text = re.sub(r'^\s*"(?:%s)":\s*(?:ROBOT_HERO_PALETTE|\{.*?\}),\n' % name_alt, "", text, flags=re.S | re.M)
    # Clear any stale sentinels.
    text = re.sub(r"\n?\t?# __HERO_WALK_GENERATED__(?:.|\n)*?(?=\nconst HERO_ABILITY_TONES)", "\n", text)

    # Insert palette entries right before HERO_PALETTES' closing brace.
    hpm = re.search(r"^const HERO_PALETTES := \{", text, re.M)
    pal_close = text.index("\n}\n", hpm.end()) + 1
    palblob = "\t# __HERO_WALK_GENERATED__ palettes\n" + "".join(
        _format_palette_entry(k, gen_pals[k]) for k in existing_keys) + "\t# __HERO_WALK_GENERATED__ end\n"
    text = text[:pal_close] + palblob + text[pal_close:]

    # Insert the generated row entries right after the LAST hero-grid entry's "],".
    row_slices = _global_entry_slices(text)
    last_key = "rime_back" if "rime_back" in row_slices else sorted(row_slices)[-1]
    rstart, rend = row_slices[last_key]
    rows_blob = "\t# __HERO_WALK_GENERATED__ rows\n" + "".join(
        format_entry(k, gen_rows[k], gen_pals[k]) for k in existing_keys) + "\t# __HERO_WALK_GENERATED__ end\n"
    text = text[:rend] + rows_blob + text[rend:]

    with open(ART, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", ART)


def _format_palette_entry(rid, pal):
    if pal == "ROBOT_HERO_PALETTE":
        return '\t"%s": ROBOT_HERO_PALETTE,\n' % rid
    inner = ", ".join('"%s": "%s"' % (k, v) for k, v in pal.items())
    return '\t"%s": {%s},\n' % (rid, inner)


if __name__ == "__main__":
    main()
