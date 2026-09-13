"""Before/after screenshot diff for the self-test harness.

Given two PNG screenshots (a "before" and an "after"), this tool:
  1. Loads both, pads to a common size, and computes a per-pixel diff.
  2. Writes a "diff map" PNG where changed pixels are highlighted in bright
     red/magenta and unchanged pixels are shown dimmed grey - so you can see
     EXACTLY what moved / appeared / disappeared.
  3. Emits a small JSON report with the fraction of changed pixels and the
     bounding box of the change, so a change is unambiguous even when the two
     images look similar to the eye.

Usage:
    python tools/diff_screenshots.py <before.png> <after.png> [--out <diff.png>] [--report <report.json>]

Exit code 0 if a diff was found, 1 if the images are (nearly) identical.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

THRESHOLD = 24  # per-channel difference considered "changed"
DIM_COLOR = (40, 40, 40, 255)
HI_COLOR = (255, 40, 90, 255)


def to_rgb(im: Image.Image) -> Image.Image:
    return im.convert("RGB")


def diff(before: Image.Image, after: Image.Image):
    before, after = to_rgb(before), to_rgb(after)
    w = max(before.width, after.width)
    h = max(before.height, after.height)

    def pad(img: Image.Image) -> Image.Image:
        if img.size == (w, h):
            return img
        canvas = Image.new("RGB", (w, h), (0, 0, 0))
        canvas.paste(img, (0, 0))
        return canvas

    b, a = pad(before), pad(after)
    pb, pa = b.load(), a.load()
    out = Image.new("RGB", (w, h), DIM_COLOR)
    po = out.load()
    changed = 0
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r1, g1, b1 = pb[x, y]
            r2, g2, b2 = pa[x, y]
            if abs(r1 - r2) > THRESHOLD or abs(g1 - g2) > THRESHOLD or abs(b1 - b2) > THRESHOLD:
                changed += 1
                po[x, y] = HI_COLOR
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
            else:
                po[x, y] = (r2 // 2, g2 // 2, b2 // 2)
    total = w * h
    frac = changed / total if total else 0.0
    bbox = None if changed == 0 else (min_x, min_y, max_x, max_y)
    return out, changed, total, bbox


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--out", default=None, help="Path to write the diff-map PNG")
    ap.add_argument("--report", default=None, help="Path to write the JSON report")
    args = ap.parse_args()

    before = Image.open(args.before)
    after = Image.open(args.after)
    out, changed, total, bbox = diff(before, after)
    frac = changed / total if total else 0.0

    out_path = args.out or (Path(args.after).with_name("diff_" + Path(args.after).name))
    out.save(out_path)
    print(f"diff map -> {out_path}")
    print(f"changed {changed}/{total} px ({frac:.4%}) bbox={bbox}")

    if args.report:
        report = {
            "before": str(args.before),
            "after": str(args.after),
            "out": str(out_path),
            "changed_pixels": changed,
            "total_pixels": total,
            "changed_fraction": round(frac, 6),
            "bbox": bbox,
            "has_change": changed > 0,
        }
        Path(args.report).parent.mkdir(parents=True, exist_ok=True)
        Path(args.report).write_text(json.dumps(report, indent=2))
        print(f"report -> {args.report}")

    sys.exit(0 if changed > 0 else 1)


if __name__ == "__main__":
    main()
