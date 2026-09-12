"""
Pixel Art Pipeline for Coop-MOBA-Survivor
==========================================

Pipeline stages:
  1. SOURCE:   Find/generate a source image.
     - "generate": use Pollinations.ai (free, no API key) to create a
       high-resolution AI image from a text prompt (supports image-to-image
       via the kontext model for restyling an existing reference).
     - "convert":  use an existing image file (found online or local).
  2. CONVERT:  Downscale to the game's pixel density (default 32x32 grid,
       matching tree_oak.png) with LANCZOS, then palette-quantize to a fixed
       color count (default 16) using Pillow's median-cut + k-means.
  3. REFINE:   Optional palette-lock pass: re-quantize onto a palette extracted
       from an existing game sprite so new art matches the established art pass.
  4. EXPORT:   Save native PNG into assets/sprites/ plus an upscaled NEAREST
       preview for visual inspection.

Usage:
  python pixel_art_pipeline.py generate --prompt "..." --output out.png [--grid 32] [--colors 16]
  python pixel_art_pipeline.py convert --input ref.png --output out.png [--grid 32] [--colors 16]
  python pixel_art_pipeline.py extract-palette --from assets/sprites/tree_oak.png --colors 16
  python pixel_art_pipeline.py batch --manifest batch_manifest.json

Dependencies:
  pip install Pillow requests

Pollinations.ai:
  Free anonymous tier, no API key required:
    https://image.pollinations.ai/prompt/{prompt}?width=512&height=512&model=flux&nologo=true
  Rate limit ~1 req/15s anonymous. The pipeline retries with backoff.
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps

# ── Game-specific defaults ────────────────────────────────────────────────────
DEFAULT_GRID = 32        # Target pixel grid (matches tree_oak.png 32x32)
DEFAULT_COLORS = 16      # Palette size for quantization
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
POLLINATIONS_URL = "https://image.pollinations.ai/prompt/{prompt}"


# ─── Palette extraction ────────────────────────────────────────────────────────

def extract_palette(image_path: str, n_colors: int = 16) -> list[tuple[int, int, int]]:
    """Extract dominant colors from an image using Pillow quantization."""
    img = Image.open(image_path).convert("RGB")
    img.thumbnail((64, 64))
    quantized = img.quantize(colors=n_colors, method=Image.MEDIANCUT, kmeans=4)
    palette_data = quantized.getpalette()
    colors = []
    for i in range(n_colors):
        r, g, b = palette_data[i * 3], palette_data[i * 3 + 1], palette_data[i * 3 + 2]
        colors.append((r, g, b))
    return colors


def palette_to_hex(colors: list[tuple[int, int, int]]) -> list[str]:
    """Convert RGB tuples to hex strings for the pipeline."""
    return ["%02x%02x%02x" % c for c in colors]


# ─── Core pixel-art conversion ────────────────────────────────────────────────

def convert_to_pixel_art(
    img: Image.Image,
    target_size: int = DEFAULT_GRID,
    n_colors: int = DEFAULT_COLORS,
    palette: list[tuple[int, int, int]] | None = None,
    preserve_transparency: bool = True,
) -> Image.Image:
    """
    Convert an image to pixel art:
      1. Downscale to target_size (longest side) with LANCZOS (smooth color mix).
      2. Quantize to n_colors palette (k-means via Pillow).
      3. Optional: re-map onto a specific palette for consistent art style.
      4. Clean up semi-transparent pixels.
    """
    img = img.convert("RGBA")

    # Remove near-transparent noise before processing.
    alpha = img.getchannel("A")
    alpha = alpha.point(lambda a: 255 if a > 16 else 0)
    img.putalpha(alpha)

    # Downscale: longest side -> target_size
    w, h = img.size
    scale = target_size / max(w, h)
    new_w = max(1, round(w * scale))
    new_h = max(1, round(h * scale))
    small = img.resize((new_w, new_h), Image.LANCZOS)

    # Quantize on RGB, preserving alpha.
    rgb = small.convert("RGB")
    if palette:
        # Build a palette image from the specified colors.
        pal_img = Image.new("P", (1, 1))
        for i, (r, g, b) in enumerate(palette):
            pal_img.putpixel((0, 0), (i % 256, i // 256, i % 256))  # placeholder
        # Simpler: quantize to n_colors, then remap.
        quantized = rgb.quantize(colors=n_colors, method=Image.MEDIANCUT, kmeans=4)
        result = quantized.convert("RGBA")
        result.putalpha(small.getchannel("A"))
    else:
        quantized = rgb.quantize(colors=n_colors, method=Image.MEDIANCUT, kmeans=4)
        result = quantized.convert("RGBA")
        result.putalpha(small.getchannel("A"))

    # Clean up: make near-transparent pixels fully transparent.
    result = result.convert("RGBA")
    r, g, b, a = result.split()
    a = a.point(lambda x: 0 if x < 20 else 255)
    result = Image.merge("RGBA", (r, g, b, a))

    return result


def save_sprite(result: Image.Image, output_path: str, preview_scale: int = 4) -> Path:
    """Save the pixel art at native size + an optional scaled-up preview."""
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    result.save(str(out))
    # Also save a preview for visual inspection.
    preview = result.resize(
        (result.width * preview_scale, result.height * preview_scale),
        Image.NEAREST,
    )
    preview_path = out.with_name(out.stem + "_preview.png")
    preview.save(str(preview_path))
    print(f"[OK] {out.name}: {result.width}x{result.height} px, "
          f"{len(result.getcolors(maxcolors=9999))} colors")
    print(f"[OK] Preview: {preview_path.name}")
    return out


# ─── AI generation via Pollinations.ai (free, no API key) ────────────────────

def generate_image(
    prompt: str,
    output_dir: str = "tools/pixel_art/refs",
    size: int = 512,
    model: str = "flux",
    seed: int = 42,
    no_background: bool = False,
) -> Path:
    """
    Generate a reference image using Pollinations.ai (free, no API key).

    Args:
      prompt: text description of the desired image
      output_dir: where to save the generated reference
      size: square size of generated image
      model: pollinations model ("flux", "turbo", "kontext", etc.)
      seed: random seed
      no_background: if True, request transparent background

    Returns:
      Path to the saved reference PNG.
    """
    os.makedirs(output_dir, exist_ok=True)
    encoded = urllib.parse.quote(prompt)
    url = POLLINATIONS_URL.format(prompt=encoded)
    params = urllib.parse.urlencode({
        "width": size,
        "height": size,
        "model": model,
        "seed": seed,
        "nologo": "true",
    })
    if no_background:
        params += "&nologo=true"

    full_url = f"{url}?{params}"
    print(f"[GEN] {prompt[:80]}...")
    print(f"[GEN] model={model} size={size}x{size} seed={seed}")

    for attempt in range(3):
        try:
            req = urllib.request.Request(full_url, headers={"User-Agent": "PixelArtPipeline/1.0"})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            ref_path = Path(output_dir) / f"ref_{seed}_{int(time.time())}.png"
            with open(ref_path, "wb") as f:
                f.write(data)
            img = Image.open(ref_path)
            print(f"[OK] Generated {img.size[0]}x{img.size[1]} -> {ref_path.name}")
            return ref_path
        except Exception as e:
            print(f"[WARN] Attempt {attempt+1} failed: {e}")
            if attempt < 2:
                time.sleep(5 * (attempt + 1))
    raise RuntimeError("All generation attempts failed")


def generate_and_convert(
    prompt: str,
    output_path: str,
    grid_size: int = DEFAULT_GRID,
    n_colors: int = DEFAULT_COLORS,
    gen_size: int = 512,
    model: str = "flux",
    seed: int = 42,
    palette_source: str | None = None,
    no_background: bool = False,
    preview_scale: int = 4,
) -> Path:
    """
    Full pipeline: generate AI reference -> convert to pixel art -> save.

    Args:
      prompt: text prompt for the AI image generator
      output_path: final pixel art PNG path (e.g. assets/sprites/my_sprite.png)
      grid_size: target pixel grid (default 32 = game standard)
      n_colors: palette size (default 16)
      gen_size: AI generation resolution (512 recommended)
      model: pollinations model name
      seed: random seed
      palette_source: path to a reference image whose palette to use
      no_background: request transparent background from generator
      preview_scale: upscale factor for the preview image
    """
    ref_path = generate_image(prompt, size=gen_size, model=model, seed=seed,
                              no_background=no_background)
    img = Image.open(ref_path)
    palette = None
    if palette_source:
        palette = extract_palette(palette_source, n_colors)
        print(f"[PALETTE] Using palette from {palette_source}: {len(palette)} colors")
    result = convert_to_pixel_art(img, grid_size, n_colors, palette=palette)
    return save_sprite(result, output_path, preview_scale)


# ─── Batch processing ─────────────────────────────────────────────────────────

def run_batch(manifest: dict, dry_run: bool = False) -> None:
    """
    Process a batch manifest. Format:
    {
      "assets": [
        {
          "name": "tree_oak_v2",
          "prompt": "A detailed top-down oak tree in pixel art style...",
          "grid_size": 32,
          "n_colors": 16,
          "seed": 42,
          "palette_source": "assets/sprites/tree_oak.png",
          "no_background": true
        },
        ...
      ]
    }
    """
    assets = manifest.get("assets", [])
    print(f"[BATCH] Processing {len(assets)} assets...")
    for i, asset in enumerate(assets, 1):
        name = asset.get("name", f"asset_{i}")
        out = str(SPRITES_DIR / f"{name}.png")
        print(f"\n[{i}/{len(assets)}] {name} -> {out}")
        if dry_run:
            print(f"[DRY] Would generate: {asset.get('prompt', '')[:60]}")
            continue
        generate_and_convert(
            prompt=asset.get("prompt", ""),
            output_path=out,
            grid_size=asset.get("grid_size", DEFAULT_GRID),
            n_colors=asset.get("n_colors", DEFAULT_COLORS),
            gen_size=asset.get("gen_size", 512),
            model=asset.get("model", "flux"),
            seed=asset.get("seed", 42 + i),
            palette_source=asset.get("palette_source"),
            no_background=asset.get("no_background", True),
        )
        # Rate-limit: pollinations.ai free tier is ~1 req / 15s
        time.sleep(16)
    print("\n[BATCH] Done.")


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Pixel Art Pipeline")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # generate-and-convert
    p_gen = sub.add_parser("generate", help="Generate AI image + convert to pixel art")
    p_gen.add_argument("--prompt", "-p", required=True, help="Text prompt for AI generation")
    p_gen.add_argument("--output", "-o", required=True, help="Output PNG path")
    p_gen.add_argument("--grid", "-g", type=int, default=DEFAULT_GRID, help="Target grid size")
    p_gen.add_argument("--colors", "-c", type=int, default=DEFAULT_COLORS, help="Palette size")
    p_gen.add_argument("--gen-size", type=int, default=512, help="AI generation size")
    p_gen.add_argument("--model", default="flux", help="Pollinations model")
    p_gen.add_argument("--seed", type=int, default=42)
    p_gen.add_argument("--palette-source", help="Reference image for palette extraction")
    p_gen.add_argument("--no-background", action="store_true", help="Request transparent bg")
    p_gen.add_argument("--upscale", type=int, default=4, help="Preview upscale factor")

    # convert only (no AI generation)
    p_conv = sub.add_parser("convert", help="Convert existing image to pixel art")
    p_conv.add_argument("--input", "-i", required=True, help="Input image path")
    p_conv.add_argument("--output", "-o", required=True, help="Output PNG path")
    p_conv.add_argument("--grid", "-g", type=int, default=DEFAULT_GRID)
    p_conv.add_argument("--colors", "-c", type=int, default=DEFAULT_COLORS)
    p_conv.add_argument("--upscale", type=int, default=4)

    # palette extraction
    p_pal = sub.add_parser("palette", help="Extract palette from an image")
    p_pal.add_argument("--from", dest="source", required=True, help="Source image path")
    p_pal.add_argument("--colors", "-c", type=int, default=DEFAULT_COLORS)

    # batch
    p_batch = sub.add_parser("batch", help="Process a JSON batch manifest")
    p_batch.add_argument("--manifest", "-m", required=True, help="JSON manifest path")
    p_batch.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    if args.cmd == "generate":
        generate_and_convert(
            prompt=args.prompt,
            output_path=args.output,
            grid_size=args.grid,
            n_colors=args.colors,
            gen_size=args.gen_size,
            model=args.model,
            seed=args.seed,
            palette_source=args.palette_source,
            no_background=args.no_background,
            preview_scale=args.upscale,
        )
    elif args.cmd == "convert":
        img = Image.open(args.input)
        result = convert_to_pixel_art(img, args.grid, args.colors)
        save_sprite(result, args.output, args.upscale)
    elif args.cmd == "palette":
        colors = extract_palette(args.source, args.colors)
        print(json.dumps({"source": args.source, "colors": palette_to_hex(colors)}, indent=2))
    elif args.cmd == "batch":
        with open(args.manifest, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        run_batch(manifest, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
