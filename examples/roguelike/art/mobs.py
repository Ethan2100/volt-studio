from lib import *

def karakasa(f):  # slime slot: hopping one-eyed umbrella
    c = C(16, 16)
    hop = [0, 1, 2, 1][f]
    y0 = 3 - hop + 1
    c.ell(8, y0 + 5, 6.6, 5.2, '#8e4bd1', keep=lambda x, y: y <= y0 + 6)
    for rx in (-4, -2, 0, 2, 4):
        c.line(8 + rx * .3, y0, 8 + rx, y0 + 6, '#6a2fa8')
    c.rect(2, y0 + 6, 13, y0 + 6, '#b987f0')
    c.rect(8, y0 + 6, 8, y0 + 7, '#6a2fa8')
    # eye
    c.ell(8, y0 + 3.5, 2.6, 2.6, '#ffffff'); c.rect(8, y0 + 3, 9, y0 + 4, '#1a1026')
    if f in (1, 2): c.rect(7, y0 + 7, 8, y0 + 9, '#ff6f9a')
    # leg + geta
    c.rect(7, y0 + 8, 8, 13, '#e9d3a8')
    c.rect(5, 14 - (1 if hop else 0), 10, 14 - (1 if hop else 0), '#8a5a3a')
    return c.outline()

def spider(f):  # goblinRun slot 16x11
    c = C(16, 11)
    for i, (lx, ly) in enumerate(((2, 1), (1, 4), (2, 8), (4, 9))):
        sh = 1 if (f + i) % 2 else 0
        c.line(6, 5, lx, ly + sh, '#3a2a52'); c.line(9, 5, 15 - lx, ly + sh, '#3a2a52')
    c.ell(8, 5.5, 4.4, 3.2, '#4a3366')
    c.rect(5, 5, 6, 5, '#c0273d'); c.rect(9, 5, 10, 5, '#c0273d')
    c.px(7, 4, '#ff4d6d'); c.px(8, 4, '#ff4d6d'); c.px(7, 3, '#8e1c2e'); c.px(8, 3, '#8e1c2e')
    c.px(12, 5, '#ffe66b'); c.px(12, 6, '#ffe66b')
    return c.outline()

def skeleton(f, ):  # ashigaru with straw hat
    c = C(16, 16)
    yo = 1 if f in (1, 3) else 0
    la = 0 if f in (0, 2) else 1
    c.rect(5, 12 + yo - 0, 5, 14 + (1 if f == 0 else 0), '#e8e2c8'); c.rect(9, 12 + yo, 9, 14 + (1 if f == 2 else 0), '#e8e2c8')
    c.rect(4, 15, 6, 15, '#e8e2c8'); c.rect(8, 15, 10, 15, '#e8e2c8')
    c.rect(5, 9 + yo, 10, 11 + yo, '#cfc8a8')
    for x in (6, 8): c.rect(x, 9 + yo, x, 11 + yo, '#5a5070')
    c.rect(5, 12 + yo, 10, 12 + yo, '#8a2a3a')
    c.ell(8, 6 + yo, 3.6, 3.2, '#efe9d2')
    c.rect(7, 6 + yo, 8, 7 + yo, '#1a1026'); c.rect(10, 6 + yo, 10, 7 + yo, '#1a1026')
    c.rect(7, 9 + yo, 10, 9 + yo, '#5a5070')
    c.tri(2, 4 + yo, 8, -0.5 + yo, 14, 4 + yo, '#c9a35a')
    c.rect(3, 4 + yo, 13, 4 + yo, '#a07a3a')
    c.line(12, 10 + yo, 15, 4 + yo, '#8a5a3a'); c.px(15, 3 + yo, '#d6e4ff')
    return c.outline()

def tengu(f):
    c = C(16, 16)
    yo = 1 if f in (1, 3) else 0
    w = [0, -1, -2, -1][f]
    c.tri(2, 7 + yo + w, 0.5, 3 + yo + w, 6, 9 + yo, '#2a2038')
    c.tri(1, 11 + yo, 4, 9 + yo, 8, 12 + yo, '#2a2038')
    legs = (5, 9)
    c.rect(5, 13 + yo, 6, 14, '#3a2a4a'); c.rect(9, 13 + yo, 10, 14, '#3a2a4a')
    c.rect(4, 15, 6, 15, '#8a5a3a'); c.rect(9, 15, 11, 15, '#8a5a3a')
    c.rect(5, 9 + yo, 10, 12 + yo, '#3a2a4a'); c.rect(5, 11 + yo, 10, 11 + yo, '#ffd23f')
    c.ell(8, 6 + yo, 4.2, 4, '#d8392f')
    c.rect(11, 6 + yo, 15, 7 + yo, '#d8392f')  # long nose
    c.px(15, 7 + yo, '#a82020')
    c.rect(6, 5 + yo, 7, 5 + yo, '#ffe66b'); c.rect(9, 5 + yo, 10, 5 + yo, '#ffe66b')
    c.line(5, 4 + yo, 7, 4 + yo, '#ffffff'); c.line(9, 4 + yo, 11, 4 + yo, '#ffffff')
    c.rect(6, 1 + yo, 9, 2 + yo, '#1a1026')  # tokin cap
    c.rect(2, 8 + yo, 4, 10 + yo, '#ffffff') if f % 2 == 0 else None
    return c.outline()

