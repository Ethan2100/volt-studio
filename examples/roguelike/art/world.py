from lib import *
import random

def mix(a, b, t):
    A, B = hexc(a), hexc(b)
    return tuple(int(A[i] + (B[i] - A[i]) * t) for i in range(3)) + (255,)

def floor_tile(seed, base, dark, light, kind):
    r = random.Random(seed)
    c = C(16, 16)
    c.rect(0, 0, 15, 15, base)
    if kind == 'stone':   # mossy flagstone
        c.rect(0, 0, 15, 0, dark); c.rect(0, 0, 0, 15, dark)
        c.rect(8, 0, 8, 7, dark) ; c.rect(0, 8, 15, 8, dark); c.rect(4, 8, 4, 15, dark) ; c.rect(12, 8, 12, 15, dark)
        for _ in range(9): c.px(r.randint(1, 15), r.randint(1, 15), light)
        for _ in range(3): c.px(r.randint(1, 15), r.randint(1, 15), '#4f8a4a')
    elif kind == 'wood':  # plank floor
        for y in (0, 5, 10, 15): c.rect(0, y, 15, y, dark)
        for y0, jx in ((0, 5), (5, 11), (10, 3)):
            c.rect(jx, y0, jx, y0 + 4, dark)
        for _ in range(8): c.px(r.randint(0, 15), r.randint(1, 14), light)
        c.px(r.randint(1, 14), 2, dark); c.px(r.randint(1, 14), 12, dark)
    elif kind == 'wave':  # seigaiha waves
        for cx in (0, 8, 16):
            for cy in (0, 8, 16):
                for rr, col in ((7, dark), (5, light), (3, dark)):
                    for ang in range(180, 361, 6):
                        x = cx + rr * math.cos(math.radians(ang)); y = cy + rr * math.sin(math.radians(ang)) + 0
                        c.px(round(x), round(y) + 0, col)
        for _ in range(5): c.px(r.randint(0, 15), r.randint(0, 15), light)
    elif kind == 'obsidian':  # cracked keep floor
        c.rect(0, 0, 15, 0, dark); c.rect(0, 0, 0, 15, dark)
        for _ in range(4):
            x, y = r.randint(2, 13), r.randint(2, 13)
            for k in range(r.randint(3, 6)):
                c.px(x, y, dark); x += r.choice((-1, 0, 1)); y += 1
        for _ in range(6): c.px(r.randint(1, 15), r.randint(1, 15), light)
        for _ in range(2): c.px(r.randint(1, 15), r.randint(1, 15), '#7a2a8a')
    return c

def wall_face():
    c = C(16, 16)
    c.rect(0, 0, 15, 15, '#3a3050')
    c.rect(0, 0, 15, 2, '#7a2a2a'); c.rect(0, 0, 15, 0, '#a33a3a'); c.rect(0, 3, 15, 3, '#2a1a1a')
    c.rect(0, 4, 15, 12, '#4a4068'); c.rect(0, 4, 1, 12, '#6a2a2a'); c.rect(1, 4, 1, 12, '#8a3a3a')
    for y in (6, 9): c.rect(3, y, 14, y, '#403659')
    c.rect(6, 5, 12, 5, '#544a76')
    c.rect(0, 13, 15, 15, '#2a2238'); c.rect(0, 13, 15, 13, '#1a1226')
    c.rect(7, 14, 8, 15, '#352c48')
    return c

def wall_top():
    c = C(16, 16)
    c.rect(0, 0, 15, 15, '#1f3a4a')
    for row in range(4):
        y = row * 4
        off = 4 if row % 2 else 0
        for x0 in range(-8 + off, 16, 8):
            for x in range(8):
                xx = x0 + x
                if 0 <= xx < 16:
                    h = [1, 2, 2, 1, 0, 0, 1, 1]
                    c.px(xx, y + 3 - (1 if x in (0, 7) else 0), '#13232e')
                    c.px(xx, y, '#3a6a7a')
                    c.px(xx, y + 1, '#2c5666')
            c.rect(x0 if x0 >= 0 else 0, y, x0, y + 3, '#13232e') if 0 <= x0 < 16 else None
    return c

