import os, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

root = r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\agent-transcripts"
missing = ["volt", "nebula", "astral", "rime"]
allh = ["cinder","pyra","slag","ember","thorn","willow","stump","sage","volt","nebula","astral","rime"]

for dirpath, _, files in os.walk(root):
    for fn in files:
        if not fn.endswith(".jsonl"):
            continue
        p = os.path.join(dirpath, fn)
        try:
            data = open(p, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        hits = {}
        for h in allh:
            # escaped JSON string key forms: \"h\":  or \"h_back\":  (prefix variants)
            c = 0
            for suf in ["", "_front", "_back", "_left", "_right"]:
                key = '\\"' + h + suf + '\\":'
                c += data.count(key)
            if c:
                hits[h] = c
        if any(h in hits for h in missing):
            print(os.path.relpath(p, root), "size=", len(data))
            print("    ", hits)
