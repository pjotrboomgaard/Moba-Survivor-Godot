import json, io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

def dump(path, tag, outdir):
    os.makedirs(outdir, exist_ok=True)
    n = 0
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
                    if "sprite_art.gd" not in p:
                        continue
                    old = inp.get("old_string", "") or ""
                    new = inp.get("new_string", "") or inp.get("contents", "") or ""
                    heroes = [h for h in ["cinder","pyra","slag","ember","thorn","willow","stump","sage","volt","nebula","astral","rime"] if (f'"{h}"' in new or f'"{h}_' in new)]
                    outp = os.path.join(outdir, f"{tag}_line{ln}_{n}.txt")
                    with open(outp, "w", encoding="utf-8") as o:
                        o.write("PATH=%s\nTOOL=%s\nHEROES=%s\nOLD_LEN=%d NEW_LEN=%d\n=====OLD=====\n%s\n=====NEW=====\n%s\n" % (p, b.get("name"), heroes, len(old), len(new), old, new))
                    n += 1
    print(f"{tag}: wrote {n} edit dumps to {outdir}")

base = r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\_recovery"
dump(r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\ebac881b-3eec-424f-bc6d-45d2a790d323\subagents\2be9532e-3c5f-4edf-b38c-c3341f7bf4b8.jsonl", "A2be8", base)
dump(r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts\0204f74b-a89a-42ae-8a8c-e2dd205f9648\0204f74b-a89a-42ae-8a8c-e2dd205f9648.jsonl", "B0204", base)
