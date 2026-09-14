"""Classify Joule menu frames by 'electricity' (lightning) presence.

The lightning in this clip is bright blue-white in the upper sky region. We
measure the count of near-white, high-brightness pixels in the top 55% of the
frame and use that as an electricity score. Frames with score >= threshold are
marked electric.

Output: prints a table and writes classify_joule_frames.json with per-frame
scores + a boolean. Also prints the recommended kept (electric) frame list.

usage: python tools/classify_joule_frames.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

FRAMES_DIR = Path(__file__).resolve().parent.parent / "assets/ui/joule_menu_video/frames"
OUT_JSON = Path(__file__).resolve().parent.parent / "tools/selftest/results/classify_joule_frames.json"

# Top 55% of the frame is where the lightning/arc lives.
SKY_FRACTION = 0.55


def electricity_score(img: Image.Image) -> float:
    arr = np.asarray(img.convert("RGB")).astype(np.int32)
    h = arr.shape[0]
    sky = arr[: int(h * SKY_FRACTION)]
    r, g, b = sky[..., 0], sky[..., 1], sky[..., 2]
    # Lightning is bright, bluish-white: high blue, high green, and blue >= red.
    bright = (b > 190) & (g > 180)
    bluish = (b > r)
    score = float(np.count_nonzero(bright & bluish))
    return score


def main() -> None:
    frames = sorted(FRAMES_DIR.glob("frame_*.png"))
    rows = []
    scores = []
    for f in frames:
        img = Image.open(f)
        sc = electricity_score(img)
        idx = int(f.stem.split("_")[1])
        rows.append((idx, sc, str(f)))
        scores.append(sc)

    # Threshold: a frame is "electric" if its score is at least 25% above the
    # minimum (the calm frames have near-zero; electric frames spike).
    lo = min(scores)
    hi = max(scores)
    threshold = lo + 0.25 * (hi - lo) if hi > lo else lo
    kept = []
    for idx, sc, _ in rows:
        is_elec = sc >= threshold
        if is_elec:
            kept.append(idx)

    print(f"{'frame':>5} {'score':>8}  electric")
    for idx, sc, _ in rows:
        mark = "  <- electric" if sc >= threshold else ""
        print(f"{idx:>5} {sc:>8.0f}  {mark}")
    print(f"\nthreshold={threshold:.1f} (lo={lo:.0f} hi={hi:.0f})")
    print(f"KEPT (electric/lightning) frames: {kept}")

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "threshold": threshold,
        "lo": lo,
        "hi": hi,
        "kept_frames": kept,
        "per_frame": [{"index": i, "score": s} for (i, s, _) in rows],
    }
    OUT_JSON.write_text(json.dumps(report, indent=2))
    print(f"\nwrote {OUT_JSON}")


if __name__ == "__main__":
    main()
