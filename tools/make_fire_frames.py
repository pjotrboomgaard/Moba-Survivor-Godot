"""Generate clean pixel-art flame tiles (12x16) for burning trees.

3 frames of flicker. Each tile is a PURE FLAME — no brown/wood base.
Colors: yellow core -> light orange -> orange -> red -> dark-red tips.
Slightly irregular silhouette that varies between frames for flicker.
"""
from PIL import Image
import os

OUT = "assets/sprites"
W, H = 12, 16

Y   = (255, 244, 130, 255)  # hot core
LO  = (255, 190,  60, 255)  # light orange
O   = (250, 140,  30, 255)  # orange
R   = (225,  70,  20, 255)  # red
DR  = (160,  35,  12, 255)  # dark red tips
T   = (0, 0, 0, 0)          # transparent

def make_flame(rows):
    img = Image.new("RGBA", (W, H), T)
    px = img.load()
    cmap = {"y": Y, "o": LO, "O": O, "r": R, "R": DR}
    for ry in range(H):
        for rx in range(W):
            if ry < len(rows) and rx < len(rows[ry]):
                ch = rows[ry][rx]
            else:
                ch = "."
            if ch != ".":
                px[rx, ry] = cmap[ch]
    return img

# Each row must be exactly 12 chars. '.' = transparent.
F0 = [
    "....R.......",
    "...rR.......",
    "...rOr......",
    "..rOoy......",
    "..rOoyO.....",
    ".rOyoyO.....",
    ".rOyoyOr....",
    ".rOyoyOOr...",
    ".rOoyOyOr...",
    "rOyOoyOyOr..",
    "rOyOoyOyOr..",
    "OyOoyOyOOr..",
    "oyOyOyOyOr..",
    "oyoyOyoyOr..",
    "OoyOyOyOr...",
    ".oyOyOyO....",
]

F1 = [
    ".....R......",
    "....rR......",
    "....rOr.....",
    "...rOyOr....",
    "...rOyOoy...",
    "..rOyOoyO...",
    "..rOyOyOyO..",
    "..rOyOyOyOr.",
    ".rOyOyOyOyOr",
    ".rOyOyOyOyOr",
    "rOyOyOyOyOyO",
    "OyOyOyOyOyOr",
    "oyOyOyOyOyOr",
    "oyOyOyOyOOr.",
    "OyOyOyOyOr..",
    ".OyOyOyOr...",
]

F2 = [
    ".........R..",
    "........rR..",
    "........rOr.",
    ".......rOOr.",
    "......rOoy..",
    "......rOyO..",
    ".....rOyOyO.",
    ".....rOyOyOr",
    "....rOyOyOyO",
    "....rOyOyOyO",
    "...rOyOyOyOy",
    "...OyOyOyOyO",
    "..oyOyOyOyOr",
    "..oyOyOyOOr.",
    "...OyOyOyO..",
    "....oyOyO...",
]

def main():
    for i, rows in enumerate((F0, F1, F2)):
        img = make_flame(rows)
        path = os.path.join(OUT, f"fire_frame_{i}.png")
        img.save(path)
        print(f"Wrote {path} ({W}x{H})")

if __name__ == "__main__":
    main()
