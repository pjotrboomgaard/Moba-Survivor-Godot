from PIL import Image
import numpy as np
from scipy import ndimage

heroes = ['arclight','bulwark','warden']
suffixes = ['','_back','_left','_right']
print('Interior hole check (threshold 64, two-stage LANCZOS):')
for h in heroes:
    for s in suffixes:
        im = Image.open(f'assets/sprites/{h}{s}.png').convert('RGBA')
        alpha = np.array(im)[:,:,3]
        bg = alpha == 0
        labeled, n = ndimage.label(bg)
        border = set(labeled[0,:])|set(labeled[-1,:])|set(labeled[:,0])|set(labeled[:,-1])
        border.discard(0)
        holes = sum(int(np.sum(labeled==i)) for i in range(1,n+1) if i not in border)
        print(f'  {h}{s:7s} {im.size} holes={holes}')
