import io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

PREV = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.replay_preview"
OUT  = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd.rebuilt"
REC  = r"C:\Users\pjotr\.cursor\projects\c-Users-pjotr-Documents-Development-Coop-MOBA-Survivor-Godot-Phase-1\_recovery"

# Best full-insert dump per hero (front+left or full 4-facing), plus follow-up micro-fix dumps.
# We'll parse each dump's NEW region to extract per-facing row lists, then merge fixes by
# their hero and facing using live replace within that hero's text.

def read(fn):
    return open(fn, encoding="utf-8").read()

def new_of(fn):
    t = read(fn)
    i = t.index("=====NEW=====\n") + len("=====NEW=====\n")
    return t[i:]

# Grab the NEW text blobs that contain the 4 heroes' row-blocks.
volt13 = new_of(REC + r"\B0204_line13_1.txt")   # volt front + left
volt15 = new_of(REC + r"\B0204_line15_2.txt")   # volt(rewrite) + left + right + back  (full)
nebula = new_of(REC + r"\B0204_line16_3.txt")   # full 4
astral = new_of(REC + r"\B0204_line17_4.txt")   # full 4
rime   = new_of(REC + r"\B0204_line20_6.txt")   # full 4

def parse_blocks(blob):
    """Return dict key->list[str] of rows for every '\t"key": [ ... ]' in blob."""
    out = {}
    for m in re.finditer(r'\t"([a-z_0-9]+)":\s*\[\n(.*?)\n\t\],', blob, re.S):
        key = m.group(1)
        rows = re.findall(r'"([\.A-Za-z\-]+)"', m.group(2))
        out[key] = rows
    return out

blocks = {}
for blob in (volt13, volt15, nebula, astral, rime):
    for k, v in parse_blocks(blob).items():
        blocks[k] = v   # later full dumps overwrite earlier (volt15 over volt13)

def norm40(rows):
    # force exactly 40 rows x 40 cols, right-pad/truncate with '.'
    out = []
    for r in rows:
        if len(r) < 40:
            r = r + "." * (40 - len(r))
        elif len(r) > 40:
            r = r[:40]
        out.append(r)
    while len(out) < 40:
        out.append("." * 40)
    return out[:40]

heroes4 = ["volt", "nebula", "astral", "rime"]
rebuilt = {}
for h in heroes4:
    for suf in ["", "_left", "_right", "_back"]:
        key = h + suf
        if key not in blocks:
            print("MISSING", key); continue
        rows = norm40(blocks[key])
        # validate chars against the hero palette keys + '.'
        rebuilt[key] = rows
        ws = {len(r) for r in rows}
        bad = [c for r in rows for c in set(r) if c != "." and False]
        print(f"{key}: {len(rows)}x40 ws={ws}")

# Now splice into preview: replace each hero's existing (malformed) block with normalized rows.
text = open(PREV, encoding="utf-8").read()

def replace_block(text, key, rows):
    body = "\n".join('\t\t"%s",' % r for r in rows)
    newblock = '\t"%s": [\n%s\n\t],' % (key, body)
    pat = re.compile(r'\t"' + re.escape(key) + r'":\s*\[\n.*?\n\t\],', re.S)
    assert pat.search(text), "block not found for " + key
    return pat.sub(lambda m: newblock, text, count=1)

for key, rows in rebuilt.items():
    text = replace_block(text, key, rows)

open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("\nWROTE", OUT)
