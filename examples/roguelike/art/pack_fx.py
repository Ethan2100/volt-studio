# Effects from the CraftPix "Free Pixel Magic Sprite Effects Pack" (72x72 frames), copied as-is.
# Unzip the pack into packs/magic/ and run: python3 art/pack_fx.py packs/magic art/fx.png
import sys, os
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else 'packs/magic'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'fx.png'
FX = [('mSlash', '3_2', 8), ('mBeam', '3', 8), ('mPuff', '9', 8), ('mHit', '10', 8), ('mFire', '6', 4), ('mHeart', '5', 8),
      ('mRing', '2', 8), ('mSpike', '7', 8), ('mThorn', '1', 8)]
sheet = Image.new('RGBA', (72 * 8, 72 * len(FX)), (0, 0, 0, 0)); lines = []
for r, (name, f, n) in enumerate(FX):
    im = Image.open(os.path.join(SRC, '1 Magic', f + '.png')).convert('RGBA')
    sheet.paste(im, (0, r * 72)); lines.append(f'sprite {name} = fxPic at 0, {r * 72} size 72, 72 frames {n}')
sheet.save(OUT); open(os.path.splitext(OUT)[0] + '_sprites.txt', 'w').write('\n'.join(lines) + '\n')
print(sheet.size)