def lantern():  # 16x22 stone toro
    c = C(16, 22)
    c.rect(4, 19, 11, 20, '#6a6a7a'); c.rect(3, 20, 12, 20, '#54546a')
    c.rect(6, 12, 9, 18, '#7a7a8c'); c.rect(7, 12, 7, 18, '#9a9aac')
    c.rect(3, 8, 12, 11, '#8a8a9c'); c.rect(3, 8, 12, 8, '#a8a8ba')
    c.rect(5, 9, 10, 10, '#ffd23f'); c.rect(7, 9, 8, 10, '#fff6b0')
    c.rect(1, 5, 14, 7, '#6a6a7a'); c.rect(2, 4, 13, 4, '#7a7a8c'); c.rect(4, 3, 11, 3, '#8a8a9c')
    c.rect(6, 1, 9, 2, '#9a9aac')
    c.px(7, 0, '#ffd23f') if False else None
    return c.outline()

def jizo():
    c = C(16, 16)
    c.rect(3, 13, 12, 14, '#6a6a7a')
    c.rect(5, 6, 10, 12, '#9a9aa8'); c.rect(5, 8, 10, 9, '#c0273d')
    c.ell(8, 5, 3.4, 3.2, '#b0b0be')
    c.rect(6, 5, 6, 5, '#2a2238'); c.rect(9, 5, 9, 5, '#2a2238')
    c.px(8, 2, '#7a7a8c'); c.px(7, 2, '#7a7a8c')
    c.rect(4, 10, 5, 12, '#9a9aa8'); c.rect(10, 10, 11, 12, '#9a9aa8')
    return c.outline()

def brazier(f):
    c = C(16, 16)
    c.rect(3, 9, 12, 10, '#4a3a5a'); c.rect(2, 8, 13, 8, '#6a5a7a')
    c.rect(5, 11, 10, 13, '#3a2a4a'); c.rect(4, 14, 11, 14, '#4a3a5a')
    fl = [0, 1, 2, 1][f]
    c.ell(8, 5 - fl * .4, 3 + (fl == 1) * .6, 3.3 + fl * .5, '#ff7a2a')
    c.ell(8, 6 - fl * .3, 1.8, 2.2 + fl * .3, '#ffd23f')
    c.px(8, 5, '#fff6b0')
    if fl == 2: c.px(6, 1, '#ff7a2a')
    return c.outline()

def cauldron(f):
    c = C(16, 16)
    c.ell(8, 11, 6.2, 4.2, '#2a1a3a'); c.rect(2, 10, 13, 12, '#2a1a3a')
    c.rect(2, 8, 13, 9, '#4a3a5a')
    c.rect(3, 14, 4, 15, '#2a1a3a'); c.rect(11, 14, 12, 15, '#2a1a3a')
    c.rect(3, 8, 12, 8, '#7a2aaa')
    fl = [0, 1, 2, 1][f]
    c.ell(8, 5 - fl * .5, 2.6, 3 + fl * .4, '#b86bff')
    c.ell(8, 6, 1.4, 2, '#e8c8ff')
    c.px(5 + fl, 2, '#c77dff'); c.px(11 - fl, 3, '#c77dff')
    return c.outline()

HEART = ["..XX....XX......", ".XXXX..XXXX.....", "XXXXXXXXXXXX....", "XXXXXXXXXXXX....", "XXXXXXXXXXXX....", ".XXXXXXXXXX.....", "..XXXXXXXX......", "...XXXXXX.......", "....XXXX........", ".....XX........."]
def heart(kind):
    c = C(16, 16)
    rows = ["..XXX..XXX..", ".XXXXXXXXXXX", "XXXXXXXXXXXXX", "XXXXXXXXXXXXX", "XXXXXXXXXXXXX", ".XXXXXXXXXXX.", "..XXXXXXXXX..", "...XXXXXXX...", "....XXXXX....", ".....XXX.....", "......X......"]
    rows = [r.ljust(13, '.') for r in rows]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == 'X':
                X, Y = x + 1, y + 2
                full = kind == 0 or (kind == 1 and x < 6)
                col = '#ff4d6d' if full else '#3a2a4a'
                if full and y in (1, 2) and x in (2, 3): col = '#ffb3c1'
                c.px(X, Y, col)
    return c.outline()

