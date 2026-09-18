"""Split the imported house sprite sheets into individual, transparent PNGs.

Each source image contains pixel-art house/building sprites on a white
background. Grid spacing is irregular, so we detect the actual white gaps
between sprites to determine cell boundaries. When the detected gap count does
not match the expected grid size (e.g. overlapping sprites or stray whitespace
rows), we fall back to an even division. Within each cell the white background
is made transparent and the content is tight-cropped, then padded to a uniform
square canvas.

Source sheets:
  pixelart1.webp  : 1024x1024, 3x3 grid  -> pixelart_house_1..9
  pixelart2.webp  : 1024x1024, 3x3 grid  -> pixelart_building_1..9
  pixelart4.webp  : 1080x607,  3x2 grid  -> pixelart4_1..6
  combination sim png: 1280x720, 4x2 grid -> pixelart_combo_1..8

Usage:
    python tools/split_house_sprites.py
"""
from pathlib import Path
from PIL import Image
import numpy as np

SPRITE_DIR = Path("assets/sprites")
IMPORT_DIR = Path("SpritesImport/houses")
WHITE_THRESHOLD = 220  # pixels at or above this on all channels = background
PAD = 8  # transparent padding around each sprite
MIN_CELL = 5  # ignore gap-derived cells smaller than this (noise)


def find_gaps(mask: np.ndarray) -> list:
    """Find contiguous True runs in a 1-D boolean mask; return (start, end_excl)."""
    gaps = []
    in_gap = False
    start = 0
    for i, val in enumerate(mask):
        if val and not in_gap:
            start = i
            in_gap = True
        elif not val and in_gap:
            gaps.append((start, i))
            in_gap = False
    if in_gap:
        gaps.append((start, len(mask)))
    return gaps


def compute_cells(gaps: list, size: int, expected: int) -> list:
    """Derive exactly `expected` cell boundaries from gap intervals, or None
    if the gap structure does not cleanly produce that many cells."""
    cells = []
    prev_end = 0
    for gap_start, gap_end in gaps:
        cell_start = prev_end
        cell_end = gap_start
        if cell_end - cell_start >= MIN_CELL:
            cells.append((cell_start, cell_end))
            if len(cells) == expected:
                return cells
        prev_end = gap_end
    if len(cells) == expected:
        return cells
    # Still need one more cell after the last gap.
    if len(cells) < expected and size - prev_end >= MIN_CELL:
        cells.append((prev_end, size))
        return cells if len(cells) == expected else None
    return None


def even_cells(count: int, size: int) -> list:
    out = [(int(round(i * size / count)), int(round((i + 1) * size / count))) for i in range(count)]
    out[-1] = (out[-1][0], size)
    return out


def derive_cells(gaps: list, size: int, expected: int) -> tuple:
    """Return (cells, used_gaps) preferring gap-derived boundaries with an even fallback."""
    cells = compute_cells(gaps, size, expected)
    if cells is not None:
        return cells, True
    return even_cells(expected, size), False


def split_sheet(src: Path, prefix: str, out_dir: Path, cols: int, rows: int) -> list:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    arr = np.array(img)
    print(f"    {w}x{h} -> {cols}x{rows} grid")

    row_empty = np.all(arr >= WHITE_THRESHOLD, axis=(1, 2))
    col_empty = np.all(arr >= WHITE_THRESHOLD, axis=(0, 2))
    row_gaps = find_gaps(row_empty)
    col_gaps = find_gaps(col_empty)

    row_cells, row_ok = derive_cells(row_gaps, h, rows)
    col_cells, col_ok = derive_cells(col_gaps, w, cols)
    print(f"    Row cells: {row_cells} (gaps={'yes' if row_ok else 'no'})")
    print(f"    Col cells: {col_cells} (gaps={'yes' if col_ok else 'no'})")

    names = []
    idx = 1
    for r, (y0, y1) in enumerate(row_cells):
        for c, (x0, x1) in enumerate(col_cells):
            cell = img.crop((x0, y0, x1, y1))

            cell_arr = np.array(cell.convert("RGB"))
            white = np.all(cell_arr >= WHITE_THRESHOLD, axis=2)
            rgba = np.array(cell.convert("RGBA"))
            rgba[white, 3] = 0
            out_img = Image.fromarray(rgba, "RGBA")

            alpha = np.array(out_img)[:, :, 3]
            ys, xs = np.where(alpha > 0)
            if xs.size == 0:
                print(f"    WARNING: cell ({c},{r}) empty, skipping")
                continue
            out_img = out_img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))

            cw, ch = out_img.size
            size = max(cw, ch) + PAD * 2
            canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            canvas.paste(out_img, (PAD, PAD), out_img)

            name = f"{prefix}_{idx}.png"
            canvas.save(out_dir / name)
            names.append(name)
            print(f"    Wrote {name} ({canvas.size[0]}x{canvas.size[1]}, content {cw}x{ch})")
            idx += 1
    return names


def main():
    out = Path(SPRITE_DIR)
    out.mkdir(parents=True, exist_ok=True)

    jobs = [
        ("pixelart1.webp", "pixelart_house", 3, 3),
        ("pixelart2.webp", "pixelart_building", 3, 3),
        ("pixelart4.webp", "pixelart4", 3, 2),
        ("ElevenLabs_image_gpt-image-2_combination sim_2026-09-18T20_49_17.png", "pixelart_combo", 4, 2),
    ]

    for fname, prefix, cols, rows in jobs:
        src = IMPORT_DIR / fname
        if not src.exists():
            print(f"WARNING: {src} not found, skipping")
            continue
        print(f"Splitting {src.name}:")
        names = split_sheet(src, prefix, out, cols, rows)
        print(f"  Done: {len(names)} sprites\n")

    print("All house sprites split successfully.")


if __name__ == "__main__":
    main()
