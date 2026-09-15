from PIL import Image, ImageChops
import sys

a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
diff = ImageChops.difference(a, b)
bbox = diff.getbbox()
print(f"File A: {sys.argv[1]}")
print(f"File B: {sys.argv[2]}")
print(f"Size A: {a.size}, Size B: {b.size}")
print(f"Diff bounding box: {bbox}")
if bbox:
    # Count non-zero pixels in the diff
    import numpy as np
    arr = np.array(diff)
    nonzero = (arr.sum(axis=2) > 0).sum()
    total = a.size[0] * a.size[1]
    print(f"Changed pixels: {nonzero}/{total} ({100.0*nonzero/total:.4f}%)")
else:
    print("No difference found.")
