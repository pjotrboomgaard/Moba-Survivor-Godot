"""Offline procedural placeholder hero covers.

Fallback for tools/gen_hero_covers.py: the ElevenLabs Image & Video API requires a
Pro plan (key's account returned HTTP 402 paid_plan_required), and no other image
API credentials (Stability / Replicate / OpenAI) are configured on this machine.
Per the brief, generate gradient + silhouette portraits so the menu has all 16
covers in-place. Re-run tools/gen_hero_covers.py with a Pro key to replace these
with true AI art; the file layout (assets/covers/<id>.png, 16:9) is identical.

Visual language matches assets/ui/*_menu_bg.png: 1080x607 banner, smooth radial
gradient backdrop tinted to the hero accent, a chunky stylized robot in
head-shoulders-chest crop (3/4 view) with a bright accent rim-light.
Pure Pillow, no network.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "covers"
W, H = 1080, 607  # matches assets/ui/*_menu_bg.png


def hexrgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# id -> (body tint, accent hex, build, head shape)
# build: 0=stocky, 1=sleek, 2=broad/heavy, 3=hover/slender
# head:  'round', 'square', 'fin', 'hood'
HEROES = {
    "tobor": ("9aa8b3", "ff8a3d", 0, "square"),
    "arclight": ("e8e8e8", "ffe14a", 1, "fin"),
    "bulwark": ("e05a28", "ff8a3d", 2, "round"),
    "warden": ("e8e8e8", "8cff4a", 3, "round"),
    "frostbinder": ("7ba9ff", "dbe9ff", 1, "square"),
    "cinder": ("c94a20", "ffb347", 1, "fin"),
    "pyra": ("8a3d2a", "ffe14a", 0, "square"),
    "slag": ("5c2e1e", "ff6b2a", 2, "round"),
    "ember": ("b3542e", "ffb46b", 3, "hood"),
    "thorn": ("4a7a2e", "a8e05c", 1, "hood"),
    "willow": ("6b5a3a", "b8ff6b", 1, "hood"),
    "stump": ("7a5a30", "d4b06b", 2, "round"),
    "sage": ("6b4a1e", "ffd9e0", 3, "round"),
    "volt": ("e8e8e8", "7af0ff", 1, "fin"),
    "nebula": ("3a2a5c", "b48cff", 3, "round"),
    "astral": ("d8dff0", "ffe9a0", 3, "round"),
    "rime": ("b8d4ff", "dbe9ff", 2, "square"),
}


def vertical_gradient(size, top, bottom):
    w, h = size
    base = Image.new("RGB", (1, h))
    px = base.load()
    for y in range(h):
        px[0, y] = lerp(top, bottom, y / max(1, h - 1))
    return base.resize((w, h))


def radial_glow(size, center, radius, color, peak=200):
    """Soft radial light falloff as an 'L' alpha mask tinted with color."""
    w, h = size
    mask = Image.new("L", (w, h), 0)
    px = mask.load()
    cx, cy = center
    for y in range(h):
        for x in range(0, w, 2):
            d = math.hypot(x - cx, y - cy) / radius
            a = max(0.0, 1.0 - d) ** 2
            val = int(peak * a)
            if val > px[x, y]:
                px[x, y] = val
                if x + 1 < w:
                    px[x + 1, y] = val
    glow = Image.new("RGB", (w, h), color)
    return glow, mask.filter(ImageFilter.GaussianBlur(40))


def draw_robot(draw: ImageDraw.ImageDraw, cx, base_y, scale, body, accent, build, head):
    """Draw a chunky stylized robot, head-shoulders-chest crop, slight 3/4 turn."""
    b = body
    edge = lerp(b, (0, 0, 0), 0.45)
    hi = lerp(b, (255, 255, 255), 0.25)
    acc = accent
    s = scale

    # torso widths by build
    torso_w = {0: 340, 1: 260, 2: 420, 3: 240}[build] * s
    shoulder_w = torso_w * (1.18 if build == 2 else 1.0)
    torso_h = 300 * s
    neck_h = 40 * s
    head_w = {0: 240, 1: 200, 2: 170, 3: 180}[build] * s
    head_h = {0: 210, 1: 200, 2: 160, 3: 190}[build] * s

    shoulder_y = base_y - torso_h
    # torso (rounded trapezoid via polygon + rounded bottom)
    tw2, sw2 = torso_w / 2, shoulder_w / 2
    draw.polygon([
        (cx - tw2, base_y), (cx + tw2, base_y),
        (cx + sw2, shoulder_y), (cx - sw2, shoulder_y),
    ], fill=b, outline=edge, width=max(2, int(4 * s)))
    # chest plate highlight
    draw.polygon([
        (cx - tw2 * 0.55, base_y - 20 * s), (cx + tw2 * 0.55, base_y - 20 * s),
        (cx + sw2 * 0.5, shoulder_y + 40 * s), (cx - sw2 * 0.5, shoulder_y + 40 * s),
    ], fill=lerp(b, hi, 0.3))
    # glowing chest core
    core_r = 34 * s
    core_y = shoulder_y + torso_h * 0.45
    draw.ellipse([cx - core_r, core_y - core_r, cx + core_r, core_y + core_r], fill=acc)
    draw.ellipse([cx - core_r, core_y - core_r, cx + core_r, core_y + core_r],
                 outline=lerp(acc, (255, 255, 255), 0.6), width=max(2, int(5 * s)))

    # shoulders (big rounded pauldrons)
    pr = 70 * s
    for sx in (-1, 1):
        pcx = cx + sx * (sw2 + pr * 0.3)
        pcy = shoulder_y + pr * 0.4
        draw.ellipse([pcx - pr, pcy - pr, pcx + pr, pcy + pr], fill=lerp(b, edge, 0.2),
                     outline=edge, width=max(2, int(4 * s)))
        draw.ellipse([pcx - pr * 0.6, pcy - pr * 0.7, pcx + pr * 0.2, pcy - pr * 0.1], fill=hi)

    # neck
    draw.rectangle([cx - 30 * s, shoulder_y - neck_h, cx + 30 * s, shoulder_y],
                   fill=lerp(b, edge, 0.3))

    # head
    hx, hy = cx + 20 * s, shoulder_y - neck_h - head_h * 0.55  # slight offset = 3/4 turn
    hw2, hh2 = head_w / 2, head_h / 2
    if head == "round":
        draw.ellipse([hx - hw2, hy - hh2, hx + hw2, hy + hh2], fill=b, outline=edge,
                     width=max(2, int(4 * s)))
    else:
        r = 36 * s
        draw.rounded_rectangle([hx - hw2, hy - hh2, hx + hw2, hy + hh2], radius=r,
                               fill=b, outline=edge, width=max(2, int(4 * s)))
    if head == "fin":
        draw.polygon([(hx - 8 * s, hy - hh2), (hx + 8 * s, hy - hh2),
                      (hx + 2 * s, hy - hh2 - 55 * s)], fill=acc, outline=edge)
    if head == "hood":
        draw.polygon([(hx - hw2 * 1.05, hy + hh2 * 0.2), (hx, hy - hh2 * 1.35),
                      (hx + hw2 * 1.05, hy + hh2 * 0.2)], fill=lerp(b, edge, 0.25))

    # face visor (dark band) + glowing eyes
    vis_y = hy - 6 * s
    draw.rounded_rectangle([hx - hw2 * 0.72, vis_y - 30 * s, hx + hw2 * 0.72, vis_y + 30 * s],
                           radius=24 * s, fill=lerp(b, (0, 0, 0), 0.7))
    for ex in (-0.34, 0.34):
        er = 18 * s
        ecx = hx + ex * head_w
        draw.ellipse([ecx - er, vis_y - er, ecx + er, vis_y + er], fill=acc)
        draw.ellipse([ecx - er * 0.45, vis_y - er * 0.45, ecx + er * 0.45, vis_y + er * 0.45],
                     fill=lerp(acc, (255, 255, 255), 0.7))

    # accent trim lines on shoulders/chest
    draw.line([(cx - sw2 * 0.8, shoulder_y + 8 * s), (cx + sw2 * 0.8, shoulder_y + 8 * s)],
              fill=acc, width=max(2, int(6 * s)))

    return hx, hy, head_w


def make_cover(hid: str) -> Path:
    body_hex, accent_hex, build, head = HEROES[hid]
    body, acc = hexrgb(body_hex), hexrgb(accent_hex)

    deep = lerp(acc, (8, 8, 14), 0.82)
    mid = lerp(acc, (20, 20, 30), 0.55)
    img = vertical_gradient((W, H), mid, deep).convert("RGB")

    # atmosphere glows: hero halo behind subject + cool rim from upper-left
    halo, hmask = radial_glow((W, H), (int(W * 0.5), int(H * 0.52)), int(H * 0.95), lerp(acc, (255, 255, 255), 0.25), peak=150)
    img.paste(halo, (0, 0), hmask)
    rim, rmask = radial_glow((W, H), (int(W * 0.12), int(H * 0.05)), int(H * 0.6), lerp(acc, (255, 255, 255), 0.55), peak=120)
    img.paste(rim, (0, 0), rmask)

    # vignette
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-W * 0.35, -H * 0.45, W * 1.35, H * 1.45], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(120))
    black = Image.new("RGB", (W, H), (6, 6, 10))
    img = Image.composite(img, black, vig)

    # robot, slightly right of center, cropped at chest by bottom edge
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx, base_y = int(W * 0.5), int(H * 1.04)
    hx, hy, head_w = draw_robot(od, cx, base_y, 1.15, body, acc, build, head)

    # soft drop shadow under subject
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([cx - 260, H - 40, cx + 260, H + 40], fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img = Image.alpha_composite(img.convert("RGBA"), shadow)

    # accent rim-light along the subject's lit side (upper-left)
    rim_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim_layer)
    rd.arc([cx - 230, base_y - 560, cx + 230, base_y - 120], start=140, end=275,
           fill=lerp(acc, (255, 255, 255), 0.4) + (255,), width=14)
    rim_layer = rim_layer.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, rim_layer)

    img = Image.alpha_composite(img, overlay)

    out = OUT_DIR / f"{hid}.png"
    img.convert("RGB").save(out, "PNG")
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for hid in HEROES:
        p = make_cover(hid)
        print(f"[OK] {p.name}  {p.stat().st_size // 1024}KB")
    print("All procedural covers generated.")


if __name__ == "__main__":
    main()
