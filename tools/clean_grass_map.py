#!/usr/bin/env python3
"""Regenerate a clean default grass map: drop ice props, drop trees inside the
crater, and cap tree/rock counts so the grass world reads as a clean meadow
rather than a random jumble of objects. Landmarks + features are preserved."""
import json
import math
import os

APPDATA = os.environ["APPDATA"]
path = os.path.join(APPDATA, "Godot", "app_userdata", "Rift Survivors",
                    "world_editor_level_grass_real.json")

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

CRATER_RADIUS = 380.0  # clear the whole boss bowl (crater ~300 + margin)

out_obstacles = []
dropped_ice = 0
dropped_crater = 0
tree_kept = 0
rock_kept = 0
grass_kept = 0
other_kept = 0

# Split first so we can cap trees/rocks deterministically.
trees = []
rocks = []
grass = []
other = []
for o in data["obstacles"]:
    spr = o["sprite"]
    x, y = o["pos"][0], o["pos"][1]
    dist = math.hypot(x, y)
    if spr.startswith("ice_"):
        dropped_ice += 1
        continue
    in_crater = dist < CRATER_RADIUS
    if spr.startswith("tree"):
        trees.append(o)
        if in_crater:
            dropped_crater += 1
    elif spr in ("rock_small", "rock_large", "boulder", "rock_jagged", "spire"):
        rocks.append(o)
        if in_crater:
            dropped_crater += 1
    elif spr in ("grass_wild", "grass_tuft", "grass_long", "grass_flower",
                 "grass_bloom", "grass_mushroom", "grass_lush", "grass_meadow",
                 "grass_bush", "flower_patch", "dirt_tile"):
        grass.append(o)
    else:
        other.append(o)

# Keep all grass + other (they're the base field). Cap trees to 40, rocks to 24.
# Deterministic: keep the ones closest to the map edge (furthest from center) so
# they ring the crater rather than cluster in it.
trees.sort(key=lambda o: -math.hypot(o["pos"][0], o["pos"][1]))
rocks.sort(key=lambda o: -math.hypot(o["pos"][0], o["pos"][1]))
trees = trees[:40]
rocks = rocks[:24]

out_obstacles = grass + other + trees + rocks
data["obstacles"] = out_obstacles

# Keep landmarks + features + biome untouched.

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

print("grass=%d other=%d trees_kept=%d rocks_kept=%d" % (
    grass_kept := len(grass), len(other), len(trees), len(rocks)))
print("dropped_ice=%d dropped_crater=%d total=%d" % (
    dropped_ice, dropped_crater, len(out_obstacles)))
