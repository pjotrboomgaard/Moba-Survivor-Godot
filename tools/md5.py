import hashlib, sys

for p in sys.argv[1:]:
    with open(p, "rb") as f:
        h = hashlib.md5(f.read()).hexdigest()
    print(f"{h}  {p}")
