# Builds hero art from the CraftPix "Free Yokai Pixel Art Character Sprites" pack.
# Put the unzipped pack folders (Kitsune, Yamabushi_tengu, Karasu_tengu) in packs/yokai/ and run this.
import sys, os
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else 'packs/yokai'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'hero.png'
F = 80  # frame size after shrinking 128 -> 80
HEROES = [  # game hero index -> folder, and which pack animation is used for each action
    ('Yamabushi_tengu', {'Idle': 'Idle', 'Run': 'Run', 'Atk': 'Attack_2', 'Hurt': 'Hurt', 'Dead': 'Dead'}),
    ('Karasu_tengu', {'Idle': 'Idle', 'Run': 'Run', 'Atk': 'Attack_1', 'Hurt': 'Hurt', 'Dead': 'Dead'}),
    ('Kitsune', {'Idle': 'Idle', 'Run': 'Run', 'Atk': 'Attack_1', 'Hurt': 'Hurt', 'Dead': 'Dead'}),
]
def shrink(fr):
    fr = fr.resize((F, F), Image.LANCZOS)
    px = fr.load()
    for y in range(F):
        for x in range(F):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a > 110 else (0, 0, 0, 0)
    return fr
rows = []
for i, (folder, anims) in enumerate(HEROES):
    for act, name in anims.items():
        sheet = Image.open(os.path.join(SRC, folder, name + '.png')).convert('RGBA')
        n = sheet.width // 128
        rows.append((f'h{i}{act}', [shrink(sheet.crop((k * 128, 0, k * 128 + 128, 128))) for k in range(n)]))
W = max(len(fr) for _, fr in rows) * F
sheet = Image.new('RGBA', (W, F * len(rows)), (0, 0, 0, 0))
lines = []
for r, (name, fr) in enumerate(rows):
    for k, f in enumerate(fr): sheet.paste(f, (k * F, r * F))
    lines.append(f'sprite {name} = heroPic at 0, {r * F} size {F}, {F} frames {len(fr)}')
sheet.save(OUT)
open(os.path.splitext(OUT)[0] + '_sprites.txt', 'w').write('\n'.join(lines) + '\n')
print(sheet.size); print('\n'.join(lines))
