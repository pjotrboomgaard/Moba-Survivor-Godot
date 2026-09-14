"""Benchmark: which screenshot-verification tool gives the best answers?

We have a set of BEFORE/AFTER screenshot pairs from past verified tasks, each
with a known GROUND-TRUTH outcome (e.g. "video now fills the screen", "sprite
got bigger", "nothing changed"). This harness runs every verification tool on
each pair and scores how well each tool's verdict matches the known truth.

Tools compared:
  - inspect_screenshot.py : deterministic layout (position/coverage/centered)
  - diff_screenshots.py   : pixel-diff (changed-fraction + bbox)
  - cv_compare.py         : OpenCV SSIM/size-ratio/translation
  - vision_check.py       : LLM (Anthropic) semantic verdict per preset

Usage:
    python tools/benchmark_verify.py [--no-llm] [--out <dir>]

Output:
    A JSON report + a human-readable table scoring each tool per use-case.
    This tells us, for the ACTUAL bug classes we hit, which tool is reliable.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
RESULTS = ROOT / "tools" / "selftest" / "results"

# ─── Use-cases: pairs of (before, after) + known ground truth ─────────────────
# Each case has:
#   id, label, before, after (paths relative to RESULTS)
#   truth: dict of expected properties a good tool should surface
#   checks: list of (tool, key, expected_value) assertions we score

def p(rel: str) -> Path:
    return RESULTS / rel

CASES = [
    {
        "id": "joule_fills_screen",
        "label": "Joule menu video: static bg -> full-bleed animated video",
        "before": "joule_menu_ingame_arclight/ingame_before_static.png",
        "after": "joule_menu_ingame_arclight/ingame_after_1.png",
        "truth": {
            "big_visual_change": True,        # SSIM low / diff high
            "after_fills_screen": True,       # coverage ~ full frame
            "layout_centered": True,          # not stuck in a corner
        },
    },
    {
        "id": "cinematic_motion",
        "label": "Crash cinematic: ship far -> ship near impact (camera/ship motion)",
        "before": "crash_ship_far_.png",
        "after": "ship_near_impact_2.405_5757.png",
        "truth": {
            "some_change": True,              # frames differ
            "big_visual_change": True,        # significant scene shift
        },
    },
    {
        "id": "storm_strikes_appear",
        "label": "Storm forest: forest before -> storm strikes (big VFX change)",
        "before": "storm_forest_full/forest_before_1.014_4036.png",
        "after": "storm_forest_full/storm_strikes_8.009_7527.png",
        "truth": {
            "big_visual_change": True,
        },
    },
    {
        "id": "identical_pair",
        "label": "Control: same image vs itself (should detect NO change)",
        "before": "tobor_vfx_iso/vfx_mid_1.50.png",
        "after": "tobor_vfx_iso/vfx_mid_1.50.png",
        "truth": {
            "identical": True,
        },
    },
]


def run_script(args: list[str]) -> tuple[int, str]:
    """Run a python script; return (exit_code, combined stdout+stderr)."""
    try:
        proc = subprocess.run(
            [sys.executable] + args,
            capture_output=True, text=True, timeout=180, cwd=str(ROOT),
        )
        return proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT"
    except Exception as e:
        return -1, f"ERROR {e!r}"


def inspect_report(png: Path) -> dict | None:
    rp = png.with_name(f"bench_inspect_{png.stem}.json")
    rc, _ = run_script([str(HERE / "inspect_screenshot.py"), str(png),
                        "--report", str(rp)])
    if rc != 0 or not rp.exists():
        return None
    return json.loads(rp.read_text())


def diff_report(before: Path, after: Path) -> dict | None:
    rp = after.with_name(f"bench_diff_{after.stem}.json")
    rc, _ = run_script([str(HERE / "diff_screenshots.py"), str(before), str(after),
                        "--report", str(rp)])
    if not rp.exists():
        return None
    return json.loads(rp.read_text())


def cv_report(before: Path, after: Path) -> dict | None:
    rp = after.with_name(f"bench_cv_{after.stem}.json")
    rc, _ = run_script([str(HERE / "cv_compare.py"), str(before), str(after),
                        "--mode", "all", "--report", str(rp)])
    if not rp.exists():
        return None
    return json.loads(rp.read_text())


def vision_report(paths: list[Path], preset: str) -> dict | None:
    rp = paths[-1].with_name(f"bench_vision_{preset}_{'_'.join(pp.stem for pp in paths)}.json")
    rc, _ = run_script([str(HERE / "vision_check.py")] + [str(pp) for pp in paths]
                       + ["--preset", preset, "--report", str(rp)])
    if rc != 0 or not rp.exists():
        return None
    return json.loads(rp.read_text())


def verdict_contains(text: str, *needles: str) -> bool:
    if not text:
        return False
    t = text.lower()
    return any(n.lower() in t for n in needles)


# ─── Per-tool scoring ─────────────────────────────────────────────────────────
def score_inspect(case: dict) -> list[tuple[str, bool, str]]:
    out = []
    after = p(case["after"])
    rep = inspect_report(after)
    if rep is None:
        out.append(("inspect", False, "no report"))
        return out
    # "fills screen" / "centered" checks on the AFTER image
    if "after_fills_screen" in case["truth"]:
        ok = rep["coverage"] >= 0.85
        out.append(("inspect:coverage>=0.85", ok, f"cov={rep['coverage']}"))
    if "layout_centered" in case["truth"]:
        ok = rep["is_centered"]
        out.append(("inspect:is_centered", ok, f"pos={rep['position']}"))
    return out


def score_diff(case: dict) -> list[tuple[str, bool, str]]:
    out = []
    rep = diff_report(p(case["before"]), p(case["after"]))
    if rep is None:
        out.append(("diff", False, "no report"))
        return out
    if "big_visual_change" in case["truth"]:
        ok = rep["changed_fraction"] > 0.05
        out.append(("diff:changed>5%", ok, f"{rep['changed_fraction']:.2%}"))
    if "identical" in case["truth"] and case["truth"]["identical"]:
        ok = rep["changed_fraction"] < 0.001
        out.append(("diff:~0 changed (identical)", ok, f"{rep['changed_fraction']:.4%}"))
    return out


def score_cv(case: dict) -> list[tuple[str, bool, str]]:
    out = []
    rep = cv_report(p(case["before"]), p(case["after"]))
    if rep is None:
        out.append(("cv", False, "no report"))
        return out
    if "big_visual_change" in case["truth"]:
        ok = rep.get("ssim", 1.0) < 0.9
        out.append(("cv:ssim<0.9", ok, f"ssim={rep.get('ssim')}"))
    if "small_motion" in case["truth"]:
        mag = rep.get("translation", {}).get("magnitude", 0.0)
        ok = 0.0 < mag < 30.0
        out.append(("cv:motion<30px", ok, f"mag={mag:.1f}"))
    if "identical" in case["truth"] and case["truth"]["identical"]:
        ok = rep.get("identical", False)
        out.append(("cv:identical", ok, f"ssim={rep.get('ssim')}"))
    return out


def score_vision(case: dict, use_llm: bool) -> list[tuple[str, bool, str]]:
    out = []
    if not use_llm:
        out.append(("vision", False, "skipped (--no-llm)"))
        return out
    # Pick preset based on what the case wants. Layout verdicts need the
    # layout preset; change/motion/identical use the change preset.
    if "after_fills_screen" in case["truth"] or "layout_centered" in case["truth"]:
        preset = "layout"
        rep = vision_report([p(case["after"])], preset)
    else:
        preset = "change"
        rep = vision_report([p(case["before"]), p(case["after"])], preset)
    if rep is None:
        out.append((f"vision:{preset}", False, "no report"))
        return out
    text = rep.get("response", "")
    if "after_fills_screen" in case["truth"]:
        # A good PASS for full-screen; a FAIL means the tool saw a corner bug.
        passed = verdict_contains(text, "pass") and not verdict_contains(text, "corner", "stuck", "top-left")
        out.append((f"vision:{preset} fills-screen PASS", passed, text[:60]))
    if "big_visual_change" in case["truth"]:
        ok = verdict_contains(text, "video", "background", "hero", "change", "different", "menu", "explosion", "effect", "vfx", "fire", "glow", "energy")
        out.append((f"vision:{preset} describes change", ok, text[:60]))
    if "some_change" in case["truth"] and not case["truth"].get("identical"):
        ok = not verdict_contains(text, "identical", "no change", "no visible", "unchanged", "exactly the same")
        out.append((f"vision:{preset} detects change", ok, text[:60]))
    if "identical" in case["truth"] and case["truth"]["identical"]:
        ok = verdict_contains(text, "identical", "same", "no change", "no visible", "unchanged", "no difference")
        out.append((f"vision:{preset} detects identical", ok, text[:60]))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-llm", action="store_true", help="skip the LLM tool")
    args = ap.parse_args()

    report = {"cases": []}
    tool_scores: dict[str, list[int]] = {}
    for case in CASES:
        before = p(case["before"])
        after = p(case["after"])
        if not before.exists() or not after.exists():
            print(f"SKIP {case['id']}: missing {before} or {after}", file=sys.stderr)
            continue

        print(f"\n=== {case['id']}: {case['label']} ===")
        rows = []
        rows += score_inspect(case)
        rows += score_diff(case)
        rows += score_cv(case)
        rows += score_vision(case, use_llm=not args.no_llm)

        passed = sum(1 for _, ok, _ in rows if ok)
        total = len(rows)
        for tool, ok, detail in rows:
            mark = "PASS" if ok else "FAIL"
            print(f"  [{mark}] {tool}: {detail}")
            fam = tool.split(":")[0]
            tool_scores.setdefault(fam, [0, 0])
            tool_scores[fam][1] += 1
            if ok:
                tool_scores[fam][0] += 1
        print(f"  SCORE {case['id']}: {passed}/{total}")
        report["cases"].append({
            "id": case["id"],
            "label": case["label"],
            "score": f"{passed}/{total}",
            "rows": [{"tool": t, "ok": o, "detail": d} for t, o, d in rows],
        })

    out_dir = ROOT / "tools" / "selftest" / "results"
    out_dir.mkdir(parents=True, exist_ok=True)
    rp = out_dir / "benchmark_verify_report.json"
    rp.write_text(json.dumps(report, indent=2))
    print(f"\nReport: {rp}")
    sys.exit(0)


if __name__ == "__main__":
    main()