def jiangshi(f):
    c = C(16, 16)
    yo = [0, -1, 0, -1][f]
    c.rect(5, 13, 6, 15 + yo if yo else 15, '#2a3a8a') ; c.rect(9, 13, 10, 15, '#2a3a8a')
    c.rect(4, 15, 6, 15, '#1a1026'); c.rect(9, 15, 11, 15, '#1a1026')
    c.rect(4, 8 + yo + 1, 11, 13, '#3a5acf')
    c.rect(4, 12, 11, 12, '#ffd23f')
    c.rect(11, 9 + yo + 1, 15, 10 + yo + 1, '#3a5acf'); c.rect(14, 9 + yo + 1, 15, 10 + yo + 1, '#9bc98a')
    c.rect(1, 9 + yo + 1, 3, 10 + yo + 1, '#3a5acf')
    c.ell(8, 5 + yo + 1, 3.7, 3.4, '#9bc98a')
    c.rect(4, 1 + yo + 1, 11, 3 + yo + 1, '#1a1026')
    c.rect(6, 4 + yo + 1, 9, 9 + yo + 1, '#ffe66b')
    c.px(7, 5 + yo + 1, '#c0273d'); c.px(8, 6 + yo + 1, '#c0273d'); c.px(7, 7 + yo + 1, '#c0273d'); c.px(8, 8 + yo + 1, '#c0273d')
    c.px(10, 5 + yo + 1, '#c0273d')
    return c.outline()

def oni(f, run):  # 16x20
    c = C(16, 20)
    yo = (1 if f in (1, 3) else 0) if run else (1 if f in (2, 3) else 0)
    if run:
        lx = {0: 3, 1: 4, 2: 5, 3: 4}[f]
    else:
        lx = 4
    c.rect(4, 15, 6, 17, '#4a6ad8'); c.rect(9, 15, 11, 17, '#4a6ad8')
    c.rect(3, 18, 6, 18, '#2a2a5a'); c.rect(9, 18, 12, 18, '#2a2a5a')
    c.rect(3, 10 + yo, 12, 15 + yo, '#4a6ad8')
    c.rect(3, 14 + yo, 12, 16 + yo, '#ffd23f')
    for x in (4, 7, 10): c.rect(x, 14 + yo, x, 16 + yo, '#2a1a10')
    c.rect(2, 11 + yo, 3, 14 + yo, '#4a6ad8')
    c.rect(12, 10 + yo, 13, 13 + yo, '#4a6ad8')
    # club (kanabo)
    c.line(14, 12 + yo, 14, 4 + yo, '#8a5a3a', 2) if not run else c.line(13, 11 + yo, 15, 4 + yo, '#8a5a3a', 2)
    for yy in (4, 6, 8): c.px(14, yy + yo, '#ffe66b')
    c.ell(8, 6 + yo, 4.6, 4.2, '#4a6ad8')
    c.rect(4, 2 + yo, 12, 3 + yo, '#1a1026')
    c.tri(4, 3 + yo, 5.5, -0.8 + yo, 7, 3 + yo, '#fff2c0'); c.tri(9, 3 + yo, 10.5, -0.8 + yo, 12, 3 + yo, '#fff2c0')
    c.line(5, 5 + yo, 7, 6 + yo, '#1a1026'); c.line(11, 5 + yo, 9, 6 + yo, '#1a1026')
    c.rect(6, 6 + yo, 6, 6 + yo, '#ffe66b'); c.rect(10, 6 + yo, 10, 6 + yo, '#ffe66b')
    c.rect(6, 9 + yo, 10, 9 + yo, '#1a1026'); c.px(6, 8 + yo, '#ffffff'); c.px(10, 8 + yo, '#ffffff')
    return c.outline()

