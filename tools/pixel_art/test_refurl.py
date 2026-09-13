import io, json, time, urllib.parse, urllib.request

# Test: does pollinations kontext accept a GitHub raw URL as image reference?
prompt = "restyle this creature into a top-down video game sprite, chunky pixel art, same style"
for raw_url in [
    "https://raw.githubusercontent.com/pjotrboomgaard/Moba-Survivor-Godot/main/assets/sprites/brute.png",
    "https://github.com/pjotrboomgaard/Moba-Survivor-Godot/raw/main/assets/sprites/brute.png",
]:
    encoded = urllib.parse.quote(prompt)
    base = f"https://image.pollinations.ai/prompt/{encoded}"
    params = {
        "width": 512, "height": 512, "model": "kontext",
        "image": raw_url, "nologo": "true",
    }
    url = f"{base}?{urllib.parse.urlencode(params)}"
    print("TRYING:", raw_url)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PixelArtPipeline/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        print("STATUS", resp.status, "bytes", len(data))
        img_bytes = data
        break
    except Exception as e:
        print("FAIL:", repr(e))
        time.sleep(3)

if img_bytes:
    with open("tools/pixel_art/test_output/ref_url_test.png", "wb") as f:
        f.write(img_bytes)
    from PIL import Image
    img = Image.open(io.BytesIO(img_bytes))
    print("Saved ref_url_test.png size:", img.size, "mode:", img.mode)
