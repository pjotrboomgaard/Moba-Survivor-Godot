import hashlib, glob, os

d = r"C:\Users\pjotr\Documents\Development\Coop-MOBA-Survivor-Godot-Phase-1\tools\selftest\results\grass_creepeye_iso"
files = sorted(glob.glob(os.path.join(d, "*.png")))
for f in files:
    with open(f, "rb") as fh:
        print(hashlib.md5(fh.read()).hexdigest(), os.path.basename(f))
