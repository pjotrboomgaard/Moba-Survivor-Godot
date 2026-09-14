"""Vision-classify Joule frames for lightning-bolt presence (ground-truth check)."""
from __future__ import annotations

import base64
import importlib.util
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("vc", TOOLS / "vision_check.py")
vc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vc)
key = vc.load_api_key()
import anthropic

client = anthropic.Anthropic(api_key=key)
FRAMES = sorted((TOOLS.parent / "assets/ui/joule_menu_video/frames").glob("frame_*.png"))
imgs = []
for f in FRAMES:
    imgs.append({
        "type": "image",
        "source": {"type": "base64", "media_type": "image/png", "data": base64.b64encode(f.read_bytes()).decode()},
    })
prompt = (
    "These are 29 sequential frames of a game menu background, in order frame 1 to frame 29. "
    "Each frame may or may not show a lightning bolt / electric arc in the sky "
    "(a bright jagged bolt shape in the upper area, NOT just ambient sky glow or the character). "
    "For EACH frame 1-29 answer only 'bolt' or 'nobolt'. Output exactly 29 lines: e.g. 1:bolt, 2:nobolt ..."
)
msg = client.messages.create(
    model="claude-sonnet-4-5-20250929", max_tokens=800,
    messages=[{"role": "user", "content": [{"type": "text", "text": prompt}] + imgs}],
)
print(msg.content[0].text)
