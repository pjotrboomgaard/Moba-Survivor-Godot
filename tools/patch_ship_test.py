import io

path = r"scenes/ship_wreck_iso/ship_wreck_iso.gd"
with open(path, encoding="utf-8") as f:
    lines = f.readlines()

# Find the AFTER assertion block start and the _write_report call after it.
start = None
end = None
for i, line in enumerate(lines):
    if start is None and "AFTER assertions:" in line:
        start = i
    if start is not None and "_write_report(report)" in line:
        end = i
        break

assert start is not None and end is not None, "block not found"

T = "\t"
new_block = [
    "\t# AFTER assertions:\n",
    "\t#  1. 3 collision segments present\n",
    "\t#  2. full crash + shop sprites present\n",
    "\t#  3. interact point at the true centre (0,0)\n",
    "\t#  4. morph completed: current_state == \"shop\"\n",
    "\t#  5. depth sorting works (front marker > back marker)\n",
    "\tvar colliders: Array = _wreck.get(\"_colliders\")\n",
    "\tvar collider_count := colliders.size() if colliders != null else 0\n",
    "\tvar all_have_collision := true\n",
    "\tvar z_values: Array = []\n",
    "\tfor p in colliders:\n",
    "\t\tif not is_instance_valid(p):\n",
    "\t\t\tall_have_collision = false\n",
    "\t\t\tcontinue\n",
    "\t\tif p.get_node_or_null(\"CollisionShape2D\") == null:\n",
    "\t\t\tall_have_collision = false\n",
    "\t\t\tcontinue\n",
    "\t\tz_values.append(int(p.get(\"z_index\")))\n",
    "\tvar crash_spr = _wreck.get(\"_crash_sprite\")\n",
    "\tvar shop_spr = _wreck.get(\"_shop_sprite\")\n",
    "\tvar sprites_ok := crash_spr != null and shop_spr != null\n",
    "\tvar z_sorted := WorldClock.depth_z(60.0) > WorldClock.depth_z(-260.0)\n",
    "\tvar state_ok := str(_wreck.get(\"current_state\")) == \"shop\"\n",
    "\tvar interact_ok := Vector2(_wreck.get(\"interact_point\")).distance_to(WRECK_CENTER) < 1.0\n",
    "\tvar ok := collider_count == 3 and all_have_collision and sprites_ok and state_ok and interact_ok and z_sorted\n",
    "\tvar report := {\n",
    "\t\t\"verdict\": \"PASS\" if ok else \"FAIL\",\n",
    "\t\t\"mode\": \"after\",\n",
    "\t\t\"collider_count\": collider_count,\n",
    "\t\t\"all_have_collision\": all_have_collision,\n",
    "\t\t\"sprites_ok\": sprites_ok,\n",
    "\t\t\"current_state\": str(_wreck.get(\"current_state\")),\n",
    "\t\t\"morph_progress\": float(_wreck.get(\"morph_progress\")),\n",
    "\t\t\"interact_point\": _wreck.get(\"interact_point\"),\n",
    "\t\t\"z_sorted\": z_sorted,\n",
    "\t\t\"z_values\": z_values,\n",
    "\t\t\"shots\": _captured.values(),\n",
    "\t}\n",
]

# Replace lines[start:end] with new_block (keep the _write_report line at end).
new_lines = lines[:start] + new_block + lines[end:]
with open(path, "w", encoding="utf-8", newline="") as f:
    f.writelines(new_lines)
print("rewrote AFTER assertion block, replaced lines", start+1, "to", end)
