from heroes import HEROES
from mobs import MOBS
from bosses import BOSSES
from world import ITEMS
from lib import *
import sys
spr = []  # (name, w, h, [frames])
for k, fn in HEROES.items():
    spr.append((k + 'Idle', 16, 22, [fn(f, False) for f in range(4)]))
    spr.append((k + 'Run', 16, 22, [fn(f, True) for f in range(4)]))
for k, fn in MOBS.items():
    fr = [fn(f) for f in range(4)]
    spr.append((k, fr[0].w, fr[0].h, fr))
for k, fn in BOSSES.items():
    fr = [fn(f) for f in range(4)]
    spr.append((k, fr[0].w, fr[0].h, fr))
for name, w, h, fr in ITEMS:
    spr.append((name, w, h, fr))
W = 256
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
    lines.append((name, px, py, w, h, len(fr)))
sheet.save('yokai.png')
with open('sprites.txt', 'w') as fh:
    for name, px, py, w, h, n in lines:
        fh.write(f"sprite {name} = tiles at {px}, {py} size {w}, {h}" + (f" frames {n}" if n > 1 else "") + "\n")
print(W, H)
