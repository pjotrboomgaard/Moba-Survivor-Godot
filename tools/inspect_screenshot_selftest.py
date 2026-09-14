"""Self-test for inspect_screenshot.py.

Generates synthetic test images and asserts the inspector detects the
expected layout (full-bleed vs. corner-stuck), so the tool is proven to
catch the exact bug class it was built for (video in top-left corner).

Exit code 0 if all assertions pass, 1 otherwise.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE / "selftest" / "results" / "inspect_tool_selftest"
OUT.mkdir(parents=True, exist_ok=True)

# Run the inspector as a subprocess and return its report JSON + stdout.
def run_inspect(png: Path) -> dict:
    import json
    report = OUT / f"report_{png.stem}.json"
    subprocess.run(
        [sys.executable, str(HERE / "inspect_screenshot.py"), str(png), "--report", str(report)],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    return json.loads(report.read_text())


def make_full_bleed(path: Path) -> None:
    """A screenshot where content fills the whole frame (menu video, correct)."""
    w, h = 640, 360
    img = np.zeros((h, w, 3), dtype=np.uint8)
    img[:] = (90, 140, 200)  # bright content everywhere
    img[:2, :] = (10, 12, 25)  # thin dark border so bg detection has something
    img[-2:, :] = (10, 12, 25)
    Image.fromarray(img).save(path)


def make_corner_stuck(path: Path) -> None:
    """A screenshot where a small video sits in the top-left corner,
    with a distinct static background filling the rest (the actual bug)."""
    w, h = 640, 360
    img = np.full((h, w, 3), (30, 60, 40), dtype=np.uint8)  # dark green bg
    # 160x90 bright block in the top-left corner
    img[:90, :160] = (230, 230, 230)
    Image.fromarray(img).save(path)


def main() -> None:
    failures = []

    full = OUT / "full_bleed.png"
    make_full_bleed(full)
    rep = run_inspect(full)
    print("FULL-BLEED:", rep["position"], f"coverage={rep['coverage']:.0%}",
          f"centered={rep['is_centered']}")
    if not rep["is_centered"]:
        failures.append(f"full-bleed should be centered, got {rep['position']}")
    if rep["coverage"] < 0.85:
        failures.append(f"full-bleed coverage too low: {rep['coverage']:.0%}")

    corner = OUT / "corner_stuck.png"
    make_corner_stuck(corner)
    rep = run_inspect(corner)
    print("CORNER-STUCK:", rep["position"], f"coverage={rep['coverage']:.0%}",
          f"centered={rep['is_centered']}")
    if rep["position"] != "TOP-LEFT":
        failures.append(f"corner-stuck should be TOP-LEFT, got {rep['position']}")
    if rep["coverage"] > 0.5:
        failures.append(f"corner-stuck coverage too high: {rep['coverage']:.0%}")
    if rep["is_centered"]:
        failures.append("corner-stuck should NOT be centered")

    if failures:
        print("\nFAIL:")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("\nPASS: inspector correctly distinguishes full-bleed vs corner-stuck")
    sys.exit(0)


if __name__ == "__main__":
    main()
