import re
text = open('tools/sprite_art.gd', encoding='utf-8').read()
m = re.search(r'^const HERO_ROWS := \{', text, re.M)
i = m.end(); depth = 1; start = i
while depth > 0 and i < len(text):
    if text[i] == '{': depth += 1
    elif text[i] == '}': depth -= 1
    i += 1
block = text[start:i-1]
print('block len', len(block))
cands = re.findall(r'^\s*"([a-z_0-9]+)":\s*\[', block, re.M)
print('entry count', len(cands))
print('count per prefix:', {})
from collections import Counter
pref = Counter(c.split('_')[0] for c in cands)
print(pref)
print('has cinder:', 'cinder' in cands, 'rime back:', 'rime_back' in cands)
