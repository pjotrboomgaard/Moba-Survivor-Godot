import re
import sys

text = open(r'tools/sprite_art.gd', encoding='utf-8').read()
m = re.search(r'"bulwark": \[(.*?)\n\t\],', text, re.S)
rows = re.findall(r'"([^"]*)"', m.group(1))
mode = sys.argv[1] if len(sys.argv) > 1 else 'check'
if mode == 'check':
    print('row count:', len(rows))
    bad = [(i, len(r)) for i, r in enumerate(rows) if len(r) != 40]
    print('bad rows:', bad)
    for i, r in enumerate(rows):
        print('%02d  %s' % (i, r))
elif mode == 'rows':
    y0, y1 = int(sys.argv[2]), int(sys.argv[3])
    x0, x1 = int(sys.argv[4]), int(sys.argv[5])
    print('    ' + ''.join(str((i // 10) % 10) for i in range(x0, x1)))
    print('    ' + ''.join(str(i % 10) for i in range(x0, x1)))
    for y in range(y0, y1):
        print('%02d  %s' % (y, rows[y][x0:x1]))
