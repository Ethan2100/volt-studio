# Enemy art from the CraftPix "Free Ninja Sprite Sheets" pack (Ninja_Peasant, Ninja_Monk, Kunoichi).
# Unzip the pack into packs/ninja/ and run: python3 art/pack_enemies.py packs/ninja art/enemy.png
import sys, os
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else 'packs/ninja'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'enemy.png'
# name, folder, source frame size, output frame size
ENEMIES = [('e0Run', 'Ninja_Peasant', 96, 48), ('e1Run', 'Ninja_Monk', 96, 48), ('e2Run', 'Kunoichi', 128, 64)]
def shrink(fr, F):
    fr = fr.resize((F, F), Image.LANCZOS); px = fr.load()
    for y in range(F):
        for x in range(F):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a > 110 else (0, 0, 0, 0)
    return fr
rows = []
for name, folder, sz, F in ENEMIES:
    sheet = Image.open(os.path.join(SRC, folder, 'Run.png')).convert('RGBA')
    rows.append((name, F, [shrink(sheet.crop((k * sz, 0, k * sz + sz, sz)), F) for k in range(sheet.width // sz)]))
W = max(len(fr) * F for _, F, fr in rows); H = sum(F for _, F, _ in rows)
sheet = Image.new('RGBA', (W, H), (0, 0, 0, 0)); y = 0; lines = []
for name, F, fr in rows:
    for k, f in enumerate(fr): sheet.paste(f, (k * F, y))
    lines.append(f'sprite {name} = enemyPic at 0, {y} size {F}, {F} frames {len(fr)}'); y += F
sheet.save(OUT); open(os.path.splitext(OUT)[0] + '_sprites.txt', 'w').write('\n'.join(lines) + '\n')
print(sheet.size); print('\n'.join(lines))
