import re

live_path = r'tools/sprite_art.gd'
bak_path = r'tools/sprite_art.gd.bak'

live = open(live_path, encoding='utf-8').read()
bak = open(bak_path, encoding='utf-8').read()

pat = r'"bulwark": \[(.*?)\n\t\],'
m_bak = re.search(pat, bak, re.S)
m_live = re.search(pat, live, re.S)
assert m_bak and m_live, 'bulwark block missing'

new_block = '"bulwark": [' + m_bak.group(1) + '\n\t],'
out = live[:m_live.start()] + new_block + live[m_live.end():]
open(live_path, 'w', encoding='utf-8', newline='\n').write(out)

rows = re.findall(r'"([^"]*)"', m_bak.group(1))
print('restored rows:', len(rows), 'lens:', sorted(set(len(r) for r in rows)))
