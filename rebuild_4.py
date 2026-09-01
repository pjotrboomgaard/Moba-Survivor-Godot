import json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SRC = r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\0204f74b-a89a-42ae-8a8c-e2dd205f9648\0204f74b-a89a-42ae-8a8c-e2dd205f9648.jsonl"

edits = []
with open(SRC, encoding="utf-8") as f:
    for ln, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try: obj = json.loads(line)
        except: continue
        for b in (obj.get("message") or {}).get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "StrReplace":
                inp = b.get("input") or {}
                if "sprite_art.gd" in str(inp.get("path", "")):
                    edits.append((ln, inp.get("old_string", ""), inp.get("new_string", "")))

# Determine intended application order by transcript appearance (already in order).
# Simulate the file as just a growable text; start from the ENEMY_PALETTES anchor tail.
# But the real trick: these edits all anchor on the tail "],\n}\n\nconst ENEMY_PALETTES"
# which only exists ONCE. The agent inserted heroes sequentially, each new insert taking the tail.
# So applying ALL edits in transcript order to a blob that starts as:
#   "<prev-hero-tail...>,\n}\n\nconst ENEMY_PALETTES..."
# reproduces the final tail. We model the region strictly between "const HERO_ROWS := {" tail area.
# Simpler: run each edit; old_string must currently exist; print diagnostics.

# We only care about the 4 heroes volt/nebula/astral/rime. Build their region by
# starting from the sage_back tail (sgggg rows) which is what line13 anchored on.
sage_tail = '''		"...............sggggggggggs.............",
		"...............ssssssssssss.............",
		"...............sggggggggggs.............",
		"...............sggggggggggs.............",
		"...............sggggggggggs.............",
		"...............sggggggggggs.............",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
	],
}

const ENEMY_PALETTES := {
	"grunt": {"o": "5a1414", "f": "ff5d5d", "l": "ffb0a9", "e": "2a0a0a", "w": "ffffff"},'''

blob = sage_tail
for ln, old, new in edits:
    # skip the palette-table edit (line12) which targets HERO_PALETTES, not this ROWS tail
    cnt = blob.count(old)
    mark = ""
    if cnt == 1:
        blob = blob.replace(old, new, 1); mark = "APPLIED"
    else:
        mark = f"SKIP(match={cnt})"
    print(f"line{ln}: old={len(old)} new={len(new)} {mark}")

open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\_recovery_region.txt","w",encoding="utf-8",newline="\n").write(blob)
print("\nWROTE _recovery_region.txt len", len(blob))
