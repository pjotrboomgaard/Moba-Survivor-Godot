import hashlib, sys, os

d = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\selftest\results\grass_creepeye_iso"
for f in sorted(os.listdir(d)):
    if f.endswith(".png"):
        p = os.path.join(d, f)
        with open(p, "rb") as fh:
            print(hashlib.md5(fh.read()).hexdigest(), f)
