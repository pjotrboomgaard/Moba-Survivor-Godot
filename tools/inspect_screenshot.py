"""Screenshot layout inspector for the self-test pipeline.

Analyzes a screenshot and produces:
  1. A thumbnail (resized to max 800px wide) with a 4x4 grid overlay and
     boundary detection (content vs. background).
  2. A JSON report with:
     - content_bounding_box: the region containing most non-background pixels
     - fill_ratio: fraction of image area that is "content"
     - quadrant_map: which quadrants have the most content
     - dominant_edges: which edges (top/bottom/left/right) are mostly content
     - is_centered: whether content is roughly centered
     - coverage: fraction of the full frame covered by content

Usage:
    python tools/inspect_screenshot.py <screenshot.png> [--out <output_dir>] [--report <report.json>]

Exit code 0 always (analysis tool, not a pass/fail gate).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def compute_content_mask(img: np.ndarray, bg_sample: np.ndarray, threshold: float = 30.0) -> np.ndarray:
    """Return a boolean mask where pixels differ from the background sample."""
    diff = np.abs(img.astype(np.float32) - bg_sample.astype(np.float32)).max(axis=2)
    return diff > threshold


def detect_background(img: np.ndarray) -> np.ndarray:
    """Sample the background color from the corners/edges (assuming they're uniform)."""
    h, w = img.shape[:2]
    # Sample a ring around the border (5px wide)
    border = np.concatenate([
        img[:5, :, :].reshape(-1, 3),
        img[-5:, :, :].reshape(-1, 3),
        img[:, :5, :].reshape(-1, 3),
        img[:, -5:, :].reshape(-1, 3),
    ])
    # Median is more robust than mean
    return np.median(border, axis=0).astype(np.uint8)


def content_bounding_box(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    """Return (x0, y0, x1, y1) of the bounding box of True pixels, or None."""
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def quadrant_content_fraction(mask: np.ndarray) -> dict:
    """Return fraction of True pixels in each quadrant (TL, TR, BL, BR)."""
    h, w = mask.shape
    mid_y, mid_x = h // 2, w // 2
    total_true = mask.sum()
    if total_true == 0:
        return {"TL": 0.0, "TR": 0.0, "BL": 0.0, "BR": 0.0}
    quads = {
        "TL": mask[:mid_y, :mid_x].sum(),
        "TR": mask[:mid_y, mid_x:].sum(),
        "BL": mask[mid_y:, :mid_x].sum(),
        "BR": mask[mid_y:, mid_x:].sum(),
    }
    return {k: float(v) / float(total_true) for k, v in quads.items()}


def edge_content_fraction(mask: np.ndarray, strip: int = 20) -> dict:
    """Fraction of content in each edge strip (top/bottom/left/right)."""
    h, w = mask.shape
    total_true = mask.sum()
    if total_true == 0:
        return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
    return {
        "top": float(mask[:strip, :].sum()) / total_true,
        "bottom": float(mask[-strip:, :].sum()) / total_true,
        "left": float(mask[:, :strip].sum()) / total_true,
        "right": float(mask[:, -strip:].sum()) / total_true,
    }


def is_centered(bb: tuple[int, int, int, int], img_w: int, img_h: int, tol: float = 0.25) -> bool:
    """Check if content bounding box is roughly centered (within tol fraction of half-size)."""
    if bb is None:
        return False
    x0, y0, x1, y1 = bb
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0
    return abs(cx - img_w / 2.0) < img_w * tol and abs(cy - img_h / 2.0) < img_h * tol


def make_thumbnail(img: np.ndarray, bb: tuple[int, int, int, int] | None, max_w: int = 800) -> np.ndarray:
    """Create a downscaled thumbnail with grid + boundary overlay."""
    h, w = img.shape[:2]
    scale = max_w / w
    # Downscale using PIL
    pil_img = Image.fromarray(img)
    pil_thumb = pil_img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    draw = ImageDraw.Draw(pil_thumb)
    t_h, t_w = pil_thumb.size[1], pil_thumb.size[0]
    
    # Draw 4x4 grid
    for i in range(1, 4):
        draw.line([(i * t_w // 4, 0), (i * t_w // 4, t_h)], fill=(200, 200, 200), width=1)
        draw.line([(0, i * t_h // 4), (t_w, i * t_h // 4)], fill=(200, 200, 200), width=1)
    
    # Draw content bounding box
    if bb is not None:
        x0, y0, x1, y1 = bb
        sx0, sy0 = int(x0 * scale), int(y0 * scale)
        sx1, sy1 = int(x1 * scale), int(y1 * scale)
        draw.rectangle([sx0, sy0, sx1, sy1], outline=(255, 0, 0), width=2)
        # Center cross
        cx, cy = (sx0 + sx1) // 2, (sy0 + sy1) // 2
        draw.line([(cx - 10, cy), (cx + 10, cy)], fill=(255, 0, 0), width=2)
        draw.line([(cx, cy - 10), (cx, cy + 10)], fill=(255, 0, 0), width=2)
    
    return np.array(pil_thumb)


def main() -> None:
    ap = argparse.ArgumentParser(description="Screenshot layout inspector")
    ap.add_argument("screenshot", help="Path to screenshot PNG")
    ap.add_argument("--out", default=None, help="Output directory for thumbnail")
    ap.add_argument("--report", default=None, help="Path to write JSON report")
    ap.add_argument("--threshold", type=float, default=30.0, help="Background difference threshold")
    args = ap.parse_args()
    
    img_path = Path(args.screenshot)
    if not img_path.exists():
        print(f"ERROR: {img_path} not found", file=sys.stderr)
        sys.exit(1)
    
    img = np.array(Image.open(img_path).convert("RGB"))
    h, w = img.shape[:2]
    
    # Detect background and content
    bg = detect_background(img)
    mask = compute_content_mask(img, bg, threshold=args.threshold)
    
    # Analysis
    bb = content_bounding_box(mask)
    fill_ratio = float(mask.sum()) / float(h * w)
    quads = quadrant_content_fraction(mask)
    edges = edge_content_fraction(mask)
    centered = is_centered(bb, w, h)
    
    # Coverage: what fraction of the full frame is content?
    coverage = fill_ratio
    if bb is not None:
        x0, y0, x1, y1 = bb
        bb_area = (x1 - x0 + 1) * (y1 - y0 + 1)
        coverage = float(bb_area) / float(w * h)
    
    # Determine position description
    position = "centered"
    if bb is not None:
        x0, y0, x1, y1 = bb
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        rel_x = cx / w
        rel_y = cy / h
        if rel_x < 0.33 and rel_y < 0.33:
            position = "TOP-LEFT"
        elif rel_x > 0.67 and rel_y < 0.33:
            position = "TOP-RIGHT"
        elif rel_x < 0.33 and rel_y > 0.67:
            position = "BOTTOM-LEFT"
        elif rel_x > 0.67 and rel_y > 0.67:
            position = "BOTTOM-RIGHT"
        elif rel_y < 0.33:
            position = "TOP"
        elif rel_y > 0.67:
            position = "BOTTOM"
        elif rel_x < 0.33:
            position = "LEFT"
        elif rel_x > 0.67:
            position = "RIGHT"
        else:
            position = "CENTER"
    
    # Write thumbnail
    thumb = make_thumbnail(img, bb)
    out_dir = Path(args.out) if args.out else img_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    thumb_path = out_dir / f"thumb_{img_path.name}"
    Image.fromarray(thumb).save(thumb_path)
    
    print(f"Screenshot: {img_path.name} ({w}x{h})")
    print(f"  Background: RGB({bg[0]}, {bg[1]}, {bg[2]})")
    print(f"  Content fill: {fill_ratio:.2%}")
    print(f"  Bounding box: {bb if bb else 'none'}")
    print(f"  Coverage (bbox/frame): {coverage:.2%}")
    print(f"  Position: {position}")
    print(f"  Centered: {centered}")
    print(f"  Quadrants: {json.dumps({k: f'{v:.1%}' for k, v in quads.items()})}")
    print(f"  Edges: {json.dumps({k: f'{v:.1%}' for k, v in edges.items()})}")
    print(f"  Thumbnail: {thumb_path}")
    
    # Write report
    report = {
        "source": str(img_path),
        "width": w,
        "height": h,
        "background_rgb": [int(bg[0]), int(bg[1]), int(bg[2])],
        "content_fill_ratio": round(fill_ratio, 4),
        "bounding_box": list(bb) if bb else None,
        "coverage": round(coverage, 4),
        "position": position,
        "is_centered": centered,
        "quadrant_fractions": {k: round(v, 4) for k, v in quads.items()},
        "edge_fractions": {k: round(v, 4) for k, v in edges.items()},
        "thumbnail": str(thumb_path),
    }
    
    report_path = Path(args.report) if args.report else out_dir / f"inspect_{img_path.stem}.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))
    print(f"  Report: {report_path}")
    
    # Alert if content is NOT filling the screen (common bug: video in corner)
    if coverage < 0.7 and bb is not None:
        print(f"\n  WARNING: Content only covers {coverage:.0%} of frame - may not be full-screen!")
        if position in ("TOP-LEFT", "TOP", "LEFT"):
            print(f"  WARNING: Content is in {position} region - check if it should fill the screen.")
    
    sys.exit(0)


if __name__ == "__main__":
    main()
