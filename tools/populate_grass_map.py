#!/usr/bin/env python3
"""
Re-populate the grass (Verdant Hollow) map with a healthy number of trees and rocks.

The earlier clean_grass_map.py over-stripped the map, leaving it looking empty
(the user reported "no rocks no trees anymore, only texture grasses"). This script
adds trees + rocks back to a natural-looking density, but:
  - never places them inside the crater (radius ~380 from map center)
  - caps the total so the map stays performant and readable
"""
import json
import math
import os
import random

APPDATA = os.environ["APPDATA"]
path = os.path.join(APPDATA, "Godot", "app_userdata", "Rift Survivors",
                     "world_editor_level_grass_real.json")

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

random.seed(20260911)

CRATER_RADIUS = 380.0
MAP_HALF = 1500.0  # approx half-extent of the grass playfield

TREE_TYPES = ["tree_oak", "tree_fir", "tree_pine", "tree_maple", "tree_cypress",
              "tree_round", "tree_willow"]
ROCK_TYPES = ["rock_small", "rock_large", "boulder", "rock_jagged"]

# How many of each to add (on top of whatever already exists)
WANT_TREES = 55
WANT_ROCKS = 35


def dist_from_center(x, y):
    return math.hypot(x, y)


# Count existing trees/rocks so we don't overshoot the target density.
existing_trees = sum(1 for o in data.get("obstacles", [])
                     if (o.get("type") or o.get("sprite") or o.get("kind", "")).startswith("tree_"))
existing_rocks = sum(1 for o in data.get("obstacles", [])
                     if (o.get("type") or o.get("sprite") or o.get("kind", "")).startswith(("rock", "boulder")))

print(f"Existing trees: {existing_trees}, rocks: {existing_rocks}")

need_trees = max(0, WANT_TREES - existing_trees)
need_rocks = max(0, WANT_ROCKS - existing_rocks)

# Collect existing positions to avoid overlaps.
existing_positions = []
for o in data.get("obstacles", []):
    pos = o.get("pos", [0, 0])
    existing_positions.append((float(pos[0]), float(pos[1])))


def find_free_position(rng, min_dist_from_center=CRATER_RADIUS + 60):
    """Return a random (x, y) inside the playfield, away from the crater and
    far enough from existing props to look natural."""
    for _ in range(200):
        x = rng.uniform(-MAP_HALF, MAP_HALF)
        y = rng.uniform(-MAP_HALF, MAP_HALF)
        if dist_from_center(x, y) < min_dist_from_center:
            continue
        # Keep at least 40px from existing props.
        ok = True
        for ex, ey in existing_positions:
            if math.hypot(x - ex, y - ey) < 40:
                ok = False
                break
        if ok:
            return x, y
    return None


new_trees = 0
for _ in range(need_trees):
    pos = find_free_position(random)
    if pos is None:
        break
    sprite = random.choice(TREE_TYPES)
    data["obstacles"].append({"type": sprite, "pos": [round(pos[0], 1), round(pos[1], 1)]})
    existing_positions.append(pos)
    new_trees += 1

new_rocks = 0
for _ in range(need_rocks):
    pos = find_free_position(random)
    if pos is None:
        break
    sprite = random.choice(ROCK_TYPES)
    data["obstacles"].append({"type": sprite, "pos": [round(pos[0], 1), round(pos[1], 1)]})
    existing_positions.append(pos)
    new_rocks += 1

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

print(f"Added {new_trees} trees, {new_rocks} rocks.")
print(f"Total obstacles now: {len(data.get('obstacles', []))}")
