import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

path = r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\ebac881b-3eec-424f-bc6d-45d2a790d323\subagents\2be9532e-3c5f-4edf-b38c-c3341f7bf4b8.jsonl"

edits = []
with open(path, encoding="utf-8") as f:
    for ln, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        msg = obj.get("message") or {}
        content = msg.get("content") or []
        if not isinstance(content, list):
            continue
        for b in content:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "tool_use" and b.get("name") in ("StrReplace", "Write"):
                inp = b.get("input") or {}
                p = str(inp.get("path", ""))
                if "sprite_art.gd" in p:
                    edits.append((ln, b.get("name"), inp))

print(f"TOTAL sprite_art.gd edit calls: {len(edits)}")
for i, (ln, name, inp) in enumerate(edits):
    old = inp.get("old_string", "") or ""
    new = inp.get("new_string", "") or inp.get("contents", "") or ""
    # Which hero keys appear
    keys = []
    for h in ["cinder","pyra","slag","ember","thorn","willow","stump","sage","volt","nebula","astral","rime"]:
        if f'"{h}"' in new or f'"{h}_' in new:
            keys.append(h)
    print(f"  [{i}] line{ln} {name} new_len={len(new)} heroes={keys}")
