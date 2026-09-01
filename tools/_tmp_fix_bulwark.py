"""Single-shot bulwark fix + bake + score, defensive against concurrent writes."""
import re
import subprocess
import sys
import time

ROOT = '.'
ART = ROOT + '/tools/sprite_art.gd'

def snapshot():
    text = open(ART, encoding='utf-8').read()
    m = re.search(r'"bulwark": \[(.*?)\n\t\],', text, re.S)
    rows = re.findall(r'"([^"]*)"', m.group(1))
    return text, m, rows

def remove_red_specks(rows):
    """Clear 'r' cells with <2 opaque 8-neighbours."""
    out = [list(r) for r in rows]
    h, w = len(rows), 40
    cleared = 0
    for y in range(h):
        for x in range(min(w, len(rows[y]))):
            if rows[y][x] != 'r':
                continue
            opaque = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < len(rows[yy]) and rows[yy][xx] != '.':
                        opaque += 1
            if opaque < 2:
                out[y][x] = '.'
                cleared += 1
    return [''.join(r) for r in out], cleared

# Loop: try up to 6 times. Each pass: read fresh, apply fixes, atomically rewrite, bake, score.
for attempt in range(6):
    text, m, rows = snapshot()
    if any(len(r) != 40 for r in rows):
        print('attempt', attempt, 'rows have bad width; retry', flush=True)
        time.sleep(0.5)
        continue
    fixed, cleared = remove_red_specks(rows)
    if fixed == rows and cleared == 0:
        print('attempt', attempt, 'no specks left; done', flush=True)
        break
    new_block = '"bulwark": [\n' + '\n'.join('\t\t"%s",' % r for r in fixed) + '\n\t],'
    new_text = text[:m.start()] + new_block + text[m.end():]
    open(ART, 'w', encoding='utf-8', newline='\n').write(new_text)
    print('attempt', attempt, 'cleared', cleared, 'specks; rewrote', flush=True)

# Quick verify
_, _, rows_after = snapshot()
print('final rows check:', len(rows_after), 'bad:', [i for i, r in enumerate(rows_after) if len(r) != 40])
nix = sum(r.count('r') for r in rows_after)
print('total r cells:', nix)
