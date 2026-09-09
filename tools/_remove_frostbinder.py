import pathlib
p = pathlib.Path('scripts/player_class.gd')
lines = p.read_text().split('\n')
# Line 2318 (0-indexed: 2317) is the playable_ids return
lines[2317] = '\treturn ["tobor", "arclight", "bulwark", "warden", "cinder", "pyra", "slug", "ember", "thorn", "willow", "stump", "sage", "volt", "nebula", "astral", "rime"]'
p.write_text('\n'.join(lines))
print("Removed frostbinder from playable_ids")
