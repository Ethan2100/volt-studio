# Bakes the game's UI panels from the Kenney "Pixel UI pack" (CC0, kenney.nl) into ui.png.
# Run: python3 build_ui.py packs/ui/9-Slice art/ui.png
import sys, os
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else 'packs/ui/9-Slice'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'ui.png'
def nine(path, w, h, m):
    src = Image.open(os.path.join(SRC, path)).convert('RGBA')
    sw, sh = src.size
    m = min(m, h // 2 - 1, w // 2 - 1)
    dst = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    def tile(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1):
        tw, th = sx1 - sx0, sy1 - sy0
        for y in range(dy0, dy1):
            for x in range(dx0, dx1):
                dst.putpixel((x, y), src.getpixel((sx0 + (x - dx0) % tw, sy0 + (y - dy0) % th)))
    tile(0, 0, m, m, 0, 0, m, m)
    tile(sw - m, 0, sw, m, w - m, 0, w, m)
    tile(0, sh - m, m, sh, 0, h - m, m, h)
    tile(sw - m, sh - m, sw, sh, w - m, h - m, w, h)
    tile(m, 0, sw - m, m, m, 0, w - m, m)
    tile(m, sh - m, sw - m, sh, m, h - m, w - m, h)
    tile(0, m, m, sh - m, 0, m, m, h - m)
    tile(sw - m, m, sw, sh - m, w - m, m, w, h - m)
    tile(m, m, sw - m, sh - m, m, m, w - m, h - m)
    return dst
PANELS = [  # name, file, w, h, margin
    ('uiHud', 'Ancient/brown.png', 320, 20, 6),
    ('uiCard', 'Ancient/tan.png', 92, 112, 8),
    ('uiCardSel', 'Colored/yellow.png', 98, 118, 8),
    ('uiShop', 'Ancient/tan.png', 66, 56, 8),
    ('uiShopSel', 'Colored/yellow.png', 72, 62, 8),
    ('uiRow', 'Ancient/tan.png', 272, 26, 8),
    ('uiRowSel', 'Colored/yellow.png', 278, 32, 8),
    ('uiDlg', 'Ancient/brown.png', 300, 150, 8),
    ('uiDlgTall', 'Ancient/brown.png', 300, 164, 8),
    ('uiBanner', 'Ancient/brown.png', 170, 42, 8),
    ('uiBoss', 'Ancient/brown.png', 192, 16, 6),
    ('uiTitleBox', 'Ancient/brown.png', 220, 46, 8),
]
DARK = ('uiHud', 'uiDlg', 'uiDlgTall', 'uiBanner', 'uiBoss', 'uiTitleBox')
def darken(im):
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            r, g, b, a = px[xx, yy]
            if a: px[xx, yy] = (int(r * .38 + 6), int(g * .3 + 4), int(b * .46 + 14), a)
    return im
W = 320
y = 0; rows = []
for name, f, w, h, m in PANELS:
    im = nine(f, w, h, m)
    rows.append((name, darken(im) if name in DARK else im, y, w, h)); y += h
sheet = Image.new('RGBA', (W, y), (0, 0, 0, 0))
lines = []
for name, im, yy, w, h in rows:
    sheet.paste(im, (0, yy)); lines.append(f'sprite {name} = uiPic at 0, {yy} size {w}, {h}')
sheet.save(OUT)
open(os.path.splitext(OUT)[0] + '_sprites.txt', 'w').write('\n'.join(lines) + '\n')
print(sheet.size)
