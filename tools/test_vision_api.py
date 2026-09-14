"""Test Anthropic vision API connectivity with a small image."""
import base64
import json
import os
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent


def load_key():
    for p in (PROJECT / ".env", Path.home() / ".env"):
        if p.exists():
            for line in p.read_text().splitlines():
                line = line.strip()
                if line.startswith("ANTHROPIC_API_KEY="):
                    return line.split("=", 1)[1].strip()
    return os.environ.get("ANTHROPIC_API_KEY")


def main():
    import anthropic

    key = load_key()
    if not key:
        print("FAIL: no API key found")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=key)

    png = PROJECT / "tools/selftest/results/joule_menu_ingame_arclight/ingame_after_1.png"
    if not png.exists():
        # fall back to any small png
        candidates = sorted(PROJECT.glob("assets/sprites/*.png"))
        if not candidates:
            print("FAIL: no image found")
            sys.exit(1)
        png = candidates[0]

    data = base64.b64encode(png.read_bytes()).decode()
    ext = png.suffix.lstrip(".").lower()
    media_type = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}.get(ext, "image/png")

    print(f"Image: {png.name}")
    msg = client.messages.create(
        model="claude-sonnet-4-5-20250929",
        max_tokens=300,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data}},
                    {
                        "type": "text",
                        "text": "In one sentence, describe what this image shows. Then state which region has the most visual content (top-left / top-right / bottom-left / bottom-right / center).",
                    },
                ],
            }
        ],
    )
    print("MODEL:", msg.model)
    print("TEXT:", msg.content[0].text)
    print("USAGE:", json.dumps(msg.usage.__dict__))
    print("OK")


if __name__ == "__main__":
    main()
