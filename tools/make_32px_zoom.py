from PIL import Image, ImageDraw

heroes = ['arclight', 'bulwark', 'warden']
suffixes = ['', '_back', '_left', '_right']
names = ['FRONT', 'BACK', 'LEFT', 'RIGHT']
S = 200  # zoom size
W = 4 * (S + 16) + 16
H = 4 * (S + 16) + 40

sheet = Image.new('RGB', (W, H), (30, 40, 35))
d = ImageDraw.Draw(sheet)
d.text((10, 5), '32px sprites at 6.25x zoom (game bg)', fill=(255, 255, 100))

for hi, hero in enumerate(heroes):
    for si, (suffix, name) in enumerate(zip(suffixes, names)):
        row, col = hi, si
        x = 16 + col * (S + 16)
        y = 30 + row * (S + 16)
        im = Image.open(f'assets/sprites/{hero}{suffix}.png').convert('RGBA')
        im_big = im.resize((S, S), Image.NEAREST)
        sheet.paste(im_big, (x, y), im_big)
        d.text((x + 4, y + S + 2), f'{hero} {name}', fill=(255, 255, 255))

sheet.save('tools/selftest/results/32px_zoom_compare.png')
print('saved')
