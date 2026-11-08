from lib import *

def phase(f, run):
    yo = (1 if f in (1, 3) else 0) if run else (1 if f in (2, 3) else 0)
    step = [(0, 1), (0, 0), (1, 0), (0, 0)][f] if run else (0, 0)
    return yo, step

def big_legs(c, step, col, boot, gy, lx=(9, 18), w=5, h=6):
    for i, x in enumerate(lx):
        lift = step[i]
        c.rect(x, gy - h - 1 - lift, x + w - 1, gy - 1 - lift, col)
        c.rect(x - 1, gy - lift, x + w, gy - lift, boot)

def oni_brute(f, run):  # 32x32
    c = C(32, 32)
    yo, step = phase(f, run)
    R, D, L = '#d8392f', '#a82020', '#ff6a5a'
    big_legs(c, step, R, '#4a1a1a', 30)
    # kanabo club raised behind-right
    c.line(27, 20 + yo, 30, 3 + yo, '#8a5a3a', 3)
    for yy in (5, 9, 13, 17): c.px(29 + (0 if yy % 8 else 1), yy + yo, '#ffe66b'); c.px(28, yy + 1 + yo, '#ffe66b')
    c.rect(26, 19 + yo, 29, 22 + yo, '#c9874a')
    # torso
    c.ell(16, 17 + yo, 9.5, 7.5, R)
    c.ell(16, 20 + yo, 6, 4, L)
    c.rect(11, 17 + yo, 21, 17 + yo, D)
    # arms
    c.ell(6.5, 17 + yo, 3.6, 5, R); c.ell(25.5, 17 + yo, 3.6, 5, R)
    c.rect(3, 20 + yo, 7, 25 + yo, R); c.rect(4, 25 + yo, 7, 26 + yo, '#ffb8a0')
    c.rect(25, 19 + yo, 29, 22 + yo, R)
    # tiger loincloth
    c.rect(9, 23 + yo, 22, 26 + yo, '#ffd23f')
    for x in (10, 13, 16, 19): c.rect(x, 23 + yo, x + 1, 26 + yo, '#2a1a10')
    c.rect(9, 23 + yo, 22, 23 + yo, '#5a2a1a')
    # head
    c.ell(16, 9 + yo, 7, 6, R)
    c.rect(9, 3 + yo, 23, 6 + yo, '#1a1026')  # hair
    c.tri(9, 5 + yo, 11, -0.5 + yo, 14, 5 + yo, '#fff2c0'); c.tri(18, 5 + yo, 21, -0.5 + yo, 23, 5 + yo, '#fff2c0')
    c.line(10, 7 + yo, 14, 9 + yo, '#1a1026', 1); c.line(22, 7 + yo, 18, 9 + yo, '#1a1026', 1)
    c.rect(12, 9 + yo, 13, 10 + yo, '#ffe66b'); c.rect(19, 9 + yo, 20, 10 + yo, '#ffe66b')
    c.rect(12, 13 + yo, 20, 13 + yo, '#1a1026')
    c.rect(12, 11 + yo, 13, 12 + yo, '#ffffff'); c.rect(19, 11 + yo, 20, 12 + yo, '#ffffff')
    return c.outline()

def gasha(f, run):  # 32x34
    c = C(32, 34)
    yo, step = phase(f, run)
    B, S = '#efe9d2', '#b9b192'
    big_legs(c, step, B, S, 33, lx=(10, 18), w=3, h=8)
    # tattered cloth
    c.rect(9, 22 + yo, 22, 27 + yo, '#5a2f7a')
    for x in range(9, 23, 3): c.rect(x, 28 + yo, x + 1, 29 + yo + (x % 2), '#5a2f7a')
    # ribcage
    c.rect(15, 11 + yo, 16, 22 + yo, S)
    for i, y in enumerate(range(12, 22, 2)):
        w = 7 - abs(i - 1)
        c.rect(16 - w, y + yo, 15 + w, y + yo, B)
    c.rect(9, 11 + yo, 22, 12 + yo, B)
    # arms: long bones with big hands
    c.line(8, 12 + yo, 4, 24 + yo, B, 2); c.ell(4, 26 + yo, 2.6, 2.6, B)
    c.line(23, 12 + yo, 27, 22 + yo, B, 2); c.ell(27.5, 24 + yo, 2.6, 2.6, B)
    for dx in (-2, 0, 2): c.px(27 + dx, 27 + yo, B)
    # giant skull
    c.ell(16, 7 + yo, 8, 6.8, B)
    c.rect(11, 11 + yo, 21, 13 + yo, B)
    c.rect(10, 5 + yo, 14, 9 + yo, '#1a1026'); c.rect(18, 5 + yo, 22, 9 + yo, '#1a1026')
    c.rect(12, 6 + yo, 13, 8 + yo, '#ff4d6d'); c.rect(20, 6 + yo, 21, 8 + yo, '#ff4d6d')
    c.tri(15, 9 + yo, 17, 9 + yo, 16, 11 + yo, '#1a1026')
    for x in range(11, 22, 2): c.rect(x, 12 + yo, x, 13 + yo, '#1a1026')
    c.rect(11, 12 + yo, 21, 12 + yo, S)
    return c.outline()

