"""LLM-based visual screenshot verification using Anthropic Claude vision.

Complements the deterministic tools (inspect_screenshot.py, diff_screenshots.py,
cv_compare.py) by adding a semantic/quality layer that answers questions like:
  * "Does the video fill the entire background?"
  * "Is the hero sprite in the top-left corner (bug) or centered?"
  * "Does the explosion look correct / animated?"
  * "Are the two heroes the same size?"
  * "What changed between before and after?"

Use cases:
  - Layout verification (full-screen vs corner-stuck)
  - Visual quality judgment (does art look right?)
  - Size/proportion comparison (hero scaling)
  - Motion/animation check (is the frame actually changing?)
  - Before/after change description (what did the code change accomplish?)

API:
  - Uses Anthropic Claude (model configurable, default claude-sonnet-4-5)
  - Key from ANTHROPIC_API_KEY env var or .env file at project root
  - Images are base64-encoded and sent inline

Usage:
  python tools/vision_check.py <screenshot.png> --question "Does the video fill the screen?"
  python tools/vision_check.py <before.png> <after.png> --question "What changed?"
  python tools/vision_check.py <img.png> --preset layout
  python tools/vision_check.py <img.png> --preset size --ref <other.png>

Presets:
  layout: "Is content filling the full screen? Is anything stuck in a corner?"
  size: "Compare the relative sizes of the main subjects between the two images"
  motion: "Is the animated content actually moving/changing between frames?"
  quality: "Does this look visually correct and polished?"
  change: "Describe the specific visual differences between before and after"

Exit code: 0 if API call succeeds and returns a verdict, 1 on failure.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_api_key() -> str:
    """Load Anthropic API key from .env or environment."""
    # 1. Environment variable
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key
    # 2. .env file at project root
    env_path = PROJECT_ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("ANTHROPIC_API_KEY="):
                return line.split("=", 1)[1].strip()
    # 3. .env in home
    env_path = Path.home() / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line.startswith("ANTHROPIC_API_KEY="):
                return line.split("=", 1)[1].strip()
    raise RuntimeError("ANTHROPIC_API_KEY not found. Set it in .env or environment.")


def encode_image(path: Path) -> tuple[str, str]:
    """Return (base64_string, media_type) for an image file."""
    suffix = path.suffix.lower()
    media_type = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
    }.get(suffix, "image/png")
    data = path.read_bytes()
    return base64.b64encode(data).decode(), media_type


# ─── Presets ──────────────────────────────────────────────────────────────────

PRESETS = {
    "layout": (
        "Analyze this game screenshot for LAYOUT correctness.\n"
        "1. Is the main content (video, sprite, UI) filling the intended area?\n"
        "2. Is anything stuck in a corner (top-left, top-right, bottom-left, bottom-right)?\n"
        "3. Is the content properly centered or positioned as expected?\n"
        "4. Are there any empty/unintended gaps or overlaps?\n\n"
        "Respond with:\n"
        "  VERDICT: PASS or FAIL\n"
        "  ISSUE: (one-line description if FAIL)\n"
        "  DETAIL: (2-3 sentences describing the layout you see)"
    ),
    "size": (
        "Compare these two images. Focus on the MAIN SUBJECT (character, sprite, object).\n"
        "1. In the FIRST image, what fraction of the frame does the main subject occupy (roughly)?\n"
        "2. In the SECOND image, what fraction does it occupy?\n"
        "3. Is the subject LARGER, SMALLER, or the SAME SIZE in the second image?\n"
        "4. By roughly what factor (e.g. 1.2x bigger, 0.8x smaller)?\n\n"
        "Respond with:\n"
        "  RATIO: (estimated size ratio of subject2/subject1)\n"
        "  DIRECTION: LARGER / SMALLER / SAME\n"
        "  DETAIL: (2-3 sentences)"
    ),
    "motion": (
        "These are two consecutive frames from an animated sequence.\n"
        "1. Is the content actually CHANGING between the two frames?\n"
        "2. Which parts moved or changed (describe regions)?\n"
        "3. Is the motion smooth/continuous or jarring?\n\n"
        "Respond with:\n"
        "  MOTION: YES / NO\n"
        "  CHANGED_REGIONS: (list of areas that changed)\n"
        "  DETAIL: (2-3 sentences)"
    ),
    "quality": (
        "Evaluate this game screenshot for VISUAL QUALITY.\n"
        "1. Does the art look polished and intentional?\n"
        "2. Are there any visual glitches, artifacts, or rendering errors?\n"
        "3. Are sprites properly aligned (feet on ground, centered, etc.)?\n"
        "4. Is the color palette cohesive?\n\n"
        "Respond with:\n"
        "  VERDICT: PASS or NEEDS-REVIEW\n"
        "  ISSUES: (list of any problems, or 'none')\n"
        "  DETAIL: (2-3 sentences)"
    ),
    "change": (
        "These are BEFORE and AFTER screenshots of a game after a code change.\n"
        "1. What SPECIFIC visual changes occurred between the two?\n"
        "2. Where in the screen did the change happen?\n"
        "3. Does the change match what you'd expect from a typical game modification?\n"
        "4. Are there any UNEXPECTED side-effects or regressions visible?\n\n"
        "Respond with:\n"
        "  CHANGES: (bullet list of specific changes)\n"
        "  LOCATION: (where the change is)\n"
        "  UNEXPECTED: (any unintended changes, or 'none')\n"
        "  DETAIL: (2-3 sentences)"
    ),
    "text": (
        "Read any TEXT visible in this game screenshot.\n"
        "List all readable text elements (labels, buttons, titles, stats) and their approximate positions.\n"
        "Also note any text that looks wrong, misspelled, or overlapping.\n\n"
        "Respond with:\n"
        "  TEXT_ELEMENTS: (list with positions)\n"
        "  ISSUES: (any text problems, or 'none')\n"
        "  DETAIL: (2-3 sentences)"
    ),
}


def call_anthropic(
    images: list[Path],
    prompt: str,
    model: str = "claude-sonnet-4-5-20250929",
    max_tokens: int = 1024,
    temperature: float = 0.0,
) -> str:
    """Call Anthropic API with one or more images + text prompt. Returns response text."""
    import anthropic

    api_key = load_api_key()
    client = anthropic.Anthropic(api_key=api_key)

    content: list = []
    for img_path in images:
        b64, media_type = encode_image(img_path)
        content.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": b64,
            },
        })
    content.append({"type": "text", "text": prompt})

    response = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        temperature=temperature,
        messages=[{"role": "user", "content": content}],
    )

    if response.stop_reason == "max_tokens":
        print("WARNING: response may be truncated (hit max_tokens)", file=sys.stderr)

    return response.content[0].text


def main() -> None:
    ap = argparse.ArgumentParser(description="LLM-based visual screenshot verification")
    ap.add_argument("images", nargs="+", help="One or two image paths (second is 'after')")
    ap.add_argument("--question", "-q", default=None, help="Custom question (overrides --preset)")
    ap.add_argument("--preset", "-p", default="layout", choices=list(PRESETS.keys()),
                    help="Use a preset question template")
    ap.add_argument("--model", default="claude-sonnet-4-5-20250929",
                    help="Anthropic model to use")
    ap.add_argument("--report", default=None, help="Write JSON report to this path")
    ap.add_argument("--max-tokens", type=int, default=1024, help="Max tokens in response")
    args = ap.parse_args()

    paths = [Path(p) for p in args.images]
    for p in paths:
        if not p.exists():
            print(f"ERROR: {p} not found", file=sys.stderr)
            sys.exit(1)

    prompt = args.question if args.question else PRESETS[args.preset]

    print(f"Analyzing {len(paths)} image(s) with {args.model}...")
    print(f"Prompt: {prompt[:80]}...")
    print("-" * 60)

    try:
        response_text = call_anthropic(paths, prompt, model=args.model, max_tokens=args.max_tokens)
    except Exception as e:
        print(f"ERROR: API call failed: {e}", file=sys.stderr)
        sys.exit(1)

    print(response_text)
    print("-" * 60)

    # Write report if requested
    if args.report:
        report = {
            "images": [str(p) for p in paths],
            "preset": args.preset if not args.question else "custom",
            "question": prompt,
            "model": args.model,
            "response": response_text,
        }
        rp = Path(args.report)
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_text(json.dumps(report, indent=2))
        print(f"Report: {rp}")


if __name__ == "__main__":
    main()
