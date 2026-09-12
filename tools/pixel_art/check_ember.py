import re
path = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd"
text = open(path, encoding="utf-8").read()
# Find the "ember": [ ... ] block in HERO_ROWS
# Locate first occurrence of '"ember": ['
idx = text.find('"ember": [')
if idx < 0:
    print("not found"); raise SystemExit
# find the matching closing '],\n'
start = text.find('[', idx)
# count brackets
depth = 0
j = start
for k in range(start, len(text)):
    if text[k] == '[':
        depth += 1
    elif text[k] == ']':
        depth -= 1
        if depth == 0:
            end = k
            break
block = text[start:end+1]
rows = re.findall(r'"([^"]+)"', block)
print("num rows:", len(rows))
for i, r in enumerate(rows):
    print(i, len(r), repr(r))
