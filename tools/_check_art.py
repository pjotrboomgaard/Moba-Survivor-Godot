import io
c = io.open("tools/sprite_art.gd", encoding="utf-8").read()
checks = {
  "HERO_ROWS cinder": '"cinder": [',
  "HERO_ROWS slag": '"slag": [',
  "HERO_ROWS sage_back": '"sage_back": [',
  "HERO_ROWS cinder_left": '"cinder_left": [',
  "ICON cinder_flame_dash": '"cinder_flame_dash": SHAPE',
  "ICON slag_volcano": '"slag_volcano": SHAPE',
  "ICON ember_phoenix_dash": '"ember_phoenix_dash": SHAPE',
  "TONE key cinder": '"cinder"',
  "TONE value name": "HERO_ABILITY_TONES",
}
for label, needle in checks.items():
    print(("FOUND " if needle in c else "MISSING "), label)
