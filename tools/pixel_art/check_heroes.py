import re
path = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\sprite_art.gd"
text = open(path, encoding="utf-8").read()
m = re.search(r"const HERO_ROWS := \{(.*?)\n\}", text, re.DOTALL)
if m:
    names = re.findall(r'"(\w+)":\s*\[', m.group(1))
    print('HERO_ROWS sprites:', names)
else:
    print('HERO_ROWS not found')
