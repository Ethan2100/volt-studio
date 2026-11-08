# Hi-res UI for Yokai Descent: lacquer-and-gold panels, HUD icons and a smooth pixel font,
# all drawn at real screen-pixel density (draw them at scale 50 in the game).
# Run: python3 build_ui2.py   (writes ui2.png, ui2_sprites.txt, font.png)
import random, math
from PIL import Image
FONT = '000000000000005f00000007000700147f147f14242a7f2a12231308646236495620500008070300001c2241000041221c002a1c7f1c2a08083e080800807030000808080808000060600020100804023e5149453e00427f400072494949462141494d331814127f1027454545393c4a49493141211109073649494936464949291e0000140000004034000000081422411414141414004122140802015909063e415d594e7c1211127c7f494949363e414141227f4141413e7f494949417f090909013e414151737f0808087f00417f41002040413f017f081422417f404040407f021c027f7f0408107f3e4141413e7f090909063e4151215e7f09192946264949493203017f01033f4040403f1f2040201f3f4038403f631408146303047804036159494d43007f4141410204081020004141417f04020102044040404040000307080020545478407f284444383844444428384444287f385454541800087e090218a4a49c787f0804047800447d40002040403d007f1028440000417f40007c047804787c080404783844444438fc1824241818242418fc7c08040408485454542404043f44243c4040207c1c2040201c3c4030403c44281028444c9090907c4464544c440008364100000077000000413608000201020402'

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
def hx(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
GOLD, GOLD_L, GOLD_D = hx('#d9a441'), hx('#f6d98a'), hx('#8a5a1f')
INK = hx('#0a0612')

def panel(w, h, top='#34254b', bot='#171021', seed=1, rim=GOLD, corner=4):
    r = random.Random(seed)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); p = im.load()
    def inside(x, y, inset=0, cut=corner):
        if x < inset or y < inset or x >= w - inset or y >= h - inset: return False
        c = max(cut - inset, 0)
        for cx, cy in ((inset, inset), (w - 1 - inset, inset), (inset, h - 1 - inset), (w - 1 - inset, h - 1 - inset)):
            if abs(x - cx) + abs(y - cy) < c and ((x < w / 2) == (cx < w / 2)) and ((y < h / 2) == (cy < h / 2)): return False
        return True
    t, b = hx(top), hx(bot)
    for y in range(h):
        for x in range(w):
            if inside(x, y):
                col = lerp(t, b, y / max(h - 1, 1))
                n = r.randint(-3, 3) + (3 if (x + y) % 7 == 0 else 0)
                p[x, y] = tuple(max(0, min(255, c + n)) for c in col) + (255,)
    # outline, gold rim (light top-left, dark bottom-right), inner shadow
    for y in range(h):
        for x in range(w):
            if inside(x, y) and not inside(x, y, 1): p[x, y] = INK + (255,)
            elif inside(x, y, 1) and not inside(x, y, 2):
                k = (x + y) / (w + h)
                p[x, y] = lerp(rim, GOLD_D, k) + (255,) if k > .55 else lerp(GOLD_L, rim, k * 1.6) + (255,)
            elif inside(x, y, 2) and not inside(x, y, 3): p[x, y] = lerp(hx(bot), INK, .6) + (255,)
            elif inside(x, y, 3) and not inside(x, y, 4):
                c0 = p[x, y]; p[x, y] = tuple(int(v * .78) for v in c0[:3]) + (255,)
    # corner brackets and studs
    for cx, cy, sx, sy in ((4, 4, 1, 1), (w - 5, 4, -1, 1), (4, h - 5, 1, -1), (w - 5, h - 5, -1, -1)):
        for i in range(0, 8):
            for (xx, yy) in ((cx + sx * i, cy), (cx, cy + sy * i)):
                if 0 <= xx < w and 0 <= yy < h: p[xx, yy] = GOLD_L + (255,) if i < 7 else GOLD + (255,)
        for dx in (0, 1):
            for dy in (0, 1):
                xx, yy = cx + sx * 2 + dx * sx, cy + sy * 2 + dy * sy
                if 0 <= xx < w and 0 <= yy < h: p[xx, yy] = hx('#c0273d') + (255,)
    return im

def glow_frame(w, h):
    return panel(w, h, top='#ffe48a', bot='#e0a030', seed=7, rim=GOLD_L, corner=5)

def hud_bar(w, h):
    im = panel(w, h + 8, top='#2b1f40', bot='#120c1c', seed=3, corner=0)
    return im.crop((0, 0, w, h))

