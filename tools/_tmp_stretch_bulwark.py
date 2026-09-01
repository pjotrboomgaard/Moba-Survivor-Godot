import re

path = r'tools/sprite_art.gd'
text = open(path, encoding='utf-8').read()
m = re.search(r'"bulwark": \[(.*?)\n\t\],', text, re.S)
rows = re.findall(r'"([^"]*)"', m.group(1))
assert len(rows) == 40
# find ink rows
ink = [i for i, r in enumerate(rows) if r.strip() and set(r) != {'.'}]
top, bottom = min(ink), max(ink)
content = rows[top:bottom + 1]
print('content rows', top, 'to', bottom, '=', len(content))
# nearest-neighbour stretch content to 40 rows
stretched = [content[min(i * len(content) // 40, len(content) - 1)] for i in range(40)]
new_block = '"bulwark": [\n' + '\n'.join('\t\t"%s",' % r for r in stretched) + '\n\t],'
new_text = text[:m.start()] + new_block + text[m.end():]
open(path, 'w', encoding='utf-8', newline='\n').write(new_text)
print('stretched to 40 rows')
