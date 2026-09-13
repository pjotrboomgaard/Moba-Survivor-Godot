"""Render each source sheet's 8 raw grid cells (4 cols x 2 rows) into a labeled
contact sheet so we can verify which cell is front/back/side/left before cutting."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "SpritesImport"
OUT = ROOT / "tools" / "selftest" / "results"

SHEETS = {
    "jolt.png":   (1280, 434),
    "tremor.png": (1280, 720),
    "totem.png":  (1280, 720),
}

for name, (W, H) in SHEETS.items():
    im = Image.open(SRC / name).convert("RGB")
    W, H = im.size
    cols = 4
    cw = W // cols
    mid = H // 2
    sheet = Image.new("RGB", (W, H * 2 + 40), (60, 60, 60))
    d = ImageDraw.Draw(sheet)
    for r in range(2):
        for c in range(cols):
            box = (c * cw, r * mid, (c + 1) * cw, (r + 1) * mid)
            cell = im.crop(box)
            xoff = c * cw + 10
            yoff = r * (H + 20) + 20
            sheet.paste(cell, (xoff, yoff))
            d.rectangle([xoff - 2, yoff - 2, xoff + cw + 2, yoff + mid + 2], outline=(255, 255, 0))
            d.text((xoff + 5, yoff + 3), f"col{c} row{r}", fill=(255, 255, 0))
    outp = OUT / f"grid_{name}"
    sheet.save(outp)
    print(f"saved {outp.name} {sheet.size}")
