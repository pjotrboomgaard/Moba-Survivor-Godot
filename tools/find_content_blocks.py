from PIL import Image
import sys

def analyze(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    # Find all non-background pixels that are NOT the typical dark blue/grey
    # background. The night background is ~ (30-50, 30-50, 40-60).
    # Creep sprites will have distinct colors.
    # Find bounding boxes of "content" regions (non-uniform areas).
    print(f"\n=== {path.split('/')[-1]} ({w}x{h}) ===")
    
    # Scan in 20x20 blocks and find which blocks have high color variance
    block_size = 20
    content_blocks = []
    for by in range(0, h - block_size, block_size):
        for bx in range(0, w - block_size, block_size):
            block = []
            for y in range(by, by + block_size, 3):
                for x in range(bx, bx + block_size, 3):
                    block.append(px[x, y])
            if len(block) < 4:
                continue
            avg_r = sum(c[0] for c in block) / len(block)
            avg_g = sum(c[1] for c in block) / len(block)
            avg_b = sum(c[2] for c in block) / len(block)
            var_r = sum((c[0] - avg_r)**2 for c in block) / len(block)
            var_g = sum((c[1] - avg_g)**2 for c in block) / len(block)
            var_b = sum((c[2] - avg_b)**2 for c in block) / len(block)
            total_var = var_r + var_g + var_b
            # Also check for reddish content
            red_count = sum(1 for c in block if c[0] > 100 and c[0] > c[1] + 30 and c[0] > c[2] + 30)
            if total_var > 500 and red_count > 0:
                content_blocks.append((bx, by, avg_r, avg_g, avg_b, total_var, red_count))
    
    print(f"Reddish content blocks: {len(content_blocks)}")
    for (bx, by, ar, ag, ab, tv, rc) in content_blocks[:20]:
        print(f"  block ({bx},{by}) avg=({ar:.0f},{ag:.0f},{ab:.0f}) var={tv:.0f} red_px={rc}")

for p in sys.argv[1:]:
    analyze(p)
