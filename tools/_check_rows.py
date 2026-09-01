import re
text = open('tools/tobor_world_art.gd', encoding='utf-8').read()
for name in ['_GRASS_BELL', '_GRASS_POOL', '_GRASS_STONE',
             '_VOLCANO_ARCH', '_VOLCANO_SHRINE', '_VOLCANO_WELL',
             '_ICE_GLADE', '_ICE_HOLLOW',
             '_FACTORY_PYLON', '_FACTORY_VAT', '_FACTORY_BAY',
             '_DOCKS_LIGHTHOUSE', '_DOCKS_BELL', '_DOCKS_POOL']:
    m = re.search(r'const %s := \[(.*?)\]' % name, text, re.S)
    rows = re.findall(r'"([^"]*)"', m.group(1))
    bad = [(i, len(r)) for i, r in enumerate(rows) if len(r) != 16]
    status = "OK " if not bad else "BAD"
    print(f"{status} {name}: rows={len(rows)}")
    for i, l in bad:
        print(f"   row {i:2d} len={l:2d} |{rows[i]}|")
