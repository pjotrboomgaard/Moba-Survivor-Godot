rows = [
    "................",
    ".......oo.......",
    "......offo......",
    ".....offffo.....",
    "....offffffo....",
    "....offwoffo....",
    "...offffffffo...",
    "...offllffffo...",
    "...offffffffo...",
    "....offffffo....",
    "....offllffo....",
    "....offffffo....",
    ".....offffo.....",
    "......offo......",
    ".......oo.......",
    "................",
]
for i, r in enumerate(rows):
    assert len(r) == 16, f'row {i} len {len(r)}: {r}'
used = set(''.join(rows))
print("All 16 rows are 16 chars OK")
print("chars used:", sorted(used))
