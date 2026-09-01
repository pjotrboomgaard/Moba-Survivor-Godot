import sys
sys.path.insert(0, r'tools')
from score_hero_sprites import score
print(score(sys.argv[1] if len(sys.argv) > 1 else 'bulwark'))