def shuten(f, run):  # 32x36
    c = C(32, 36)
    yo, step = phase(f, run)
    P, D, L = '#6b3fa0', '#472a70', '#9a6fd0'
    # cape
    c.rect(7, 14 + yo, 25, 30 + yo, '#2a1440')
    c.rect(7, 30 + yo, 25, 31 + yo + (1 if f % 2 else 0), '#2a1440')
    big_legs(c, step, '#1c1030', '#ffd23f', 35, lx=(10, 18), w=4, h=6)
    # odachi
    c.line(28, 28 + yo, 29, 4 + yo, '#ff6f9a', 2)
    c.line(28, 28 + yo, 28, 5 + yo, '#ffd6e8', 1)
    c.rect(26, 27 + yo, 31, 28 + yo, '#ffd23f'); c.rect(28, 29 + yo, 29, 31 + yo, '#3a2030')
    # armor
    c.ell(16, 19 + yo, 8.5, 6.5, '#2a1f3f')
    c.rect(11, 15 + yo, 21, 24 + yo, '#2a1f3f')
    c.rect(11, 15 + yo, 21, 15 + yo, '#ffd23f'); c.rect(11, 24 + yo, 21, 24 + yo, '#ffd23f')
    c.rect(15, 16 + yo, 16, 23 + yo, '#ffd23f')
    c.ell(7, 16 + yo, 4, 3.4, '#ffd23f'); c.ell(25, 16 + yo, 4, 3.4, '#ffd23f')
    c.rect(4, 18 + yo, 8, 26 + yo, P); c.rect(24, 18 + yo, 27, 26 + yo, P)
    c.rect(4, 26 + yo, 8, 28 + yo, '#2a1f3f')
    c.rect(26, 25 + yo, 29, 28 + yo, P)
    # head, hair, horns
    hw = [0, 1, 0, -1][f]
    c.rect(8 + hw, 8 + yo, 10 + hw, 22 + yo, '#f4f1ff'); c.rect(22 - hw, 8 + yo, 24 - hw, 22 + yo, '#f4f1ff')
    c.ell(16, 10 + yo, 7, 6.4, P)
    c.rect(9, 3 + yo, 23, 6 + yo, '#f4f1ff')
    c.tri(10, 6 + yo, 11, -0.5 + yo, 13, 5 + yo, '#ffd23f'); c.tri(15, 4 + yo, 16, -1 + yo, 17, 4 + yo, '#ffd23f'); c.tri(19, 5 + yo, 21, -0.5 + yo, 22, 6 + yo, '#ffd23f')
    c.line(10, 8 + yo, 14, 10 + yo, '#1a1026'); c.line(22, 8 + yo, 18, 10 + yo, '#1a1026')
    c.rect(12, 10 + yo, 13, 11 + yo, '#ff4d6d'); c.rect(19, 10 + yo, 20, 11 + yo, '#ff4d6d')
    c.rect(13, 14 + yo, 19, 14 + yo, '#1a1026')
    c.px(13, 13 + yo, '#ffffff'); c.px(19, 13 + yo, '#ffffff')
    c.px(16, 8 + yo, '#ff4d6d'); c.px(16, 7 + yo, '#ff4d6d')
    return c.outline()

BOSSES = {
    'ogreIdle': lambda f: oni_brute(f, False), 'ogreRun': lambda f: oni_brute(f, True),
    'wardenIdle': lambda f: gasha(f, False), 'wardenRun': lambda f: gasha(f, True),
    'kingIdle': lambda f: shuten(f, False), 'kingRun': lambda f: shuten(f, True),
}
