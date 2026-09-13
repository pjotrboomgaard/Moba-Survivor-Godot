import base64, io, time, urllib.parse, urllib.request
from PIL import Image

ref_path = "assets/sprites/brute.png"
with open(ref_path, "rb") as f:
    b64 = base64.b64encode(f.read()).decode()
data_uri = "data:image/png;base64," + b64

prompt = ("a wolf creature in the same chunky top-down pixel art game sprite "
          "style, thick dark outline, flat saturated colors, plain white "
          "background, no ground, no shadow, single creature")
encoded = urllib.parse.quote(prompt)

variants = [
    # (model, image-param-key, extra)
    ("kontext", "image", "https://image.pollinations.ai/prompt/{p}"),
    ("kontext", "img",   "https://image.pollinations.ai/prompt/{p}"),
    ("flux",    "image", "https://image.pollinations.ai/prompt/{p}"),
]
img_bytes = None
used = None
for model, key, tmpl in variants:
    base = tmpl.format(p=encoded)
    params = {
        "width": 512, "height": 512, "model": model,
        key: data_uri, "seed": 7, "nologo": "true",
    }
    url = f"{base}?{urllib.parse.urlencode(params)}"
    print(f"Trying model={model} param={key} ...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PixelArtPipeline/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            img_bytes = resp.read()
        print("  OK bytes", len(img_bytes))
        used = (model, key)
        break
    except Exception as e:
        print("  FAIL:", repr(e))
    time.sleep(3)

if img_bytes:
    out = "tools/pixel_art/test_output/wolf_i2i_bruteref.png"
    with open(out, "wb") as f:
        f.write(img_bytes)
    img = Image.open(io.BytesIO(img_bytes))
    print("Saved", out, "size:", img.size, "mode:", img.mode, "used:", used)
else:
    print("No image retrieved — all variants failed")
