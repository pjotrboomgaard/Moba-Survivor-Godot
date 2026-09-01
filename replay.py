import json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

CUR = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd"
OUT = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview"

def collect_edits(path):
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
                if b.get("type") == "tool_use" and b.get("name") == "StrReplace":
                    inp = b.get("input") or {}
                    if "sprite_art.gd" not in str(inp.get("path", "")):
                        continue
                    edits.append((ln, inp.get("old_string", ""), inp.get("new_string", "")))
    return edits

text = open(CUR, encoding="utf-8").read()

sessions = [
    r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\ebac881b-3eec-424f-bc6d-45d2a790d323\subagents\2be9532e-3c5f-4edf-b38c-c3341f7bf4b8.jsonl",
    r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\0204f74b-a89a-42ae-8a8c-e2dd205f9648\0204f74b-a89a-42ae-8a8c-e2dd205f9648.jsonl",
]

applied = 0
skipped = 0
for sp in sessions:
    edits = collect_edits(sp)
    tag = sp.split("\\")[-1][:8]
    for ln, old, new in edits:
        if old == "":
            print(f"  [{tag} line{ln}] SKIP empty old_string")
            skipped += 1
            continue
        cnt = text.count(old)
        if cnt == 1:
            text = text.replace(old, new, 1)
            applied += 1
            print(f"  [{tag} line{ln}] OK applied (old_len={len(old)} new_len={len(new)})")
        else:
            skipped += 1
            print(f"  [{tag} line{ln}] !! MATCH={cnt} (NOT applied) old_len={len(old)}")

# Idempotent: if hero already present, the palette insert would've failed; report.
print(f"\nAPPLIED={applied} SKIPPED={skipped}")

# sanity: how many hero keys now present
for h in ["cinder","pyra","slag","ember","thorn","willow","stump","sage","volt","nebula","astral","rime"]:
    present = f'\t"{h}": [' in text
    pal = f'\t"{h}": {{' in text
    print(f"  {h}: rows={present} palette={pal}")

open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("WROTE", OUT, "len", len(text))
