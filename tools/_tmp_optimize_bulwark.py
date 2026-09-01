"""Per-cell local optimizer: for each inked sprite cell, find the palette char
that minimises colour distance to the *shrunken* reference at the same cell,
then report the total score delta if all such swaps are applied at once."""
from __future__ import annotations

import re
from PIL import Image
import numpy as np

PAL = {
    'w': (0xf4, 0xf6, 0xf8), 'u': (0xe2, 0xe6, 0xea), 's': (0xb8, 0xbe, 0xc6),
    'm': (0x6e, 0x76, 0x7f), 'd': (0x23, 0x28, 0x30), 'n': (0xff, 0x78, 0x28),
    'r': (0xe0, 0x5a, 0x1c), 't': (0xff, 0x4a, 0x2e), 'l': (0xff, 0xb2, 0x94),
    'i': (0xff, 0xc1, 0x9a), 'y': (0xf2, 0xec, 0x3c), 'a': (0xfc, 0xff, 0xd0),
    'k': (0x14, 0x17, 0x1c), 'g': (0xa8, 0xff, 0x3c), 'G': (0x36, 0xc4, 0x32),
    'c': (0x79, 0x5a, 0x30), 'b': (0x3a, 0x22, 0x10), 'h': (0xff, 0xff, 0xff),
    'o': (0x10, 0x14, 0x1a), 'e': (0xff, 0x9a, 0x28), 'p': (0x4f, 0x8f, 0xe0),
    'q': (0x6d, 0x76, 0x80), 'f': (0xf2, 0xe2, 0xb0),
}

text = open(r'tools/sprite_art.gd', encoding='utf-8').read()
m = re.search(r'"bulwark": \[(.*?)\n\t\],', text, re.S)
rows = [list(r) for r in re.findall(r'"([^"]*)"', m.group(1))]
print('rows:', len(rows), 'lens:', sorted(set(len(r) for r in rows)))

ref = Image.open(r'ref image/_debug/turnarounds/bulwark/front_0.png').convert('RGB')
rp = np.array(ref.resize((40, 40), Image.Resampling.LANCZOS))
r_mask = rp.min(axis=2) < 235

suggestions = {}
for y in range(40):
    for x in range(40):
        ch = rows[y][x]
        if ch == '.' or not r_mask[y][x]:
            continue
        rr, rg, rb = rp[y][x].astype(int)
        sr, sg, sb = PAL.get(ch, (0, 0, 0))
        d = (((sr - rr) ** 2 + (sg - rg) ** 2 + (sb - rb) ** 2) / (3 * 255 * 255)) ** 0.5
        cur_gain = max(0.0, 1.0 - d)
        best, best_gain = ch, cur_gain
        for alt, (ar, ag, ab) in PAL.items():
            d = (((ar - rr) ** 2 + (ag - rg) ** 2 + (ab - rb) ** 2) / (3 * 255 * 255)) ** 0.5
            g = max(0.0, 1.0 - d)
            if g > best_gain + 0.001:
                best, best_gain = alt, g
        if best != ch:
            suggestions[(y, x)] = (ch, best, cur_gain, best_gain)

den = num = num2 = 0.0
for y in range(40):
    for x in range(40):
        s_ink = rows[y][x] != '.'
        r_ink = bool(r_mask[y][x])
        if not (s_ink or r_ink):
            continue
        den += 1
        if s_ink and r_ink:
            rr, rg, rb = rp[y][x].astype(int)
            sr, sg, sb = PAL[rows[y][x]]
            d = (((sr - rr) ** 2 + (sg - rg) ** 2 + (sb - rb) ** 2) / (3 * 255 * 255)) ** 0.5
            num += max(0.0, 1.0 - d)
            tgt = suggestions.get((y, x), (rows[y][x], rows[y][x], 0, 0))[1]
            ar, ag, ab = PAL[tgt]
            d = (((ar - rr) ** 2 + (ag - rg) ** 2 + (ab - rb) ** 2) / (3 * 255 * 255)) ** 0.5
            num2 += max(0.0, 1.0 - d)
print('baseline colour = %.4f' % (num / den))
print('projected colour if all swaps = %.4f' % (num2 / den))
ranked = sorted(suggestions.items(), key=lambda kv: kv[1][3] - kv[1][2], reverse=True)
for (y, x), (cur, alt, cg, bg) in ranked[:20]:
    print('(%2d,%2d): %s -> %s   gain %.3f -> %.3f' % (y, x, cur, alt, cg, bg))
