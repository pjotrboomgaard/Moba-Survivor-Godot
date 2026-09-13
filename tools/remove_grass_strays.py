#!/usr/bin/env python3
"""T3.35 item 8: Remove the stray pulse_wipe "Grove Bell" landmark (at [0,0])
and the 3 stray trees (2 inside the crater, 1 outside) near [0,-1176] from the
grass world map file, in BOTH the repo assets copy and the live user-data copy
(if it exists), so they never reappear on Play in non-classic mode.

This is a one-off surgical removal: only the specific entries listed below are
removed; all other landmarks / obstacles / trees are left untouched.
"""
import json
import os
import sys

REPO_PATH = os.path.join(
    os.path.dirname(__file__), "..", "assets", "levels", "grass_real.json"
)
APPDATA = os.environ.get("APPDATA", "")
USER_PATH = (
    os.path.join(
        APPDATA, "Godot", "app_userdata", "Rift Survivors",
        "world_editor_level_grass_real.json",
    )
    if APPDATA
    else None
)

# The stray landmark: pulse_wipe "Grove Bell" at exactly [0,0] (the OTHER "Grove
# Bell" at [0,-1176] is the legitimate authored landmark kept from the world kit).
STRAY_LANDMARK_POS = (0.0, 0.0)
STRAY_LANDMARK_EFFECT = "pulse_wipe"

# The 3 stray trees near [0,-1176] (see PLAN.md T3.35 item 8 / user report):
#   2 trees inside the central crater, 1 tree just outside it.
STRAY_TREES = [
    {"sprite": "tree_cypress", "pos": [369.136840820313, -1223.75268554688]},
    {"sprite": "tree_cypress", "pos": [-259.923156738281, -855.376708984375]},
    {"sprite": "tree_oak", "pos": [-295.111083984375, -1414.65576171875]},
]

# Tolerance for matching a float position back from JSON (round-trip safety).
POS_TOL = 0.5


def _match_pos(entry_pos, target):
    try:
        x = float(entry_pos[0])
        y = float(entry_pos[1])
    except (IndexError, TypeError, ValueError):
        return False
    return abs(x - target[0]) <= POS_TOL and abs(y - target[1]) <= POS_TOL


def clean_one(path):
    if not os.path.isfile(path):
        print(f"[skip] not found: {path}")
        return 0, 0
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    removed_lm = 0
    landmarks = data.get("landmarks", [])
    kept_lm = []
    for lm in landmarks:
        if (
            str(lm.get("effect", "")) == STRAY_LANDMARK_EFFECT
            and _match_pos(lm.get("pos", []), STRAY_LANDMARK_POS)
        ):
            removed_lm += 1
            print(f"  [remove landmark] {lm.get('hint','?')} at {lm.get('pos')}")
            continue
        kept_lm.append(lm)
    data["landmarks"] = kept_lm

    removed_trees = 0
    obstacles = data.get("obstacles", [])
    kept_obs = []
    for obs in obstacles:
        sprite = str(obs.get("sprite") or obs.get("type") or obs.get("kind") or "")
        matched = False
        for target in STRAY_TREES:
            if sprite == target["sprite"] and _match_pos(obs.get("pos", []), target["pos"]):
                removed_trees += 1
                print(f"  [remove tree] {sprite} at {obs.get('pos')}")
                matched = True
                break
        if not matched:
            kept_obs.append(obs)
    data["obstacles"] = kept_obs

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(
        f"[done] {path}: removed {removed_lm} stray landmark(s), "
        f"{removed_trees} stray tree(s)"
    )
    return removed_lm, removed_trees


def main():
    total_lm = 0
    total_trees = 0
    total_lm, total_trees = clean_one(REPO_PATH)
    if USER_PATH:
        user_lm, user_trees = clean_one(USER_PATH)
        total_lm += user_lm
        total_trees += user_trees
    print(f"[summary] total removed: {total_lm} landmark(s), {total_trees} tree(s)")


if __name__ == "__main__":
    main()
