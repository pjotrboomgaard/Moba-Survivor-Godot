"""OpenCV-based screenshot comparison for the self-test pipeline.

Complements inspect_screenshot.py (layout/position) and diff_screenshots.py
(per-pixel changed-region). This tool answers the questions the pixel-diff
tool CANNOT:

  * "Did object X get bigger / smaller?"  -> size-ratio between two images
  * "Did the object move?"                -> translation vector between images
  * "How similar are the two frames?"     -> SSIM + mean-absolute-diff
  * "What changed and where?"             -> optical-flow magnitude heatmap
  * "Is there motion in a region?"        -> flow-magnitude crop

Use cases in this project:
  * Hero-size tuning (T3.68/69): "tremor should be ~1.2x tobor"
  * Hover offset checks: "totem must fly a little higher"
  * VFX verification: "did the explosion actually animate?"
  * General before/after sanity: "did the change land where I expect?"

CLI:
    python tools/cv_compare.py before.png after.png \
        [--mode diff|size|motion|all] \
        [--roi x0,y0,x1,y1]   # restrict analysis to a bounding box
        [--report report.json]
        [--out out_dir]       # where to save heatmap PNGs

Exit codes:
    0 - analysis completed (regardless of whether changes were detected)
    1 - input error (missing files, bad ROI, etc.)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np


# ─── SSIM (structural similarity) ────────────────────────────────────────────
def _gaussian_window(size: int, sigma: float) -> np.ndarray:
    g = cv2.getGaussianKernel(size, sigma)
    return g @ g.T


def ssim(a: np.ndarray, b: np.ndarray) -> dict:
    """Compute SSIM between two grayscale images. Returns dict with global score
    and per-band breakdown. Falls back to 0.0 if sizes mismatch (caller pads)."""
    C1, C2 = (64 * 0.01) ** 2, (64 * 0.03) ** 2
    if a.shape != b.shape:
        b = cv2.resize(b, (a.shape[1], a.shape[0]))
    a = a.astype(np.float64)
    b = b.astype(np.float64)
    mu_a = cv2.GaussianBlur(a, (11, 11), 1.5)
    mu_b = cv2.GaussianBlur(b, (11, 11), 1.5)
    mu_a_sq = mu_a ** 2
    mu_b_sq = mu_b ** 2
    mu_ab = mu_a * mu_b
    sa = cv2.GaussianBlur(a ** 2, (11, 11), 1.5) - mu_a_sq
    sb = cv2.GaussianBlur(b ** 2, (11, 11), 1.5) - mu_b_sq
    sab = cv2.GaussianBlur(a * b, (11, 11), 1.5) - mu_ab
    num = (2 * mu_ab + C1) * (2 * sab + C2)
    den = (mu_a_sq + mu_b_sq + C1) * (sa + sb + C2)
    score = (num / den).mean()
    return {"ssim": float(score), "identical": abs(score - 1.0) < 1e-3}


# ─── Mean absolute difference ────────────────────────────────────────────────
def mad(a: np.ndarray, b: np.ndarray) -> float:
    """Mean absolute pixel difference (0-255 scale, on grayscale)."""
    if a.shape != b.shape:
        b = cv2.resize(b, (a.shape[1], a.shape[0]))
    return float(np.abs(a.astype(np.int16) - b.astype(np.int16)).mean())


# ─── Translation vector (optical flow, sparse) ───────────────────────────────
def estimate_translation(before: np.ndarray, after: np.ndarray,
                         max_displacement: int = 256) -> dict:
    """Estimate global translation between two grayscale frames using
    Farneback dense flow, then average over high-magnitude pixels.
    Returns {'dx': float, 'dy': int, 'magnitude': float, 'inliers': int}."""
    # Downscale for speed (flow on 1920x1080 is slow); Farneback needs grayscale
    scale = 0.5
    def _gray(x):
        x = cv2.resize(x, None, fx=scale, fy=scale)
        return x if x.ndim == 2 else cv2.cvtColor(x, cv2.COLOR_BGR2GRAY)
    bf = _gray(before)
    af = _gray(after)
    flow = cv2.calcOpticalFlowFarneback(
        bf, af, None,
        pyr_scale=0.5, levels=3, winsize=15,
        iterations=3, poly_n=5, poly_sigma=1.2,
        flags=cv2.OPTFLOW_FARNEBACK_GAUSSIAN,
    )
    # Magnitude mask: only trust pixels with strong flow
    mag = cv2.magnitude(flow[:, :, 0], flow[:, :, 1])
    strong = mag > (mag.max() * 0.3) if mag.max() > 0 else None
    if strong is None or not strong.any():
        return {"dx": 0.0, "dy": 0.0, "magnitude": 0.0, "inliers": 0}
    dx = float(np.mean(flow[:, :, 0][strong])) * (1.0 / scale)
    dy = float(np.mean(flow[:, :, 1][strong])) * (1.0 / scale)
    return {
        "dx": dx,
        "dy": dy,
        "magnitude": float(np.hypot(dx, dy)),
        "inliers": int(strong.sum()),
    }


# ─── Bounding-box size ratio (ROI-based) ─────────────────────────────────────
def bbox_size_ratio(before: np.ndarray, after: np.ndarray,
                    roi: tuple | None = None) -> dict:
    """Compare the bounding box of 'foreground' pixels in a region.

    Foreground = pixels that differ from the corner-sampled background.
    Returns the before/after bbox sizes, the width & height ratios, and an
    'area_ratio' (after/before).  An area_ratio near 1.0 means unchanged;
    > 1.0 means after is bigger; < 1.0 means after is smaller.
    """
    def fg_bbox(img: np.ndarray) -> tuple | None:
        if roi is not None:
            x0, y0, x1, y1 = roi
            sub = img[y0:y1, x0:x1]
            off_x, off_y = x0, y0
        else:
            sub = img
            off_x, off_y = 0, 0
        h, w = sub.shape[:2]
        # Background = median of border pixels
        border = np.concatenate([
            sub[:4, :].reshape(-1, 3),
            sub[-4:, :].reshape(-1, 3),
            sub[:, :4].reshape(-1, 3),
            sub[:, -4:].reshape(-1, 3),
        ])
        bg = np.median(border, axis=0)
        diff = np.abs(sub.astype(np.int16) - bg.astype(np.int16)).max(axis=2)
        mask = diff > 40  # threshold
        if not mask.any():
            return None
        ys, xs = np.where(mask)
        return (int(xs.min()) + off_x, int(ys.min()) + off_y,
                int(xs.max()) + off_x, int(ys.max()) + off_y)

    bb = fg_bbox(before)
    ba = fg_bbox(after)
    if bb is None or ba is None:
        return {"before_bbox": bb, "after_bbox": ba,
                "width_ratio": None, "height_ratio": None, "area_ratio": None,
                "note": "could not detect foreground in one or both images"}
    bw = bb[2] - bb[0]
    bh = bb[3] - bb[1]
    aw = ba[2] - ba[0]
    ah = ba[3] - ba[1]
    return {
        "before_bbox": list(bb),
        "after_bbox": list(ba),
        "before_wh": [bw, bh],
        "after_wh": [aw, ah],
        "width_ratio": round(aw / bw, 4) if bw else None,
        "height_ratio": round(ah / bh, 4) if bh else None,
        "area_ratio": round((aw * ah) / (bw * bh), 4) if bw * bh else None,
    }


# ─── Optical-flow heatmap ────────────────────────────────────────────────────
def flow_heatmap(before: np.ndarray, after: np.ndarray) -> np.ndarray:
    """Return a BGR heatmap of motion magnitude between the two frames."""
    scale = 0.5
    bf = cv2.cvtColor(cv2.resize(before, None, fx=scale, fy=scale), cv2.COLOR_BGR2GRAY)
    af = cv2.cvtColor(cv2.resize(after, None, fx=scale, fy=scale), cv2.COLOR_BGR2GRAY)
    flow = cv2.calcOpticalFlowFarneback(
        bf, af, None, 0.5, 3, 15, 3,
        poly_n=5, poly_sigma=1.2, flags=cv2.OPTFLOW_FARNEBACK_GAUSSIAN,
    )
    mag = cv2.magnitude(flow[:, :, 0], flow[:, :, 1])
    mag = cv2.normalize(mag, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
    # Upscale back to original resolution
    mag = cv2.resize(mag, (before.shape[1], before.shape[0]))
    return cv2.applyColorMap(mag, cv2.COLORMAP_JET)


# ─── CLI ─────────────────────────────────────────────────────────────────────
def main() -> None:
    ap = argparse.ArgumentParser(description="OpenCV screenshot comparison")
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--mode", default="all",
                    choices=["diff", "size", "motion", "all"],
                    help="which analysis to run (default: all)")
    ap.add_argument("--roi", default=None,
                    help="restrict analysis to x0,y0,x1,y1 (comma-separated)")
    ap.add_argument("--report", default=None, help="JSON report output path")
    ap.add_argument("--out", default=None, help="output dir for heatmap PNGs")
    args = ap.parse_args()

    before = cv2.imread(args.before)
    after = cv2.imread(args.after)
    if before is None or after is None:
        print(f"ERROR: could not load {args.before} or {args.after}", file=sys.stderr)
        sys.exit(1)

    roi = None
    if args.roi:
        try:
            x0, y0, x1, y1 = [int(v) for v in args.roi.split(",")]
            roi = (x0, y0, x1, y1)
        except ValueError:
            print(f"ERROR: bad --roi '{args.roi}' (expected x0,y0,x1,y1)",
                  file=sys.stderr)
            sys.exit(1)

    out_dir = Path(args.out) if args.out else Path(args.after).parent
    out_dir.mkdir(parents=True, exist_ok=True)

    result: dict = {
        "before": str(args.before),
        "after": str(args.after),
        "roi": list(roi) if roi else None,
        "before_size": list(before.shape[:2]),
        "after_size": list(after.shape[:2]),
    }

    # Restrict to ROI if requested
    if roi is not None:
        x0, y0, x1, y1 = roi
        before = before[y0:y1, x0:x1]
        after = after[y0:y1, x0:x1]

    gray_b = cv2.cvtColor(before, cv2.COLOR_BGR2GRAY)
    gray_a = cv2.cvtColor(after, cv2.COLOR_BGR2GRAY)

    if args.mode in ("diff", "all"):
        s = ssim(gray_b, gray_a)
        m = mad(gray_b, gray_a)
        result["ssim"] = s["ssim"]
        result["mad"] = m
        result["identical"] = s["identical"] or m < 1.0
        print(f"SSIM={s['ssim']:.4f}  MAD={m:.2f}  identical={result['identical']}")

    if args.mode in ("size", "all"):
        sz = bbox_size_ratio(before, after, roi=None)
        result["size"] = sz
        if sz.get("area_ratio") is not None:
            print(f"Size ratio: width={sz['width_ratio']}, height={sz['height_ratio']}, "
                  f"area={sz['area_ratio']}")

    if args.mode in ("motion", "all"):
        tr = estimate_translation(gray_b, gray_a)
        result["translation"] = tr
        print(f"Translation: dx={tr['dx']:.1f} dy={tr['dy']:.1f} "
              f"|mag|={tr['magnitude']:.1f} inliers={tr['inliers']}")
        heat = flow_heatmap(before, after)
        heat_path = out_dir / f"heat_{Path(args.after).stem}.png"
        cv2.imwrite(str(heat_path), heat)
        result["heatmap"] = str(heat_path)
        print(f"Heatmap: {heat_path.name}")

    if args.report:
        rp = Path(args.report)
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_text(json.dumps(result, indent=2))
        print(f"Report: {rp}")

    # Exit hint (not a hard gate)
    if args.mode in ("diff", "all") and result.get("identical"):
        print("\nNOTE: images appear identical - did the change land?")
    sys.exit(0)


if __name__ == "__main__":
    main()
