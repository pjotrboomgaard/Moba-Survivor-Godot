"""Analyze Joule menu frames for lightning bolt presence.

For each frame, we look at the top-right region (where lightning appears) and
count very bright pixels (RGB all > 220). Frames with many such pixels have
visible lightning; calm frames have few.

Outputs a table and writes classify_joule_frames.json.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

FRAMES_DIR = Path(__file__).resolve().parent.parent / "assets/ui/joule_menu_video/frames"
OUT_JSON = Path(__file__).resolve().parent.parent / "tools/selftest/results/classify_joule_frames.json"


def analyze_frame(img_path: Path) -> dict:
    img = np.asarray(Image.open(img_path).convert("RGB")).astype(np.int32)
    h, w, _ = img.shape
    # Top 60% of frame, right half (where lightning typically appears)
    sky = img[: int(h * 0.60), int(w * 0.3):]
    r, g, b = sky[..., 0], sky[..., 1], sky[..., 2]
    # Lightning: bright white-blue. Threshold: all channels > 210, blue > red.
    lightning_px = (r > 200) & (g > 200) & (b > 200) & (b >= r)
    count = int(np.count_nonzero(lightning_px))
    # Also check for the jagged bolt shape: vertical extent of bright pixels
    rows_with_bright = int(np.count_nonzero(np.any(lightning_px, axis=1)))
    return {"lightning_px": count, "rows_with_bright": rows_with_bright}


def main() -> None:
    frames = sorted(FRAMES_DIR.glob("frame_*.png"))
    results = []
    for f in frames:
        info = analyze_frame(f)
        frame_num = int(f.stem.split("_")[1])
        results.append({"frame": frame_num, **info})

    # Determine threshold: calm frames have very few lightning pixels (< 500)
    # while lightning frames have many (> 2000). Use 1000 as threshold.
    THRESHOLD = 1000
    electric_frames = [r["frame"] for r in results if r["lightning_px"] >= THRESHOLD]
    calm_frames = [r["frame"] for r in results if r["lightning_px"] < THRESHOLD]

    print(f"{'frame':>5} {'lightning_px':>12} {'rows':>6}  verdict")
    for r in results:
        verdict = "ELECTRIC" if r["lightning_px"] >= THRESHOLD else "calm"
        print(f"{r['frame']:>5} {r['lightning_px']:>12} {r['rows_with_bright']:>6}  {verdict}")
    print(f"\nElectric frames ({len(electric_frames)}): {electric_frames}")
    print(f"Calm frames ({len(calm_frames)}): {calm_frames}")

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "threshold": THRESHOLD,
        "electric_frames": electric_frames,
        "calm_frames": calm_frames,
        "all_frames": results,
    }
    OUT_JSON.write_text(json.dumps(report, indent=2))
    print(f"\nWrote {OUT_JSON}")


if __name__ == "__main__":
    main()