def heart(kind):
    im = Image.new('RGBA', (24, 22), (0, 0, 0, 0)); p = im.load()
    def shape(x, y):
        xx, yy = x + .5, y + .5
        if (xx - 7.2) ** 2 + (yy - 7.2) ** 2 <= 6.4 ** 2: return True
        if (xx - 16.8) ** 2 + (yy - 7.2) ** 2 <= 6.4 ** 2: return True
        return yy >= 7 and abs(xx - 12) <= (20.8 - yy) * (11.2 / 13.8)
    for y in range(22):
        for x in range(24):
            if shape(x, y):
                t = y / 21
                if kind == 2: col = lerp(hx('#3b2a4d'), hx('#20152e'), t)
                elif kind == 1 and x > 11: col = lerp(hx('#3b2a4d'), hx('#20152e'), t)
                else: col = lerp(hx('#ff7a8f'), hx('#c4203f'), t)
                p[x, y] = col + (255,)
    for y in range(22):
        for x in range(24):
            if p[x, y][3] == 0 and any(0 <= x + dx < 24 and 0 <= y + dy < 22 and p[x + dx, y + dy][3] and p[x + dx, y + dy][:3] != INK for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                p[x, y] = INK + (255,)
    if kind != 2:
        for (x, y) in ((5, 5), (6, 4), (7, 4), (5, 6), (4, 6)): 
            if p[x, y][3] and kind == 0 or (p[x, y][3] and x < 11): p[x, y] = hx('#ffd0d8') + (255,)
    return im

def orb(full):
    im = Image.new('RGBA', (12, 16), (0, 0, 0, 0)); p = im.load()
    for y in range(16):
        for x in range(12):
            X = (x - 5.5) / 5.0; Y = (y - 10) / 5.6
            drop = (X * X + Y * Y <= 1) or (y < 10 and abs(X) <= (y - 1) / 9.0 * 0.95 and y >= 1)
            if drop:
                if full: p[x, y] = lerp(hx('#bff4ff'), hx('#2a8fd8'), y / 15) + (255,)
                else: p[x, y] = lerp(hx('#2b3550'), hx('#161c30'), y / 15) + (255,)
    for y in range(16):
        for x in range(12):
            if p[x, y][3] == 0 and any(0 <= x + dx < 12 and 0 <= y + dy < 16 and p[x + dx, y + dy][3] and p[x + dx, y + dy][:3] != INK for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                p[x, y] = INK + (255,)
    if full:
        for (x, y) in ((4, 10), (4, 11), (5, 9)): p[x, y] = (255, 255, 255, 255)
    return im

def dash_frame():
    return panel(52, 14, top='#2b1f40', bot='#120c1c', seed=5, corner=0)

SPRITES = []
def build():
    items = [
        ('uiHud', [hud_bar(640, 40)]),
        ('uiCard', [panel(184, 224, seed=11)]),
        ('uiCardSel', [glow_frame(196, 236)]),
        ('uiShop', [panel(132, 112, seed=12)]),
        ('uiShopSel', [glow_frame(144, 124)]),
        ('uiRow', [panel(544, 52, seed=13)]),
        ('uiRowSel', [glow_frame(556, 64)]),
        ('uiDlg', [panel(600, 300, seed=14)]),
        ('uiDlgTall', [panel(600, 328, seed=15)]),
        ('uiBanner', [panel(340, 84, top='#3a1f3d', bot='#1a0d1c', seed=16)]),
        ('uiBoss', [panel(384, 32, top='#3a1f3d', bot='#1a0d1c', seed=17, corner=3)]),
        ('uiTitleBox', [panel(440, 92, seed=18)]),
        ('uiHeart', [heart(0), heart(1), heart(2)]),
        ('uiOrb', [orb(True), orb(False)]),
        ('uiDash', [dash_frame()]),
    ]
    W = 640; y = 0; placed = []
    for name, fr in items:
        placed.append((name, y, fr)); y += max(f.height for f in fr) + 2
    sheet = Image.new('RGBA', (W, y), (0, 0, 0, 0)); lines = []
    for name, yy, fr in placed:
        for i, f in enumerate(fr): sheet.paste(f, (i * f.width, yy))
        lines.append(f'sprite {name} = uiPic at 0, {yy} size {fr[0].width}, {fr[0].height}' + (f' frames {len(fr)}' if len(fr) > 1 else ''))
    sheet.save('ui2.png'); open('ui2_sprites.txt', 'w').write('\n'.join(lines) + '\n')

def scale2x(src):
    w, h = src.size; P = src.load(); out = Image.new('RGBA', (w * 2, h * 2), (0, 0, 0, 0)); O = out.load()
    def g(x, y): return P[x, y] if 0 <= x < w and 0 <= y < h else (0, 0, 0, 0)
    for y in range(h):
        for x in range(w):
            c = g(x, y); a, b, l, d = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            p1 = p2 = p3 = p4 = c
            if l == a and l != d and a != b: p1 = a
            if a == b and a != l and b != d: p2 = b
            if d == l and d != b and l != a: p3 = l
            if b == d and b != a and d != l: p4 = d
            O[x * 2, y * 2], O[x * 2 + 1, y * 2], O[x * 2, y * 2 + 1], O[x * 2 + 1, y * 2 + 1] = p1, p2, p3, p4
    return out

def font():
    cells = Image.new('RGBA', (95 * 12, 16), (0, 0, 0, 0))
    for ch in range(95):
        g = Image.new('RGBA', (5, 8), (0, 0, 0, 0)); gp = g.load()
        for col in range(5):
            bv = int(FONT[(ch * 5 + col) * 2:(ch * 5 + col) * 2 + 2], 16)
            for row in range(8):
                if (bv >> row) & 1: gp[col, row] = (255, 255, 255, 255)
        big = scale2x(g)  # 10 x 16, smoother diagonals
        cells.paste(big, (ch * 12, 0))
    cells.save('font.png')

build(); font()
print('done')
