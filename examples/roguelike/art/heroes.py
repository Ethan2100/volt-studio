from lib import *

def legs(c, f, run, col, boot, hide=False):
    if run:
        pos = {0: (4, 19, 10, 20), 1: (5, 20, 9, 20), 2: (4, 20, 10, 19), 3: (5, 20, 9, 20)}[f]
    else:
        pos = (5, 20, 9, 20)
    lx, ly, rx, ry = pos
    for x, y in ((lx, ly), (rx, ry)):
        c.rect(x, y - 3, x + 1, y - 1, col)
        c.rect(x, y, x + 2, y, boot)

def head(c, yo, skin, eye='#2a1a3a'):
    c.ell(8, 7.5 + yo, 4.7, 4.6, skin)
    c.rect(8, 7 + yo, 8, 8 + yo, eye)
    c.rect(11, 7 + yo, 11, 8 + yo, eye)
    c.px(7, 9 + yo, '#ff9aa8'); c.px(12, 9 + yo, '#ff9aa8')

def hair(c, yo, col, dark, fringe=True):
    def inhead(x, y):
        return ((x + .5 - 8) / 5.0) ** 2 + ((y + .5 - (7.5 + yo)) / 4.9) ** 2 <= 1
    for y in range(0, 14):
        for x in range(2, 14):
            if inhead(x, y):
                top = y <= 5 + yo
                back = x <= 4 and y <= 10 + yo
                bang = fringe and y == 6 + yo and x in (5, 6, 8, 9, 12)
                if top or back or bang:
                    c.px(x, y, dark if (y == 5 + yo and x % 2 == 0) or (x <= 3) else col)

def sakura(f, run):
    c = C(16, 22)
    yo = (1 if f in (1, 3) else 0) if run else (1 if f in (2, 3) else 0)
    sway = [0, 1, 0, -1][f]
    # ponytail behind
    c.ell(2.5 + sway * .5, 9 + yo, 2, 4.5, '#ff9ad5')
    c.line(3, 5 + yo, 1 + sway, 14 + yo, '#d1609f', 1)
    legs(c, f, run, '#3a2146', '#2a1a3a')
    # hakama (crimson) + kimono top (white)
    c.rect(4, 16 + yo, 11, 18, '#c0273d')
    c.rect(4, 18, 5, 18, '#8e1c2e'); c.rect(10, 18, 11, 18, '#8e1c2e')
    c.rect(5, 12 + yo, 10, 15 + yo, '#f6efe9')
    c.rect(5, 15 + yo, 10, 15 + yo, '#d9a0b4')  # sash
    c.line(7, 12 + yo, 9, 14 + yo, '#c0273d')
    # sword arm + katana
    c.rect(11, 13 + yo, 12, 15 + yo, '#f6efe9')
    c.px(12, 15 + yo, '#ffd7b8')
    c.rect(13, 8 + yo, 13, 14 + yo, '#e6f0ff')
    c.rect(13, 14 + yo, 13, 15 + yo, '#5a2a3a')
    c.px(12, 14 + yo, '#ffd23f'); c.px(14, 14 + yo, '#ffd23f')
    c.px(13, 7 + yo, '#ffffff')
    head(c, yo, '#ffe2cc')
    hair(c, yo, '#ff9ad5', '#e0709f')
    c.rect(3, 5 + yo, 4, 6 + yo, '#c0273d')  # ribbon
    c.px(5, 3 + yo, '#ffd1ea'); c.px(10, 2 + yo, '#ffd1ea')
    return c.outline()

def ren(f, run):
    c = C(16, 22)
    yo = (1 if f in (1, 3) else 0) if run else (1 if f in (2, 3) else 0)
    sway = [0, 1, 1, 0][f] if not run else [0, 2, 0, 2][f]
    # big tail
    c.ell(2, 15 + yo - sway * .5, 2.2, 4.5, '#f0883e')
    c.ell(1.5, 11 + yo - sway * .5, 1.5, 2.2, '#fff6e8')
    legs(c, f, run, '#2c3e5c', '#1c2540')
    # haori (teal) with orange trim, white inner
    c.rect(5, 12 + yo, 10, 17 + yo, '#2f7f8a')
    c.rect(5, 12 + yo, 5, 17 + yo, '#f0883e'); c.rect(10, 12 + yo, 10, 17 + yo, '#f0883e')
    c.rect(7, 13 + yo, 8, 16 + yo, '#fff6e8')
    c.rect(5, 16 + yo, 10, 16 + yo, '#1c2540')
    # arm + kunai
    c.rect(11, 13 + yo, 12, 15 + yo, '#2f7f8a'); c.px(12, 15 + yo, '#ffe2cc')
    c.line(13, 15 + yo, 14, 11 + yo, '#d6e4ff', 1)
    c.px(13, 16 + yo, '#5a2a3a')
    # fox ears
    c.tri(3, 4 + yo, 3.5, -0.5 + yo, 7, 3 + yo, '#f0883e')
    c.tri(9, 3 + yo, 11.5, -0.8 + yo, 12.5, 4 + yo, '#f0883e')
    c.px(4, 2 + yo, '#3a2030'); c.px(11, 1 + yo, '#3a2030'); c.px(11, 2 + yo, '#3a2030')
    head(c, yo, '#ffe2cc', '#3a1a10')
    hair(c, yo, '#f0883e', '#c8641e')
    c.rect(4, 6 + yo, 12, 6 + yo, '#fff6e8')  # headband
    c.px(8, 6 + yo, '#c0273d')
    return c.outline()

def hoshi(f, run):
    c = C(16, 22)
    yo = (1 if f in (1, 3) else 0) if run else (1 if f in (2, 3) else 0)
    bob = [0, -1, 0, -1][f] if not run else 0
    # staff behind arm
    c.rect(13, 7 + yo, 13, 20, '#8a5a3a')
    c.ell(13.5, 5 + yo + bob, 1.8, 1.8, '#ffe66b')
    c.px(13, 2 + yo + bob, '#fff6b0'); c.px(13, 8 + yo + bob, '#fff6b0')
    legs(c, f, run, '#4a2a7a', '#1e1033')
    # long violet robe
    c.rect(4, 12 + yo, 11, 19, '#6a3fb0')
    c.rect(3, 17, 12, 19, '#6a3fb0')
    c.rect(4, 12 + yo, 5, 19, '#8a5fd0')
    c.rect(5, 15 + yo, 10, 15 + yo, '#ffd23f')
    c.px(8, 13 + yo, '#ffe66b'); c.px(8, 14 + yo, '#ffe66b')
    c.rect(3, 19, 12, 19, '#4a2a7a')
    # sleeve + hand
    c.rect(11, 13 + yo, 13, 15 + yo, '#8a5fd0'); c.px(13, 14 + yo, '#ffe2cc')
    head(c, yo, '#ffe2cc', '#241a50')
    hair(c, yo, '#c8b6ff', '#9a86e0')
    # tall eboshi hat
    c.rect(5, 0 + yo, 10, 3 + yo, '#241a50')
    c.rect(4, 4 + yo, 11, 4 + yo, '#241a50')
    c.px(7, 1 + yo, '#ffd23f'); c.px(8, 2 + yo, '#ffd23f'); c.px(8, 1 + yo, '#ffe66b')
    return c.outline()

HEROES = {'lady': sakura, 'elf': ren, 'mage': hoshi}
