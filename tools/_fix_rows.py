with open("tools/sprite_art.gd", encoding="utf-8") as f:
    lines = f.read().split("\n")

def fix_block(key, target_rows=40):
    target = '"%s": [' % key
    start = None
    for i, l in enumerate(lines):
        if l.strip() == target:
            start = i
            break
    if start is None:
        print(key, "not found")
        return
    end = None
    for j in range(start + 1, len(lines)):
        if lines[j].strip() == "],":
            end = j
            break
    content = lines[start + 1:end]
    n = len(content)
    if n == target_rows:
        print(key, "ok", n)
        return
    if n > target_rows:
        to_remove = n - target_rows
        removed = 0
        new_content = []
        for k, row in enumerate(content):
            inner = row.strip().strip('"').strip(',')
            is_empty = set(inner) <= set('.')
            if removed < to_remove and is_empty and k >= n - to_remove - 3:
                removed += 1
                continue
            new_content.append(row)
        lines[start + 1:end] = new_content
        print(key, "now", len(new_content))
    elif n < target_rows:
        pad_row = '\t\t"",' + "." * 40 + '",'
        # correct pad row: tab tab quote 40-dots quote comma
        pad_row = "\t\t\"" + "." * 40 + "\","
        to_add = target_rows - n
        for _ in range(to_add):
            content.append(pad_row)
        lines[start + 1:end] = content
        print(key, "now", len(content))

for k in ["ember", "rime"]:
    fix_block(k)

with open("tools/sprite_art.gd", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines))
print("done")
