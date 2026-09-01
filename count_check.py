import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
t = open(r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview", encoding="utf-8").read()
for h in ["cinder","pyra","slag","ember","thorn","willow","stump","sage","volt","nebula","astral","rime"]:
    rows = len(re.findall(r'\t"' + h + r'(?:_left|_right|_back)?":\s*\[', t))
    pals = len(re.findall(r'\t"' + h + r'(?:_left|_right|_back)?":\s*\{', t))
    print(f"{h}: row-arrays={rows} palette-entries={pals}")
print("HERO_ROWS:", t.count("const HERO_ROWS"))
print("HERO_PALETTES:", t.count("const HERO_PALETTES"))
print("ENEMY_PALETTES:", t.count("const ENEMY_PALETTES"))
print("ENEMY_ROWS:", t.count("const ENEMY_ROWS"))