def kitsune(f):  # shaman slot 16x20
    c = C(16, 20)
    yo = 1 if f in (1, 3) else 0
    c.rect(4, 11 + yo, 11, 18, '#f4f1ff'); c.rect(3, 16, 12, 18, '#f4f1ff')
    c.rect(4, 11 + yo, 4, 18, '#c0273d'); c.rect(11, 11 + yo, 11, 18, '#c0273d')
    c.rect(4, 14 + yo, 11, 14 + yo, '#c0273d')
    c.rect(3, 18, 12, 18, '#c9c4e8')
    c.rect(12, 12 + yo, 14, 14 + yo, '#f4f1ff')
    # gohei staff
    c.rect(14, 5 + yo, 14, 18, '#8a5a3a')
    c.rect(13, 3 + yo, 15, 5 + yo, '#ffffff')
    c.px(15, 6 + yo, '#ffffff'); c.px(13, 7 + yo, '#ffffff')
    # fox mask head
    c.tri(3, 4 + yo, 3.5, -0.5 + yo, 7, 3 + yo, '#f4f1ff'); c.tri(9, 3 + yo, 11.5, -0.5 + yo, 12.5, 4 + yo, '#f4f1ff')
    c.px(4, 2 + yo, '#c0273d'); c.px(11, 1 + yo, '#c0273d')
    c.ell(8, 7 + yo, 4.5, 4, '#f4f1ff')
    c.rect(11, 8 + yo, 13, 9 + yo, '#f4f1ff'); c.px(13, 9 + yo, '#1a1026')
    c.line(5, 6 + yo, 7, 7 + yo, '#c0273d'); c.line(11, 6 + yo, 9, 7 + yo, '#c0273d')
    c.px(6, 7 + yo, '#1a1026'); c.px(10, 7 + yo, '#1a1026')
    c.rect(7, 9 + yo, 7, 10 + yo, '#c0273d'); c.rect(9, 9 + yo, 9, 10 + yo, '#c0273d')
    # floating spirit-fire
    ph = [0, 1, 0, -1][f]
    c.ell(1.5, 12 + yo + ph, 1.3, 1.6, '#7fd6ff'); c.px(1, 11 + yo + ph, '#ffffff')
    return c.outline()

def chochin(f):  # angel slot: floating paper lantern ghost
    c = C(16, 16)
    sw = [0, 1, 0, -1][f]
    c.rect(5 + sw, 1, 10 + sw, 2, '#2a1a3a')
    c.ell(8 + sw, 8, 5.6, 5.4, '#ff6f6f')
    for rr in (4, 6, 9, 11): c.line(3 + sw, rr, 12 + sw, rr, '#d03a3a')
    c.rect(5 + sw, 13, 10 + sw, 14, '#2a1a3a')
    c.ell(8 + sw, 7, 2.6, 2.4, '#fff6e8'); c.rect(8 + sw, 6, 9 + sw, 8, '#1a1026')
    if f % 2 == 0: c.rect(7 + sw, 10, 9 + sw, 12, '#ff9ad5')
    c.px(2 + sw, 6, '#ffe66b'); c.px(13 + sw, 9, '#ffe66b')
    return c.outline()

def yurei(f):  # necro slot 16x20 (drawn x2)
    c = C(16, 20)
    ph = [0, 1, 0, -1][f]
    for y in range(10, 19):
        w = 5 - (y - 10) * .35
        sw = math.sin((y + f * 2) * .9) * 1.2
        c.rect(int(8 - w + sw), y, int(8 + w + sw), y, '#e6ecff' if y < 17 else '#b9c4ff')
    c.rect(4, 10, 11, 10, '#7a4fd0'); c.rect(3, 11, 12, 12, '#7a4fd0')
    c.rect(7, 11, 8, 14, '#ffd23f')
    c.ell(8, 6, 4, 4, '#f0f4ff')
    c.rect(4, 0, 11, 3, '#241a50'); c.rect(3, 4, 12, 4, '#241a50')
    c.tri(6, 4.5, 9.5, 4.5, 7.8, 7.5, '#ffffff')
    c.rect(6, 6, 6, 7, '#1a1026'); c.rect(10, 6, 10, 7, '#1a1026')
    c.rect(7, 8, 9, 8, '#7a4fd0')
    c.rect(1, 12 + ph, 2, 14 + ph, '#e6ecff'); c.rect(13, 12 - ph, 14, 14 - ph, '#e6ecff')
    c.ell(14, 6 + ph, 1.4, 1.4, '#7fd6ff')
    return c.outline()

MOBS = {'slime': karakasa, 'goblinRun': spider, 'skelRun': skeleton, 'impRun': tengu, 'zombie': jiangshi,
        'orcIdle': lambda f: oni(f, False), 'orcRun': lambda f: oni(f, True), 'shamanRun': kitsune,
        'angelRun': chochin, 'necro': yurei}
