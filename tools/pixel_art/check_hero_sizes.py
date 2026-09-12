import glob, os
from PIL import Image
heroes = ['arclight','bulwark','warden','cinder','pyra','slag','ember','thorn','willow','stump','sage','volt','nebula','astral','rime','tobor']
bad = []
for h in heroes:
    p = f'assets/sprites/{h}.png'
    if not os.path.exists(p):
        print(f'{h:12s} MISSING')
        bad.append(h)
        continue
    im = Image.open(p)
    w,hh = im.size
    flag = '' if w >= 24 and hh >= 24 else '  <-- TOO SMALL'
    if flag:
        bad.append(h)
    print(f'{h:12s} {w}x{hh}{flag}')
print('\nBAD:', bad if bad else 'none')
