import re
src = open('scripts/upgrade_catalog.gd').read()
defs = re.findall(r'^\s+"([a-z_]+)":\s*\{"name"', src, re.M)
rows = re.findall(r'^\s+"([a-z_]+)":\s*\[', src, re.M)
missing = [d for d in defs if d not in rows]
print('DEFS:', len(defs))
print('ROWS:', len(rows))
print('MISSING ROWS:', missing)
