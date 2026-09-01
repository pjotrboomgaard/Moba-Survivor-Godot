import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
t = open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview", encoding="utf-8").read()
key = sys.argv[1]
m = re.search(r'\t"' + re.escape(key) + r'":\s*\[\n(.*?)\n\t\],', t, re.S)
rows = re.findall(r'"([\.a-zA-Z\-]+)"', m.group(1))
print(f"{key}: {len(rows)} rows")
for i, r in enumerate(rows):
    flag = "" if len(r) == 40 else f"  << WIDTH {len(r)}"
    print(f"  [{i:02d}] {r}{flag}")
