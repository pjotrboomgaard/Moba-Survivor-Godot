import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
t = open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview", encoding="utf-8").read()

def block_of(key):
    m = re.search(r'\t"' + re.escape(key) + r'":\s*\[\n(.*?)\n\t\],', t, re.S)
    return m.group(1) if m else None

for key in ["slag", "ember", "volt", "nebula", "astral", "rime"]:
    b = block_of(key)
    if b is None:
        print(f"{key}: MISSING BLOCK!")
        continue
    rows = re.findall(r'"([\.a-zA-Z]+)"', b)
    nonempty = [r for r in rows if set(r) != {"."}]
    w = set(len(r) for r in rows)
    print(f"{key}: rows={len(rows)} widths={sorted(w)} nonempty={len(nonempty)}")
    # show first non-empty art row
    for r in rows:
        if set(r) != {"."}:
            print("   first-art:", r)
            break
