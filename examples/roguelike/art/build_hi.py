# Builds yokai.png: enemies, bosses, props and tiles drawn at 16-px detail, then doubled
# smoothly (Scale2x), shaded and outlined, so they sit at the same density as the hero art.
import lib
lib.OUTLINE = False
from lib import *
from mobs import MOBS
from bosses import BOSSES
from world import ITEMS
TILES = ('floorA', 'floorB', 'floorC', 'floorD', 'wallFace', 'wallTop')
spr = []
for k, fn in list(MOBS.items()) + list(BOSSES.items()):
    fr = [hires(fn(f)) for f in range(4)]
    spr.append((k, fr[0].w, fr[0].h, fr))
for name, w, h, fr in ITEMS:
    if name in TILES:
        fr2 = [scale2x(f) for f in fr]
    else:
        fr2 = [hires(f) for f in fr]
    spr.append((name, fr2[0].w, fr2[0].h, fr2))
W = 512
x = y = rowh = 0
placed = []
for name, w, h, fr in sorted(spr, key=lambda s: -s[2]):
    tw = w * len(fr)
    if x + tw > W: x = 0; y += rowh; rowh = 0
    placed.append((name, x, y, w, h, fr)); x += tw; rowh = max(rowh, h)
H = y + rowh
sheet = Image.new('RGBA', (W, H), (0, 0, 0, 0))
lines = []
for name, px, py, w, h, fr in placed:
    for i, f in enumerate(fr): sheet.paste(f.im, (px + i * w, py))
    lines.append(f"sprite {name} = tiles at {px}, {py} size {w}, {h}" + (f" frames {len(fr)}" if len(fr) > 1 else ""))
sheet.save('yokai.png')
open('sprites.txt', 'w').write('\n'.join(lines) + '\n')
print(W, H)
