#!/usr/bin/env python3
"""
Clean up misplaced biome objects in saved world-editor maps.

Rules (per user requirement "world cleanup"):
  - volcano (biome 1): remove all grass_* and tree_* and flower_patch
  - ice (biome 2): remove water-related objects (none expected) — keep ice props only
  - factory (biome 3): remove tree_* (no trees in a factory)
  - docks (biome 4): remove town_* houses/structures (no random houses in docks)
  - grass (biome 0): already cleaned by clean_grass_map.py
"""
import json
import os
import re

APPDATA = os.environ["APPDATA"]
base = os.path.join(APPDATA, "Godot", "app_userdata", "Rift Survivors")

# Map of biome_id -> (filename, list of regex patterns to remove from sprite/type names)
CLEAN_RULES = {
    1: {  # volcano
        "file": "world_editor_level_volcano.json",
        "remove_patterns": [
            r"^grass_.*",
            r"^tree_.*",
            r"^flower_patch$",
            r"^bush.*",
        ],
    },
    2: {  # ice
        "file": "world_editor_level_ice.json",
        "remove_patterns": [
            # Remove non-ice trees (they don't belong on an ice field)
            r"^tree_dead$",
            r"^tree_oak$",
            r"^tree_maple$",
            r"^tree_cypress$",
            r"^tree_pine$",
            r"^tree_willow$",
            # Water objects (if any)
            r"^water_.*",
            r"^pond_.*",
            r"^lake_.*",
        ],
    },
    3: {  # factory
        "file": "world_editor_level_factory.json",
        "remove_patterns": [
            r"^tree_.*",
            r"^flower_.*",
        ],
    },
    4: {  # docks
        "file": "world_editor_level_docks.json",
        "remove_patterns": [
            r"^town_house$",
            r"^town_well$",
            r"^town_church$",
            r"^town_shop$",
            r"^town_.*",  # remove ALL town structures — no random houses in docks
        ],
    },
}


def should_remove(sprite_type: str, patterns: list) -> bool:
    for pat in patterns:
        if re.match(pat, sprite_type):
            return True
    return False


for biome_id, rule in CLEAN_RULES.items():
    path = os.path.join(base, rule["file"])
    if not os.path.exists(path):
        print(f"[{rule['file']}] not found, skipping")
        continue

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    removed_counts = {}
    for key in ["obstacles", "landmarks", "features"]:
        original = data.get(key, [])
        filtered = []
        for obj in original:
            sprite = obj.get("type") or obj.get("sprite") or obj.get("kind") or ""
            if should_remove(sprite, rule["remove_patterns"]):
                removed_counts[sprite] = removed_counts.get(sprite, 0) + 1
            else:
                filtered.append(obj)
        data[key] = filtered
        print(f"[{rule['file']}] {key}: {len(original)} -> {len(filtered)} (removed {len(original)-len(filtered)})")

    print(f"[{rule['file']}] removed sprites: {removed_counts}")

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"[{rule['file']}] written\n")