def coin(f):
    c = C(8, 8)
    w = [3, 2, 0, 2][f]
    c.ell(4, 4, 1 + w, 3.4, '#ffd23f')
    if w >= 2: c.rect(4, 2, 4, 5, '#b8860b'); c.px(3, 2, '#fff6b0')
    elif w == 0: c.rect(4, 1, 4, 6, '#ffd23f'); c.rect(3, 1, 3, 6, '#b8860b')
    return c.outline()

def gourd():
    c = C(16, 16)
    c.ell(8, 11, 4.6, 3.8, '#c98a3a'); c.ell(8, 5.5, 3, 2.8, '#c98a3a')
    c.rect(7, 2, 8, 3, '#8a5a2a'); c.rect(5, 8, 10, 8, '#a0702a')
    c.line(6, 7, 10, 7, '#d6a05a'); c.px(6, 10, '#e8c080'); c.px(6, 11, '#e8c080')
    c.rect(7, 1, 8, 1, '#c0273d'); c.px(9, 1, '#c0273d'); c.px(10, 2, '#c0273d')
    c.rect(7, 8, 8, 9, '#ffffff') if False else None
    return c.outline()

def tanuki(f):  # merchant 16x19
    c = C(16, 19)
    yo = 1 if f in (1, 2) else 0
    c.ell(8, 13 + yo, 5.6, 5, '#8a5a3a'); c.ell(8, 14 + yo, 3.8, 3.4, '#f0dcb0')
    c.rect(4, 17, 6, 18, '#5a3a22'); c.rect(9, 17, 11, 18, '#5a3a22')
    c.ell(2.6, 12 + yo, 1.6, 2, '#8a5a3a'); c.ell(13.4, 12 + yo, 1.6, 2, '#8a5a3a')
    c.rect(11, 9 + yo, 14, 12 + yo, '#c98a3a'); c.px(12, 9 + yo, '#8a5a2a')  # tokkuri sake
    c.ell(8, 6 + yo, 4.6, 4, '#8a5a3a')
    c.ell(4, 3 + yo, 1.5, 1.5, '#5a3a22'); c.ell(12, 3 + yo, 1.5, 1.5, '#5a3a22')
    c.ell(8, 8 + yo, 3, 2.2, '#f0dcb0')
    c.rect(5, 5 + yo, 6, 6 + yo, '#2a1a10'); c.rect(10, 5 + yo, 11, 6 + yo, '#2a1a10')
    c.px(5, 5 + yo, '#ffffff'); c.px(10, 5 + yo, '#ffffff')
    c.rect(7, 7 + yo, 9, 7 + yo, '#2a1a10')
    # leaf hat
    c.ell(8, 1.6 + yo, 3, 1.6, '#4fa24a'); c.px(8, 0 + yo, '#7fd06a'); c.line(8, 1 + yo, 8, 2 + yo, '#2f7a30')
    return c.outline()

ITEMS = [
    ('heart', 16, 16, [heart(0), heart(1), heart(2)]),
    ('coin', 8, 8, [coin(f) for f in range(4)]),
    ('flask', 16, 16, [gourd()]),
    ('lizardIdle', 16, 19, [tanuki(f) for f in range(4)]),
    ('crate', 16, 22, [lantern()]),
    ('skull', 16, 16, [jizo()]),
    ('basin', 16, 16, [brazier(f) for f in (0, 1, 2)]),
    ('fountain', 16, 16, [cauldron(f) for f in (0, 1, 2)]),
    ('wallFace', 16, 16, [wall_face()]),
    ('wallTop', 16, 16, [wall_top()]),
    ('floorA', 16, 16, [floor_tile(i + 1, '#243a36', '#192a28', '#2f4a44', 'stone') for i in range(3)]),
    ('floorB', 16, 16, [floor_tile(i + 11, '#3a2a40', '#281c2e', '#4a3652', 'wood') for i in range(3)]),
    ('floorC', 16, 16, [floor_tile(i + 21, '#3a1a2a', '#2a1220', '#4e2638', 'wave') for i in range(2)]),
    ('floorD', 16, 16, [floor_tile(i + 31, '#1c1626', '#120d1a', '#2c2240', 'obsidian') for i in range(3)]),
]
