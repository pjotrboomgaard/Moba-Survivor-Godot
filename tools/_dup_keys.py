import io, re, collections
c = io.open("tools/sprite_art.gd", encoding="utf-8").read()
m = re.search(r"const HERO_ROWS := \{(.*?)\n\}\n", c, re.S)
block = m.group(1)
keys = re.findall(r'^\s*"([A-Za-z0-9_]+)":', block, re.M)
counts = collections.Counter(keys)
dups = {k: n for k, n in counts.items() if n > 1}
print("total keys:", len(keys))
print("duplicates:", dups)
# also verify the dict braces balance inside the whole file region
print("array-open lines:", len(re.findall(r'": \[$', block, re.M)))
